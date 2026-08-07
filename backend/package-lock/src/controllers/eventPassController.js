'use strict';

const eventPassService = require('../services/eventPassService');
const { validateEmailOrThrow } = require('../utils/emailValidation');
const { resolveComplexId, isComplexAdmin, stampComplexId, assertComplexAccess } = require('../middleware/complexScope');
const { resolveClientPlatform } = require('../utils/clientPlatform');

// ── Event Pass CRUD (admin) ───────────────────────────────────────────────────

exports.getAllEventPasses = async (req, res) => {
  try {
    const { status, search, page = 1, limit = 10 } = req.query;

    const filters = { status, search };
    // Per-complex admin scoping (null for super admin = all complexes)
    const complexId = resolveComplexId(req);
    if (complexId != null) filters.sportComplexId = complexId;

    const result = await eventPassService.getAllEventPasses(
      filters,
      parseInt(page),
      parseInt(limit)
    );
    res.status(200).json({
      success: true,
      message: 'Event passes retrieved successfully',
      data: result.events,
      pagination: {
        currentPage: result.currentPage,
        totalPages: result.totalPages,
        totalItems: result.totalItems,
        itemsPerPage: result.itemsPerPage,
      },
    });
  } catch (error) {
    console.error('Error in getAllEventPasses:', error);
    res.status(500).json({ success: false, message: 'Failed to retrieve event passes', error: error.message });
  }
};

exports.getEventPassById = async (req, res) => {
  try {
    const event = await eventPassService.getEventPassById(req.params.id);
    if (!event) return res.status(404).json({ success: false, message: 'Event pass not found' });
    // Complex admins can only view event passes in their own complex
    if (!assertComplexAccess(req, res, event.sportComplexId)) return;
    res.status(200).json({ success: true, data: event });
  } catch (error) {
    console.error('Error in getEventPassById:', error);
    res.status(500).json({ success: false, message: 'Failed to retrieve event pass', error: error.message });
  }
};

exports.createEventPass = async (req, res) => {
  try {
    const { title, description, image, status, slots, faqs, customFields } = req.body;
    if (!title || !title.trim()) {
      return res.status(400).json({ success: false, message: 'Event title is required' });
    }
    const eventData = { title: title.trim(), description, image, status, slots, faqs, customFields };
    // Force the complex for a complex admin; honor explicit value for super admin
    stampComplexId(req, eventData);

    // Every event belongs to exactly one sports complex — the website filters by
    // it, so an unassigned event would be invisible under any complex.
    if (eventData.sportComplexId == null || Number.isNaN(Number(eventData.sportComplexId))) {
      return res.status(400).json({ success: false, message: 'Sports complex is required' });
    }
    try {
      await eventPassService.assertComplexExists(eventData.sportComplexId);
    } catch (complexErr) {
      return res.status(400).json({ success: false, message: complexErr.message });
    }

    const event = await eventPassService.createEventPass(eventData);
    res.status(201).json({ success: true, message: 'Event pass created successfully', data: event });
  } catch (error) {
    console.error('Error in createEventPass:', error);
    res.status(500).json({ success: false, message: 'Failed to create event pass', error: error.message });
  }
};

exports.updateEventPass = async (req, res) => {
  try {
    const existing = await eventPassService.getEventPassById(req.params.id);
    if (!existing) {
      return res.status(404).json({ success: false, message: 'Event pass not found' });
    }

    // Complex admins may only edit event passes in their own complex, and cannot
    // move an event to a different complex.
    if (isComplexAdmin(req)) {
      if (!assertComplexAccess(req, res, existing.sportComplexId)) return;
      stampComplexId(req, req.body);
    }

    // The complex stays mandatory on edit. Legacy events created before this was
    // enforced carry a null complex — saving one now requires picking it.
    const effectiveComplexId =
      req.body.sportComplexId !== undefined ? req.body.sportComplexId : existing.sportComplexId;
    if (effectiveComplexId == null || Number.isNaN(Number(effectiveComplexId))) {
      return res.status(400).json({ success: false, message: 'Sports complex is required' });
    }
    if (Number(effectiveComplexId) !== Number(existing.sportComplexId)) {
      try {
        await eventPassService.assertComplexExists(effectiveComplexId);
      } catch (complexErr) {
        return res.status(400).json({ success: false, message: complexErr.message });
      }
    }

    const updated = await eventPassService.updateEventPass(req.params.id, req.body);
    if (!updated) return res.status(404).json({ success: false, message: 'Event pass not found' });
    res.status(200).json({ success: true, message: 'Event pass updated successfully', data: updated });
  } catch (error) {
    console.error('Error in updateEventPass:', error);
    res.status(500).json({ success: false, message: 'Failed to update event pass', error: error.message });
  }
};

