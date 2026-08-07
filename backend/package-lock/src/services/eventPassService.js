'use strict';

const { EventPass, EventPassSlot, EventPassBooking, EventIndividualPass, EventPassMember, EventPassScanLog, User, SportComplex, sequelize } = require('../models');
const { Op } = require('sequelize');
const emailService = require('./emailService');

// ── Helpers ───────────────────────────────────────────────────────────────────

/** Unique pass code: EVTPASS-<year>-<bookingId padded> */
function generatePassCode(bookingId) {
  const year = new Date().getFullYear();
  const bid = String(bookingId).padStart(6, '0');
  return `EVTPASS-${year}-${bid}`;
}

/** QR code image URL */
function buildQrUrl(passCode) {
  return `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(passCode)}&format=png&margin=10`;
}

/** Normalize an incoming faqs payload into a clean [{ question, answer }] array */
function sanitizeFaqs(faqs) {
  if (!Array.isArray(faqs)) return [];
  return faqs
    .filter((f) => f && String(f.question).trim() && String(f.answer).trim())
    .map((f) => ({ question: String(f.question).trim(), answer: String(f.answer).trim() }));
}

// ── Custom booking fields ─────────────────────────────────────────────────────

/** Input types an admin may choose for a custom booking field. */
const CUSTOM_FIELD_TYPES = ['text', 'textarea', 'number', 'email', 'phone', 'date', 'select'];

/** "WhatsApp Number" → "whatsapp_number" — the stable link between a field and its answers. */
function slugifyFieldKey(label) {
  return String(label)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 50);
}

/**
 * Normalize an incoming customFields payload into a clean definition array.
 *
 * An existing `key` sent by the admin panel is preserved so renaming a label
 * never breaks the link to answers already collected; a new field gets its key
 * derived from the label. Keys are de-duplicated because they address answers.
 */
function sanitizeCustomFields(fields) {
  if (!Array.isArray(fields)) return [];

  const usedKeys = new Set();

  return fields.reduce((acc, f) => {
    if (!f) return acc;

    const label = String(f.label ?? '').trim();
    if (!label) return acc; // a field without a label has nothing to show

    const type = CUSTOM_FIELD_TYPES.includes(f.type) ? f.type : 'text';

    // Dropdowns are meaningless without choices — degrade to a plain text input
    // rather than shipping an empty <select> to the booking form.
    const options =
      type === 'select'
        ? [...new Set((Array.isArray(f.options) ? f.options : []).map((o) => String(o).trim()).filter(Boolean))]
        : [];
    if (type === 'select' && options.length === 0) return acc;

    let key = slugifyFieldKey(f.key || label) || `field_${acc.length + 1}`;
    while (usedKeys.has(key)) key = `${key}_${acc.length + 1}`;
    usedKeys.add(key);

    acc.push({
      key,
      label,
      type,
      required: Boolean(f.required),
      placeholder: String(f.placeholder ?? '').trim() || null,
      options,
    });
    return acc;
  }, []);
}

/**
 * Check a booking's submitted answers against the event's field definitions and
 * return the [{ key, label, value }] snapshot to store on the booking.
 *
 * Runs on the server because the browser form is only a convenience — a direct
 * API call must not be able to skip a required field.
 *
 * @param {Array} definitions  event.customFields
 * @param {Array|Object} submitted  [{ key, value }] or { key: value }
 * @throws {Error} on a missing required field or a malformed value
 */
