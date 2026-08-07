'use strict';

const { Court, CourtSlot, SportComplex, Sport, Booking, BookingMember, User, sequelize } = require('../models');
const { Op, Transaction } = require('sequelize');
const slotEngine = require('./slotEngineService');
const { toMinutes, toEndMinutes, toTimeString } = require('../utils/timeIntervals');
const logger = require('../utils/logger');

const payLog = logger.child({ module: 'payment' });

/** Roles allowed to finalize/act on any booking (not just their own). */
const STAFF_ROLES = new Set(['ADMIN', 'SUPER_ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE']);
const isStaffUser = (user) => !!user && STAFF_ROLES.has(String(user.role || '').toUpperCase());

const DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

/** Minutes a Pending public hold survives before its slot frees again. */
const HOLD_TTL_MINUTES = 10;

// ── QR helpers (same pattern as eventPassService) ─────────────────────────────

/** Unique pass code: BOOK-<year>-<bookingId padded to 6 digits> */
function generateBookingPassCode(bookingId) {
  const year = new Date().getFullYear();
  const bid = String(bookingId).padStart(6, '0');
  return `BOOK-${year}-${bid}`;
}

/** QR code image URL via free QR Server API */
function buildQrUrl(passCode) {
  return `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(passCode)}&format=png&margin=10`;
}

/** Per-member pass code: <bookingPassCode>-M<idx padded 2> e.g. BOOK-2026-000042-M01 */
function generateMemberPassCode(bookingPassCode, bookingId, idx) {
  const base = bookingPassCode || generateBookingPassCode(bookingId);
  return `${base}-M${String(idx).padStart(2, '0')}`;
}

/**
 * Payment states where the venue is NOT holding the customer's money, so no
 * pass may be valid no matter what bookingStatus says.
 *
 * 'Refunded' is the important one: refunding from the admin panel writes ONLY
 * paymentStatus and leaves bookingStatus 'Confirmed'. Without this list the
 * `bookingStatus === 'Confirmed'` fallback below kept the QR working, so a
 * customer could be refunded in full and still walk in.
 */
const NON_PASS_PAYMENT_STATUSES = ['Refunded', 'Failed'];

/**
 * A booking's pass only exists once the money is in: paymentStatus 'Paid'.
 * Staff may also hand out a pass for a booking they have confirmed manually
 * (cash at the counter → bookingStatus 'Confirmed'), but a Pending website
 * hold — which is what an abandoned/cancelled Razorpay checkout leaves behind —
 * is never pass-worthy, and neither is a booking whose money has gone back.
 */
function isPassEligible(booking) {
  if (!booking || booking.isDeleted || booking.bookingStatus === 'Cancelled') return false;
  // Checked BEFORE the Confirmed fallback — a refund must override it.
  if (NON_PASS_PAYMENT_STATUSES.includes(booking.paymentStatus)) return false;
  return booking.paymentStatus === 'Paid' || booking.bookingStatus === 'Confirmed';
}

/** Shared with bookingService so manual admin edits use the same rule. */
exports.isPassEligible = isPassEligible;
exports.NON_PASS_PAYMENT_STATUSES = NON_PASS_PAYMENT_STATUSES;

/**
 * Why a pass was refused, in words the guard on the gate can act on. A refunded
 * booking is NOT "payment incomplete" — telling staff that sends them chasing a
 * payment that was deliberately returned.
 */
function passRejectionMessage(booking) {
  if (booking && booking.paymentStatus === 'Refunded') {
    return 'This booking was refunded. The pass is no longer valid — entry denied.';
  }
  if (booking && booking.paymentStatus === 'Failed') {
    return 'Payment for this booking failed. This pass is not valid.';
  }
  return 'Payment for this booking is not complete. This pass is not valid.';
}

/**
 * Issue the QR pass for a booking — idempotent, and the ONLY place a booking
 * pass is minted. Called after a payment is verified (or when staff confirm an
 * offline booking), never at booking-creation time.
 *
 * @param {number|object} bookingOrId  booking id or a loaded Booking instance
 * @param {object|null} transaction    optional sequelize transaction
 * @returns {Promise<object|null>} the booking with passCode/qrCode set
 */
exports.issueBookingPass = async (bookingOrId, transaction = null) => {
  const booking = (bookingOrId && typeof bookingOrId === 'object')
    ? bookingOrId
    : await Booking.findByPk(bookingOrId, { transaction });
  if (!booking) return null;
  if (booking.passCode && booking.qrCode) return booking; // already issued

  const passCode = booking.passCode || generateBookingPassCode(booking.id);
  const qrCode = booking.qrCode || buildQrUrl(passCode);
  await booking.update({ passCode, qrCode }, { transaction });
  return booking;
};

/**
 * Validate that "now" is STRICTLY inside the booking's time slot — the pass is
 * only valid between startTime and endTime on the booking date (no early grace).
 * Returns { ok, message }.
 * Guards the "24:00:00" midnight-close value, which is not a valid JS Date.
 */
function checkBookingTimeWindow(booking) {
  if (!booking || !booking.date) return { ok: true };
  const now = new Date();
  const norm = (t, fallback) => {
    if (!t) return fallback;
    return t === '24:00:00' ? '23:59:59' : t;
  };
  const startStr = `${booking.date}T${norm(booking.startTime, '00:00:00')}`;
  const endStr   = `${booking.date}T${norm(booking.endTime, '23:59:59')}`;
  const start = new Date(startStr);
  const end   = new Date(endStr);
  if (isNaN(start) || isNaN(end)) return { ok: true }; // can't validate — don't block

  const fmt = (t) => {
    if (!t) return '';
    const [h, m] = t.split(':').map(Number);
    const ampm = h >= 12 ? 'PM' : 'AM';
    return `${h % 12 || 12}:${String(m).padStart(2, '0')} ${ampm}`;
  };

  if (now < start) {
    return { ok: false, message: `This pass is only valid from ${fmt(booking.startTime)}. Please come within your booked slot.` };
  }
  if (now > end) {
    return { ok: false, message: 'Booking time has ended. This pass is no longer valid.' };
  }
  return { ok: true };
}

// ── Courts CRUD ───────────────────────────────────────────────────────────────

exports.getAllCourts = async (filters = {}, page = 1, limit = 20) => {
  const where = {};
  if (filters.status) where.status = filters.status;
  if (filters.sportComplexId) where.sportComplexId = filters.sportComplexId;
  if (filters.sportId) where.sportId = filters.sportId;
  if (filters.showOnFrontend !== undefined) where.showOnFrontend = filters.showOnFrontend;

  const offset = (page - 1) * limit;
  const { count, rows } = await Court.findAndCountAll({
    where,
    include: [
      { model: SportComplex, attributes: ['id', 'name', 'city', 'address'] },
      { model: Sport, attributes: ['id', 'name', 'category'] },
      { model: CourtSlot, as: 'slots', where: { status: 'Active' }, required: false },
    ],
    order: [['createdAt', 'DESC']],
    limit,
    offset,
  });

  return {
    courts: rows,
    currentPage: page,
    totalPages: Math.ceil(count / limit),
    totalItems: count,
    itemsPerPage: limit,
  };
};

exports.getCourtById = async (id) => {
  return Court.findByPk(id, {
    include: [
      { model: SportComplex, attributes: ['id', 'name', 'city', 'address', 'contactPhone'] },
      { model: Sport, attributes: ['id', 'name', 'category', 'image'] },
      { model: CourtSlot, as: 'slots', where: { status: 'Active' }, required: false },
    ],
  });
};

exports.createCourt = async (data) => {
  const court = await Court.create({
    sportComplexId: data.sportComplexId,
    sportId: data.sportId,
    name: data.name,
    description: data.description || null,
    capacity: data.capacity || null,
    surfaceType: data.surfaceType || 'Synthetic',
    lightingAvailable: data.lightingAvailable || false,
    equipmentAvailable: data.equipmentAvailable || null,
    hourlyRate: parseFloat(data.hourlyRate) || 0,
    status: data.status || 'Active',
    image: data.image || null,
  });

  if (data.slots && Array.isArray(data.slots) && data.slots.length > 0) {
    const slotRecords = data.slots
      .filter((s) => s.startTime && s.endTime)
      .map((s) => ({
        courtId: court.id,
        startTime: s.startTime,
        endTime: s.endTime,
        availableDays: Array.isArray(s.availableDays)
          ? s.availableDays.join(',')
          : s.availableDays || 'Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday',
        slotType: s.slotType || 'Regular',
        priceOverride: s.priceOverride ? parseFloat(s.priceOverride) : null,
        status: 'Active',
      }));
    if (slotRecords.length > 0) await CourtSlot.bulkCreate(slotRecords);
  }

  return exports.getCourtById(court.id);
};

