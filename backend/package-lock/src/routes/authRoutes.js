const express = require('express');
const authController = require('../controllers/authController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { upload, uploadToCloudinaryMiddleware } = require('../middleware/cloudinaryUploadMiddleware');

const router = express.Router();

// Public routes
router.post('/register', authController.register);
router.post('/login', authController.login);
router.post('/google-login', authController.googleLogin);
router.post('/refresh', authController.refreshToken);
router.post('/forgot-password', authController.forgotPassword);
router.post('/reset-password', authController.resetPassword);
router.post('/set-password', authController.setPassword);

// Debug endpoint (remove in production)
router.get('/debug-token', (req, res) => {
  const token = req.cookies.accessToken;
  res.json({
    hasToken: !!token,
    token: token ? token.substring(0, 20) + '...' : null,
    cookies: req.cookies,
    headers: req.headers
  });
});

// Protected routes
router.post('/logout', authenticateToken, authController.logout);

router.get('/profile', authenticateToken, authController.getProfile);

// Admin-entered staff record (Employee / Coach) shown read-only on My Profile.
router.get('/staff-details', authenticateToken, authController.getStaffDetails);
router.put('/profile', authenticateToken, authController.updateProfile);
router.put('/change-password', authenticateToken, authController.changePassword);
router.post(
  '/profile/picture',
  authenticateToken,
  upload.single('profile_picture'),
  uploadToCloudinaryMiddleware('profiles'),
  authController.uploadProfilePicture
);

module.exports = router;