function validateCustomFieldValues(definitions, submitted) {
  const defs = Array.isArray(definitions) ? definitions : [];
  if (defs.length === 0) return [];

  // Accept either wire shape: an array of { key, value } or a plain map.
  const byKey = new Map();
  if (Array.isArray(submitted)) {
    submitted.forEach((v) => v && v.key != null && byKey.set(String(v.key), v.value));
  } else if (submitted && typeof submitted === 'object') {
    Object.entries(submitted).forEach(([k, v]) => byKey.set(String(k), v));
  }

  return defs.map((def) => {
    const raw = byKey.get(def.key);
    const value = raw == null ? '' : String(raw).trim();

    if (!value) {
      if (def.required) throw new Error(`${def.label} is required`);
      return { key: def.key, label: def.label, value: '' };
    }

    switch (def.type) {
      case 'number':
        if (Number.isNaN(Number(value))) throw new Error(`${def.label} must be a number`);
        break;
      case 'email':
        if (!/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(value)) {
          throw new Error(`${def.label} must be a valid email address`);
        }
        break;
      case 'phone': {
        const digits = value.replace(/\D/g, '');
        if (digits.length < 7 || digits.length > 15) {
          throw new Error(`${def.label} must be a valid phone number`);
        }
        break;
      }
      case 'date':
        if (Number.isNaN(new Date(value).getTime())) throw new Error(`${def.label} must be a valid date`);
        break;
      case 'select':
        if (Array.isArray(def.options) && def.options.length > 0 && !def.options.includes(value)) {
          throw new Error(`${def.label} must be one of: ${def.options.join(', ')}`);
        }
        break;
      default:
        break;
    }

    return { key: def.key, label: def.label, value };
  });
}

exports.sanitizeCustomFields = sanitizeCustomFields;
exports.validateCustomFieldValues = validateCustomFieldValues;

// ── Event Pass CRUD (admin) ───────────────────────────────────────────────────

exports.getAllEventPasses = async (filters = {}, page = 1, limit = 10) => {
  const where = {};
  if (filters.status) where.status = filters.status;
  if (filters.search) {
    where[Op.or] = [{ title: { [Op.iLike]: `%${filters.search}%` } }];
  }

  // Per-complex admin scoping (no-op when not provided)
  if (filters.sportComplexId != null) {
    where.sportComplexId = filters.sportComplexId;
  }

  const offset = (page - 1) * limit;
  const { count, rows } = await EventPass.findAndCountAll({
    where,
    include: [
      { model: EventPassSlot, as: 'slots', where: { status: 'Active' }, required: false },
      { model: SportComplex, as: 'sportComplex', attributes: ['id', 'name'], required: false },
    ],
    order: [['createdAt', 'DESC']],
    limit,
    offset,
  });

  return {
    events: rows,
    currentPage: page,
    totalPages: Math.ceil(count / limit),
    totalItems: count,
    itemsPerPage: limit,
  };
};

exports.getEventPassById = async (id) => {
  return EventPass.findByPk(id, {
    include: [
      { model: EventPassSlot, as: 'slots', where: { status: 'Active' }, required: false },
      { model: SportComplex, as: 'sportComplex', attributes: ['id', 'name'], required: false },
    ],
  });
};

/** Reject an unknown complex up front so the caller gets a message, not an FK error. */
exports.assertComplexExists = async (sportComplexId) => {
  const complex = await SportComplex.findByPk(sportComplexId, { attributes: ['id'] });
  if (!complex) throw new Error('Selected sports complex does not exist');
  return true;
};

exports.createEventPass = async (data) => {
  const event = await EventPass.create({
    title: data.title,
    description: data.description || null,
    image: data.image || null,
    status: data.status || 'Active',
    sportComplexId: data.sportComplexId != null ? data.sportComplexId : null, // Per-complex admin scoping
    faqs: sanitizeFaqs(data.faqs),
    customFields: sanitizeCustomFields(data.customFields),
  });

  if (data.slots && Array.isArray(data.slots) && data.slots.length > 0) {
    const slotRecords = data.slots
      .filter((s) => s.name && s.date)
      .map((s) => ({
        eventPassId: event.id,
        name: s.name,
        date: s.date,
        price: parseFloat(s.price) || 0,
        passType: s.passType || null,
        startTime: s.startTime || null,
        endTime: s.endTime || null,
        status: 'Active',
      }));
    if (slotRecords.length > 0) await EventPassSlot.bulkCreate(slotRecords);
  }

  return exports.getEventPassById(event.id);
};

