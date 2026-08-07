const express = require('express');
const router = express.Router();
const reportsController = require('../controllers/reportsController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');

// All routes require authentication and Admin or Employee role
router.use(authenticateToken);
router.use(allowRoles('ADMIN', 'EMPLOYEE', 'COMPLEX_ADMIN'));

// Dashboard overview
router.get('/overview', reportsController.getDashboardOverview);

// Revenue analytics
router.get('/revenue', reportsController.getRevenueAnalytics);

// Booking analytics
router.get('/bookings', reportsController.getBookingAnalytics);

// Get all bookings with filters
router.get('/bookings/all', reportsController.getAllBookings);

// Get booking filter options
router.get('/bookings/filter-options', reportsController.getBookingFilterOptions);

// Get all students with filters
router.get('/students/all', reportsController.getAllStudents);

// Get student filter options
router.get('/students/filter-options', reportsController.getStudentFilterOptions);

// Get new students with retention rate
router.get('/students/new', reportsController.getNewStudents);

// Get new student filter options
router.get('/students/new/filter-options', reportsController.getNewStudentFilterOptions);

// Coach-wise student retention ratio (which coach keeps their students)
router.get('/coaches/retention', reportsController.getCoachRetention);

// Get all coaches with filters
router.get('/coaches/all', reportsController.getAllCoaches);

// Get coach filter options
router.get('/coaches/filter-options', reportsController.getCoachFilterOptions);

// Membership analytics
router.get('/memberships', reportsController.getMembershipAnalytics);

// User analytics
router.get('/users', reportsController.getUserAnalytics);

// Coaching analytics
router.get('/coaching', reportsController.getCoachingAnalytics);

// Facility analytics
router.get('/facilities', reportsController.getFacilityAnalytics);

// Chart data endpoints
router.get('/booking-trends', reportsController.getBookingTrends);
router.get('/revenue-by-court', reportsController.getRevenueByCourtChart);
router.get('/peak-hours', reportsController.getPeakHours);
router.get('/court-performance', reportsController.getCourtPerformance);

module.exports = router;