exports.updateCourt = async (id, data) => {
  const court = await Court.findByPk(id);
  if (!court) return null;

  await court.update({
    sportComplexId: data.sportComplexId ?? court.sportComplexId,
    sportId: data.sportId ?? court.sportId,
    name: data.name ?? court.name,
    description: data.description !== undefined ? data.description : court.description,
    capacity: data.capacity !== undefined ? data.capacity : court.capacity,
    surfaceType: data.surfaceType ?? court.surfaceType,
    lightingAvailable: data.lightingAvailable !== undefined ? data.lightingAvailable : court.lightingAvailable,
    equipmentAvailable: data.equipmentAvailable !== undefined ? data.equipmentAvailable : court.equipmentAvailable,
    hourlyRate: data.hourlyRate !== undefined ? parseFloat(data.hourlyRate) : court.hourlyRate,
    status: data.status ?? court.status,
    image: data.image !== undefined ? data.image : court.image,
    showOnFrontend: data.showOnFrontend !== undefined ? data.showOnFrontend : court.showOnFrontend,
  });

  if (data.slots && Array.isArray(data.slots)) {
    await CourtSlot.destroy({ where: { courtId: id } });
    const slotRecords = data.slots
      .filter((s) => s.startTime && s.endTime)
      .map((s) => ({
        courtId: id,
        startTime: s.startTime,
        endTime: s.endTime,
        availableDays: Array.isArray(s.availableDays)
          ? s.availableDays.join(',')
          : s.availableDays || 'Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday',
        slotType: s.slotType || 'Regular',
        priceOverride: s.priceOverride ? parseFloat(s.priceOverride) : null,
        status: 'Active',
      }));
    if (slotRecords.length > 0) await CourtSlot.bulkCreate(slotRecords);
  }

  return exports.getCourtById(id);
};

exports.deleteCourt = async (id) => {
  const court = await Court.findByPk(id);
  if (!court) return false;
  await court.destroy();
  return true;
};

// ── Available slots for a court on a specific date ────────────────────────────

exports.getAvailableSlots = async (courtId, dateStr) => {
  const court = await Court.findByPk(courtId, {
    include: [{ model: CourtSlot, as: 'slots', required: false }],
  });
  if (!court) throw new Error('Court not found');

  const date = new Date(dateStr + 'T00:00:00');
  const dayName = DAYS[date.getDay()];

  const daySlots = (court.slots || []).filter((slot) => {
    const days = slot.availableDays ? slot.availableDays.split(',').map((d) => d.trim()) : [];
    return days.includes(dayName);
  });

  const existingBookings = await Booking.findAll({
    where: {
      courtId,
      date: dateStr,
      isDeleted: false,
      bookingStatus: { [Op.notIn]: ['Cancelled'] },
    },
    attributes: ['id', 'startTime', 'endTime', 'isBlocked', 'blockedBy', 'notes'],
  });

  // Occupancy is matched by OVERLAP, not by an exact "start-end" string. A
  // 2-hour booking or block (18:00-20:00) does not equal either 1-hour slot key,
  // so exact matching left both hours looking free here while the booking-create
  // conflict scan (which is interval-based) rejected them at checkout.
  const occupants = existingBookings.map((b) => ({
    row: b,
    startMin: toMinutes(b.startTime),
    endMin: toEndMinutes(b.endTime, toMinutes(b.startTime)),
  }));

  return daySlots.map((slot) => {
    const slotStart = toMinutes(slot.startTime);
    const slotEnd = toEndMinutes(slot.endTime, slotStart);
    // Half-open [start, end): 9-10 and 10-11 abut, they do not overlap.
    const covering = occupants.filter((o) => o.startMin < slotEnd && o.endMin > slotStart);

    // A block and a customer booking both occupy the slot but mean opposite
    // things to whoever is looking at the screen, so they stay separate.
    const isSlotBookedByUser = covering.some((o) => !o.row.isBlocked);
    const block = (covering.find((o) => o.row.isBlocked) || {}).row || null;
    // An Inactive template blocks this slot on EVERY date, not just this one.
    const isSlotInactive = slot.status === 'Inactive';

    return {
      id: slot.id,
      startTime: slot.startTime,
      endTime: slot.endTime,
      slotType: slot.slotType,
      price: slot.priceOverride !== null ? parseFloat(slot.priceOverride) : parseFloat(court.hourlyRate),
      status: slot.status,
      isBooked: isSlotInactive || isSlotBookedByUser || !!block,
      isUserBooked: isSlotBookedByUser,
      // Block detail — lets the Blocked Slots screen show WHO blocked it and
      // gives it the id to release. 'Template' = the all-dates legacy toggle.
      isBlocked: isSlotInactive || !!block,
      blockedBy: block ? block.blockedBy : (isSlotInactive ? 'Template' : null),
      blockId: block ? block.id : null,
      blockNotes: block ? block.notes : null,
    };
  });
};

// ── Court-hidden availability (auto slot adjustment) ──────────────────────────

/**
 * Load the equivalent-court pool for a sport+venue on a date as plain objects
 * the pure slot engine can consume: each court with its weekday-active CourtSlot
 * templates, plus that date's live bookings across those courts.
 *
 * NOTE: live courts use status='Active' (DB enum is Active/Inactive).
 * showOnFrontend is intentionally not filtered — the public flow has always
 * booked across all active courts of the sport+venue.
 */
async function loadAvailabilityData(sportComplexId, sportId, dateStr, transaction = null) {
  const date = new Date(dateStr + 'T00:00:00');
  const dayName = DAYS[date.getDay()];

  const courts = await Court.findAll({
    where: { sportComplexId, sportId, status: 'Active' },
    include: [{ model: CourtSlot, as: 'slots', where: { status: 'Active' }, required: false }],
    transaction,
  });

  const courtObjs = courts.map((c) => ({
    id: c.id,
    capacity: c.capacity,
    hourlyRate: c.hourlyRate,
    externalResourceId: c.externalResourceId,
    slots: (c.slots || [])
      .filter((s) => s.availableDays.split(',').map((d) => d.trim()).includes(dayName))
      .map((s) => ({ startTime: s.startTime, endTime: s.endTime, slotType: s.slotType, priceOverride: s.priceOverride })),
  }));

  const courtIds = courtObjs.map((c) => c.id);
  let bookingObjs = [];
  if (courtIds.length) {
    const bookings = await Booking.findAll({
      where: {
        courtId: { [Op.in]: courtIds },
        date: dateStr,
        isDeleted: false,
        bookingStatus: { [Op.notIn]: ['Cancelled'] },
      },
      // isBlocked is required by the engine's movable check — a block is pinned
      // to its court and must never be relocated.
      attributes: ['id', 'courtId', 'userId', 'startTime', 'endTime', 'bookingStatus', 'holdExpiresAt', 'bookingSource', 'maxPersons', 'isDeleted', 'isBlocked'],
      transaction,
      ...(transaction ? { lock: transaction.LOCK.UPDATE } : {}),
    });
    bookingObjs = bookings.map((b) => b.get({ plain: true }));
  }

  return { courts: courtObjs, bookings: bookingObjs };
}

/** Group courts by hourlyRate — each rate is an independent move pool (same-price equivalence). */
function groupByRate(courts) {
  const groups = new Map();
  for (const c of courts) {
    const key = String(parseFloat(c.hourlyRate));
    if (!groups.has(key)) groups.set(key, []);
    groups.get(key).push(c);
  }
  return [...groups.values()];
}

function preferAvailable(best, candidate) {
  if (!best) return true;
  if (best.requiresRearrangement && !candidate.requiresRearrangement) return true;
  if (best.requiresRearrangement === candidate.requiresRearrangement) return candidate.price < best.price;
  return false;
}

/**
 * Court-hidden availability for one (startTime, duration). Returns only what the
 * public UI should see (no court identity). The booking-create path recomputes
 * the host/moves under a lock, so we deliberately omit them here.
 */
exports.getCourtAvailability = async ({ sportComplexId, sportId, date, startTime, durationMinutes, maxMoves = 2 }) => {
  const { courts, bookings } = await loadAvailabilityData(sportComplexId, sportId, date);
  const now = new Date();
  let best = null;
  let bestFallback = null;

  for (const group of groupByRate(courts)) {
    const r = slotEngine.computeAvailability({ courts: group, bookings, now, startTime, durationMinutes, maxMoves });
    if (r.available) {
      if (preferAvailable(best, r)) best = r;
    } else if (r.fallback) {
      const bf = r.fallback;
      const better = !bestFallback
        || bf.durationMinutes > bestFallback.durationMinutes
        || (bf.durationMinutes === bestFallback.durationMinutes && bf.price < bestFallback.price);
      if (better) bestFallback = bf;
    }
  }

  const endTime = toTimeString(toMinutes(startTime) + durationMinutes);
  if (best) {
    return {
      available: true,
      requiresRearrangement: best.requiresRearrangement,
      startTime,
      endTime,
      durationMinutes,
      price: best.price,
      fallback: null,
    };
  }
  return { available: false, requiresRearrangement: false, startTime, endTime, durationMinutes, price: null, fallback: bestFallback };
};