exports.updateEventPass = async (id, data) => {
  const event = await EventPass.findByPk(id);
  if (!event) return null;

  await event.update({
    title: data.title ?? event.title,
    description: data.description !== undefined ? data.description : event.description,
    image: data.image !== undefined ? data.image : event.image,
    status: data.status ?? event.status,
    // Per-complex admin scoping — honor explicit sportComplexId, otherwise keep existing
    sportComplexId: data.sportComplexId !== undefined ? data.sportComplexId : event.sportComplexId,
    faqs: data.faqs !== undefined ? sanitizeFaqs(data.faqs) : event.faqs,
    customFields:
      data.customFields !== undefined ? sanitizeCustomFields(data.customFields) : event.customFields,
  });

  if (data.slots && Array.isArray(data.slots)) {
    await EventPassSlot.destroy({ where: { eventPassId: id } });
    const slotRecords = data.slots
      .filter((s) => s.name && s.date)
      .map((s) => ({
        eventPassId: id,
        name: s.name,
        date: s.date,
        price: parseFloat(s.price) || 0,
        passType: s.passType || null,
        startTime: s.startTime || null,
        endTime: s.endTime || null,
        status: 'Active',
      }));
    if (slotRecords.length > 0) await EventPassSlot.bulkCreate(slotRecords);
  }

  return exports.getEventPassById(id);
};

exports.deleteEventPass = async (id) => {
  const event = await EventPass.findByPk(id);
  if (!event) return false;
  await event.destroy();
  return true;
};

/**
 * Permanently delete event-pass BOOKINGS (admin cleanup from "Issue Event Pass").
 *
 * A booking owns individual passes, which in turn own members and scan logs, so
 * the children are removed first — a plain booking.destroy() would trip the
 * foreign keys. Everything runs in one transaction so a partial delete can
 * never leave orphaned passes behind.
 *
 * @param {Array<number|string>} ids  booking ids
 * @returns {Promise<{deleted: number, notFound: number[]}>}
 */
exports.deleteBookings = async (ids = []) => {
  const bookingIds = [...new Set(
    ids.map((id) => parseInt(id, 10)).filter((id) => Number.isInteger(id) && id > 0)
  )];
  if (bookingIds.length === 0) return { deleted: 0, notFound: [] };

  return sequelize.transaction(async (t) => {
    const bookings = await EventPassBooking.findAll({
      where: { id: { [Op.in]: bookingIds } },
      attributes: ['id'],
      transaction: t,
    });

    const foundIds = bookings.map((b) => b.id);
    const notFound = bookingIds.filter((id) => !foundIds.includes(id));
    if (foundIds.length === 0) return { deleted: 0, notFound };

    const passes = await EventIndividualPass.findAll({
      where: { bookingId: { [Op.in]: foundIds } },
      attributes: ['id'],
      transaction: t,
    });
    const passIds = passes.map((p) => p.id);

    if (passIds.length > 0) {
      await EventPassScanLog.destroy({ where: { individualPassId: { [Op.in]: passIds } }, transaction: t });
      await EventPassMember.destroy({ where: { passId: { [Op.in]: passIds } }, transaction: t });
      await EventIndividualPass.destroy({ where: { id: { [Op.in]: passIds } }, transaction: t });
    }

    const deleted = await EventPassBooking.destroy({
      where: { id: { [Op.in]: foundIds } },
      transaction: t,
    });

    return { deleted, notFound };
  });
};

// ── Bookings ──────────────────────────────────────────────────────────────────

/**
 * Issue the single group pass for a booking. That one pass is valid for
 * `numberOfPasses` persons (maxPersons on the pass = numberOfPasses).
 *
 * Idempotent: if the booking already has a pass it returns the existing one, so
 * a repeated /payments/verify call can never mint a second pass.
 *
 * Only ever called once a booking is actually payable-complete: immediately for
 * a ₹0 booking, and from the payment-verification path for a paid booking.
 */
