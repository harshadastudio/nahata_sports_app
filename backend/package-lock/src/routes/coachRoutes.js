const express = require('express');
const router = express.Router();
const coachController = require('../controllers/coachController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { optionalAuth } = require('../middleware/optionalAuth');
const { allowRoles } = require('../middleware/roleMiddleware');
// NOTE: coach create/update/delete is ADMIN-only by design. Employees get a
// read-only Coaches list (employee_coaches) and must not be able to add, edit or
// remove a coach.
const { upload, uploadToCloudinaryMiddleware } = require('../middleware/cloudinaryUploadMiddleware');

// ── Image upload endpoint (Cloudinary) ────────────────────────────────────────
router.post('/upload-image', 
  upload.single('image'), 
  uploadToCloudinaryMiddleware('coaches'),
  (req, res) => {
    if (!req.cloudinaryResult) {
      return res.status(400).json({ success: false, message: 'No image file provided' });
    }
    res.json({ 
      success: true, 
      imageUrl: req.cloudinaryResult.url,
      publicId: req.cloudinaryResult.publicId 
    });
  }
);

// Public read routes.
// optionalAuth: anonymous = all coaches (website); logged-in COMPLEX_ADMIN = own complex only.
router.get('/', optionalAuth, coachController.getAllCoaches);
router.get('/sport/:sportId', coachController.getCoachesBySport);
router.get('/:id', optionalAuth, coachController.getCoachById);
router.get('/:id/stats', coachController.getCoachStats);

// Reveal / reset the coach's login password (ADMIN + COMPLEX_ADMIN only)
router.get('/:id/password', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN'), coachController.revealPassword);
router.post('/:id/reset-password', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN'), coachController.resetPassword);

// Protected write routes — ADMIN (super admin) or COMPLEX_ADMIN (own complex)
router.post('/', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN'), coachController.createCoach);
router.put('/:id', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN'), coachController.updateCoach);
router.patch('/:id/status', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN'), coachController.updateCoachStatus);
router.delete('/:id', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN'), coachController.deleteCoach);

module.exports = router;
