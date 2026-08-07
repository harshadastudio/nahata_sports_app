const express = require('express');
const blogController = require('../controllers/blogController');
const { authenticateToken: authMiddleware } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');
const { upload, uploadToCloudinaryMiddleware } = require('../middleware/cloudinaryUploadMiddleware');

const router = express.Router();

// ── Image upload endpoint (Cloudinary) ────────────────────────────────────────
router.post('/upload-image', 
  upload.single('image'), 
  uploadToCloudinaryMiddleware('blogs'),
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

// Public routes (no authentication required)
router.get('/', blogController.getAllBlogs);
router.get('/stats', blogController.getBlogStats);
router.get('/popular', blogController.getPopularBlogs);
router.get('/recent', blogController.getRecentBlogs);
router.get('/categories', blogController.getCategories); // Get all categories
router.get('/slug/:slug', blogController.getBlogBySlug);
router.get('/:id', blogController.getBlogById);
router.post('/:id/views', blogController.incrementViews);
router.post('/:id/likes', blogController.incrementLikes);

// Admin routes (no authentication for now, can be protected later)
router.post('/', blogController.createBlog);
router.put('/:id', blogController.updateBlog);
router.patch('/:id/status', blogController.updateBlogStatus);
router.delete('/:id', blogController.deleteBlog);

// Category management routes
router.post('/categories', blogController.createCategory); // Create new category
router.put('/categories/:oldName', blogController.updateCategory); // Update category
router.delete('/categories/:name', blogController.deleteCategory); // Delete category

// Protected routes (if needed in future)
// router.use(authMiddleware);
// router.post('/', allowRoles('ADMIN', 'EMPLOYEE'), blogController.createBlog);
// router.put('/:id', allowRoles('ADMIN', 'EMPLOYEE'), blogController.updateBlog);
// router.delete('/:id', allowRoles('ADMIN'), blogController.deleteBlog);

module.exports = router;