exports.issuePassForBooking = async (bookingId) => {
  const existing = await EventIndividualPass.findOne({ where: { bookingId } });
  if (existing) return existing;

  const booking = await EventPassBooking.findByPk(bookingId);
  if (!booking) throw new Error('Booking not found');

  const passCode = generatePassCode(booking.id);
  const qrUrl = buildQrUrl(passCode);

  const pass = await EventIndividualPass.create({
    bookingId: booking.id,
    eventPassId: booking.eventPassId,
    slotId: booking.slotId,
    holderName: booking.name,
    holderEmail: booking.email,
    passCode,
    qrCode: qrUrl,
    maxPersons: booking.numberOfPasses,   // ← this pass covers N people
    scannedInCount: 0,
    scannedOutCount: 0,
    scanStatus: 'NotScanned',
    isValid: true,
  });

  // Mirror the QR on the booking for convenience
  await booking.update({ qrCode: qrUrl });

  return pass;
};

/**
 * Issue the pass for a paid booking and email it to the booker. Called after
 * the payment has been verified.
 *
 * The pass is created before returning (the caller reports success only once it
 * exists); the email is fire-and-forget so SMTP latency never delays the
 * payment-verification response. Never throws.
 */
exports.issueAndSendPassAfterPayment = async (bookingId) => {
  try {
    // Already issued (a repeat verify call) → nothing to do, and crucially no
    // second email.
    const already = await EventIndividualPass.findOne({ where: { bookingId } });
    if (already) return already;

    const pass = await exports.issuePassForBooking(bookingId);
    const booking = await EventPassBooking.findByPk(bookingId);
    if (booking?.email) {
      exports.sendPassByEmail(pass.id, booking.email, booking.name)
        .then(() => console.log(`✅ Event pass email sent to ${booking.email}`))
        .catch((err) => console.error(`❌ Event pass email failed for booking ${bookingId}:`, err.message));
    }
    return pass;
  } catch (err) {
    console.error(`❌ Failed to issue event pass for booking ${bookingId}:`, err.message);
    return null;
  }
};

/**
 * Create a booking.
 *
 * The pass is NOT created here for a paid booking — the booking is left
 * 'Pending' with no pass, and `issuePassForBooking` runs only after the payment
 * is verified. This is what stops a cancelled/abandoned checkout from handing
 * out a usable pass. A ₹0 booking has nothing to pay, so it is confirmed and
 * issued straight away.
 */
