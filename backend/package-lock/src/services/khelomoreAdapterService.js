'use strict';

/**
 * Khelomore Adapter Service — translation layer between Khelomore's aggregator
 * contract and the internal Nahata services. See .kiro/specs/khelomore-api-adapter/design.md.
 *
 * IMPORTANT — external contract assumptions:
 * The design doc specifies the FLOW and the response envelope ({status, data})
 * but not every field name Khelomore sends/expects. The request parsers below
 * accept several common field-name variants, and every response shape is built
 * in ONE place per endpoint so it is trivial to reconcile against Khelomore's
 * live API. Anything marked "ASSUMPTION" should be confirmed against Khelomore's
 * real payloads during integration testing.
 */

const { Court, Booking, User, sequelize } = require('../models');
const { Op, Transaction } = require('sequelize');
const courtService = require('./courtService');
const bookingService = require('./bookingService');
const sessionStore = require('./khelomoreSessionStore');
const authService = require('./authService');
const { getPartnerEmail, DEFAULT_PARTNER_SOURCE } = require('../config/partnerSources');

const httpError = (status, message) => Object.assign(new Error(message), { status });

// ── helpers ───────────────────────────────────────────────────────────────────

const pad2 = (v) => String(v ?? '').padStart(2, '0');

/** Normalise a time to "HH:MM:SS" (accepts "16:00", "16:00:00", "4:00"). */
function normTime(t) {
  if (t === null || t === undefined || t === '') return null;
  const [h, m = '00', s = '00'] = String(t).trim().split(':');
  if (Number.isNaN(parseInt(h, 10))) return null;
  return `${pad2(parseInt(h, 10))}:${pad2(parseInt(m, 10))}:${pad2(parseInt(s, 10))}`;
}

/**
 * Cached id of a partner's service account, keyed by source label.
 *
 * Each partner books under its OWN account so its bookings are attributable, with
 * the shared KHELOMORE_SERVICE_EMAIL account as the fallback for any partner that
 * has no dedicated one yet.
 */
const _serviceUserIds = new Map();
async function resolveServiceUserId(source) {
  const cacheKey = source || '__default__';
  if (_serviceUserIds.has(cacheKey)) return _serviceUserIds.get(cacheKey);

  const candidates = [...new Set([getPartnerEmail(source), process.env.KHELOMORE_SERVICE_EMAIL].filter(Boolean))];
  if (!candidates.length) {
    throw httpError(503, `No service account configured for "${source}" (set PARTNERS_JSON or KHELOMORE_SERVICE_EMAIL)`);
  }

  for (const email of candidates) {
    const user = await User.findOne({ where: { email } });
    if (user) {
      _serviceUserIds.set(cacheKey, user.id);
      return user.id;
    }
  }
  throw httpError(503, `Service account not found for "${source}" (tried: ${candidates.join(', ')})`);
}

/**
 * Resolve Khelomore's "court" reference to a Court row.
 * ASSUMPTION: Khelomore references our courts by external uuid / external id /
 * court name. Tried in that order, then our internal id.
 */
async function resolveCourt(courtRef) {
  if (courtRef === null || courtRef === undefined || courtRef === '') throw httpError(400, 'court is required');
  const ref = String(courtRef).trim();

  if (/^[0-9a-f]{8}-[0-9a-f-]{20,}$/i.test(ref)) {
    const c = await Court.findOne({ where: { externalResourceUuid: ref } });
    if (c) return c;
  }
  if (/^\d+$/.test(ref)) {
    const n = parseInt(ref, 10);
    const byExt = await Court.findOne({ where: { externalResourceId: n } });
    if (byExt) return byExt;
    const byId = await Court.findByPk(n);
    if (byId) return byId;
  }
  const byName = await Court.findOne({ where: { name: { [Op.iLike]: ref } } });
  if (byName) return byName;

  throw httpError(400, `Court not found for reference "${ref}"`);
}

/**
 * Parse Khelomore's "slots" into sorted intervals.
 * Accepts: ["16:00-17:00"], [{startTime,endTime}], [{start,end}], [{start_time,end_time}].
 * The booking is created as ONE record spanning earliest start → latest end.
 * ASSUMPTION: slots are contiguous (the typical aggregator case).
 */
function parseSlots(slots) {
  if (!slots) throw httpError(400, 'slots are required');
  const arr = Array.isArray(slots) ? slots : [slots];
  const intervals = arr
    .map((s) => {
      if (typeof s === 'string') {
        const [a, b] = s.split('-').map((x) => x.trim());
        return { startTime: normTime(a), endTime: normTime(b) };
      }
      return {
        startTime: normTime(s.startTime || s.start || s.start_time || s.from),
        endTime: normTime(s.endTime || s.end || s.end_time || s.to),
      };
    })
    .filter((i) => i.startTime && i.endTime);

  if (!intervals.length) throw httpError(400, 'no valid slots provided');
  intervals.sort((a, b) => a.startTime.localeCompare(b.startTime));
  return intervals;
}

// ── endpoint translations ───────────────────────────────────────────────────

