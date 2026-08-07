const express = require('express');
const router = express.Router();
const sportsComplexController = require('../controllers/sportsComplexController');
const { upload, uploadToCloudinaryMiddleware } = require('../middleware/cloudinaryUploadMiddleware');
const { deleteFromCloudinary, extractPublicId } = require('../config/cloudinary');

// ── Image upload endpoint (Cloudinary) ────────────────────────────────────────
router.post('/upload-image', 
  upload.single('image'), 
  uploadToCloudinaryMiddleware('sports-complexes'),
  (req, res) => {
    if (!req.cloudinaryResult) {
      return res.status(400).json({ success: false, message: 'No image file provided' });
    }
    return res.status(200).json({ 
      success: true, 
      imageUrl: req.cloudinaryResult.url,
      publicId: req.cloudinaryResult.publicId 
    });
  }
);

// ── Delete image from Cloudinary ──────────────────────────────────────────────
router.delete('/delete-image', async (req, res) => {
  try {
    const { imageUrl } = req.query;
    if (!imageUrl) {
      return res.status(400).json({ success: false, message: 'imageUrl required' });
    }
    
    const publicId = extractPublicId(imageUrl);
    if (publicId) {
      await deleteFromCloudinary(publicId);
    }
    
    return res.status(200).json({ success: true });
  } catch (error) {
    console.error('Error deleting image:', error);
    return res.status(500).json({ success: false, message: 'Failed to delete image' });
  }
});

// ── CRUD routes ───────────────────────────────────────────────────────────────
router.get('/', sportsComplexController.getAllSportsComplexes);
router.get('/city/:city', sportsComplexController.getSportsComplexesByCity);
router.get('/state/:state', sportsComplexController.getSportsComplexesByState);
router.get('/:id', sportsComplexController.getSportsComplexById);
router.get('/:id/stats', sportsComplexController.getSportsComplexStats);
router.post('/', sportsComplexController.createSportsComplex);
router.put('/:id', sportsComplexController.updateSportsComplex);
router.patch('/:id/status', sportsComplexController.updateSportsComplexStatus);
router.patch('/:id/show-on-frontend', sportsComplexController.toggleShowOnFrontend);
router.delete('/:id', sportsComplexController.deleteSportsComplex);

module.exports = router;