/**
 * Court-hidden grid of candidate start-times for a chosen duration. Merges the
 * per-rate-group grids, keeping the best cell per start-time (available wins,
 * then no-rearrangement, then cheapest).
 */
exports.getAvailableStartTimes = async ({ sportComplexId, sportId, date, durationMinutes, maxMoves = 2, gridStepMinutes = 60 }) => {
  const { courts, bookings } = await loadAvailabilityData(sportComplexId, sportId, date);
  const now = new Date();
  const merged = new Map();

  for (const group of groupByRate(courts)) {
    const grid = slotEngine.listBookableStartTimes({ courts: group, bookings, now, durationMinutes, maxMoves, gridStepMinutes });
    for (const cell of grid) {
      const existing = merged.get(cell.startTime);
      if (!existing) { merged.set(cell.startTime, cell); continue; }
      const better =
        (cell.available && !existing.available) ||
        (cell.available && existing.available && (
          (existing.requiresRearrangement && !cell.requiresRearrangement) ||
          (existing.requiresRearrangement === cell.requiresRearrangement && (cell.price ?? Infinity) < (existing.price ?? Infinity))
        ));
      if (better) merged.set(cell.startTime, cell);
    }
  }

  return [...merged.values()].sort((a, b) => a.startTime.localeCompare(b.startTime));
};

// ── Court Bookings ────────────────────────────────────────────────────────────

/**
 * Normalize a midnight close ("00:00:00") to "24:00:00" so SQL TIME comparisons
 * and downstream minute math treat it as end-of-day (1440), not 0. Without this
 * an interval ending at midnight is invisible to the half-open overlap check
 * (startTime < "00:00:00" is never true), risking a double booking.
 */
function normalizeEndTime(startTime, endTime) {
  return toMinutes(endTime) <= toMinutes(startTime) ? '24:00:00' : endTime;
}

/**
 * "18:00" | "18:00:00" -> "18:00:00", so a partner sending HH:MM and our stored
 * SQL TIME compare equal. Returns null for empty input.
 */
function normalizeTimeString(t) {
  if (t === null || t === undefined || t === '') return null;
  return toTimeString(toMinutes(t));
}

/**
 * The single occupancy check for a court+date interval — used by BOTH real
 * bookings and slot blocks so the two can never disagree about what is free.
 *
 * Half-open overlap [start, end): abutting intervals (9-10 / 10-11) do NOT
 * conflict. Expired Pending holds are treated as free. Blocks are ordinary
 * occupants here, so a block stops a booking and a booking stops a block.
 *
 * Pass a transaction to take a row lock (SERIALIZABLE callers rely on this).
 */
async function findConflictingBooking({ courtId, date, startTime, endTime }, transaction = null) {
  const now = new Date();
  return Booking.findOne({
    where: {
      courtId,
      date,
      isDeleted: false,
      bookingStatus: { [Op.notIn]: ['Cancelled'] },
      startTime: { [Op.lt]: endTime },
      endTime: { [Op.gt]: startTime },
      [Op.or]: [
        { holdExpiresAt: null },
        { holdExpiresAt: { [Op.gt]: now } },
      ],
    },
    transaction,
    ...(transaction ? { lock: transaction.LOCK.UPDATE } : {}),
  });
}

exports.createCourtBooking = async (data, transaction = null) => {
  const court = await Court.findByPk(data.courtId, { transaction });
  if (!court) throw new Error('Court not found');

  const endTime = normalizeEndTime(data.startTime, data.endTime);

  const conflict = await findConflictingBooking(
    { courtId: data.courtId, date: data.date, startTime: data.startTime, endTime },
    transaction,
  );

  if (conflict) {
    // A block is not "booked" — say so, or staff chase a customer who doesn't exist.
    const what = conflict.isBlocked
      ? `Slot is blocked by ${conflict.blockedBy || 'the venue'}`
      : 'Slot already booked';
    throw new Error(`${what}: courtId ${data.courtId} on ${data.date} from ${data.startTime} to ${data.endTime}`);
  }

  // ── Coupon handling ───────────────────────────────────────────────────────
  const couponService = require('./couponService');
  let couponCode = null;
  let discountAmount = 0;
  const originalAmount = parseFloat(data.totalAmount) || 0;
  let finalAmount = originalAmount;

  if (data.couponCode && data.couponCode.trim()) {
    const coupon = await couponService.validateCoupon(data.couponCode.trim(), {
      appliesTo: 'Court',
      sportComplexId: court.sportComplexId,
      sportId: court.sportId,
      // Undefined for admin/partner-created bookings → platform not enforced.
      platform: data.platform,
    });

    if (coupon.discountType === 'Percentage') {
      discountAmount = (originalAmount * parseFloat(coupon.discountValue)) / 100;
      if (coupon.maxDiscount && discountAmount > parseFloat(coupon.maxDiscount)) {
        discountAmount = parseFloat(coupon.maxDiscount);
      }
    } else {
      discountAmount = parseFloat(coupon.discountValue);
      if (discountAmount > originalAmount) discountAmount = originalAmount;
    }

    discountAmount = Math.round(discountAmount * 100) / 100;
    finalAmount = Math.max(0, originalAmount - discountAmount);
    couponCode = coupon.code;

    // Increment usage count
    await couponService.incrementUsageCount(coupon.id, { transaction });
  }

  // Public bookings are created as a Pending HOLD that frees automatically if
  // unpaid (holdExpiresAt). Payment verification flips them to Confirmed and
  // clears the hold. This prevents abandoned checkouts from blocking slots.
  const bookingStatus = data.bookingStatus || 'Pending';
  let holdExpiresAt = data.holdExpiresAt || null;
  if (bookingStatus === 'Pending' && !holdExpiresAt) {
    holdExpiresAt = new Date(Date.now() + HOLD_TTL_MINUTES * 60 * 1000);
  }

  // The number of valid passes/members for a booking is the sport's "Allowed
  // Members" (configured on the Sports List). Fall back to the court's capacity
  // only when the sport has none set (allowedMembers = 0/null).
  const sport = court.sportId
    ? await Sport.findByPk(court.sportId, { attributes: ['id', 'allowedMembers'], transaction })
    : null;
  const maxPersons = (sport && sport.allowedMembers > 0)
    ? sport.allowedMembers
    : (court.capacity || null);

  const booking = await Booking.create({
    userId: data.userId,
    sportId: court.sportId,
    courtId: data.courtId,
    date: data.date,
    startTime: data.startTime,
    endTime, // midnight close normalized to "24:00:00" above
    bookingSource: data.bookingSource || 'Website',
    paymentStatus: data.paymentStatus || 'Pending',
    bookingStatus,
    holdExpiresAt,
    totalAmount: finalAmount,
    originalAmount: originalAmount !== finalAmount ? originalAmount : null,
    discountAmount,
    couponCode,
    notes: data.notes || null,
    isDeleted: false,
    // Valid pass count = sport.allowedMembers (fallback: court capacity)
    maxPersons,
  }, { transaction });

  // ── Pass issuance ─────────────────────────────────────────────────────────
  // The QR pass is NOT minted here for an unpaid booking. A website booking is
  // only a Pending hold until Razorpay confirms, so a cancelled/abandoned/failed
  // checkout leaves a booking with NO pass — confirmFacilityPayment issues it
  // once the payment is verified. Staff/offline bookings that are created
  // already Paid (or already Confirmed) have nothing left to pay, so they get
  // their pass straight away.
  if (isPassEligible(booking)) {
    await exports.issueBookingPass(booking, transaction);
  }

  // ── Fetch full booking with associations for email ────────────────────────
  const fullBooking = await Booking.findByPk(booking.id, {
    include: [
      { model: Court, as: 'court', include: [{ model: SportComplex, attributes: ['id', 'name', 'city'] }] },
      { model: Sport, as: 'sport', attributes: ['id', 'name'] },
      { model: User, as: 'user', attributes: ['id', 'name', 'email'] },
    ],
    transaction,
  });

  // NOTE: the confirmation email is intentionally NOT sent here. The booking is
  // only a Pending hold until payment succeeds — paymentController.verifyPayment
  // sends the confirmation email once the booking is Confirmed/Paid.

  // Admins are alerted only for a booking that is actually real. An unpaid hold
  // stays silent until its payment is confirmed (see the confirmation
  // side-effects), so a cancelled checkout no longer rings the admin bell.
  if (isPassEligible(booking)) {
    exports.notifyAdminsOfBooking(fullBooking, court.sportComplexId);
  }

  return fullBooking;
};

/**
 * Bell alert for the relevant admins (super admin + this complex's admin).
 * Fire-and-forget: never blocks or fails the caller.
 */
