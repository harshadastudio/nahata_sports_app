const express = require('express');
const router = express.Router();
const cmsSportController = require('../controllers/cmsSportController');
const { authenticateToken, requireRole } = require('../middleware/authMiddleware');
const { upload, uploadToCloudinaryMiddleware } = require('../middleware/cloudinaryUploadMiddleware');

// Image upload (local/Cloudinary) - Protected
router.post('/upload-image',
  authenticateToken,
  requireRole(['Super Admin', 'Admin']),
  upload.single('image'),
  uploadToCloudinaryMiddleware('cms-sports'),
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
router.get('/frontend', cmsSportController.getFrontendCmsSports);

// Protected routes (admin)
router.get('/', authenticateToken, requireRole(['Super Admin', 'Admin']), cmsSportController.getAllCmsSports);
router.get('/:id', authenticateToken, requireRole(['Super Admin', 'Admin']), cmsSportController.getCmsSportById);
router.post('/', authenticateToken, requireRole(['Super Admin', 'Admin']), cmsSportController.createCmsSport);
router.put('/:id', authenticateToken, requireRole(['Super Admin', 'Admin']), cmsSportController.updateCmsSport);
router.patch('/:id/show-on-frontend', authenticateToken, requireRole(['Super Admin', 'Admin']), cmsSportController.toggleShowOnFrontend);
router.delete('/:id', authenticateToken, requireRole(['Super Admin', 'Admin']), cmsSportController.deleteCmsSport);

module.exports = router;
