'use strict';

const courtService = require('../services/courtService');
const { resolveComplexId, isComplexScoped, stampComplexId, assertComplexAccess } = require('../middleware/complexScope');
const { resolveClientPlatform } = require('../utils/clientPlatform');

exports.getAllCourts = async (req, res) => {
  try {
    const { status, sportComplexId, sportId, showOnFrontend, page = 1, limit = 20 } = req.query;
    const filters = { status, sportComplexId, sportId };
    if (showOnFrontend !== undefined) filters.showOnFrontend = showOnFrontend === 'true';

    // Per-complex admin scoping (null for super admin = all complexes; a complex
    // admin is forced to their own complex, overriding any ?sportComplexId).
    // Reuses the existing sportComplexId filter on the list service.
    const complexId = resolveComplexId(req);
    if (complexId != null) filters.sportComplexId = complexId;
    const result = await courtService.getAllCourts(filters, parseInt(page), parseInt(limit));
    res.status(200).json({ success: true, data: result.courts, pagination: { currentPage: result.currentPage, totalPages: result.totalPages, totalItems: result.totalItems } });
  } catch (err) {
    console.error('getAllCourts error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.getCourtById = async (req, res) => {
  try {
    const court = await courtService.getCourtById(req.params.id);
    if (!court) return res.status(404).json({ success: false, message: 'Court not found' });
    // Complex admins can only view courts in their own complex
    if (!assertComplexAccess(req, res, court.sportComplexId)) return;
    res.status(200).json({ success: true, data: court });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.createCourt = async (req, res) => {
  try {
    // Force the complex for a complex admin; honor explicit value for super admin.
    // Stamped before validation so a complex admin's own complex satisfies the check.
    stampComplexId(req, req.body);

    const { name, sportComplexId, sportId, hourlyRate } = req.body;
    if (!name || !sportComplexId || !sportId || hourlyRate === undefined) {
      return res.status(400).json({ success: false, message: 'name, sportComplexId, sportId and hourlyRate are required' });
    }
    const court = await courtService.createCourt(req.body);
    res.status(201).json({ success: true, message: 'Court created successfully', data: court });
  } catch (err) {
    console.error('createCourt error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.updateCourt = async (req, res) => {
  try {
    // Complex admins may only edit courts in their own complex, and cannot move
    // a court to a different complex.
    if (isComplexScoped(req)) {
      const existing = await courtService.getCourtById(req.params.id);
      if (!existing) return res.status(404).json({ success: false, message: 'Court not found' });
      if (!assertComplexAccess(req, res, existing.sportComplexId)) return;
      stampComplexId(req, req.body);
    }
    const updated = await courtService.updateCourt(req.params.id, req.body);
    if (!updated) return res.status(404).json({ success: false, message: 'Court not found' });
    res.status(200).json({ success: true, message: 'Court updated successfully', data: updated });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.deleteCourt = async (req, res) => {
  try {
    if (isComplexScoped(req)) {
      const existing = await courtService.getCourtById(req.params.id);
      if (!existing) return res.status(404).json({ success: false, message: 'Court not found' });
      if (!assertComplexAccess(req, res, existing.sportComplexId)) return;
    }
    const deleted = await courtService.deleteCourt(req.params.id);
    if (!deleted) return res.status(404).json({ success: false, message: 'Court not found' });
    res.status(200).json({ success: true, message: 'Court deleted successfully' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.getAvailableSlots = async (req, res) => {
  try {
    const { date } = req.query;
    if (!date) return res.status(400).json({ success: false, message: 'date query param required (YYYY-MM-DD)' });
    const slots = await courtService.getAvailableSlots(req.params.id, date);
    res.status(200).json({ success: true, data: slots });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── Court-hidden availability (auto slot adjustment) ──────────────────────────

exports.getAvailability = async (req, res) => {
  try {
    const { sportComplexId, sportId, date, startTime, duration } = req.query;
    if (!sportComplexId || !sportId || !date || !startTime || !duration) {
      return res.status(400).json({ success: false, message: 'sportComplexId, sportId, date, startTime and duration are required' });
    }
    const durationMinutes = Math.round(parseFloat(duration) * 60);
    if (!(durationMinutes > 0)) {
      return res.status(400).json({ success: false, message: 'duration must be a positive number of hours' });
    }
    const result = await courtService.getCourtAvailability({ sportComplexId, sportId, date, startTime, durationMinutes });
    res.status(200).json({ success: true, data: result });
  } catch (err) {
    console.error('getAvailability error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.getAvailabilityTimes = async (req, res) => {
  try {
    const { sportComplexId, sportId, date, duration } = req.query;
    if (!sportComplexId || !sportId || !date || !duration) {
      return res.status(400).json({ success: false, message: 'sportComplexId, sportId, date and duration are required' });
    }
    const durationMinutes = Math.round(parseFloat(duration) * 60);
    if (!(durationMinutes > 0)) {
      return res.status(400).json({ success: false, message: 'duration must be a positive number of hours' });
    }
    const data = await courtService.getAvailableStartTimes({ sportComplexId, sportId, date, durationMinutes });
    res.status(200).json({ success: true, data });
  } catch (err) {
    console.error('getAvailabilityTimes error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.createBooking = async (req, res) => {
  try {
    if (!req.user) return res.status(401).json({ success: false, message: 'Login required to book a court' });

    const body = req.body || {};

    // Which client is booking — gates coupons restricted to Web or App.
    const platform = resolveClientPlatform(req);

    // ── Court-hidden (time-first) path: client sends sport+venue, no courtId ──
    if (!body.bookings && !body.courtId && body.sportComplexId && body.sportId) {
      const { sportComplexId, sportId, date, startTime, endTime, totalAmount, couponCode } = body;
      if (!date || !startTime || !endTime) {
        return res.status(400).json({ success: false, message: 'date, startTime and endTime are required' });
      }
      const { booking, movedBookings } = await courtService.createAutoAdjustedBooking({
        userId: req.user.id,
        sportComplexId,
        sportId,
        date,
        startTime,
        endTime,
        totalAmount,
        couponCode: couponCode || null,
        platform,
      });

      // Notify customers whose court was silently reassigned (non-blocking).
      if (movedBookings.length && typeof courtService.notifyReassignedBookings === 'function') {
        courtService.notifyReassignedBookings(movedBookings).catch((e) => console.error('reassign notify error:', e.message));
      }

      return res.status(201).json({
        success: true,
        message: 'Court reserved',
        data: { bookings: [booking], combinedTotal: parseFloat(booking.totalAmount) },
      });
    }

    // ── Legacy court-specified path (backward compatible) ────────────────────
    let bookings = body.bookings;
    const isOldFormat = !bookings;

    if (isOldFormat) {
      bookings = [body];
    }

    if (!Array.isArray(bookings) || bookings.length === 0) {
      return res.status(400).json({ success: false, message: 'bookings array is required and must not be empty' });
    }

    // Validation
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
      couponCode: isOldFormat ? req.body.couponCode : null, // Support coupon only for old format or if explicitly handled later
      platform,
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
    console.error('createBooking error:', err);
    const status = err.code === 'SLOT_UNAVAILABLE' || err.message.includes('already booked') ? 409
      : err.message.includes('Invalid coupon') || err.message.includes('Coupon') ? 400
      : 500;
    res.status(status).json({ success: false, message: err.message });
  }
};

exports.cancelBookings = async (req, res) => {
  try {
    let bookings = req.body.bookings;

    // Backward compatibility: if "bookings" key is missing but it's a single booking object
    if (!bookings && req.body.bookingId) {
      bookings = [req.body];
    }

    if (!bookings || !Array.isArray(bookings) || bookings.length === 0) {
      return res.status(400).json({ success: false, message: 'bookings array is required and must not be empty' });
    }

    // Validation
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

    res.status(200).json({
      success: true,
      message,
      data: result,
    });
  } catch (err) {
    console.error('cancelBookings error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
};

// POST /api/courts/bookings/:bookingId/release
// Called by the checkout when the user cancels/dismisses the Razorpay popup or
// the payment fails: frees the held slot right away and drops the unpaid
// booking, so a cancelled payment never leaves a booking (or a pass) behind.
exports.releaseBooking = async (req, res) => {
  try {
    if (!req.user) return res.status(401).json({ success: false, message: 'Login required' });

    const result = await courtService.releaseUnpaidBooking({
      bookingId: req.params.bookingId,
      requestUser: req.user,
    });

    if (result.status === 'not_found') {
      return res.status(404).json({ success: false, message: 'Booking not found' });
    }
    if (result.status === 'forbidden') {
      return res.status(403).json({ success: false, message: 'You cannot release this booking.' });
    }
    if (result.status === 'paid') {
      return res.status(400).json({ success: false, message: 'This booking is already paid. Cancel it instead.' });
    }

    return res.status(200).json({
      success: true,
      message: result.status === 'already' ? 'Booking was already released' : 'Booking released',
    });
  } catch (err) {
    console.error('releaseBooking error:', err);
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.getMyBookings = async (req, res) => {
  try {
    if (!req.user) return res.status(401).json({ success: false, message: 'Login required' });
    const { page = 1, limit = 20 } = req.query;
    const result = await courtService.getUserCourtBookings(req.user.id, parseInt(page), parseInt(limit));
    res.status(200).json({ success: true, data: result.bookings, pagination: { currentPage: result.currentPage, totalPages: result.totalPages, totalItems: result.totalItems } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// POST /api/courts/bookings/:bookingId/send-email
// Share a confirmed booking's QR pass to an email address.
exports.sendPassByEmail = async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { recipientEmail, recipientName } = req.body;
    await courtService.sendBookingPassByEmail(bookingId, recipientEmail, recipientName);
    res.status(200).json({ success: true, message: 'Booking pass sent via email successfully' });
  } catch (err) {
    console.error('Error in court sendPassByEmail:', err);
    res.status(500).json({ success: false, message: err.message || 'Failed to send pass email' });
  }
};

// ── Booking Members + Scanning ────────────────────────────────────────────────

// POST /api/courts/bookings/:bookingId/members
// Save (replace) the allowed members for a booking. Each gets an individual QR.
exports.saveMembers = async (req, res) => {
  try {
    const { bookingId } = req.params;
    const { members } = req.body;
    if (!Array.isArray(members)) {
      return res.status(400).json({ success: false, message: 'members must be an array' });
    }
    const saved = await courtService.saveBookingMembers(bookingId, members);
    res.status(200).json({ success: true, message: 'Members saved successfully', data: saved });
  } catch (err) {
    res.status(400).json({ success: false, message: err.message });
  }
};

// POST /api/courts/bookings/:bookingId/members/:memberId/send-email
exports.sendMemberPassByEmail = async (req, res) => {
  try {
    const { bookingId, memberId } = req.params;
    const { recipientEmail } = req.body;
    await courtService.sendMemberPassByEmail(bookingId, memberId, recipientEmail);
    res.status(200).json({ success: true, message: 'Member pass sent via email successfully' });
  } catch (err) {
    console.error('Error in court sendMemberPassByEmail:', err);
    res.status(400).json({ success: false, message: err.message || 'Failed to send member pass email' });
  }
};

// POST /api/courts/bookings/scan  (NO auth — security tablet)
exports.scanPass = async (req, res) => {
  try {
    const { passCode, code, scanType } = req.body;
    const result = await courtService.scanBookingPass(passCode || code, scanType);
    const status = result.success ? 200 : 400;
    res.status(status).json({ ...result, data: result.booking });
  } catch (err) {
    console.error('Error in court scanPass:', err);
    res.status(500).json({ success: false, message: err.message || 'Scan failed' });
  }
};

// POST /api/courts/members/:memberId/scan  (NO auth — security tablet)
exports.scanMember = async (req, res) => {
  try {
    const { memberId } = req.params;
    const { scanType } = req.body;
    const result = await courtService.scanBookingMember(memberId, scanType);
    const status = result.success ? 200 : 400;
    res.status(status).json({ ...result, data: result.booking });
  } catch (err) {
    console.error('Error in court scanMember:', err);
    res.status(500).json({ success: false, message: err.message || 'Scan failed' });
  }
};

// GET /api/courts/bookings/scan-stats?courtId=&date=
exports.getScanStats = async (req, res) => {
  try {
    const { courtId, date } = req.query;
    const stats = await courtService.getCourtScanStats(courtId, date);
    res.status(200).json({ success: true, data: stats });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── Slot CRUD ─────────────────────────────────────────────────────────────────

exports.getSlotsByCourt = async (req, res) => {
  try {
    const slots = await courtService.getSlotsByCourt(req.params.courtId);
    res.status(200).json({ success: true, data: slots });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.createSlot = async (req, res) => {
  try {
    const { startTime, endTime, availableDays, slotType, priceOverride, status } = req.body;
    if (!startTime || !endTime) {
      return res.status(400).json({ success: false, message: 'startTime and endTime are required' });
    }
    const slot = await courtService.createSlot(req.params.courtId, {
      startTime, endTime, availableDays, slotType, priceOverride, status,
    });
    res.status(201).json({ success: true, message: 'Slot created', data: slot });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.updateSlot = async (req, res) => {
  try {
    const slot = await courtService.updateSlot(req.params.slotId, req.body);
    if (!slot) return res.status(404).json({ success: false, message: 'Slot not found' });
    res.status(200).json({ success: true, message: 'Slot updated', data: slot });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.deleteSlot = async (req, res) => {
  try {
    const deleted = await courtService.deleteSlot(req.params.slotId);
    if (!deleted) return res.status(404).json({ success: false, message: 'Slot not found' });
    res.status(200).json({ success: true, message: 'Slot deleted' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.toggleSlotStatus = async (req, res) => {
  try {
    const { status } = req.body;
    if (!['Active', 'Inactive'].includes(status)) {
      return res.status(400).json({ success: false, message: 'status must be Active or Inactive' });
    }
    const slot = await courtService.toggleSlotStatus(req.params.slotId, status);
    if (!slot) return res.status(404).json({ success: false, message: 'Slot not found' });
    res.status(200).json({ success: true, message: 'Slot status updated', data: slot });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── CourtSlot CRUD ────────────────────────────────────────────────────────────

// Blocked-slot management scopes through the slot's court: a complex admin may only
// touch slots of courts in their own complex. (All slot routes carry :id = courtId.)
const ensureCourtInComplex = async (req, res) => {
  if (!isComplexScoped(req)) return true;
  const court = await courtService.getCourtById(req.params.id);
  if (!court) {
    res.status(404).json({ success: false, message: 'Court not found' });
    return false;
  }
  return assertComplexAccess(req, res, court.sportComplexId);
};

exports.getSlotsByCourt = async (req, res) => {
  try {
    if (!(await ensureCourtInComplex(req, res))) return;
    const slots = await courtService.getSlotsByCourt(req.params.id);
    res.status(200).json({ success: true, data: slots });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.createSlot = async (req, res) => {
  try {
    if (!(await ensureCourtInComplex(req, res))) return;
    const slot = await courtService.createSlot(req.params.id, req.body);
    res.status(201).json({ success: true, message: 'Slot created successfully', data: slot });
  } catch (err) {
    const status = err.message.includes('not found') ? 404 : 500;
    res.status(status).json({ success: false, message: err.message });
  }
};

exports.updateSlot = async (req, res) => {
  try {
    if (!(await ensureCourtInComplex(req, res))) return;
    const slot = await courtService.updateSlot(req.params.slotId, req.body);
    if (!slot) return res.status(404).json({ success: false, message: 'Slot not found' });
    res.status(200).json({ success: true, message: 'Slot updated successfully', data: slot });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.deleteSlot = async (req, res) => {
  try {
    if (!(await ensureCourtInComplex(req, res))) return;
    const deleted = await courtService.deleteSlot(req.params.slotId);
    if (!deleted) return res.status(404).json({ success: false, message: 'Slot not found' });
    res.status(200).json({ success: true, message: 'Slot deleted successfully' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

exports.toggleSlotStatus = async (req, res) => {
  try {
    // `req.body` is undefined when a client PATCHes without a JSON body, and
    // destructuring it threw a 500 ("Cannot destructure property 'status' of
    // 'req.body'") instead of the intended 400.
    const { status } = req.body || {};
    if (!['Active', 'Inactive'].includes(status)) {
      return res.status(400).json({ success: false, message: 'status must be Active or Inactive' });
    }
    if (!(await ensureCourtInComplex(req, res))) return;
    const slot = await courtService.toggleSlotStatus(req.params.slotId, status);
    if (!slot) return res.status(404).json({ success: false, message: 'Slot not found' });
    res.status(200).json({ success: true, message: `Slot ${status.toLowerCase()}`, data: slot });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── Date-specific slot blocks ─────────────────────────────────────────────────
//
// Distinct from toggleSlotStatus above, which flips the SLOT TEMPLATE and so
// blocks that time on every date it applies to. These act on one date only,
// which is what the Blocked Slots screen (court + date + slot) actually means.

const ISO_DATE = /^\d{4}-\d{2}-\d{2}$/;

/** POST /courts/:id/slots/:slotId/block — body { date, notes? } */
exports.blockSlotForDate = async (req, res) => {
  try {
    const { date, notes } = req.body || {};
    if (!ISO_DATE.test(String(date || ''))) {
      return res.status(400).json({ success: false, message: 'date is required (YYYY-MM-DD)' });
    }
    if (!(await ensureCourtInComplex(req, res))) return;

    // The slot template carries the interval — the client sends a slot, not times,
    // so a block can never drift from the grid the court actually sells.
    const slot = await courtService.getSlotById(req.params.slotId);
    if (!slot || String(slot.courtId) !== String(req.params.id)) {
      return res.status(404).json({ success: false, message: 'Slot not found for this court' });
    }

    const block = await courtService.createSlotBlock({
      courtId: Number(req.params.id),
      date,
      startTime: slot.startTime,
      endTime: slot.endTime,
      blockedBy: 'Admin',
      notes: notes || null,
    });

    res.status(201).json({ success: true, message: 'Slot blocked', data: block });
  } catch (err) {
    // Never block over a real customer — the booking wins.
    const status = err.code === 'SLOT_BOOKED' ? 409 : 500;
    res.status(status).json({ success: false, message: err.message });
  }
};

/**
 * POST /courts/:id/slots/:slotId/unblock — body { date }
 *
 * Releases whoever placed it, partner blocks included: the venue must always be
 * able to put its own court back on sale without waiting on the partner.
 */
exports.unblockSlotForDate = async (req, res) => {
  try {
    const { date } = req.body || {};
    if (!ISO_DATE.test(String(date || ''))) {
      return res.status(400).json({ success: false, message: 'date is required (YYYY-MM-DD)' });
    }
    if (!(await ensureCourtInComplex(req, res))) return;

    const slot = await courtService.getSlotById(req.params.slotId);
    if (!slot || String(slot.courtId) !== String(req.params.id)) {
      return res.status(404).json({ success: false, message: 'Slot not found for this court' });
    }

    const released = await courtService.releaseSlotBlock({
      courtId: Number(req.params.id),
      date,
      startTime: slot.startTime,
      // Passing the full interval lets a longer partner block that merely
      // covers this slot be found and released.
      endTime: slot.endTime,
    });

    if (!released) {
      return res.status(404).json({ success: false, message: 'No active block found for that slot and date' });
    }

    res.status(200).json({ success: true, message: 'Slot unblocked', data: released });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── Toggle showOnFrontend ─────────────────────────────────────────────────────

exports.toggleShowOnFrontend = async (req, res) => {
  try {
    const { showOnFrontend } = req.body;
    if (typeof showOnFrontend !== 'boolean') {
      return res.status(400).json({ success: false, message: 'showOnFrontend must be a boolean' });
    }
    if (isComplexScoped(req)) {
      const existing = await courtService.getCourtById(req.params.id);
      if (!existing) return res.status(404).json({ success: false, message: 'Court not found' });
      if (!assertComplexAccess(req, res, existing.sportComplexId)) return;
    }
    const court = await courtService.toggleShowOnFrontend(req.params.id, showOnFrontend);
    if (!court) return res.status(404).json({ success: false, message: 'Court not found' });
    res.status(200).json({
      success: true,
      message: `Court ${showOnFrontend ? 'shown on' : 'hidden from'} frontend`,
      data: court,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};