exports.notifyAdminsOfBooking = (booking, sportComplexId) => {
  if (!booking) return;
  try {
    require('./notificationService').notifyAdmins({
      type: 'Booking',
      title: 'New Court Booking',
      message: `${booking.user?.name || 'A user'} booked ${booking.sport?.name || 'a court'}`
        + `${booking.court?.name ? ` (${booking.court.name})` : ''} on ${booking.date} at ${booking.startTime}`,
      actionUrl: '/booking-list',
      sportComplexId: sportComplexId ?? booking.court?.sportComplexId ?? booking.court?.SportComplex?.id ?? null,
    });
  } catch (err) {
    payLog.warn('booking.admin_notify_failed', { bookingId: booking.id, err });
  }
};

exports.createMultipleCourtBookings = async (data) => {
  const { userId, bookings, couponCode, bookingSource, bookingStatus, paymentStatus, platform } = data;

  return await sequelize.transaction(async (t) => {
    const createdBookings = [];
    let combinedTotal = 0;

    for (const b of bookings) {
      const booking = await exports.createCourtBooking({
        userId,
        courtId: b.courtId,
        date: b.date,
        startTime: b.startTime,
        endTime: b.endTime,
        totalAmount: b.totalAmount,
        notes: b.notes,
        couponCode: couponCode || null, // If single booking format, couponCode is passed here
        platform, // which client is booking — gates platform-restricted coupons
        // Optional overrides (used by the Khelomore surface to create permanent,
        // non-expiring bookings). Undefined here keeps the website defaults.
        bookingSource,
        bookingStatus,
        paymentStatus,
      }, t);

      createdBookings.push(booking);
      combinedTotal += parseFloat(booking.totalAmount);
    }

    return {
      bookings: createdBookings,
      combinedTotal: Math.round(combinedTotal * 100) / 100,
    };
  });
};

/**
 * Court-hidden booking with auto slot adjustment.
 *
 * Resolves the court server-side (the client never sends one). Runs inside a
 * SERIALIZABLE transaction that LOCKS the equivalent pool's bookings for the
 * date, recomputes the solution under the lock (no TOCTOU), relocates any
 * conflicting bookings to free a host court, and creates the user's booking on
 * that host as a Pending hold. Rolls back everything on conflict.
 *
 * Returns { booking, movedBookings:[{bookingId, fromCourtId, toCourtId}] }.
 */
exports.createAutoAdjustedBooking = async ({ userId, sportComplexId, sportId, date, startTime, endTime, totalAmount, couponCode, platform, maxMoves = 2 }) => {
  const durationMinutes = toEndMinutes(endTime, toMinutes(startTime)) - toMinutes(startTime);
  if (!(durationMinutes > 0)) throw new Error('endTime must be after startTime');

  return await sequelize.transaction(
    { isolationLevel: Transaction.ISOLATION_LEVELS.SERIALIZABLE },
    async (t) => {
      const { courts, bookings } = await loadAvailabilityData(sportComplexId, sportId, date, t);
      const now = new Date();

      let chosen = null;
      for (const group of groupByRate(courts)) {
        const r = slotEngine.computeAvailability({ courts: group, bookings, now, startTime, durationMinutes, maxMoves });
        if (r.available && preferAvailable(chosen, r)) chosen = r;
      }
      if (!chosen) {
        const err = new Error('Selected time is no longer available. Please pick another slot.');
        err.code = 'SLOT_UNAVAILABLE';
        throw err;
      }

      // Relocate conflicting bookings to free the host court. Same-rate pool, so
      // the moved booking's amount stays valid; the engine already validated
      // capacity and no-overlap against the locked snapshot.
      const movedBookings = [];
      for (const m of chosen.moves) {
        const moved = await Booking.findByPk(m.bookingId, { transaction: t, lock: t.LOCK.UPDATE });
        if (!moved || moved.bookingStatus === 'Cancelled' || moved.isDeleted) {
          const err = new Error('Could not consolidate bookings — please retry.');
          err.code = 'SLOT_UNAVAILABLE';
          throw err;
        }
        await moved.update(
          { courtId: m.toCourtId, movedFromCourtId: m.fromCourtId, moveReason: 'auto-consolidation', movedAt: now },
          { transaction: t }
        );
        movedBookings.push({ bookingId: moved.id, fromCourtId: m.fromCourtId, toCourtId: m.toCourtId });
      }

      // Create the user's booking on the freed host court as a Pending hold.
      const booking = await exports.createCourtBooking(
        {
          userId,
          courtId: chosen.hostCourtId,
          date,
          startTime,
          endTime,
          totalAmount,
          couponCode,
          platform,
          bookingStatus: 'Pending',
          holdExpiresAt: new Date(now.getTime() + HOLD_TTL_MINUTES * 60 * 1000),
        },
        t
      );

      return { booking, movedBookings };
    }
  );
};

/** Load a booking with the associations needed for confirmation side-effects. */
async function _loadFullBooking(bookingId) {
  return Booking.findByPk(bookingId, {
    include: [
      { model: Court, as: 'court', include: [{ model: SportComplex, attributes: ['id', 'name', 'city'] }] },
      { model: Sport, as: 'sport', attributes: ['id', 'name'] },
      { model: User, as: 'user', attributes: ['id', 'name', 'email', 'phone_number'] },
    ],
  });
}

/**
 * Perform the Pending→Paid transition exactly once, inside a locked transaction.
 * Idempotent: if the booking is already Paid, it returns { status:'already' }
 * WITHOUT re-writing anything — this is what prevents duplicate confirmations,
 * duplicate confirmation emails on a replayed verify.
 *
 * @returns {{status:'confirmed'|'already'|'not_found', booking?:object}}
 */
async function _finalizePaidBooking({ bookingId, paymentId, orderId, transaction }) {
  const booking = await Booking.findByPk(bookingId, {
    transaction,
    lock: transaction ? transaction.LOCK.UPDATE : undefined,
  });
  if (!booking) return { status: 'not_found' };

  // Idempotency guard — paymentStatus is the reliable signal (bookingStatus
  // can already be 'Confirmed' by default on admin-created bookings).
  if (booking.paymentStatus === 'Paid') {
    return { status: 'already', booking };
  }

  // The pass is minted HERE — first time this booking becomes Paid. Everything
  // before this point (Pending hold, cancelled checkout) has no pass at all.
  const passCode = booking.passCode || generateBookingPassCode(booking.id);
  const qrCode = booking.qrCode || buildQrUrl(passCode);

  await booking.update(
    {
      paymentStatus: 'Paid',
      transactionId: paymentId || booking.transactionId,
      razorpayOrderId: orderId || booking.razorpayOrderId,
      bookingStatus: 'Confirmed',
      holdExpiresAt: null, // hold released; booking is now permanent
      passCode,
      qrCode,
    },
    { transaction }
  );

  return { status: 'confirmed', booking };
}

/**
 * One-time side-effects after a booking becomes Paid: confirmation email (kept
 * as-is, non-blocking) and the admin bell alert — both belong to the payment,
 * not to the hold. Guarded upstream so it runs only on the first finalize.
 */
async function _bookingConfirmationSideEffects(bookingId) {
  const full = await _loadFullBooking(bookingId);
  if (!full) return null;

  // Admins hear about the booking now that it is paid for.
  exports.notifyAdminsOfBooking(full, full.court?.SportComplex?.id);

  // Email (unchanged behaviour: fire-and-forget, never blocks the response).
  if (full.user?.email) {
    const emailService = require('./emailService');
    emailService
      .sendBookingConfirmationEmail({
        to: full.user.email,
        name: full.user.name || 'Valued Customer',
        passCode: full.passCode,
        qrCodeUrl: full.qrCode,
        sportName: full.sport?.name || 'Sport',
        courtName: full.court?.name || 'Court',
        venueName: full.court?.SportComplex?.name || '',
        date: full.date,
        startTime: full.startTime,
        endTime: full.endTime,
        totalAmount: full.totalAmount,
        maxPersons: full.maxPersons,
        bookingRef: `#NSC-${String(full.id).padStart(6, '0')}`,
      })
      .catch((err) => payLog.error('booking.email_failed', { bookingId, err }));
  }

  return full;
}

/**
 * LEGACY entry point (kept for backward compatibility). Now idempotent and
 * transaction-safe. Prefer confirmFacilityPayment() which additionally verifies
 * the payment against Razorpay. Returns the full booking, or null if not found.
 */
exports.finalizeBookingPayment = async (bookingId, transactionId) => {
  const result = await sequelize.transaction((t) =>
    _finalizePaidBooking({ bookingId, paymentId: transactionId, transaction: t })
  );
  if (result.status === 'not_found') return null;
  if (result.status === 'confirmed') await _bookingConfirmationSideEffects(bookingId);
  return _loadFullBooking(bookingId);
};

