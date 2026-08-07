'use strict';

/**
 * Khelomore aggregator adapter routes.
 *
 * Exposes the Khelomore-compatible surface alongside the internal API WITHOUT
 * touching existing routes. The API-key guard is applied PER-ROUTE so this
 * router safely passes through any non-Khelomore path to the rest of the app
 * (it is mounted at '/').
 *
 *   POST /api/login
 *   POST /api/save-booking
 *   GET  /api/booking-summary
 *   POST /api/finalize-booking
 *   POST /api/block-slot
 *   POST /api/unblock-slot
 *   GET  /fetchslots
 */

const express = require('express');
const guard = require('../middleware/khelomoreAuth');
const c = require('../controllers/khelomoreController');

const router = express.Router();

router.post('/api/login', guard, c.login);
router.post('/api/save-booking', guard, c.saveBooking);
router.get('/api/booking-summary', guard, c.bookingSummary);
router.post('/api/finalize-booking', guard, c.finalizeBooking);
router.post('/api/block-slot', guard, c.blockSlot);
router.post('/api/unblock-slot', guard, c.unblockSlot);
router.get('/fetchslots', guard, c.fetchSlots);

module.exports = router;
