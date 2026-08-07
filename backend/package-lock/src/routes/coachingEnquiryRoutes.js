const express = require('express');
const router = express.Router();
const coachingEnquiryController = require('../controllers/coachingEnquiryController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');

// Admin routes - must be defined before user routes to avoid conflicts
router.post('/admin/create', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN'), coachingEnquiryController.createEnquiryByAdmin);
router.get('/all', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE'), coachingEnquiryController.getAllEnquiries);
router.patch('/:id/status', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN'), coachingEnquiryController.updateEnquiryStatus);
router.post('/:id/approve-and-enroll', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN', 'COACH', 'EMPLOYEE'), coachingEnquiryController.approveAndEnroll);
router.delete('/:id', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN'), coachingEnquiryController.deleteEnquiry);

// Coach routes - coaches can view their assigned enquiries and create new ones
router.get('/coach/my-enquiries', authenticateToken, allowRoles('COACH'), coachingEnquiryController.getCoachEnquiries);
router.post('/coach/create', authenticateToken, allowRoles('COACH'), coachingEnquiryController.createEnquiryByCoach);
router.patch('/coach/:id/status', authenticateToken, allowRoles('COACH'), coachingEnquiryController.updateEnquiryStatusByCoach);
router.delete('/coach/:id', authenticateToken, allowRoles('COACH'), coachingEnquiryController.deleteEnquiryByCoach);

// User routes
router.post('/', authenticateToken, coachingEnquiryController.createEnquiry);
router.get('/my-enquiries', authenticateToken, coachingEnquiryController.getUserEnquiries);
router.get('/:id', authenticateToken, coachingEnquiryController.getEnquiryById);

module.exports = router;
