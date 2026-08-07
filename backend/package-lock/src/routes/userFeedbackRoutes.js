'use strict';

const express    = require('express');
const router     = express.Router();
const controller = require('../controllers/userFeedbackController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { allowRoles }        = require('../middleware/roleMiddleware');

// ─── Authenticated User Routes ────────────────────────────────────────────────

// POST /api/user-feedback — Submit feedback (logged-in users only)
router.post(
  '/',
  authenticateToken,
  controller.submitFeedback.bind(controller)
);

// GET /api/user-feedback/mine — User's own feedback threads
router.get(
  '/mine',
  authenticateToken,
  controller.listMyFeedback.bind(controller)
);

// POST /api/user-feedback/:id/reply — User replies on their own thread
router.post(
  '/:id/reply',
  authenticateToken,
  controller.replyAsUser.bind(controller)
);

// ─── Admin Routes ─────────────────────────────────────────────────────────────

// GET /api/user-feedback/admin — List all feedback
router.get(
  '/admin',
  authenticateToken,
  allowRoles('ADMIN'),
  controller.listFeedback.bind(controller)
);

// GET /api/user-feedback/admin/:id — Get single feedback
router.get(
  '/admin/:id',
  authenticateToken,
  allowRoles('ADMIN'),
  controller.getFeedback.bind(controller)
);

// PATCH /api/user-feedback/admin/:id/status — Update status
router.patch(
  '/admin/:id/status',
  authenticateToken,
  allowRoles('ADMIN'),
  controller.updateStatus.bind(controller)
);

// POST /api/user-feedback/admin/:id/reply — Admin replies on a thread
router.post(
  '/admin/:id/reply',
  authenticateToken,
  allowRoles('ADMIN'),
  controller.replyAsAdmin.bind(controller)
);

// DELETE /api/user-feedback/admin/:id — Soft delete
router.delete(
  '/admin/:id',
  authenticateToken,
  allowRoles('ADMIN'),
  controller.deleteFeedback.bind(controller)
);

module.exports = router;
