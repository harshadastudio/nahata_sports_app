const express = require('express');
const router = express.Router();
const dashboardController = require('../controllers/dashboardController');
const { authenticateToken } = require('../middleware/authMiddleware');

// All dashboard routes require authentication
router.use(authenticateToken);

/**
 * @route   GET /api/dashboard/stats
 * @desc    Get dashboard statistics
 * @access  Authenticated users
 */
router.get('/stats', dashboardController.getDashboardStats);

/**
 * @route   GET /api/dashboard/enrollment-trends
 * @desc    Get enrollment trends for chart (last 6 months)
 * @access  Authenticated users
 */
router.get('/enrollment-trends', dashboardController.getEnrollmentTrends);

/**
 * @route   GET /api/dashboard/sport-distribution
 * @desc    Get sport distribution for pie chart
 * @access  Authenticated users
 */
router.get('/sport-distribution', dashboardController.getSportDistribution);

/**
 * @route   GET /api/dashboard/live-enquiries
 * @desc    Get recent live enquiries
 * @access  Authenticated users
 */
router.get('/live-enquiries', dashboardController.getLiveEnquiries);

module.exports = router;