/**
 * Assert a Razorpay payment is genuine, captured, for the expected order, and
 * for the expected amount. Throws a tagged Error on a hard mismatch. If the
 * Razorpay API is unreachable, it degrades gracefully — the signature check plus
 * the server-side order amount and order-binding already close the ₹1 bypass.
 */
async function _assertRazorpayPaymentValid({ paymentId, orderId, expectedPaise }) {
  const razorpayService = require('./razorpayService');
  let payment;
  try {
    payment = await razorpayService.fetchPayment(paymentId);
  } catch (err) {
    payLog.warn('payment.fetch_failed_fallback', { paymentId, err });
    return; // rely on signature + order binding + server-side amount
  }

  if (orderId && payment.order_id && payment.order_id !== orderId) {
    const e = new Error('Payment does not belong to the provided order.');
    e.code = 'ORDER_MISMATCH';
    throw e;
  }
  if (!['captured', 'authorized'].includes(payment.status)) {
    const e = new Error(`Payment has not been captured (status: ${payment.status}).`);
    e.code = 'NOT_CAPTURED';
    throw e;
  }
  if (typeof payment.amount === 'number' && payment.amount !== expectedPaise) {
    const e = new Error(`Paid amount does not match the booking amount.`);
    e.code = 'AMOUNT_MISMATCH';
    payLog.error('payment.amount_mismatch', { paymentId, paid: payment.amount, expectedPaise });
    throw e;
  }
}

/**
 * SECURE facility-payment confirmation. Validates ownership, order-binding,
 * captured status and amount before transitioning the booking to Paid inside a
 * locked transaction, then triggers one-time side-effects.
 *
 * The caller (paymentController) must have already verified the Razorpay
 * signature. Returns a discriminated result the controller maps to HTTP codes.
 *
 * @param {object} p
 * @param {number} p.bookingId
 * @param {string} p.orderId       razorpay_order_id from the client
 * @param {string} p.paymentId     razorpay_payment_id from the client
 * @param {object} [p.requestUser] req.user if authenticated (ownership check)
 * @returns {{status:'confirmed'|'already'|'not_found'|'forbidden'|'order_mismatch', booking?:object}}
 */
exports.confirmFacilityPayment = async ({ bookingId, orderId, paymentId, requestUser }) => {
  // 1. Pre-load (no lock) for ownership, order-binding and amount expectation.
  const pre = await Booking.findByPk(bookingId, {
    attributes: ['id', 'userId', 'totalAmount', 'paymentStatus', 'razorpayOrderId'],
  });
  if (!pre) return { status: 'not_found' };

  // Ownership: a logged-in non-staff user may only pay for their own booking.
  // Guests (no token) are allowed through — their guarantee is order-binding +
  // the authoritative Razorpay checks below.
  if (requestUser && !isStaffUser(requestUser) && pre.userId && pre.userId !== requestUser.id) {
    payLog.warn('payment.ownership_denied', {
      bookingId, bookingUserId: pre.userId, requestUserId: requestUser.id,
    });
    return { status: 'forbidden' };
  }

  // Order binding: the submitted order must match the one we created for this
  // booking. (Null for bookings created before this feature shipped — allowed
  // through so in-flight checkouts during deploy don't break.)
  if (orderId && pre.razorpayOrderId && pre.razorpayOrderId !== orderId) {
    payLog.warn('payment.order_mismatch', { bookingId, expected: pre.razorpayOrderId, got: orderId });
    return { status: 'order_mismatch' };
  }

  // Fast idempotency exit (re-checked under lock in step 3).
  if (pre.paymentStatus === 'Paid') return { status: 'already', booking: pre };

  // 2. Authoritative Razorpay verification (network call, kept OUT of the txn).
  const razorpayService = require('./razorpayService');
  const expectedPaise = Math.round(Number(pre.totalAmount) * (razorpayService.MULTIPLIER || 100));
  await _assertRazorpayPaymentValid({ paymentId, orderId, expectedPaise });

  // 3. Transactional, locked, idempotent finalize.
  const result = await sequelize.transaction((t) =>
    _finalizePaidBooking({ bookingId, paymentId, orderId, transaction: t })
  );
  if (result.status === 'not_found') return { status: 'not_found' };
  if (result.status === 'already') return { status: 'already', booking: result.booking };

  // 4. One-time side-effects (confirmation email) — only on first finalize.
  await _bookingConfirmationSideEffects(bookingId);
  payLog.info('payment.confirmed', { bookingId, paymentId });
  return { status: 'confirmed', booking: result.booking };
};

/**
 * Release an UNPAID Pending hold — the counterpart of confirmFacilityPayment,
 * called when the user cancels/dismisses the Razorpay checkout or the payment
 * fails. The slot is freed immediately (instead of waiting out holdExpiresAt)
 * and the abandoned row is cancelled + soft-deleted so it never shows up as a
 * booking. Any coupon use it claimed is given back.
 *
 * Refuses to touch a booking that is already Paid — a paid booking can only be
 * cancelled through the normal cancellation flow.
 *
 * @returns {{status:'released'|'already'|'not_found'|'forbidden'|'paid'}}
 */
exports.releaseUnpaidBooking = async ({ bookingId, requestUser }) => {
  const booking = await Booking.findByPk(bookingId);
  if (!booking) return { status: 'not_found' };

  // Ownership: a non-staff user may only release their own booking.
  if (requestUser && !isStaffUser(requestUser) && booking.userId && booking.userId !== requestUser.id) {
    return { status: 'forbidden' };
  }

  if (booking.paymentStatus === 'Paid') return { status: 'paid' };
  if (booking.isDeleted || booking.bookingStatus === 'Cancelled') return { status: 'already' };

  await booking.update({
    bookingStatus: 'Cancelled',
    paymentStatus: 'Failed',
    holdExpiresAt: null,
    isDeleted: true,
    passCode: null,
    qrCode: null,
    notes: [booking.notes, 'Payment not completed — hold released'].filter(Boolean).join(' | '),
  });

  // Give the coupon use back, otherwise abandoned checkouts burn up the quota.
  if (booking.couponCode) {
    try {
      await require('./couponService').decrementUsageCount(booking.couponCode);
    } catch (err) {
      payLog.warn('release.coupon_restore_failed', { bookingId, code: booking.couponCode, err });
    }
  }

  payLog.info('payment.hold_released', { bookingId });
  return { status: 'released' };
};

// ── Send booking pass by email ────────────────────────────────────────────────
// Re-sends/shares a confirmed booking's QR pass to any recipient email.
// Mirrors the Event Pass "send pass by email" flow.
exports.sendBookingPassByEmail = async (bookingId, recipientEmail, recipientName) => {
  const booking = await Booking.findByPk(bookingId, {
    include: [
      { model: Court, as: 'court', include: [{ model: SportComplex, attributes: ['id', 'name', 'city'] }] },
      { model: Sport, as: 'sport', attributes: ['id', 'name'] },
      { model: User, as: 'user', attributes: ['id', 'name', 'email'] },
    ],
  });

  if (!booking) throw new Error('Booking not found');
  if (!booking.passCode || !booking.qrCode) {
    throw new Error('This booking does not have a pass yet.');
  }

  const to = (recipientEmail && recipientEmail.trim()) || booking.user?.email;
  if (!to) throw new Error('No recipient email provided');

  const emailService = require('./emailService');
  await emailService.sendBookingConfirmationEmail({
    to,
    name: (recipientName && recipientName.trim()) || booking.user?.name || 'Valued Customer',
    passCode: booking.passCode,
    qrCodeUrl: booking.qrCode,
    sportName: booking.sport?.name || 'Sport',
    courtName: booking.court?.name || 'Court',
    venueName: booking.court?.SportComplex?.name || '',
    date: booking.date,
    startTime: booking.startTime,
    endTime: booking.endTime,
    totalAmount: booking.totalAmount,
    maxPersons: booking.maxPersons,
    bookingRef: `#NSC-${String(booking.id).padStart(6, '0')}`,
  });

  return { success: true };
};

/**
 * Notify customers whose bookings were silently moved to an equivalent court by
 * the auto-consolidation engine. Sends an in-app notification + email per moved
 * booking. Non-blocking; failures are logged, not thrown. Called AFTER commit.
 *
 * @param {Array<{bookingId:number, fromCourtId:number, toCourtId:number}>} movedBookings
 */
