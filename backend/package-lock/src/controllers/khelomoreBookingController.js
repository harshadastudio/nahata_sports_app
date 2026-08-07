'use strict';

/**
 * Khelomore court-specified booking controller (JWT Bearer auth).
 *
 * This is the SEPARATE Khelomore surface: every booking names an explicit
 * `courtId`. It deliberately does NOT contain the website's court-hidden /
 * auto-shift logic — that stays isolated on the public /api/courts flow. The
 * three handlers below are thin wrappers over the shared courtService so the
 * behaviour (atomic multi-slot create, identity-matched cancel, slot
 * availability) stays identical to the documented contract.
 *
 *   POST /api/khelomore/bookings/create
 *   POST /api/khelomore/bookings/cancel
 *   GET  /api/khelomore/courts/:courtId/available-slots?date=YYYY-MM-DD
 */

const courtService = require('../services/courtService');
const { resolvePartnerSource } = require('../config/partnerSources');

// POST /api/khelomore/bookings/create — court-specified, multi-slot, atomic.
exports.createBooking = async (req, res) => {
  try {
    if (!req.user) return res.status(401).json({ success: false, message: 'Login required to book a court' });

    const body = req.body || {};

    // Court-specified ONLY. Accept a `bookings[]` array, or a single booking
    // object (backward compatible). The court-hidden (sportComplexId+sportId,
    // no courtId) path is intentionally NOT handled here.
    let bookings = body.bookings;
    const isOldFormat = !bookings;
    if (isOldFormat) bookings = [body];

    if (!Array.isArray(bookings) || bookings.length === 0) {
      return res.status(400).json({ success: false, message: 'bookings array is required and must not be empty' });
    }

    for (let i = 0; i < bookings.length; i++) {
      const b = bookings[i];
      if (!b.courtId) return res.status(400).json({ success: false, message: `courtId is required in booking at index ${i}` });
      if (!b.date) return res.status(400).json({ success: false, message: `date is required in booking at index ${i}` });
      if (!b.startTime) return res.status(400).json({ success: false, message: `startTime is required in booking at index ${i}` });
      if (!b.endTime) return res.status(400).json({ success: false, message: `endTime is required in booking at index ${i}` });
      if (b.totalAmount === undefined) return res.status(400).json({ success: false, message: `totalAmount is required in booking at index ${i}` });
    }

    const result = await courtService.createMultipleCourtBookings({
      userId: req.user.id,
      bookings,
      couponCode: isOldFormat ? req.body.couponCode : null,
      // Khelomore bookings are permanent on creation: Confirmed + Paid, no hold.
      // Khelomore collects payment on its side, so there is no expiry/finalize step.
      // Huddle and KheloMore share this surface, so the source is derived from the
      // partner service account that authenticated rather than hardcoded.
      bookingSource: resolvePartnerSource(req.user),
      bookingStatus: 'Confirmed',
      paymentStatus: 'Paid',
    });

    res.status(201).json({
      success: true,
      message: 'Courts booked successfully',
      data: {
        bookings: result.bookings,
        combinedTotal: result.combinedTotal,
      },
    });
  } catch (err) {
    console.error('khelomore createBooking error:', err);
    const status = err.code === 'SLOT_UNAVAILABLE' || err.message.includes('already booked') ? 409
      : err.message.includes('Invalid coupon') || err.message.includes('Coupon') ? 400
      : 500;
    res.status(status).json({ success: false, message: err.message });
  }
};