exports.deleteEventPass = async (req, res) => {
  try {
    // Complex admins may only delete event passes in their own complex
    if (isComplexAdmin(req)) {
      const existing = await eventPassService.getEventPassById(req.params.id);
      if (!existing) {
        return res.status(404).json({ success: false, message: 'Event pass not found' });
      }
      if (!assertComplexAccess(req, res, existing.sportComplexId)) return;
    }

    const deleted = await eventPassService.deleteEventPass(req.params.id);
    if (!deleted) return res.status(404).json({ success: false, message: 'Event pass not found' });
    res.status(200).json({ success: true, message: 'Event pass deleted successfully' });
  } catch (error) {
    console.error('Error in deleteEventPass:', error);
    res.status(500).json({ success: false, message: 'Failed to delete event pass', error: error.message });
  }
};

// ── DELETE /api/event-passes/bookings ─────────────────────────────────────────
// Permanently delete one or more event-pass bookings (admin cleanup).
// Accepts { ids: [...] } for a bulk delete, or a single id in the URL.
exports.deleteBookings = async (req, res) => {
  try {
    const fromBody = Array.isArray(req.body?.ids) ? req.body.ids : [];
    const fromParam = req.params.bookingId ? [req.params.bookingId] : [];
    const ids = [...fromBody, ...fromParam];

    if (ids.length === 0) {
      return res.status(400).json({ success: false, message: 'No booking ids provided' });
    }

    const { deleted, notFound } = await eventPassService.deleteBookings(ids);

    if (deleted === 0) {
      return res.status(404).json({ success: false, message: 'No matching bookings found' });
    }

    res.status(200).json({
      success: true,
      message: `${deleted} booking${deleted === 1 ? '' : 's'} deleted permanently`,
      data: { deleted, notFound },
    });
  } catch (error) {
    console.error('Error in deleteBookings:', error);
    res.status(500).json({ success: false, message: 'Failed to delete bookings', error: error.message });
  }
};

// ── Image Upload (Cloudinary) ─────────────────────────────────────────────────

exports.uploadImage = (req, res) => {
  try {
    if (!req.cloudinaryResult) {
      return res.status(400).json({ success: false, message: 'No image file provided' });
    }
    res.status(200).json({ 
      success: true, 
      imageUrl: req.cloudinaryResult.url,
      publicId: req.cloudinaryResult.publicId 
    });
  } catch (error) {
    console.error('Error in uploadImage:', error);
    res.status(500).json({ success: false, message: 'Failed to upload image', error: error.message });
  }
};

// ── Bookings ──────────────────────────────────────────────────────────────────

