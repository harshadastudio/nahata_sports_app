'use strict';

const userFeedbackService = require('../services/userFeedbackService');

class UserFeedbackController {
  // ─── Authenticated User: Submit Feedback ──────────────────────────────────

  /**
   * POST /api/user-feedback
   * Requires authentication — user must be logged in.
   */
  async submitFeedback(req, res, next) {
    try {
      const { subject, rating, message } = req.body;

      // req.user is set by authenticateToken middleware
      const userId   = req.user?.id   || null;
      const fullName = req.user?.name || req.user?.fullName || req.body.fullName || 'User';
      const email    = req.user?.email || req.body.email || '';

      const ipAddress =
        (req.headers['x-forwarded-for'] || '').split(',')[0].trim() ||
        req.ip ||
        null;
      const userAgent = req.headers['user-agent'] || null;

      const feedback = await userFeedbackService.createFeedback({
        userId,
        fullName,
        email,
        subject,
        rating,
        message,
        ipAddress,
        userAgent,
      });

      return res.status(201).json({
        success: true,
        message: 'Your feedback has been submitted successfully.',
        data: { referenceNumber: feedback.referenceNumber },
      });
    } catch (error) {
      next(error);
    }
  }

  // ─── Authenticated User: My Feedback Threads ──────────────────────────────

  /**
   * GET /api/user-feedback/mine
   * Returns the logged-in user's submitted feedback with full conversation threads.
   */
  async listMyFeedback(req, res, next) {
    try {
      const userId = req.user?.id;
      if (!userId) {
        return res.status(401).json({ success: false, message: 'Authentication required.' });
      }

      const feedbacks = await userFeedbackService.listMyFeedback(userId);
      return res.status(200).json({ success: true, data: { feedbacks } });
    } catch (error) {
      next(error);
    }
  }

  // ─── Authenticated User: Reply on own thread ──────────────────────────────

  /**
   * POST /api/user-feedback/:id/reply
   */
  async replyAsUser(req, res, next) {
    try {
      const { message } = req.body;
      if (!message || !message.trim()) {
        return res.status(400).json({ success: false, message: 'Message is required.' });
      }

      const senderName = req.user?.name || req.user?.fullName || 'User';
      const result = await userFeedbackService.addUserReply(req.params.id, req.user.id, {
        message,
        senderName,
      });

      if (result.error === 'not_found') {
        return res.status(404).json({ success: false, message: 'Feedback not found.' });
      }
      if (result.error === 'forbidden') {
        return res.status(403).json({ success: false, message: 'You can only reply to your own feedback.' });
      }

      return res.status(201).json({
        success: true,
        message: 'Reply sent.',
        data: { message: result.message },
      });
    } catch (error) {
      next(error);
    }
  }

  // ─── Admin: List All Feedback ─────────────────────────────────────────────

  /**
   * GET /api/user-feedback/admin
   */
  async listFeedback(req, res, next) {
    try {
      const { page, limit, search, status, sortBy, sortOrder } = req.query;

      const result = await userFeedbackService.listFeedback({
        page, limit, search, status, sortBy, sortOrder,
      });

      return res.status(200).json({ success: true, data: result });
    } catch (error) {
      next(error);
    }
  }

  // ─── Admin: Get Single ────────────────────────────────────────────────────

  /**
   * GET /api/user-feedback/admin/:id
   */
  async getFeedback(req, res, next) {
    try {
      const feedback = await userFeedbackService.getFeedbackById(req.params.id);

      if (!feedback) {
        return res.status(404).json({ success: false, message: 'Feedback not found.' });
      }

      return res.status(200).json({ success: true, data: { feedback } });
    } catch (error) {
      next(error);
    }
  }

  // ─── Admin: Update Status ─────────────────────────────────────────────────

  /**
   * PATCH /api/user-feedback/admin/:id/status
   */
  async updateStatus(req, res, next) {
    try {
      const { status } = req.body;
      const VALID = ['new', 'in_progress', 'resolved', 'closed'];

      if (!VALID.includes(status)) {
        return res.status(400).json({
          success: false,
          message: `Invalid status. Must be one of: ${VALID.join(', ')}`,
        });
      }

      const feedback = await userFeedbackService.updateStatus(req.params.id, status);

      if (!feedback) {
        return res.status(404).json({ success: false, message: 'Feedback not found.' });
      }

      return res.status(200).json({
        success: true,
        message: 'Status updated successfully.',
        data: { feedback },
      });
    } catch (error) {
      next(error);
    }
  }

  // ─── Admin: Reply on a thread ─────────────────────────────────────────────

  /**
   * POST /api/user-feedback/admin/:id/reply
   * Saves an admin reply on the thread and notifies the submitter.
   */
  async replyAsAdmin(req, res, next) {
    try {
      const { message } = req.body;
      if (!message || !message.trim()) {
        return res.status(400).json({ success: false, message: 'Message is required.' });
      }

      const adminName = req.user?.name || req.user?.fullName || 'Admin';
      const reply = await userFeedbackService.addAdminReply(req.params.id, {
        message,
        adminId: req.user?.id,
        adminName,
      });

      if (!reply) {
        return res.status(404).json({ success: false, message: 'Feedback not found.' });
      }

      return res.status(201).json({
        success: true,
        message: 'Reply sent to user.',
        data: { message: reply },
      });
    } catch (error) {
      next(error);
    }
  }

  // ─── Admin: Delete ────────────────────────────────────────────────────────

  /**
   * DELETE /api/user-feedback/admin/:id
   */
  async deleteFeedback(req, res, next) {
    try {
      const deleted = await userFeedbackService.deleteFeedback(req.params.id);

      if (!deleted) {
        return res.status(404).json({ success: false, message: 'Feedback not found.' });
      }

      return res.status(200).json({ success: true, message: 'Feedback deleted successfully.' });
    } catch (error) {
      next(error);
    }
  }
}

module.exports = new UserFeedbackController();
