'use strict';

const express = require('express');
const { upload, uploadToCloudinaryMiddleware } = require('../middleware/cloudinaryUploadMiddleware');
const studentController = require('../controllers/studentController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');

const router = express.Router();

// ── Public route ──────────────────────────────────────────────────────────────
// POST /api/students/register  — anyone can register as a student
router.post('/register', 
  upload.single('photo'), 
  uploadToCloudinaryMiddleware('students'),
  studentController.registerStudent
);

// ── Protected routes ──────────────────────────────────────────────────────────
// GET /api/students/me  — logged-in user gets their own student profile
router.get('/me', authenticateToken, studentController.getMyStudentProfile);

// GET /api/students/me/enrollments  — logged-in student: own batch enrollment history
router.get('/me/enrollments', authenticateToken, studentController.getMyEnrollments);

// GET /api/students/feedback  — logged-in student: get feedback received from admin
router.get('/feedback', authenticateToken, studentController.getMyFeedback);

// POST /api/students/feedback/read  — mark all feedback as read
router.post('/feedback/read', authenticateToken, studentController.markFeedbackRead);

// GET /api/students/coach/my-students  — coach: get students enrolled in their programs
router.get('/coach/my-students', authenticateToken, allowRoles('COACH'), studentController.getCoachStudents);

// GET /api/students/coach/all-students  — coach: get all students in database (for fee management)
router.get('/coach/all-students', authenticateToken, allowRoles('COACH'), studentController.getAllStudents);

// GET /api/students  — admin only: list all students
router.get('/', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN'), studentController.getAllStudents);

// GET /api/students/:id  — admin only: get single student
router.get('/:id', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN'), studentController.getStudentById);

// POST /api/students/:id/feedback  — admin/employee/coach: send feedback to a student
router.post(
  '/:id/feedback',
  authenticateToken,
  allowRoles('ADMIN', 'COMPLEX_ADMIN', 'COACH', 'EMPLOYEE'),
  studentController.sendFeedbackToStudent
);

module.exports = router;
