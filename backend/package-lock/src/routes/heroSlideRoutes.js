const express = require('express');
const router = express.Router();
const heroSlideController = require('../controllers/heroSlideController');
const { authenticateToken, requireRole } = require('../middleware/authMiddleware');
const { upload, uploadToCloudinaryMiddleware } = require('../middleware/cloudinaryUploadMiddleware');

// Image upload endpoint (Cloudinary) - Protected
router.post('/upload-image', 
  authenticateToken,
  requireRole(['Super Admin', 'Admin']),
  upload.single('image'), 
  uploadToCloudinaryMiddleware('hero-slides'),
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

// Public routes (for frontend)
router.get('/frontend', heroSlideController.getFrontendHeroSlides);

// Protected routes (for admin)
router.get('/', authenticateToken, requireRole(['Super Admin', 'Admin']), heroSlideController.getAllHeroSlides);
router.get('/:id', authenticateToken, requireRole(['Super Admin', 'Admin']), heroSlideController.getHeroSlideById);
router.post('/', authenticateToken, requireRole(['Super Admin', 'Admin']), heroSlideController.createHeroSlide);
router.put('/:id', authenticateToken, requireRole(['Super Admin', 'Admin']), heroSlideController.updateHeroSlide);
router.patch('/:id/status', authenticateToken, requireRole(['Super Admin', 'Admin']), heroSlideController.updateHeroSlideStatus);
router.delete('/:id', authenticateToken, requireRole(['Super Admin', 'Admin']), heroSlideController.deleteHeroSlide);
router.put('/display-order/bulk', authenticateToken, requireRole(['Super Admin', 'Admin']), heroSlideController.updateDisplayOrder);

module.exports = router;