exports.createBooking = async (req, res) => {
  try {
    const { eventPassId, slotId, name, email, numberOfPasses, couponCode, customFieldValues } = req.body;

    if (!eventPassId || !slotId) {
      return res.status(400).json({ success: false, message: 'eventPassId and slotId are required' });
    }
    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, message: 'Name is required' });
    }
    if (!email || !email.trim()) {
      return res.status(400).json({ success: false, message: 'Email is required' });
    }

    // Validate email & catch domain typos so the event-pass email doesn't bounce
    let validEmail;
    try {
      validEmail = validateEmailOrThrow(email, 'Email');
    } catch (emailErr) {
      return res.status(400).json({ success: false, message: emailErr.message });
    }

    const userId = req.user?.id || null;

    const booking = await eventPassService.createBooking({
      eventPassId,
      slotId,
      userId,
      name: name.trim(),
      email: validEmail,
      numberOfPasses: parseInt(numberOfPasses) || 1,
      couponCode: couponCode || null,
      // Answers to the event's admin-defined fields — validated server-side.
      customFieldValues: customFieldValues ?? null,
      // Which client is booking — gates coupons restricted to Web or App.
      platform: resolveClientPlatform(req),
    });

    // ── Auto-send pass email after booking ────────────────────────────────────
    // Only a FREE booking carries a pass at this point. A paid booking has no
    // pass until /payments/verify confirms the payment, which issues and emails
    // it — so a cancelled checkout sends nothing.
    if (booking.individualPasses && booking.individualPasses.length > 0) {
      const pass = booking.individualPasses[0];
      eventPassService.sendPassByEmail(pass.id, validEmail, name.trim())
        .then(() => console.log(`✅ Event pass email sent to ${validEmail}`))
        .catch((err) => console.error(`❌ Event pass email failed for booking ${booking.id}:`, err.message));
    }

    res.status(201).json({ success: true, message: 'Booking created successfully', data: booking });
  } catch (error) {
    console.error('Error in createBooking:', error);
    // Coupon problems and custom-field validation failures are the user's to fix,
    // so they come back as 400 with the reason rather than a generic 500.
    const isUserError =
      /Invalid coupon|Coupon|is required|must be/i.test(error.message) ||
      error.message === 'Slot not found';
    res.status(isUserError ? 400 : 500).json({
      success: false,
      message: isUserError ? error.message : 'Failed to create booking',
      error: error.message,
    });
  }
};

exports.getAllBookings = async (req, res) => {
  try {
    const { status, eventPassId, page = 1, limit = 10 } = req.query;

    const filters = { status, eventPassId };
    // Per-complex scoping (null for super admin = every complex). Applies to the
    // Issue Event Pass list and its CSV export alike, so a complex admin can
    // never read another complex's guest names and emails.
    const complexId = resolveComplexId(req);
    if (complexId != null) filters.sportComplexId = complexId;

    const result = await eventPassService.getAllBookings(
      filters,
      parseInt(page),
      parseInt(limit)
    );
    res.status(200).json({
      success: true,
      message: 'Bookings retrieved successfully',
      data: result.bookings,
      pagination: {
        currentPage: result.currentPage,
        totalPages: result.totalPages,
        totalItems: result.totalItems,
        itemsPerPage: result.itemsPerPage,
      },
    });
  } catch (error) {
    console.error('Error in getAllBookings:', error);
    res.status(500).json({ success: false, message: 'Failed to retrieve bookings', error: error.message });
  }
};

// GET /api/event-passes/bookings/my
exports.getMyBookings = async (req, res) => {
  try {
    const { page = 1, limit = 20 } = req.query;
    const userId = req.user?.id;
    const email = req.user?.email;

    const result = await eventPassService.getAllBookings(
      { userId },
      parseInt(page),
      parseInt(limit)
    );

    let bookings = result.bookings;
    if (bookings.length === 0 && email) {
      const emailResult = await eventPassService.getAllBookings(
        { email },
        parseInt(page),
        parseInt(limit)
      );
      bookings = emailResult.bookings;
    }

    res.status(200).json({
      success: true,
      message: 'Your bookings retrieved successfully',
      data: bookings,
      pagination: result.pagination,
    });
  } catch (error) {
    console.error('Error in getMyBookings:', error);
    res.status(500).json({ success: false, message: 'Failed to retrieve your bookings', error: error.message });
  }
};

// ── Individual Passes ─────────────────────────────────────────────────────────

// GET /api/event-passes/bookings/:bookingId/passes
// Returns the single group pass for a booking
exports.getIndividualPasses = async (req, res) => {
  try {
    const pass = await eventPassService.getPassForBooking(req.params.bookingId);
    res.status(200).json({ success: true, data: pass });
  } catch (error) {
    console.error('Error in getIndividualPasses:', error);
    res.status(500).json({ success: false, message: 'Failed to retrieve pass', error: error.message });
  }
};

