'use strict';

const { Op } = require('sequelize');
const { UserFeedback, FeedbackMessage, Notification } = require('../models');

// Include used to load a feedback's conversation thread, oldest first.
const MESSAGES_INCLUDE = {
  model: FeedbackMessage,
  as: 'messages',
  separate: true,
  order: [['createdAt', 'ASC']],
};

/**
 * UserFeedbackService
 * Handles all DB operations for user-submitted feedback from the frontend dashboard.
 */
class UserFeedbackService {
  // ─── Sanitize ─────────────────────────────────────────────────────────────

  sanitize(input) {
    if (typeof input !== 'string') return input;
    return input
      .replace(/<script[\s\S]*?>[\s\S]*?<\/script>/gi, '')
      .replace(/<iframe[\s\S]*?>[\s\S]*?<\/iframe>/gi, '')
      .replace(/<[^>]+>/g, '')
      .trim();
  }

  // ─── Reference Number ─────────────────────────────────────────────────────

  async generateReferenceNumber() {
    const year = new Date().getFullYear();
    const startOfYear = new Date(`${year}-01-01T00:00:00.000Z`);
    const endOfYear   = new Date(`${year}-12-31T23:59:59.999Z`);

    const count = await UserFeedback.count({
      where: { createdAt: { [Op.between]: [startOfYear, endOfYear] } },
      paranoid: false,
    });

    const sequence = String(count + 1).padStart(4, '0');
    return `NS-FB-${year}-${sequence}`;
  }

  // ─── Create ───────────────────────────────────────────────────────────────

  async createFeedback({ userId, fullName, email, subject, rating, message, ipAddress, userAgent }) {
    const feedback = await UserFeedback.create({
      userId:          userId || null,
      fullName:        this.sanitize(fullName),
      email,
      subject:         this.sanitize(subject),
      rating:          rating ? parseInt(rating, 10) : null,
      message:         this.sanitize(message),
      ipAddress:       ipAddress || null,
      userAgent:       userAgent || null,
      referenceNumber: await this.generateReferenceNumber(),
    });

    return feedback;
  }

  // ─── Admin: List ──────────────────────────────────────────────────────────

  async listFeedback({ page = 1, limit = 20, search, status, sortBy = 'createdAt', sortOrder = 'DESC' }) {
    const safeLimit = Math.min(parseInt(limit, 10) || 20, 100);
    const safePage  = Math.max(parseInt(page, 10) || 1, 1);
    const offset    = (safePage - 1) * safeLimit;

    const ALLOWED_SORT = ['createdAt', 'updatedAt', 'fullName', 'email', 'status', 'rating', 'referenceNumber'];
    const safeSortBy    = ALLOWED_SORT.includes(sortBy) ? sortBy : 'createdAt';
    const safeSortOrder = sortOrder.toUpperCase() === 'ASC' ? 'ASC' : 'DESC';

    const where = {};

    if (search && search.trim()) {
      where[Op.or] = [
        { fullName: { [Op.iLike]: `%${search.trim()}%` } },
        { email:    { [Op.iLike]: `%${search.trim()}%` } },
        { subject:  { [Op.iLike]: `%${search.trim()}%` } },
      ];
    }

    if (status && status.trim()) {
      where.status = status.trim();
    }

    const { count: total, rows: feedbacks } = await UserFeedback.findAndCountAll({
      where,
      order:  [[safeSortBy, safeSortOrder]],
      limit:  safeLimit,
      offset,
    });

    const statusCounts = await this._getStatusCounts();

    return {
      feedbacks,
      pagination: {
        total,
        page:       safePage,
        limit:      safeLimit,
        totalPages: Math.ceil(total / safeLimit),
      },
      statusCounts,
    };
  }

  async _getStatusCounts() {
    const [newCount, inProgressCount, resolvedCount, closedCount, total] = await Promise.all([
      UserFeedback.count({ where: { status: 'new' } }),
      UserFeedback.count({ where: { status: 'in_progress' } }),
      UserFeedback.count({ where: { status: 'resolved' } }),
      UserFeedback.count({ where: { status: 'closed' } }),
      UserFeedback.count(),
    ]);

    return { new: newCount, in_progress: inProgressCount, resolved: resolvedCount, closed: closedCount, total };
  }

  // ─── Admin: Get Single (with thread) ──────────────────────────────────────

  async getFeedbackById(id) {
    return UserFeedback.findByPk(id, { include: [MESSAGES_INCLUDE] });
  }

  // ─── User: List My Feedback (with threads) ────────────────────────────────

  async listMyFeedback(userId) {
    return UserFeedback.findAll({
      where: { userId },
      order: [['createdAt', 'DESC']],
      include: [MESSAGES_INCLUDE],
    });
  }

  // ─── User: Reply on own thread ────────────────────────────────────────────

  async addUserReply(id, userId, { message, senderName }) {
    const feedback = await UserFeedback.findByPk(id);
    if (!feedback) return { error: 'not_found' };
    if (feedback.userId !== userId) return { error: 'forbidden' };

    const reply = await FeedbackMessage.create({
      feedbackId:  feedback.id,
      senderType:  'user',
      senderId:    userId,
      senderName:  this.sanitize(senderName) || feedback.fullName || 'User',
      message:     this.sanitize(message),
    });

    // A new user reply on a closed/resolved thread reopens it for admin attention.
    if (['resolved', 'closed'].includes(feedback.status)) {
      await feedback.update({ status: 'in_progress' });
    }

    return { message: reply };
  }

  // ─── Admin: Reply on a thread ─────────────────────────────────────────────

  async addAdminReply(id, { message, adminId, adminName }) {
    const feedback = await UserFeedback.findByPk(id);
    if (!feedback) return null;

    const reply = await FeedbackMessage.create({
      feedbackId:  feedback.id,
      senderType:  'admin',
      senderId:    adminId || null,
      senderName:  this.sanitize(adminName) || 'Admin',
      message:     this.sanitize(message),
    });

    // First admin response moves the ticket out of "new".
    if (feedback.status === 'new') {
      await feedback.update({ status: 'in_progress' });
    }

    // Wire the two sides together: notify the submitter through the same
    // Notifications channel their "From Admin" tab already reads from.
    if (feedback.userId) {
      await Notification.create({
        userId:    feedback.userId,
        title:     `Re: ${feedback.subject}`,
        message:   this.sanitize(message),
        type:      'Feedback',
        isRead:    false,
        actionUrl: '/dashboard/feedback',
        sentAt:    new Date(),
      });
    }

    return reply;
  }

  // ─── Admin: Update Status ─────────────────────────────────────────────────

  async updateStatus(id, status) {
    const feedback = await UserFeedback.findByPk(id);
    if (!feedback) return null;
    await feedback.update({ status });
    return feedback;
  }

  // ─── Admin: Delete ────────────────────────────────────────────────────────

  async deleteFeedback(id) {
    const feedback = await UserFeedback.findByPk(id);
    if (!feedback) return false;
    await feedback.destroy();
    return true;
  }
}

module.exports = new UserFeedbackService();
