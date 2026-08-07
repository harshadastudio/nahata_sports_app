'use strict';

/**
 * Khelomore court-specified booking routes (JWT Bearer auth).
 *
 * The SEPARATE Khelomore surface, mounted at /api/khelomore. Court is always
 * explicit (courtId). The website's court-hidden / auto-shift flow lives on
 * /api/courts and is intentionally NOT reachable here.
 *
 *   POST /api/khelomore/bookings/create
 *   POST /api/khelomore/bookings/cancel
 *   POST /api/khelomore/slots/block
 *   POST /api/khelomore/slots/unblock
 *   GET  /api/khelomore/courts/:courtId/available-slots?date=YYYY-MM-DD
 *
 * (Mounted at /api/nahatasports — see server.js.)
 */

const express = require('express');
const khelomoreBookingController = require('../controllers/khelomoreBookingController');
const { authenticateToken } = require('../middleware/authMiddleware');

const router = express.Router();

// ── Booking (auth required) ───────────────────────────────────────────────────
router.post('/bookings/create', authenticateToken, khelomoreBookingController.createBooking);
router.post('/bookings/cancel', authenticateToken, khelomoreBookingController.cancelBookings);

// ── Slot blocks (auth required) ───────────────────────────────────────────────
// Take a slot off sale without creating a booking, and release it again.
router.post('/slots/block', authenticateToken, khelomoreBookingController.blockSlots);
router.post('/slots/unblock', authenticateToken, khelomoreBookingController.unblockSlots);

// ── Slot availability (public, per court) ─────────────────────────────────────
router.get('/courts/:courtId/available-slots', khelomoreBookingController.getAvailableSlots);

module.exports = router;