// ── Scan IN / OUT ─────────────────────────────────────────────────────────────

// POST /api/event-passes/scan
exports.scanPass = async (req, res) => {
  try {
    const { passCode, scanType } = req.body;

    if (!passCode || !passCode.trim()) {
      return res.status(400).json({ success: false, message: 'passCode is required' });
    }
    if (!scanType || !['In', 'Out'].includes(scanType)) {
      return res.status(400).json({ success: false, message: 'scanType must be "In" or "Out"' });
    }

    // Attribute the scan to the logged-in security guard when present
    // (route uses optionalAuth, so unauthenticated devices still work).
    const scannedBy = req.user?.id || null;
    const result = await eventPassService.scanPass(passCode.trim(), scanType, scannedBy);

    if (!result.success) {
      return res.status(400).json({ success: false, message: result.message, pass: result.pass || null });
    }

    res.status(200).json({
      success: true,
      message: result.message,
      data: result.pass,
    });
  } catch (error) {
    console.error('Error in scanPass:', error);
    res.status(500).json({ success: false, message: 'Scan failed', error: error.message });
  }
};

// GET /api/event-passes/my-scan-stats — event-pass scans by the logged-in guard
exports.getMyScanStats = async (req, res) => {
  try {
    const stats = await eventPassService.getMyEventScanStats(req.user?.id);
    res.status(200).json({ success: true, data: stats });
  } catch (error) {
    console.error('Error in getMyScanStats:', error);
    res.status(500).json({ success: false, message: 'Failed to get scan stats', error: error.message });
  }
};

// GET /api/event-passes/:eventPassId/scan-stats
exports.getScanStats = async (req, res) => {
  try {
    const stats = await eventPassService.getEventScanStats(req.params.eventPassId);
    res.status(200).json({ success: true, data: stats });
  } catch (error) {
    console.error('Error in getScanStats:', error);
    res.status(500).json({ success: false, message: 'Failed to get scan stats', error: error.message });
  }
};

// ── Send pass by email ────────────────────────────────────────────────────────

// POST /api/event-passes/individual-passes/:passId/send-email
exports.sendPassByEmail = async (req, res) => {
  try {
    const { passId } = req.params;
    const { recipientEmail, recipientName } = req.body;

    await eventPassService.sendPassByEmail(passId, recipientEmail, recipientName);

    res.status(200).json({ success: true, message: 'Pass sent via email successfully' });
  } catch (error) {
    console.error('Error in sendPassByEmail:', error);
    res.status(500).json({ success: false, message: 'Failed to send pass email', error: error.message });
  }
};

// ── Member Management ─────────────────────────────────────────────────────────

// POST /api/event-passes/individual-passes/:passId/members
// Save (replace) the member list for a pass
exports.saveMembers = async (req, res) => {
  try {
    const { passId } = req.params;
    const { members } = req.body;

    if (!Array.isArray(members)) {
      return res.status(400).json({ success: false, message: 'members must be an array' });
    }

    const saved = await eventPassService.saveMembers(passId, members);
    res.status(200).json({ success: true, message: 'Members saved successfully', data: saved });
  } catch (error) {
    console.error('Error in saveMembers:', error);
    res.status(400).json({ success: false, message: error.message });
  }
};

// POST /api/event-passes/members/:memberId/scan
// Scan a specific member IN or OUT
exports.scanMember = async (req, res) => {
  try {
    const { memberId } = req.params;
    const { scanType } = req.body;

    if (!scanType || !['In', 'Out'].includes(scanType)) {
      return res.status(400).json({ success: false, message: 'scanType must be "In" or "Out"' });
    }

    const result = await eventPassService.scanMember(memberId, scanType);

    if (!result.success) {
      return res.status(400).json({ success: false, message: result.message, member: result.member || null });
    }

    res.status(200).json({ success: true, message: result.message, data: { member: result.member, pass: result.pass } });
  } catch (error) {
    console.error('Error in scanMember:', error);
    res.status(500).json({ success: false, message: 'Scan failed', error: error.message });
  }
};
