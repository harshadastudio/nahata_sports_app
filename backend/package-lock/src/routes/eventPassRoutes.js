'use strict';

const express = require('express');
const eventPassController = require('../controllers/eventPassController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');
const { upload, uploadToCloudinaryMiddleware } = require('../middleware/cloudinaryUploadMiddleware');

const router = express.Router();

// ── Event Pass CRUD (admin) ───────────────────────────────────────────────────
// optionalAuth: anonymous = all events (website); logged-in COMPLEX_ADMIN = own complex only.
router.get('/', optionalAuth, eventPassController.getAllEventPasses);
// Specific GET before "/:id" so it isn't captured as an id param.
router.get('/my-scan-stats', authenticateToken, eventPassController.getMyScanStats);
router.get('/:id', optionalAuth, eventPassController.getEventPassById);
router.post('/', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN'), eventPassController.createEventPass);
router.put('/:id', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN'), eventPassController.updateEventPass);

// DELETE bookings permanently — admin only. MUST be declared before "/:id",
// otherwise Express matches "bookings" as an event-pass id.
// Bulk form takes { ids: [...] }; the /:bookingId form deletes a single booking.
router.delete('/bookings', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN'), eventPassController.deleteBookings);
router.delete('/bookings/:bookingId', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN'), eventPassController.deleteBookings);

router.delete('/:id', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN'), eventPassController.deleteEventPass);

// ── Image upload (Cloudinary) ─────────────────────────────────────────────────
router.post('/upload-image', 
  upload.single('image'), 
  uploadToCloudinaryMiddleware('event-passes'),
  eventPassController.uploadImage
);

// ── Scan stats per event ──────────────────────────────────────────────────────
router.get('/:eventPassId/scan-stats', eventPassController.getScanStats);

// ── Scan IN / OUT (security guard endpoint) ───────────────────────────────────
// optionalAuth: device without login still scans; a logged-in guard's scan gets
// attributed to them (for the security dashboard "Event Passes Scanned" count).
router.post('/scan', optionalAuth, eventPassController.scanPass);

// ── Bookings ──────────────────────────────────────────────────────────────────
// NOTE: specific sub-paths must come before /:id to avoid route conflicts

// GET all bookings — back-office only (Issue Event Pass list + its CSV export).
// Auth is required so the handler can resolve the caller's complex: the rows
// carry guest names and emails, and a complex admin must only ever see their
// own complex's. Previously this route had no auth middleware at all.
router.get(
  '/bookings/all',
  authenticateToken,
  allowRoles('ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE', 'SECURITY'),
  eventPassController.getAllBookings
);

// GET my bookings — requires auth
router.get('/bookings/my', authenticateToken, eventPassController.getMyBookings);

// GET individual passes for a booking
router.get('/bookings/:bookingId/passes', optionalAuth, eventPassController.getIndividualPasses);

// POST create booking — optional auth (attaches userId if logged in)
router.post('/bookings/create', optionalAuth, eventPassController.createBooking);

// ── Individual pass actions ───────────────────────────────────────────────────

// POST send individual pass by email
router.post('/individual-passes/:passId/send-email', eventPassController.sendPassByEmail);

// POST save members for a pass
router.post('/individual-passes/:passId/members', authenticateToken, eventPassController.saveMembers);

// POST scan a specific member IN/OUT
router.post('/members/:memberId/scan', eventPassController.scanMember);

// ── Optional auth middleware ──────────────────────────────────────────────────

function optionalAuth(req, res, next) {
  const authHeader = req.headers.authorization || req.headers.Authorization;
  const token = (authHeader && authHeader.startsWith('Bearer '))
    ? authHeader.substring(7)
    : req.cookies?.accessToken;

  if (!token) return next();

  const { verifyAccessToken } = require('../utils/tokenUtils');
  const { User } = require('../models');

  try {
    const decoded = verifyAccessToken(token);
    User.findByPk(decoded.id, { attributes: { exclude: ['password'] } })
      .then((user) => {
        if (user) req.user = user;
        next();
      })
      .catch(() => next());
  } catch {
    next();
  }
}

module.exports = router;
