const express = require('express');
const bookingController = require('../controllers/bookingController');
const { authenticateToken, requireRole } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');

const router = express.Router();

// Protected routes - require authentication
router.use(authenticateToken);

// Create booking - ADMIN, USER, EMPLOYEE, COMPLEX_ADMIN
router.post('/', allowRoles('ADMIN', 'USER', 'EMPLOYEE', 'COMPLEX_ADMIN'), bookingController.createBooking);

// Get all bookings - ADMIN, EMPLOYEE, COMPLEX_ADMIN
router.get('/', allowRoles('ADMIN', 'EMPLOYEE', 'COMPLEX_ADMIN'), bookingController.getAllBookings);

// Get statistics - ADMIN, EMPLOYEE, COMPLEX_ADMIN (place before /:id route)
router.get('/stats', allowRoles('ADMIN', 'EMPLOYEE', 'COMPLEX_ADMIN'), bookingController.getBookingStats);

// Get current/today's bookings - ADMIN, EMPLOYEE, COMPLEX_ADMIN
router.get('/current', allowRoles('ADMIN', 'EMPLOYEE', 'COMPLEX_ADMIN'), bookingController.getCurrentBookings);

// Get single booking - any authenticated user
router.get('/:id', bookingController.getBookingById);

// Update booking - ADMIN, USER, EMPLOYEE, COMPLEX_ADMIN
router.put('/:id', allowRoles('ADMIN', 'USER', 'EMPLOYEE', 'COMPLEX_ADMIN'), bookingController.updateBooking);

// Delete booking - ADMIN, USER, EMPLOYEE, COMPLEX_ADMIN
router.delete('/:id', allowRoles('ADMIN', 'USER', 'EMPLOYEE', 'COMPLEX_ADMIN'), bookingController.deleteBooking);

module.exports = router;
