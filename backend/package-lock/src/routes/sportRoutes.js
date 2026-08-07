const express = require('express');
const sportController = require('../controllers/sportController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { optionalAuth } = require('../middleware/optionalAuth');
const { allowRoles } = require('../middleware/roleMiddleware');
const { requireEmployeePermission, EMPLOYEE_PERMISSIONS } = require('../middleware/employeePermission');
const { upload, uploadToCloudinaryMiddleware } = require('../middleware/cloudinaryUploadMiddleware');

// Employees may manage sports only when the admin has granted the module.
// Data stays limited to their own complex via complexScope (EMPLOYEE is listed
// in COMPLEX_SCOPED_ROLES), so this only controls WHAT, not WHERE.
const empSports = requireEmployeePermission(EMPLOYEE_PERMISSIONS.SPORTS);

const router = express.Router();

// ── Image upload endpoint (Cloudinary) ────────────────────────────────────────
router.post('/upload-image', 
  upload.single('image'), 
  uploadToCloudinaryMiddleware('sports'),
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

// Public routes - anyone can view sports and programs.
// optionalAuth: anonymous = all sports (website); logged-in COMPLEX_ADMIN = own complex only.
router.get('/', optionalAuth, sportController.getAllSports);
router.get('/programs', optionalAuth, sportController.getSportsWithPrograms);
router.get('/:id', optionalAuth, sportController.getSportById);
router.get('/:id/stats', sportController.getSportStats);

// Write routes — admins, plus employees holding the Sports module permission.
router.post('/', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE'), empSports, sportController.createSport);
router.put('/:id', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE'), empSports, sportController.updateSport);
router.patch('/:id/status', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE'), empSports, sportController.updateSportStatus);
router.patch('/:id/show-on-frontend', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE'), empSports, sportController.toggleShowOnFrontend);
router.delete('/:id', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE'), empSports, sportController.deleteSport);

// Protected routes - require authentication
router.use(authenticateToken);

// Get sports by ground/sport complex
router.get('/ground/:sportComplexId', sportController.getSportsByGround);

// Assign sport to ground/sport complex
router.post(
  '/:sportId/assign-ground',
  allowRoles('ADMIN', 'MANAGER', 'COMPLEX_ADMIN'),
  sportController.assignSportToGround
);

module.exports = router;
