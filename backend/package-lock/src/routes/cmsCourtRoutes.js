const express = require('express');
const router = express.Router();
const cmsCourtController = require('../controllers/cmsCourtController');
const { authenticateToken, requireRole } = require('../middleware/authMiddleware');
const { upload, uploadToCloudinaryMiddleware } = require('../middleware/cloudinaryUploadMiddleware');

// Image upload (local/Cloudinary) - Protected
router.post('/upload-image',
  authenticateToken,
  requireRole(['Super Admin', 'Admin']),
  upload.single('image'),
  uploadToCloudinaryMiddleware('cms-courts'),
  (req, res) => {
    if (!req.cloudinaryResult) {
      return res.status(400).json({ success: false, message: 'No image file provided' });
    }
    return res.status(200).json({
      success: true,
      url: req.cloudinaryResult.url,
      publicId: req.cloudinaryResult.publicId
    });
  }
);

// Public route (for the Home page)
router.get('/frontend', cmsCourtController.getFrontendCmsCourts);

// Protected routes (admin)
router.get('/', authenticateToken, requireRole(['Super Admin', 'Admin']), cmsCourtController.getAllCmsCourts);
router.get('/:id', authenticateToken, requireRole(['Super Admin', 'Admin']), cmsCourtController.getCmsCourtById);
router.post('/', authenticateToken, requireRole(['Super Admin', 'Admin']), cmsCourtController.createCmsCourt);
router.put('/:id', authenticateToken, requireRole(['Super Admin', 'Admin']), cmsCourtController.updateCmsCourt);
router.patch('/:id/show-on-frontend', authenticateToken, requireRole(['Super Admin', 'Admin']), cmsCourtController.toggleShowOnFrontend);
router.delete('/:id', authenticateToken, requireRole(['Super Admin', 'Admin']), cmsCourtController.deleteCmsCourt);

module.exports = router;
