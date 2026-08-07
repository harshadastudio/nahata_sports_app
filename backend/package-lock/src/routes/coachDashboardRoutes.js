const express = require('express');
const router = express.Router();
const coachDashboardController = require('../controllers/coachDashboardController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');

// All routes require COACH authentication
router.use(authenticateToken);
router.use(allowRoles('COACH'));

// Dashboard stats
router.get('/stats', coachDashboardController.getDashboardStats);

// Today's schedule
router.get('/schedule/today', coachDashboardController.getTodaySchedule);

// Top performers
router.get('/students/top-performers', coachDashboardController.getTopPerformers);

// My students
router.get('/students/my-students', coachDashboardController.getMyStudents);

// Month-wise enrollments, grouped batch-wise
router.get('/students/enrollments-by-month', coachDashboardController.getEnrollmentsByMonth);

// Attendance records
router.get('/attendance/records', coachDashboardController.getAttendanceRecords);

// Student progress
router.get('/performance/progress', coachDashboardController.getStudentProgress);
// Record a new progress/assessment for one of the coach's students
router.post('/performance/progress', coachDashboardController.recordStudentProgress);
// Edit / delete an existing progress record (own students only)
router.put('/performance/progress/:id', coachDashboardController.updateStudentProgress);
router.delete('/performance/progress/:id', coachDashboardController.deleteStudentProgress);

// My batches/schedule
router.get('/schedule/batches', coachDashboardController.getMyBatches);

// Autocomplete endpoints
router.get('/autocomplete/students', coachDashboardController.getStudentsAutocomplete);
router.get('/autocomplete/sports', coachDashboardController.getSportsAutocomplete);
router.get('/autocomplete/batches', coachDashboardController.getBatchesAutocomplete);
router.get('/autocomplete/programs', coachDashboardController.getProgramsAutocomplete);

module.exports = router;