exports.notifyReassignedBookings = async (movedBookings) => {
  if (!Array.isArray(movedBookings) || movedBookings.length === 0) return;
  const emailService = require('./emailService');
  const notificationService = require('./notificationService');

  for (const m of movedBookings) {
    try {
      const b = await Booking.findByPk(m.bookingId, {
        include: [
          { model: Court, as: 'court', include: [{ model: SportComplex, attributes: ['id', 'name', 'city'] }] },
          { model: Sport, as: 'sport', attributes: ['id', 'name'] },
          { model: User, as: 'user', attributes: ['id', 'name', 'email'] },
        ],
      });
      if (!b) continue;

      const oldCourt = m.fromCourtId ? await Court.findByPk(m.fromCourtId, { attributes: ['id', 'name'] }) : null;
      const newCourtName = b.court?.name || 'your court';
      const venueName = b.court?.SportComplex?.name || '';
      const bookingRef = `#NSC-${String(b.id).padStart(6, '0')}`;
      const timeShort = `${String(b.startTime).slice(0, 5)}–${String(b.endTime).slice(0, 5)}`;

      try {
        await notificationService.createNotification({
          userId: b.userId,
          title: 'Court updated for your booking',
          message: `Your ${b.sport?.name || 'court'} booking on ${b.date} (${timeShort}) has been moved to ${newCourtName}${venueName ? ' at ' + venueName : ''}. Your time, price and pass code are unchanged.`,
          type: 'Booking',
          actionUrl: '/dashboard/bookings',
        });
      } catch (e) {
        console.error('reassign notification error:', e.message);
      }

      if (b.user?.email) {
        await emailService.sendBookingCourtReassignedEmail({
          to: b.user.email,
          name: b.user.name || 'Valued Customer',
          sportName: b.sport?.name || 'Sport',
          oldCourtName: oldCourt?.name || '',
          newCourtName,
          venueName,
          date: b.date,
          startTime: b.startTime,
          endTime: b.endTime,
          passCode: b.passCode,
          qrCodeUrl: b.qrCode,
          bookingRef,
        });
      }
    } catch (e) {
      console.error('notifyReassignedBookings error for booking', m.bookingId, e.message);
    }
  }
};

exports.cancelMultipleBookings = async (bookingsToCancel) => {
  const result = {
    cancelled: [],
    alreadyCancelled: [],
    notFound: [],
  };

  // Normalise a time to "HH:MM:SS" so "16:28" and "16:28:00" compare equal.
  const normTime = (t) => {
    if (t === null || t === undefined || t === '') return null;
    const parts = String(t).trim().split(':');
    if (Number.isNaN(parseInt(parts[0], 10))) return null;
    const [h, m = '00', s = '00'] = parts;
    const pad = (v) => String(parseInt(v, 10)).padStart(2, '0');
    return `${pad(h)}:${pad(m)}:${pad(s)}`;
  };

  for (const b of bookingsToCancel) {
    const booking = await Booking.findByPk(b.bookingId);

    // The booking is only cancelled when its bookingId AND all four identifiers
    // (courtId, date, startTime, endTime) match the booking on record. A wrong
    // or mismatched identifier is treated as "not found" — so a booking can't be
    // cancelled by guessing the id alone.
    const identityMatches =
      booking &&
      String(booking.courtId) === String(b.courtId) &&
      String(booking.date) === String(b.date) &&
      normTime(booking.startTime) === normTime(b.startTime) &&
      normTime(booking.endTime) === normTime(b.endTime);

    if (!booking || !identityMatches) {
      result.notFound.push(b.bookingId);
      continue;
    }

    if (booking.bookingStatus === 'Cancelled') {
      result.alreadyCancelled.push(b.bookingId);
      continue;
    }

    await booking.update({
      bookingStatus: 'Cancelled',
      isDeleted: true,
    });

    // Update user total_bookings if needed
    await User.decrement('total_bookings', {
      where: { id: booking.userId, total_bookings: { [Op.gt]: 0 } },
    });

    result.cancelled.push(booking.id);
  }

  return result;
};

// ── CourtSlot CRUD ────────────────────────────────────────────────────────────

exports.getSlotsByCourt = async (courtId) => {
  return CourtSlot.findAll({
    where: { courtId },
    order: [['startTime', 'ASC']],
  });
};

exports.getSlotById = async (slotId) => CourtSlot.findByPk(slotId);

exports.createSlot = async (courtId, data) => {
  const court = await Court.findByPk(courtId);
  if (!court) throw new Error('Court not found');

  return CourtSlot.create({
    courtId,
    startTime: data.startTime,
    endTime: data.endTime,
    availableDays: Array.isArray(data.availableDays)
      ? data.availableDays.join(',')
      : data.availableDays || 'Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday',
    slotType: data.slotType || 'Regular',
    priceOverride: data.priceOverride ? parseFloat(data.priceOverride) : null,
    status: data.status || 'Active',
  });
};

exports.updateSlot = async (slotId, data) => {
  const slot = await CourtSlot.findByPk(slotId);
  if (!slot) return null;

  await slot.update({
    startTime: data.startTime ?? slot.startTime,
    endTime: data.endTime ?? slot.endTime,
    availableDays: data.availableDays
      ? (Array.isArray(data.availableDays) ? data.availableDays.join(',') : data.availableDays)
      : slot.availableDays,
    slotType: data.slotType ?? slot.slotType,
    priceOverride: data.priceOverride !== undefined
      ? (data.priceOverride ? parseFloat(data.priceOverride) : null)
      : slot.priceOverride,
    status: data.status ?? slot.status,
  });

  return slot.reload();
};

exports.deleteSlot = async (slotId) => {
  const slot = await CourtSlot.findByPk(slotId);
  if (!slot) return false;
  await slot.destroy();
  return true;
};

exports.toggleSlotStatus = async (slotId, status) => {
  const slot = await CourtSlot.findByPk(slotId);
  if (!slot) return null;
  await slot.update({ status });
  return slot.reload();
};

// ── Date-specific slot blocks ─────────────────────────────────────────────────
//
// A block is a Booking row with isBlocked=true. That is deliberate: it means a
// block occupies the interval through the exact same conflict scan, availability
// query and aggregator feed as a paid reservation, with no parallel code path to
// keep in sync. It is Confirmed (so nothing expires it) but never Paid (so it
// stays out of every revenue report, all of which filter on paymentStatus).

/** Cache of the account blocks are booked under (Bookings.userId is NOT NULL). */
let _blockUserId = null;

/**
 * Owner account for block rows. Prefers the configured block/service account,
 * then any admin — a block has no real customer, so this is bookkeeping only.
 */
async function resolveBlockUserId(transaction = null) {
  if (_blockUserId) return _blockUserId;

  const email = process.env.SLOT_BLOCK_SERVICE_EMAIL || process.env.KHELOMORE_SERVICE_EMAIL;
  let user = email ? await User.findOne({ where: { email }, transaction }) : null;
  if (!user) {
    // 'ADMIN' is the only super-user value in the Users.role enum — comparing
    // against a value the enum doesn't define errors out in Postgres.
    user = await User.findOne({ where: { role: 'ADMIN' }, order: [['id', 'ASC']], transaction });
  }
  if (!user) throw new Error('No account available to own slot blocks (set SLOT_BLOCK_SERVICE_EMAIL)');

  _blockUserId = user.id;
  return _blockUserId;
}

/**
 * Block one court+date+interval.
 *
 * SERIALIZABLE + row lock for the same reason /save-booking uses it: a block and
 * a website checkout must never both win the same slot.
 *
 * @param {object} p
 * @param {number} p.courtId
 * @param {string} p.date        YYYY-MM-DD
 * @param {string} p.startTime   HH:MM or HH:MM:SS
 * @param {string} p.endTime
 * @param {string} p.blockedBy   'Admin' | partner label ('KheloMore', 'Huddle')
 * @param {number} [p.amount]    Recorded for the partner's reconciliation; never billed.
 * @param {string} [p.notes]
 * @returns {Promise<Booking>}
 */
exports.createSlotBlock = async ({ courtId, date, startTime, endTime, blockedBy, amount = 0, notes = null }) => {
  if (!courtId) throw new Error('courtId is required');
  if (!date) throw new Error('date is required');
  if (!startTime || !endTime) throw new Error('startTime and endTime are required');

  return sequelize.transaction(
    { isolationLevel: Transaction.ISOLATION_LEVELS.SERIALIZABLE },
    async (t) => {
      const court = await Court.findByPk(courtId, { transaction: t });
      if (!court) throw new Error('Court not found');

      // Partners send "18:00"; the column is SQL TIME. Normalising here keeps
      // every stored block on the same "HH:MM:SS" form the slot grid uses.
      const normalizedStart = normalizeTimeString(startTime);
      const normalizedEnd = normalizeEndTime(normalizedStart, normalizeTimeString(endTime));
      const conflict = await findConflictingBooking(
        { courtId, date, startTime: normalizedStart, endTime: normalizedEnd },
        t,
      );

      if (conflict) {
        // Blocking an already-blocked slot is a no-op, not an error — the caller
        // ends up in the state it asked for, so retries stay safe.
        if (conflict.isBlocked) return conflict;
        const err = new Error(`Slot is already booked by a customer: courtId ${courtId} on ${date} ${startTime}-${endTime}`);
        err.code = 'SLOT_BOOKED';
        throw err;
      }

      return Booking.create({
        userId: await resolveBlockUserId(t),
        sportId: court.sportId,
        courtId,
        date,
        startTime: normalizedStart,
        endTime: normalizedEnd,
        // The partner label doubles as the Source column, matching their bookings.
        bookingSource: blockedBy || 'Admin',
        // Confirmed so no hold sweeper frees it; Pending payment so it can never
        // be counted as revenue.
        bookingStatus: 'Confirmed',
        paymentStatus: 'Pending',
        holdExpiresAt: null,
        totalAmount: parseFloat(amount) || 0,
        discountAmount: 0,
        notes: notes || `Slot blocked by ${blockedBy || 'Admin'}`,
        isBlocked: true,
        blockedBy: blockedBy || 'Admin',
        isDeleted: false,
        // No pass, no QR, no members — nobody is coming through the gate.
        maxPersons: null,
      }, { transaction: t });
    },
  );
};