exports.createBooking = async (data) => {
  const slot = await EventPassSlot.findByPk(data.slotId, {
    include: [{ model: EventPass, as: 'event' }],
  });
  if (!slot) throw new Error('Slot not found');

  const numPasses = parseInt(data.numberOfPasses) || 1;
  const originalAmount = parseFloat(slot.price) * numPasses;

  // Admin-defined extra inputs — validated here (not just in the browser) and
  // captured once for the whole booking, whatever the number of passes.
  const customFieldValues = validateCustomFieldValues(
    slot.event?.customFields,
    data.customFieldValues
  );

  // ── Coupon handling ───────────────────────────────────────────────────────
  const couponService = require('./couponService');
  let couponCode = null;
  let discountAmount = 0;
  let finalAmount = originalAmount;

  if (data.couponCode && data.couponCode.trim()) {
    const coupon = await couponService.validateCoupon(data.couponCode.trim(), {
      appliesTo: 'Event',
      eventPassId: data.eventPassId,
      // Undefined for admin-created bookings → platform not enforced.
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
    await couponService.incrementUsageCount(coupon.id);
  }

  // Nothing to pay → the booking is complete on creation.
  const isFree = finalAmount <= 0;

  // Create the parent booking record
  const booking = await EventPassBooking.create({
    eventPassId: data.eventPassId,
    slotId: data.slotId,
    userId: data.userId || null,
    name: data.name,
    email: data.email,
    numberOfPasses: numPasses,
    customFieldValues,
    totalAmount: finalAmount,
    originalAmount: originalAmount !== finalAmount ? originalAmount : null,
    discountAmount,
    couponCode,
    status: isFree ? 'Confirmed' : 'Pending',
    qrCode: null,
  });

  // Notify admins (super admin + the event's complex admin) — fire-and-forget.
  require('./notificationService').notifyAdmins({
    type: 'Booking',
    title: 'New Event Booking',
    message: `${data.name || 'A user'} booked ${numPasses} pass(es) for ${slot.event?.title || 'an event'}`,
    actionUrl: '/issue-pass',
    sportComplexId: slot.event?.sportComplexId ?? null,
  });

  // Free booking → issue the group pass now. Paid booking → no pass yet; it is
  // issued from the payment-verification path once the payment succeeds.
  if (isFree) {
    await exports.issuePassForBooking(booking.id);
  }

  return EventPassBooking.findByPk(booking.id, {
    include: [
      { model: EventPass, as: 'event' },
      { model: EventPassSlot, as: 'slot' },
      {
        model: EventIndividualPass,
        as: 'individualPasses',
        attributes: [
          'id', 'passCode', 'qrCode', 'maxPersons',
          'scannedInCount', 'scannedOutCount', 'scanStatus',
          'scannedInAt', 'scannedOutAt', 'holderName', 'holderEmail', 'isValid',
        ],
      },
    ],
  });
};

exports.getAllBookings = async (filters = {}, page = 1, limit = 10) => {
  const where = {};
  if (filters.status) where.status = filters.status;
  if (filters.eventPassId) where.eventPassId = filters.eventPassId;
  if (filters.userId) where.userId = filters.userId;
  if (filters.email) where.email = filters.email;

  // A booking has no complex of its own — it is reached through its event.
  // Join-scoping the include (required: true) keeps a complex admin's list and
  // CSV export limited to their own complex's bookings.
  const eventWhere = filters.sportComplexId != null
    ? { sportComplexId: filters.sportComplexId }
    : undefined;

  const offset = (page - 1) * limit;
  const { count, rows } = await EventPassBooking.findAndCountAll({
    where,
    // distinct: the hasMany includes below multiply rows, which would otherwise
    // inflate `count` and break pagination.
    distinct: true,
    include: [
      {
        model: EventPass,
        as: 'event',
        attributes: ['id', 'title', 'image', 'sportComplexId'],
        where: eventWhere,
        required: Boolean(eventWhere),
        include: [{ model: SportComplex, as: 'sportComplex', attributes: ['id', 'name'], required: false }],
      },
      {
        model: EventPassSlot,
        as: 'slot',
        attributes: ['id', 'name', 'date', 'passType', 'price', 'startTime', 'endTime'],
      },
      {
        model: EventIndividualPass,
        as: 'individualPasses',
        attributes: [
          'id', 'passCode', 'qrCode', 'maxPersons',
          'scannedInCount', 'scannedOutCount', 'scanStatus',
          'scannedInAt', 'scannedOutAt', 'holderName', 'holderEmail', 'isValid',
        ],
        include: [
          {
            model: EventPassMember,
            as: 'members',
            attributes: ['id', 'name', 'phone', 'scanStatus', 'scannedInAt', 'scannedOutAt'],
          },
        ],
      },
    ],
    order: [['createdAt', 'DESC']],
    limit,
    offset,
  });

  return {
    bookings: rows,
    currentPage: page,
    totalPages: Math.ceil(count / limit),
    totalItems: count,
    itemsPerPage: limit,
  };
};

// ── Get the single pass for a booking ────────────────────────────────────────

exports.getPassForBooking = async (bookingId) => {
  return EventIndividualPass.findOne({
    where: { bookingId },
    include: [
      { model: EventPass, as: 'event', attributes: ['id', 'title', 'image'] },
      {
        model: EventPassSlot,
        as: 'slot',
        attributes: ['id', 'name', 'date', 'passType', 'price', 'startTime', 'endTime'],
      },
      {
        model: EventPassMember,
        as: 'members',
        attributes: ['id', 'name', 'phone', 'scanStatus', 'scannedInAt', 'scannedOutAt'],
      },
    ],
  });
};

// ── Scan IN / OUT ─────────────────────────────────────────────────────────────

/**
 * Scan a group pass IN or OUT.
 *
 * Rules:
 *  - Pass must exist and be valid
 *  - Current time must be within the event's time window (±30 min)
 *  - IN: scannedInCount < maxPersons  (can scan multiple times up to limit)
 *  - OUT: scannedOutCount < scannedInCount  (can't exit more than entered)
 *  - scanStatus reflects the latest direction
 */
exports.scanPass = async (passCode, scanType, scannedBy = null) => {
  const pass = await EventIndividualPass.findOne({
    where: { passCode },
    include: [
      { model: EventPass, as: 'event', attributes: ['id', 'title', 'sportComplexId'] },
      {
        model: EventPassSlot,
        as: 'slot',
        attributes: ['id', 'name', 'date', 'passType', 'startTime', 'endTime'],
      },
    ],
  });

  if (!pass) {
    return { success: false, message: 'Pass not found. Invalid QR code.' };
  }

  if (!pass.isValid) {
    return { success: false, message: 'This pass has been cancelled or invalidated.' };
  }

  // ── Time window validation ────────────────────────────────────────────────
  const slot = pass.slot;
  if (slot && slot.date) {
    const now = new Date();
    const eventDate = slot.date;
    const startStr = slot.startTime ? `${eventDate}T${slot.startTime}` : `${eventDate}T00:00:00`;
    const endStr   = slot.endTime   ? `${eventDate}T${slot.endTime}`   : `${eventDate}T23:59:59`;

    const eventStart = new Date(startStr);
    const eventEnd   = new Date(endStr);
    const scanWindowStart = new Date(eventStart.getTime() - 30 * 60 * 1000);

    if (now < scanWindowStart) {
      const mins = Math.round((eventStart - now) / 60000);
      return {
        success: false,
        message: `Event hasn't started yet. Scanning opens ${mins} minute${mins !== 1 ? 's' : ''} before the event.`,
      };
    }
    if (now > eventEnd) {
      return { success: false, message: 'Event has ended. This pass is no longer valid.' };
    }
  }

  // Capture the complex now — the reload below re-selects `event` without it.
  const complexId = pass.event ? pass.event.sportComplexId : null;

  // ── Scan direction logic ──────────────────────────────────────────────────
  const now = new Date();

  if (scanType === 'In') {
    if (pass.scannedInCount >= pass.maxPersons) {
      return {
        success: false,
        message: `All ${pass.maxPersons} person${pass.maxPersons > 1 ? 's' : ''} on this pass have already entered.`,
        pass,
      };
    }
    const newCount = pass.scannedInCount + 1;
    await pass.update({
      scannedInCount: newCount,
      scanStatus: 'In',
      scannedInAt: now,
    });
  } else if (scanType === 'Out') {
    const currentlyInside = pass.scannedInCount - pass.scannedOutCount;
    if (currentlyInside <= 0) {
      return {
        success: false,
        message: 'No one from this pass is currently inside. Cannot scan OUT.',
        pass,
      };
    }
    const newCount = pass.scannedOutCount + 1;
    await pass.update({
      scannedOutCount: newCount,
      scanStatus: 'Out',
      scannedOutAt: now,
    });
  } else {
    return { success: false, message: 'Invalid scan type. Use "In" or "Out".' };
  }

  await pass.reload({
    include: [
      { model: EventPass, as: 'event', attributes: ['id', 'title'] },
      {
        model: EventPassSlot,
        as: 'slot',
        attributes: ['id', 'name', 'date', 'passType', 'startTime', 'endTime'],
      },
      {
        model: EventPassMember,
        as: 'members',
        attributes: ['id', 'name', 'phone', 'scanStatus', 'scannedInAt', 'scannedOutAt'],
      },
    ],
  });

  // Audit + attribution: record who scanned this event pass (for the security
  // dashboard "Event Passes Scanned" count and a per-complex trail). Non-fatal.
  try {
    await EventPassScanLog.create({
      individualPassId: pass.id,
      eventPassId: pass.eventPassId,
      scannedBy: scannedBy || null,
      scanType,
      sportComplexId: complexId,
    });
  } catch (e) {
    console.warn('⚠️ Could not write event pass scan log:', e.message);
  }

  const remaining = pass.maxPersons - pass.scannedInCount;
  const inside    = pass.scannedInCount - pass.scannedOutCount;

  return {
    success: true,
    message: scanType === 'In'
      ? `Entry recorded. ${pass.scannedInCount}/${pass.maxPersons} person${pass.maxPersons > 1 ? 's' : ''} entered.${remaining > 0 ? ` ${remaining} remaining.` : ' Pass fully used.'}`
      : `Exit recorded. ${inside} person${inside !== 1 ? 's' : ''} still inside.`,
    pass,
  };
};

// ── IN/OUT counts per event ───────────────────────────────────────────────────

exports.getEventScanStats = async (eventPassId) => {
  const passes = await EventIndividualPass.findAll({ where: { eventPassId } });

  const totalPasses   = passes.length;
  const totalPersons  = passes.reduce((s, p) => s + p.maxPersons, 0);
  const inCount       = passes.reduce((s, p) => s + p.scannedInCount, 0);
  const outCount      = passes.reduce((s, p) => s + p.scannedOutCount, 0);
  const notScanned    = passes.filter((p) => p.scannedInCount === 0).length;
  const currentlyInside = inCount - outCount;

  return {
    totalPasses,
    totalPersons,
    in: inCount,
    out: outCount,
    notScanned,
    currentlyInside,
  };
};

// ── "How many event passes did THIS guard scan" (total + today) ────────────────

exports.getMyEventScanStats = async (userId) => {
  if (!userId) return { total: 0, today: 0 };

  const total = await EventPassScanLog.count({ where: { scannedBy: userId } });

  // Start of today in server local time.
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  const today = await EventPassScanLog.count({
    where: { scannedBy: userId, createdAt: { [Op.gte]: start } },
  });

  return { total, today };
};

// ── Send pass by email ────────────────────────────────────────────────────────

exports.sendPassByEmail = async (individualPassId, recipientEmail, recipientName) => {
  const pass = await EventIndividualPass.findByPk(individualPassId, {
    include: [
      { model: EventPass, as: 'event', attributes: ['id', 'title', 'image'] },
      {
        model: EventPassSlot,
        as: 'slot',
        attributes: ['id', 'name', 'date', 'passType', 'price', 'startTime', 'endTime'],
      },
    ],
  });

  if (!pass) throw new Error('Pass not found');

  await emailService.sendEventPassEmail({
    to: recipientEmail || pass.holderEmail,
    name: recipientName || pass.holderName,
    eventTitle: pass.event?.title || 'Event',
    passCode: pass.passCode,
    qrCodeUrl: pass.qrCode,
    slotDate: pass.slot?.date,
    slotName: pass.slot?.name,
    passType: pass.slot?.passType,
    startTime: pass.slot?.startTime,
    endTime: pass.slot?.endTime,
    maxPersons: pass.maxPersons,
  });

  return { success: true };
};

// ── Member Management ─────────────────────────────────────────────────────────

/**
 * Save (replace) the member list for a pass.
 * members = [{ name, phone }, ...]
 * Count must equal pass.maxPersons.
 */
exports.saveMembers = async (passId, members) => {
  const pass = await EventIndividualPass.findByPk(passId);
  if (!pass) throw new Error('Pass not found');

  if (!Array.isArray(members) || members.length === 0) {
    throw new Error('Members list cannot be empty');
  }
  if (members.length !== pass.maxPersons) {
    throw new Error(
      `This pass is for ${pass.maxPersons} person${pass.maxPersons > 1 ? 's' : ''}. Please add exactly ${pass.maxPersons} member${pass.maxPersons > 1 ? 's' : ''}.`
    );
  }

  // Validate each member
  for (const m of members) {
    if (!m.name || !String(m.name).trim()) throw new Error('Each member must have a name');
    if (!m.phone || !String(m.phone).trim()) throw new Error('Each member must have a WhatsApp number');
    // Basic phone validation — digits only, 7-15 chars
    const digits = String(m.phone).replace(/\D/g, '');
    if (digits.length < 7 || digits.length > 15) {
      throw new Error(`Invalid phone number for ${m.name}: ${m.phone}`);
    }
  }

  // Replace all existing members
  await EventPassMember.destroy({ where: { passId } });

  const records = members.map((m) => ({
    passId,
    name: String(m.name).trim(),
    phone: String(m.phone).replace(/\D/g, ''), // store digits only
    scanStatus: 'NotScanned',
  }));

  await EventPassMember.bulkCreate(records);

  return EventPassMember.findAll({
    where: { passId },
    attributes: ['id', 'name', 'phone', 'scanStatus', 'scannedInAt', 'scannedOutAt'],
  });
};

/**
 * Scan a specific member IN or OUT by memberId.
 * Also updates the parent pass counters.
 */
exports.scanMember = async (memberId, scanType) => {
  const member = await EventPassMember.findByPk(memberId, {
    include: [
      {
        model: EventIndividualPass,
        as: 'pass',
        include: [
          { model: EventPass, as: 'event', attributes: ['id', 'title'] },
          {
            model: EventPassSlot,
            as: 'slot',
            attributes: ['id', 'name', 'date', 'passType', 'startTime', 'endTime'],
          },
        ],
      },
    ],
  });

  if (!member) return { success: false, message: 'Member not found' };

  const pass = member.pass;
  if (!pass || !pass.isValid) {
    return { success: false, message: 'This pass has been cancelled or invalidated.' };
  }

  // Time window validation
  const slot = pass.slot;
  if (slot && slot.date) {
    const now = new Date();
    const startStr = slot.startTime ? `${slot.date}T${slot.startTime}` : `${slot.date}T00:00:00`;
    const endStr   = slot.endTime   ? `${slot.date}T${slot.endTime}`   : `${slot.date}T23:59:59`;
    const eventStart = new Date(startStr);
    const eventEnd   = new Date(endStr);
    const scanWindowStart = new Date(eventStart.getTime() - 30 * 60 * 1000);

    if (now < scanWindowStart) {
      const mins = Math.round((eventStart - now) / 60000);
      return { success: false, message: `Event hasn't started yet. Scanning opens ${mins} minute${mins !== 1 ? 's' : ''} before the event.` };
    }
    if (now > eventEnd) {
      return { success: false, message: 'Event has ended. This pass is no longer valid.' };
    }
  }

  const now = new Date();

  if (scanType === 'In') {
    if (member.scanStatus === 'In') {
      return { success: false, message: `${member.name} has already entered.`, member };
    }
    await member.update({ scanStatus: 'In', scannedInAt: now });
    // Increment parent pass counter
    await pass.update({
      scannedInCount: pass.scannedInCount + 1,
      scanStatus: 'In',
      scannedInAt: now,
    });
  } else if (scanType === 'Out') {
    if (member.scanStatus !== 'In') {
      return { success: false, message: `${member.name} has not entered yet. Cannot scan OUT.`, member };
    }
    await member.update({ scanStatus: 'Out', scannedOutAt: now });
    await pass.update({
      scannedOutCount: pass.scannedOutCount + 1,
      scanStatus: 'Out',
      scannedOutAt: now,
    });
  } else {
    return { success: false, message: 'Invalid scan type. Use "In" or "Out".' };
  }

  await member.reload();

  return {
    success: true,
    message: `${member.name} scanned ${scanType} successfully.`,
    member,
    pass,
  };
};