/** POST /api/login */
async function login(email, password) {
  if (!email || !password) throw httpError(400, 'email and password are required');
  const result = await authService.login(email, password);
  return { user_id: result.user.id, name: result.user.name, email: result.user.email };
}

/**
 * POST /api/save-booking — creates a Pending booking + session for the calling partner.
 * `source` comes from the API key the caller authenticated with (req.partnerSource).
 */
async function saveBooking({ date, court, slots, amount, notes }, source = DEFAULT_PARTNER_SOURCE) {
  if (!date) throw httpError(400, 'date is required');
  const partnerSource = source || DEFAULT_PARTNER_SOURCE;
  const userId = await resolveServiceUserId(partnerSource);
  const courtRow = await resolveCourt(court);
  const intervals = parseSlots(slots);
  const startTime = intervals[0].startTime;
  const endTime = intervals[intervals.length - 1].endTime;
  const holdMin = parseInt(process.env.KHELOMORE_HOLD_MINUTES || '30', 10);

  // SERIALIZABLE + row lock (createCourtBooking locks its conflict scan when a
  // transaction is passed) so a Khelomore save can't double-book against the site.
  const booking = await sequelize.transaction(
    { isolationLevel: Transaction.ISOLATION_LEVELS.SERIALIZABLE },
    async (t) => courtService.createCourtBooking(
      {
        userId,
        courtId: courtRow.id,
        date,
        startTime,
        endTime,
        totalAmount: amount,
        notes: notes || `${partnerSource} booking`,
        bookingSource: partnerSource,
        bookingStatus: 'Pending',
        holdExpiresAt: new Date(Date.now() + holdMin * 60 * 1000),
      },
      t,
    ),
  );

  const session = sessionStore.create({
    bookingId: booking.id, courtId: courtRow.id, date, startTime, endTime, amount,
  });

  return {
    booking_id: booking.id,
    session_id: session.token, // Khelomore should echo this as X-Khelomore-Session (or booking_id) on summary/finalize
    court: courtRow.name,
    court_id: courtRow.id,
    date,
    start_time: startTime,
    end_time: endTime,
    amount: parseFloat(booking.totalAmount),
    // Null until /finalize-booking: an unpaid hold has no pass.
    pass_code: booking.passCode,
    qr_code: booking.qrCode,
  };
}

/** GET /api/booking-summary — reads the pending booking from the session. */
async function bookingSummary(session) {
  const booking = await bookingService.getBookingById(session.bookingId);
  return {
    booking_id: booking.id,
    court: booking.court?.name,
    sport: booking.sport?.name,
    venue: booking.court?.SportComplex?.name || null,
    date: booking.date,
    start_time: booking.startTime,
    end_time: booking.endTime,
    amount: parseFloat(booking.totalAmount),
    status: booking.bookingStatus,
    payment_status: booking.paymentStatus,
    pass_code: booking.passCode,
    qr_code: booking.qrCode,
  };
}

/** POST /api/finalize-booking — marks the held booking Paid/Confirmed. */
async function finalizeBooking(session, payload) {
  const booking = await Booking.findByPk(session.bookingId);
  if (!booking || booking.isDeleted) throw httpError(404, 'Booking not found');

  await booking.update({
    paymentStatus: 'Paid',
    bookingStatus: 'Confirmed',
    holdExpiresAt: null, // hold released; booking is permanent
    transactionId: payload.razorpay_payment_id || payload.payment_id || booking.transactionId,
  });

  // The pass is issued here, on payment — /save-booking only creates an unpaid
  // hold, so pass_code/qr_code are null there and populated from this call on.
  await courtService.issueBookingPass(booking);

  // The admin bell alert also belongs to the payment, not to the hold.
  try {
    courtService.notifyAdminsOfBooking(await bookingService.getBookingById(booking.id));
  } catch (err) {
    console.error('khelomore finalize notify error:', err.message);
  }

  sessionStore.remove(session.token);

  // NOTE: we do NOT send our own confirmation email here — the booking is owned
  // by the Khelomore service account, and Khelomore notifies the end customer.
  return {
    booking_id: booking.id,
    payment_id: payload.razorpay_payment_id || payload.payment_id || null,
    amount_paid: payload.amount_paid != null ? Number(payload.amount_paid) : parseFloat(booking.totalAmount),
    status: 'Confirmed',
    pass_code: booking.passCode,
    qr_code: booking.qrCode,
  };
}

/**
 * POST /api/block-slot — the partner marks one court+date+interval unavailable.
 *
 * Distinct from /save-booking: a block is NOT a reservation. No customer, no
 * pass, no QR, no admin alert, and it never counts as revenue. It exists purely
 * to take the slot off sale on our side when the partner sells or holds it
 * elsewhere. The slot disappears from /fetchslots, the website and the admin
 * panel immediately, and shows in Blocked Slots badged with the partner's name.
 *
 * Idempotent: blocking an already-blocked slot returns the existing block.
 */