/**
 * Release a block. Cancelling (not deleting) frees the interval for the
 * availability queries while leaving an audit trail of who blocked what.
 *
 * Identify it by `blockId`, or by the court+date+startTime that was blocked —
 * a partner that stored no id can still release its own block.
 *
 * @returns {Promise<Booking|null>} the released block, or null if none matched.
 */
exports.releaseSlotBlock = async ({ blockId, courtId, date, startTime, endTime = null, blockedBy = null }) => {
  const where = { isBlocked: true, isDeleted: false, bookingStatus: { [Op.ne]: 'Cancelled' } };

  if (blockId) {
    where.id = blockId;
  } else {
    if (!courtId || !date || !startTime) {
      throw new Error('Provide blockId, or courtId + date + startTime');
    }
    where.courtId = courtId;
    where.date = date;

    // Match by OVERLAP, not by an exact start. A block may span more hours than
    // the slot being clicked (a 18:00-20:00 block covers the 19:00 slot), and an
    // exact startTime match would report "no block found" for that hour.
    const start = normalizeTimeString(startTime);
    // With no end supplied, probe a 1-minute window to find whatever block
    // covers this instant. A probe past the last minute of the day wraps to
    // "00:00:00", which would compare as BEFORE every start — pin it to 24:00.
    let end = normalizeTimeString(endTime);
    if (!end) {
      const probe = toTimeString(toMinutes(start) + 1);
      end = probe === '00:00:00' ? '24:00:00' : probe;
    }
    where.startTime = { [Op.lt]: end };
    where.endTime = { [Op.gt]: start };
  }

  // A partner may only release its OWN blocks; admin (blockedBy omitted) may
  // release any, so the venue is never locked out by a partner outage.
  if (blockedBy) where.blockedBy = blockedBy;

  const block = await Booking.findOne({ where, order: [['startTime', 'ASC']] });
  if (!block) return null;

  await block.update({ bookingStatus: 'Cancelled' });
  return block.reload();
};

/**
 * Block several slots in one call — the partner-facing batch, shaped like
 * cancelMultipleBookings so the contract reads the same as create/cancel.
 *
 * Deliberately NOT atomic: one slot already sold must not throw away the other
 * nine blocks the partner asked for. Each result is reported individually.
 *
 * @returns {{blocked: object[], alreadyBlocked: object[], failed: object[]}}
 */
exports.blockMultipleSlots = async (slots, blockedBy) => {
  const result = { blocked: [], alreadyBlocked: [], failed: [] };

  for (const s of slots) {
    const ref = { courtId: s.courtId, date: s.date, startTime: s.startTime, endTime: s.endTime };
    try {
      const existingBefore = await Booking.findOne({
        where: {
          courtId: s.courtId,
          date: s.date,
          isBlocked: true,
          isDeleted: false,
          bookingStatus: { [Op.ne]: 'Cancelled' },
          startTime: normalizeTimeString(s.startTime),
        },
        attributes: ['id'],
      });

      const block = await exports.createSlotBlock({
        courtId: s.courtId,
        date: s.date,
        startTime: s.startTime,
        endTime: s.endTime,
        blockedBy,
        amount: s.totalAmount != null ? s.totalAmount : s.amount,
        notes: s.notes || null,
      });

      const row = { ...ref, blockId: block.id };
      // createSlotBlock is idempotent — tell the caller which of the two happened
      // so a re-sent batch doesn't look like it created duplicates.
      if (existingBefore && existingBefore.id === block.id) result.alreadyBlocked.push(row);
      else result.blocked.push(row);
    } catch (err) {
      result.failed.push({ ...ref, reason: err.message });
    }
  }

  return result;
};

/**
 * Release several blocks in one call. Mirrors cancelMultipleBookings' reporting:
 * every entry lands in exactly one bucket and the call itself always succeeds.
 *
 * @returns {{unblocked: object[], notFound: object[]}}
 */
exports.unblockMultipleSlots = async (slots, blockedBy = null) => {
  const result = { unblocked: [], notFound: [] };

  for (const s of slots) {
    const ref = { blockId: s.blockId ?? null, courtId: s.courtId, date: s.date, startTime: s.startTime };
    try {
      const released = await exports.releaseSlotBlock({
        blockId: s.blockId,
        courtId: s.courtId,
        date: s.date,
        startTime: s.startTime,
        endTime: s.endTime || null,
        blockedBy,
      });

      if (released) result.unblocked.push({ ...ref, blockId: released.id });
      else result.notFound.push(ref);
    } catch (err) {
      result.notFound.push({ ...ref, reason: err.message });
    }
  }

  return result;
};

// ── Toggle showOnFrontend ─────────────────────────────────────────────────────

exports.toggleShowOnFrontend = async (courtId, showOnFrontend) => {
  const court = await Court.findByPk(courtId);
  if (!court) return null;
  await court.update({ showOnFrontend });
  return court.reload();
};

// ── Available slots for a court on a specific date ────────────────────────────

exports.getUserCourtBookings = async (userId, page = 1, limit = 20) => {
  const offset = (page - 1) * limit;
  const { count, rows } = await Booking.findAndCountAll({
    where: { userId, isDeleted: false },
    include: [
      { model: Court, as: 'court', include: [{ model: SportComplex, attributes: ['id', 'name', 'city'] }] },
      { model: Sport, as: 'sport', attributes: ['id', 'name', 'image'] },
      {
        model: BookingMember,
        as: 'members',
        attributes: ['id', 'name', 'phone', 'email', 'passCode', 'qrCode', 'scanStatus', 'scannedInAt', 'scannedOutAt'],
      },
    ],
    attributes: [
      'id', 'date', 'startTime', 'endTime', 'bookingStatus', 'paymentStatus',
      'totalAmount', 'bookingSource', 'passCode', 'qrCode', 'maxPersons',
      'scannedInCount', 'scannedOutCount', 'scanStatus', 'scannedInAt', 'scannedOutAt',
      'transactionId', 'couponCode', 'discountAmount', 'notes', 'createdAt',
    ],
    order: [['date', 'DESC'], ['startTime', 'DESC']],
    limit,
    offset,
  });

  return {
    bookings: rows,
    currentPage: page,
    totalPages: Math.ceil(count / limit),
    totalItems: count,
  };
};

// ── Booking Members (allowed members of a court pass) ─────────────────────────

const MEMBER_ATTRS = ['id', 'name', 'phone', 'email', 'passCode', 'qrCode', 'scanStatus', 'scannedInAt', 'scannedOutAt'];

/**
 * Save (replace) the allowed-member list for a booking. Each member gets a unique,
 * individually-scannable passCode + QR. members = [{ name, phone, email? }, ...]
 * Count must equal booking.maxPersons.
 */
exports.saveBookingMembers = async (bookingId, members) => {
  const booking = await Booking.findByPk(bookingId);
  if (!booking) throw new Error('Booking not found');

  // Member passes are derived from the booking pass, so they follow the same
  // rule: no payment, no pass.
  if (!isPassEligible(booking) || !booking.passCode) {
    throw new Error('This booking has no pass yet. Complete the payment first.');
  }

  const cap = booking.maxPersons;
  if (!cap || cap < 1) {
    throw new Error('This booking has no member capacity configured.');
  }
  if (!Array.isArray(members) || members.length === 0) {
    throw new Error('Members list cannot be empty');
  }
  if (members.length !== cap) {
    throw new Error(`This booking is for ${cap} person${cap > 1 ? 's' : ''}. Please add exactly ${cap} member${cap > 1 ? 's' : ''}.`);
  }

  for (const m of members) {
    if (!m.name || !String(m.name).trim()) throw new Error('Each member must have a name');
    if (!m.phone || !String(m.phone).trim()) throw new Error('Each member must have a WhatsApp number');
    const digits = String(m.phone).replace(/\D/g, '');
    if (digits.length < 7 || digits.length > 15) {
      throw new Error(`Invalid phone number for ${m.name}: ${m.phone}`);
    }
  }

  // Replace all existing members for this booking
  await BookingMember.destroy({ where: { bookingId } });

  const records = members.map((m, i) => {
    const passCode = generateMemberPassCode(booking.passCode, booking.id, i + 1);
    const email = m.email && String(m.email).trim() ? String(m.email).trim() : null;
    return {
      bookingId,
      name: String(m.name).trim(),
      phone: String(m.phone).replace(/\D/g, ''), // store digits only
      email,
      passCode,
      qrCode: buildQrUrl(passCode),
      scanStatus: 'NotScanned',
    };
  });

  await BookingMember.bulkCreate(records);

  return BookingMember.findAll({
    where: { bookingId },
    attributes: MEMBER_ATTRS,
    order: [['id', 'ASC']],
  });
};

