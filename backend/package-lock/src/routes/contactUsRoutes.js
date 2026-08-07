'use strict';

const express = require('express');
const router  = express.Router();
const rateLimit = require('express-rate-limit');
const { upload, uploadToCloudinaryMiddleware } = require('../middleware/cloudinaryUploadMiddleware');

const contactUsController = require('../controllers/contactUsController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { allowRoles }      = require('../middleware/roleMiddleware');
const {
  validateContactSubmission,
  validateStatusUpdate,
  validateContactInfo,
} = require('../validations/contactUsValidation');

// ─── Rate Limiter — Public Submission Endpoint ────────────────────────────────
// 5 requests per IP per 15-minute window to prevent spam
// const contactFormLimiter = rateLimit({
//   windowMs: 15 * 60 * 1000, // 15 minutes
//   max: 5,
//   message: {
//     success: false,
//     message: 'Too many requests. Please try again later.',
//   },
//   standardHeaders: true,  // RateLimit-* headers
//   legacyHeaders:   false, // Disable X-RateLimit-* headers
// });

// ─── Public Routes ─────────────────────────────────────────────────────────────

// POST /api/v1/contact-us — Submit contact form (no auth required)
router.post(
  '/',
  // contactFormLimiter,
  validateContactSubmission,
  contactUsController.submitContactForm.bind(contactUsController)
);

// GET /api/v1/contact-us/info — Get active contact information (no auth required)
router.get(
  '/info',
  contactUsController.getContactInfo.bind(contactUsController)
);

// ─── Admin Routes ─────────────────────────────────────────────────────────────
// All admin routes require a valid JWT and ADMIN role

// POST /api/contact-us/admin/upload-image — Upload contact image
router.post(
  '/admin/upload-image',
  authenticateToken,
  allowRoles('ADMIN'),
  upload.single('image'),
  uploadToCloudinaryMiddleware('contact'),
  (req, res) => {
    if (!req.cloudinaryResult) {
      return res.status(400).json({ 
        success: false, 
        message: 'No image file provided' 
      });
    }
    
    return res.status(200).json({ 
      success: true, 
      data: { 
        url: req.cloudinaryResult.url,
        publicId: req.cloudinaryResult.publicId 
      } 
    });
  }
);

// GET /api/contact-us/admin — Paginated list with search/filter
router.get(
  '/admin',
  authenticateToken,
  allowRoles('ADMIN', 'COMPLEX_ADMIN'),
  contactUsController.listInquiries.bind(contactUsController)
);

// GET /api/contact-us/admin/info/list — List all contact information entries
router.get(
  '/admin/info/list',
  authenticateToken,
  allowRoles('ADMIN', 'COMPLEX_ADMIN'),
  contactUsController.listAllContactInfo.bind(contactUsController)
);

// GET /api/contact-us/admin/info — Get active contact information for management
router.get(
  '/admin/info',
  authenticateToken,
  allowRoles('ADMIN', 'COMPLEX_ADMIN'),
  contactUsController.getContactInfoAdmin.bind(contactUsController)
);

// GET /api/contact-us/admin/info/:id — Get contact information by ID
router.get(
  '/admin/info/:id',
  authenticateToken,
  allowRoles('ADMIN', 'COMPLEX_ADMIN'),
  contactUsController.getContactInfoById.bind(contactUsController)
);

// POST /api/contact-us/admin/info — Create new contact information
router.post(
  '/admin/info',
  authenticateToken,
  allowRoles('ADMIN', 'COMPLEX_ADMIN'),
  validateContactInfo,
  contactUsController.createContactInfo.bind(contactUsController)
);

// PUT /api/contact-us/admin/info/:id — Update contact information by ID
router.put(
  '/admin/info/:id',
  authenticateToken,
  allowRoles('ADMIN', 'COMPLEX_ADMIN'),
  validateContactInfo,
  contactUsController.updateContactInfoById.bind(contactUsController)
);

// PUT /api/contact-us/admin/info — Update active contact information (legacy)
router.put(
  '/admin/info',
  authenticateToken,
  allowRoles('ADMIN'),
  validateContactInfo,
  contactUsController.updateContactInfo.bind(contactUsController)
);

// DELETE /api/contact-us/admin/info/:id — Delete contact information
router.delete(
  '/admin/info/:id',
  authenticateToken,
  allowRoles('ADMIN', 'COMPLEX_ADMIN'),
  contactUsController.deleteContactInfo.bind(contactUsController)
);

// GET /api/contact-us/admin/:id — View single inquiry
router.get(
  '/admin/:id',
  authenticateToken,
  allowRoles('ADMIN', 'COMPLEX_ADMIN'),
  contactUsController.getInquiry.bind(contactUsController)
);

// PATCH /api/contact-us/admin/:id/status — Update inquiry status
router.patch(
  '/admin/:id/status',
  authenticateToken,
  allowRoles('ADMIN', 'COMPLEX_ADMIN'),
  validateStatusUpdate,
  contactUsController.updateStatus.bind(contactUsController)
);

// DELETE /api/contact-us/admin/:id — Soft delete inquiry
router.delete(
  '/admin/:id',
  authenticateToken,
  allowRoles('ADMIN', 'COMPLEX_ADMIN'),
  contactUsController.deleteInquiry.bind(contactUsController)
);

module.exports = router;
