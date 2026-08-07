'use strict';

const express = require('express');
const router = express.Router();
const paymentController = require('../controllers/paymentController');
const { authenticateToken, optionalAuthenticate } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');

// GET /api/payments/all — aggregated payments view (super admin = all complexes;
// complex admin = only their complex's facility/event/coaching payments)
router.get('/all', authenticateToken, allowRoles('ADMIN', 'EMPLOYEE', 'COMPLEX_ADMIN'), paymentController.getAllPayments);

// POST /api/payments/create-order
// optionalAuthenticate: website facility bookings are always logged in (ownership
// enforced); guest event checkout is allowed (no token). The charge amount is
// derived server-side and the order is bound to the booking regardless.
router.post('/create-order', optionalAuthenticate, paymentController.createOrder);

// POST /api/payments/verify
router.post('/verify', optionalAuthenticate, paymentController.verifyPayment);

module.exports = router;
