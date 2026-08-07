const express = require('express');
const router = express.Router();
const settingsController = require('../controllers/settingsController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');
const { upload, uploadToCloudinaryMiddleware } = require('../middleware/cloudinaryUploadMiddleware');

// ── Public (no auth) — storefront-safe subset, e.g. booking-page banner ───────
router.get('/public', settingsController.getPublicSettings);

// All remaining settings routes require authentication and admin role
router.use(authenticateToken);
router.use(allowRoles('ADMIN', 'admin', 'super_admin', 'SUPER_ADMIN'));

/**
 * @route   POST /api/settings/upload-image
 * @desc    Upload an image (e.g. booking-summary banner) to local server storage
 * @access  Admin, Super Admin
 */
router.post(
  '/upload-image',
  upload.single('image'),
  uploadToCloudinaryMiddleware('settings'),
  (req, res) => {
    if (!req.cloudinaryResult) {
      return res.status(400).json({ success: false, message: 'No image file provided' });
    }
    res.json({ success: true, imageUrl: req.cloudinaryResult.url });
  }
);

/**
 * @route   GET /api/settings
 * @desc    Get all settings
 * @access  Admin, Super Admin
 */
router.get('/', settingsController.getSettings);

/**
 * @route   PUT /api/settings
 * @desc    Update all settings
 * @access  Admin, Super Admin
 */
router.put('/', settingsController.updateSettings);

/**
 * @route   PUT /api/settings/general
 * @desc    Update general settings
 * @access  Admin, Super Admin
 */
router.put('/general', settingsController.updateGeneralSettings);

/**
 * @route   PUT /api/settings/pricing
 * @desc    Update pricing settings
 * @access  Admin, Super Admin
 */
router.put('/pricing', settingsController.updatePricingSettings);

/**
 * @route   PUT /api/settings/integration
 * @desc    Update integration settings
 * @access  Admin, Super Admin
 */
router.put('/integration', settingsController.updateIntegrationSettings);

/**
 * @route   PUT /api/settings/social
 * @desc    Update social media links shown in the public site footer
 * @access  Admin, Super Admin
 */
router.put('/social', settingsController.updateSocialSettings);

module.exports = router;