const SCAN_BOOKING_INCLUDE = [
  { model: Court, as: 'court', include: [{ model: SportComplex, attributes: ['id', 'name', 'city'] }] },
  { model: Sport, as: 'sport', attributes: ['id', 'name'] },
  { model: BookingMember, as: 'members', attributes: MEMBER_ATTRS },
];

/**
 * Resolve a scanned code to either a member (individual QR) or a booking
 * (counter fallback) and record the scan. Time-window validated against the
 * booking's date/time slot.
 */
exports.scanBookingPass = async (code, scanType) => {
  const trimmed = String(code || '').trim();
  if (!trimmed) return { success: false, message: 'No pass code provided.' };
  if (scanType !== 'In' && scanType !== 'Out') {
    return { success: false, message: 'Invalid scan type. Use "In" or "Out".' };
  }

  // 1) Member pass (individual QR)
  const member = await BookingMember.findOne({ where: { passCode: trimmed } });
  if (member) {
    return exports.scanBookingMember(member.id, scanType);
  }

  // 2) Booking pass (counter fallback)
  const booking = await Booking.findOne({ where: { passCode: trimmed }, include: SCAN_BOOKING_INCLUDE });
  if (!booking) {
    return { success: false, message: 'Pass not found. Invalid QR code.' };
  }
  const cap = booking.maxPersons || 1;
  const now = new Date();
  // Anyone recorded as inside must always be able to leave, even if the booking
  // was cancelled or refunded while they were on court — otherwise they are
  // stuck at the gate and the venue's headcount never returns to zero.
  const stillInside = booking.scannedInCount - booking.scannedOutCount > 0;
  const exitingSomeoneInside = scanType === 'Out' && stillInside;

  if (!exitingSomeoneInside) {
    if (booking.isDeleted || booking.bookingStatus === 'Cancelled') {
      return { success: false, message: 'This booking has been cancelled.' };
    }
    // Unpaid = not a valid pass. New bookings never get a pass before payment;
    // this also blocks legacy passes minted at booking time on holds that were
    // never paid for, and any booking whose money has been refunded.
    if (!isPassEligible(booking)) {
      return { success: false, message: passRejectionMessage(booking), booking };
    }

    const win = checkBookingTimeWindow(booking);
    if (!win.ok) return { success: false, message: win.message, booking };
  }

  if (scanType === 'In') {
    if (booking.scannedInCount >= cap) {
      return { success: false, message: `All ${cap} person${cap > 1 ? 's' : ''} on this pass have already entered.`, booking };
    }
    await booking.update({ scannedInCount: booking.scannedInCount + 1, scanStatus: 'In', scannedInAt: now });
  } else {
    const inside = booking.scannedInCount - booking.scannedOutCount;
    if (inside <= 0) {
      return { success: false, message: 'No one from this pass is currently inside. Cannot scan OUT.', booking };
    }
    await booking.update({ scannedOutCount: booking.scannedOutCount + 1, scanStatus: 'Out', scannedOutAt: now });
  }

  await booking.reload({ include: SCAN_BOOKING_INCLUDE });

  const remaining = cap - booking.scannedInCount;
  const inside = booking.scannedInCount - booking.scannedOutCount;
  return {
    success: true,
    message: scanType === 'In'
      ? `Entry recorded. ${booking.scannedInCount}/${cap} person${cap > 1 ? 's' : ''} entered.${remaining > 0 ? ` ${remaining} remaining.` : ' Pass fully used.'}`
      : `Exit recorded. ${inside} person${inside !== 1 ? 's' : ''} still inside.`,
    booking,
  };
};

/** Scan a specific member IN or OUT; also bumps the parent booking counters. */
exports.scanBookingMember = async (memberId, scanType) => {
  if (scanType !== 'In' && scanType !== 'Out') {
    return { success: false, message: 'Invalid scan type. Use "In" or "Out".' };
  }

  const member = await BookingMember.findByPk(memberId, {
    include: [{ model: Booking, as: 'booking', include: SCAN_BOOKING_INCLUDE }],
  });
  if (!member) return { success: false, message: 'Member not found' };

  const booking = member.booking;
  if (!booking) return { success: false, message: 'This booking has been cancelled or is invalid.' };

  // Same rule as the booking pass: a member already inside can always exit,
  // whatever happened to the booking while they were on court.
  const exitingSomeoneInside = scanType === 'Out' && member.scanStatus === 'In';

  if (!exitingSomeoneInside) {
    if (booking.isDeleted || booking.bookingStatus === 'Cancelled') {
      return { success: false, message: 'This booking has been cancelled or is invalid.' };
    }
    if (!isPassEligible(booking)) {
      return { success: false, message: passRejectionMessage(booking), booking, member };
    }

    const win = checkBookingTimeWindow(booking);
    if (!win.ok) return { success: false, message: win.message, booking, member };
  }

  const now = new Date();

  if (scanType === 'In') {
    if (member.scanStatus === 'In') {
      return { success: false, message: `${member.name} has already entered.`, booking, member };
    }
    await member.update({ scanStatus: 'In', scannedInAt: now });
    await booking.update({ scannedInCount: booking.scannedInCount + 1, scanStatus: 'In', scannedInAt: now });
  } else {
    if (member.scanStatus !== 'In') {
      return { success: false, message: `${member.name} has not entered yet. Cannot scan OUT.`, booking, member };
    }
    await member.update({ scanStatus: 'Out', scannedOutAt: now });
    await booking.update({ scannedOutCount: booking.scannedOutCount + 1, scanStatus: 'Out', scannedOutAt: now });
  }

  await booking.reload({ include: SCAN_BOOKING_INCLUDE });

  const cap = booking.maxPersons || booking.members?.length || 1;
  return {
    success: true,
    message: scanType === 'In'
      ? `${member.name} entered. ${booking.scannedInCount}/${cap} checked in.`
      : `${member.name} exited.`,
    booking,
    member,
  };
};

/** Live IN/OUT stats for a court on a given date (admin scanner panel). */
exports.getCourtScanStats = async (courtId, date) => {
  const where = { isDeleted: false };
  if (courtId) where.courtId = courtId;
  if (date) where.date = date;

  const bookings = await Booking.findAll({
    where,
    attributes: ['id', 'maxPersons', 'scannedInCount', 'scannedOutCount', 'scanStatus'],
  });

  const totalPasses = bookings.length;
  const totalPersons = bookings.reduce((s, b) => s + (b.maxPersons || 1), 0);
  const inCount = bookings.reduce((s, b) => s + b.scannedInCount, 0);
  const outCount = bookings.reduce((s, b) => s + b.scannedOutCount, 0);
  const notScanned = bookings.filter((b) => b.scannedInCount === 0).length;

  return {
    totalPasses,
    totalPersons,
    in: inCount,
    out: outCount,
    notScanned,
    currentlyInside: inCount - outCount,
  };
};

/** Send a single member's individual pass by email (reuses the booking-confirmation template). */
exports.sendMemberPassByEmail = async (bookingId, memberId, recipientEmail) => {
  const member = await BookingMember.findOne({
    where: { id: memberId, bookingId },
    include: [{ model: Booking, as: 'booking', include: [
      { model: Court, as: 'court', include: [{ model: SportComplex, attributes: ['id', 'name', 'city'] }] },
      { model: Sport, as: 'sport', attributes: ['id', 'name'] },
    ] }],
  });
  if (!member) throw new Error('Member not found');

  const to = (recipientEmail && recipientEmail.trim()) || member.email;
  if (!to) throw new Error('No recipient email provided for this member');

  const booking = member.booking;
  const emailService = require('./emailService');
  await emailService.sendBookingConfirmationEmail({
    to,
    name: member.name,
    passCode: member.passCode,
    qrCodeUrl: member.qrCode,
    sportName: booking?.sport?.name || 'Sport',
    courtName: booking?.court?.name || 'Court',
    venueName: booking?.court?.SportComplex?.name || '',
    date: booking?.date,
    startTime: booking?.startTime,
    endTime: booking?.endTime,
    totalAmount: booking?.totalAmount,
    maxPersons: 1, // individual member pass
    bookingRef: `#NSC-${String(booking?.id).padStart(6, '0')}`,
  });

  return { success: true };
};
