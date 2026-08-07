const express = require('express');
const router = express.Router();
const attendanceController = require('../controllers/attendanceController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');

// All routes require authentication
router.use(authenticateToken);

// My attendance — must be before /:id to avoid param collision
router.get('/my', attendanceController.getMyAttendance);

// Stats
router.get('/stats', allowRoles('ADMIN', 'EMPLOYEE', 'COMPLEX_ADMIN'), attendanceController.getAttendanceStats);

// List all attendance (admin/employee/coach)
router.get('/', allowRoles('ADMIN', 'EMPLOYEE', 'COACH', 'COMPLEX_ADMIN'), attendanceController.getAllAttendance);

// Mark attendance (admin/employee/coach)
router.post('/', allowRoles('ADMIN', 'EMPLOYEE', 'COACH', 'COMPLEX_ADMIN'), attendanceController.markAttendance);

// Update a record
router.patch('/:id', allowRoles('ADMIN', 'COACH', 'COMPLEX_ADMIN'), attendanceController.updateAttendance);

// Delete a record
router.delete('/:id', allowRoles('ADMIN', 'COMPLEX_ADMIN'), attendanceController.deleteAttendance);

module.exports = router;