async function blockSlot({ courtId, court, date, startTime, endTime, totalAmount, amount, notes }, source = DEFAULT_PARTNER_SOURCE) {
  if (!date) throw httpError(400, 'date is required');

  const partnerSource = source || DEFAULT_PARTNER_SOURCE;
  // Accept `courtId` (their stated field) or `court` (the /save-booking field),
  // both resolved through the same court reference rules.
  const courtRow = await resolveCourt(courtId != null && courtId !== '' ? courtId : court);

  const start = normTime(startTime);
  const end = normTime(endTime);
  if (!start || !end) throw httpError(400, 'startTime and endTime are required (HH:MM)');

  let block;
  try {
    block = await courtService.createSlotBlock({
      courtId: courtRow.id,
      date,
      startTime: start,
      endTime: end,
      blockedBy: partnerSource,
      // Recorded for the partner's own reconciliation; we never bill it.
      amount: totalAmount != null ? totalAmount : amount,
      notes: notes || `Blocked by ${partnerSource}`,
    });
  } catch (err) {
    // A real customer already holds it — 409 so the partner can re-sync rather
    // than treat it as a transient failure and retry forever.
    if (err.code === 'SLOT_BOOKED') throw httpError(409, err.message);
    throw err;
  }

  return {
    block_id: block.id,
    court: courtRow.name,
    court_id: courtRow.id,
    date: block.date,
    start_time: block.startTime,
    end_time: block.endTime,
    amount: parseFloat(block.totalAmount),
    blocked_by: block.blockedBy,
    status: 'Blocked',
  };
}

/**
 * POST /api/unblock-slot — release a block and put the slot back on sale.
 *
 * Identified by the `block_id` we returned, or by court+date+startTime for a
 * partner that stored nothing. A partner may only release its OWN blocks.
 *
 * Idempotent: releasing an already-released (or unknown) block returns
 * already_released rather than an error, so retries are safe.
 */
async function unblockSlot({ blockId, block_id, courtId, court, date, startTime }, source = DEFAULT_PARTNER_SOURCE) {
  const partnerSource = source || DEFAULT_PARTNER_SOURCE;
  const id = blockId != null ? blockId : block_id;

  let courtRowId = null;
  if (!id) {
    if (!date || !startTime) throw httpError(400, 'Provide block_id, or courtId + date + startTime');
    const courtRow = await resolveCourt(courtId != null && courtId !== '' ? courtId : court);
    courtRowId = courtRow.id;
  }

  const released = await courtService.releaseSlotBlock({
    blockId: id,
    courtId: courtRowId,
    date,
    startTime: normTime(startTime),
    // Scoped to the caller: KheloMore cannot release a Huddle or Admin block.
    blockedBy: partnerSource,
  });

  if (!released) {
    return { block_id: id || null, status: 'already_released' };
  }

  return {
    block_id: released.id,
    court_id: released.courtId,
    date: released.date,
    start_time: released.startTime,
    end_time: released.endTime,
    status: 'Unblocked',
  };
}

/**
 * GET /fetchslots?date=YYYY-MM-DD — availability across the Khelomore-mapped
 * courts, shaped as { "YYYY-MM": { "YYYY-MM-DD": { any: [ ...freeSlots ] } } }.
 * "any" = available on at least one court (aggregated, cheapest price kept).
 */
async function fetchSlots(date) {
  if (!date) throw httpError(400, 'date is required');

  const complexId = process.env.KHELOMORE_SPORT_COMPLEX_ID
    ? parseInt(process.env.KHELOMORE_SPORT_COMPLEX_ID, 10)
    : null;

  // Prefer the courts explicitly mapped to Khelomore (externalResourceId set).
  const where = { externalResourceId: { [Op.ne]: null } };
  if (complexId) where.sportComplexId = complexId;
  let courts = await Court.findAll({ where });
  if (!courts.length) {
    const fb = { status: 'Active' };
    if (complexId) fb.sportComplexId = complexId;
    courts = await Court.findAll({ where: fb });
  }

  const agg = new Map(); // "start-end" -> { start_time, end_time, price, available }
  for (const c of courts) {
    let slots = [];
    try { slots = await courtService.getAvailableSlots(c.id, date); } catch { slots = []; }
    for (const s of slots) {
      const key = `${s.startTime}-${s.endTime}`;
      const free = !s.isBooked;
      const prev = agg.get(key);
      if (!prev) agg.set(key, { start_time: s.startTime, end_time: s.endTime, price: s.price, available: free });
      else { prev.available = prev.available || free; if (free) prev.price = Math.min(prev.price, s.price); }
    }
  }

  const any = [...agg.values()].filter((x) => x.available).sort((a, b) => a.start_time.localeCompare(b.start_time));
  const ym = date.slice(0, 7);
  return { [ym]: { [date]: { any } } };
}

module.exports = {
  login,
  saveBooking,
  bookingSummary,
  finalizeBooking,
  blockSlot,
  unblockSlot,
  fetchSlots,
  // exported for tests
  _internals: { normTime, parseSlots, resolveCourt, resolveServiceUserId },
};