// POST /api/khelomore/bookings/cancel — multi-slot, identity-matched cancel.
exports.cancelBookings = async (req, res) => {
  try {
    let bookings = req.body.bookings;

    // Backward compatibility: single booking object without the `bookings` key.
    if (!bookings && req.body.bookingId) {
      bookings = [req.body];
    }

    if (!bookings || !Array.isArray(bookings) || bookings.length === 0) {
      return res.status(400).json({ success: false, message: 'bookings array is required and must not be empty' });
    }

    for (let i = 0; i < bookings.length; i++) {
      const b = bookings[i];
      if (!b.bookingId) return res.status(400).json({ success: false, message: `bookingId is required in booking at index ${i}` });
      if (!b.courtId || !b.date || !b.startTime || !b.endTime) {
        return res.status(400).json({ success: false, message: `courtId, date, startTime, endTime are required for identification in booking at index ${i}` });
      }
    }

    const result = await courtService.cancelMultipleBookings(bookings);

    const message = (result.alreadyCancelled.length > 0 || result.notFound.length > 0)
      ? 'Partial cancellation completed'
      : 'Bookings cancelled successfully';

    res.status(200).json({ success: true, message, data: result });
  } catch (err) {
    console.error('khelomore cancelBookings error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── Slot blocks ───────────────────────────────────────────────────────────────
//
// A block takes a slot OFF SALE without being a booking: no customer, no pass,
// no QR, no payment, and excluded from every revenue report. It is what the
// partner sends when it holds or sells the slot on its own platform.
//
// Same request shape as bookings/create and bookings/cancel: a `slots[]` array,
// or a single object for convenience. Neither call is atomic — one bad slot
// must not discard the rest of the batch — so each entry is reported separately
// and the call itself returns 200/201 with the breakdown.

/** Pull `slots[]` (or a single object) out of the body, matching create/cancel. */
function readSlotsArray(body) {
  const slots = body.slots || body.bookings;
  if (slots) return slots;
  // Single object without the wrapper — accepted the same way create/cancel do.
  return Object.keys(body).length ? [body] : null;
}

// POST /api/nahatasports/slots/block
exports.blockSlots = async (req, res) => {
  try {
    if (!req.user) return res.status(401).json({ success: false, message: 'Login required to block a slot' });

    const slots = readSlotsArray(req.body || {});
    if (!Array.isArray(slots) || slots.length === 0) {
      return res.status(400).json({ success: false, message: 'slots array is required and must not be empty' });
    }

    for (let i = 0; i < slots.length; i++) {
      const s = slots[i];
      if (!s.courtId) return res.status(400).json({ success: false, message: `courtId is required in slot at index ${i}` });
      if (!s.date) return res.status(400).json({ success: false, message: `date is required in slot at index ${i}` });
      if (!s.startTime) return res.status(400).json({ success: false, message: `startTime is required in slot at index ${i}` });
      if (!s.endTime) return res.status(400).json({ success: false, message: `endTime is required in slot at index ${i}` });
    }

    // The partner label comes from the service account that authenticated, so
    // KheloMore and Huddle sharing this surface stay distinguishable in the panel.
    const result = await courtService.blockMultipleSlots(slots, resolvePartnerSource(req.user));

    const message = result.failed.length
      ? 'Partial block completed — some slots could not be blocked'
      : 'Slots blocked successfully';

    res.status(201).json({ success: true, message, data: result });
  } catch (err) {
    console.error('khelomore blockSlots error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
};

// POST /api/nahatasports/slots/unblock
exports.unblockSlots = async (req, res) => {
  try {
    if (!req.user) return res.status(401).json({ success: false, message: 'Login required to unblock a slot' });

    const slots = readSlotsArray(req.body || {});
    if (!Array.isArray(slots) || slots.length === 0) {
      return res.status(400).json({ success: false, message: 'slots array is required and must not be empty' });
    }

    for (let i = 0; i < slots.length; i++) {
      const s = slots[i];
      // Either the id we handed back, or the slot identity — nothing else needed.
      if (!s.blockId && !(s.courtId && s.date && s.startTime)) {
        return res.status(400).json({
          success: false,
          message: `Provide blockId, or courtId + date + startTime in slot at index ${i}`,
        });
      }
    }

    // Scoped to the caller: a partner can only release blocks it placed itself.
    const result = await courtService.unblockMultipleSlots(slots, resolvePartnerSource(req.user));

    const message = result.notFound.length
      ? 'Partial unblock completed — some blocks were not found'
      : 'Slots unblocked successfully';

    res.status(200).json({ success: true, message, data: result });
  } catch (err) {
    console.error('khelomore unblockSlots error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
};

// GET /api/khelomore/courts/:courtId/available-slots?date=YYYY-MM-DD
exports.getAvailableSlots = async (req, res) => {
  try {
    const { date } = req.query;
    if (!date) return res.status(400).json({ success: false, message: 'date query param required (YYYY-MM-DD)' });
    const slots = await courtService.getAvailableSlots(req.params.courtId, date);
    res.status(200).json({ success: true, data: slots });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};
