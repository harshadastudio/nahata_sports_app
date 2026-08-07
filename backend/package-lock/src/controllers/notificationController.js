const notificationService = require('../services/notificationService');

class NotificationController {
  async sendNotification(req, res) {
    try {
      const { title, message, type, actionUrl, recipient, userId, userIds, coachIds } = req.body;

      // Validate required fields
      if (!title || !message) {
        return res.status(400).json({
          success: false,
          message: 'Title and message are required'
        });
      }

      // ── Employee ceiling ────────────────────────────────────────────────
      // An EMPLOYEE may only notify their OWN complex's coaches and students —
      // never website users, other complexes, or admins. Every targeting mode
      // is intersected with that audience, so "All Users" means "all of my
      // complex" and a tampered userIds/coachIds list cannot reach outside it.
      const role = String(req.user?.role || '').toUpperCase();
      if (role === 'EMPLOYEE') {
        const complexId = req.user.sportComplexId;
        if (complexId == null) {
          return res.status(403).json({
            success: false,
            message: 'Your account is not linked to a sports complex. Please contact your admin.',
          });
        }

        const audience = await notificationService.resolveComplexAudience(complexId);
        const allowed = new Set(audience.userIds);

        let targetIds;
        if (recipient === 'coaches') {
          if (!Array.isArray(coachIds) || coachIds.length === 0) {
            return res.status(400).json({ success: false, message: 'Please select at least one coach' });
          }
          const coachAudience = await notificationService.resolveCoachAudience(coachIds);
          targetIds = coachAudience.userIds.filter((id) => allowed.has(id));
        } else if (recipient === 'selected') {
          if (!Array.isArray(userIds) || userIds.length === 0) {
            return res.status(400).json({ success: false, message: 'Please select at least one recipient' });
          }
          targetIds = userIds.map(Number).filter((id) => allowed.has(id));
        } else {
          targetIds = audience.userIds;
        }

        if (targetIds.length === 0) {
          return res.status(400).json({
            success: false,
            message: 'No valid recipients in your sports complex for this selection.',
          });
        }

        const empResult = await notificationService.createMultipleNotifications({
          userIds: targetIds,
          title,
          message,
          type: type || 'System',
          actionUrl,
        });
        return res.status(201).json({
          success: true,
          message: 'Notification sent successfully',
          data: empResult,
        });
      }

      let result;
      // Coach-wise: the selected coaches AND every student in their batches.
      // Checked before the others so it isn't swallowed by the `!userIds` case.
      if (recipient === 'coaches') {
        if (!Array.isArray(coachIds) || coachIds.length === 0) {
          return res.status(400).json({
            success: false,
            message: 'Please select at least one coach'
          });
        }
        result = await notificationService.createCoachAudienceNotifications({
          coachIds,
          title,
          message,
          type: type || 'System',
          actionUrl
        });
      } else if (recipient === 'all' || (!userId && !userIds)) {
        // Broadcast to all users
        result = await notificationService.createBroadcastNotifications({
          title,
          message,
          type: type || 'System',
          actionUrl
        });
      } else if (userIds && Array.isArray(userIds) && userIds.length > 0) {
        // Send to multiple selected users
        result = await notificationService.createMultipleNotifications({
          userIds,
          title,
          message,
          type: type || 'System',
          actionUrl
        });
      } else if (userId) {
        // Send to specific single user
        result = await notificationService.createNotification({
          userId,
          title,
          message,
          type: type || 'System',
          actionUrl
        });
      } else {
        return res.status(400).json({
          success: false,
          message: 'Please specify recipient(s)'
        });
      }

      res.status(201).json({
        success: true,
        message: 'Notification sent successfully',
        data: result
      });
    } catch (error) {
      const statusCode = error.message.includes('not found') ? 404 : 500;
      res.status(statusCode).json({
        success: false,
        message: error.message
      });
    }
  }

  async getUsers(req, res) {
    try {
      const users = await notificationService.getAllUsers();

      res.status(200).json({
        success: true,
        data: users
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: 'Failed to retrieve users',
        error: error.message
      });
    }
  }

  async getAdminNotifications(req, res) {
    try {
      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 50;
      const type = req.query.type || null; // optional filter by type e.g. 'Booking'

      const result = await notificationService.getAdminNotifications(page, limit, type);

      res.status(200).json({
        success: true,
        data: result.notifications,
        pagination: {
          currentPage: result.currentPage,
          totalPages: result.totalPages,
          totalItems: result.totalItems
        }
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: 'Failed to retrieve admin notifications',
        error: error.message
      });
    }
  }

  async markAllAsRead(req, res) {
    try {
      const userId = req.user.id;
      await notificationService.markAllAsRead(userId);

      res.status(200).json({
        success: true,
        message: 'All notifications marked as read'
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: 'Failed to mark all notifications as read',
        error: error.message
      });
    }
  }

  /**
   * GET /api/notifications/audience
   * Everyone the caller may broadcast to. For an EMPLOYEE this is their own
   * complex's coaches and students — the exact set the send endpoint enforces,
   * so the pickers can never offer a recipient the send would reject.
   */
  async getBroadcastAudience(req, res) {
    try {
      const role = String(req.user?.role || '').toUpperCase();
      if (role !== 'EMPLOYEE') {
        return res.status(403).json({ success: false, message: 'Not available for this role' });
      }
      const complexId = req.user.sportComplexId;
      if (complexId == null) {
        return res.status(200).json({ success: true, data: { coaches: [], students: [], userIds: [] } });
      }
      const audience = await notificationService.resolveComplexAudience(complexId);
      return res.status(200).json({ success: true, data: audience });
    } catch (error) {
      return res.status(500).json({ success: false, message: error.message });
    }
  }

  async getUserNotifications(req, res) {
    try {
      const userId = req.user.id;
      const page = parseInt(req.query.page) || 1;
      const limit = parseInt(req.query.limit) || 20;

      const result = await notificationService.getUserNotifications(userId, page, limit);

      res.status(200).json({
        success: true,
        data: result.notifications,
        pagination: {
          currentPage: result.currentPage,
          totalPages: result.totalPages,
          totalItems: result.totalItems
        }
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: 'Failed to retrieve notifications',
        error: error.message
      });
    }
  }

  async getUnreadCount(req, res) {
    try {
      const userId = req.user.id;
      const count = await notificationService.getUnreadCount(userId);

      res.status(200).json({
        success: true,
        count
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: 'Failed to retrieve unread count',
        error: error.message
      });
    }
  }

  async markAsRead(req, res) {
    try {
      const { id } = req.params;
      const userId = req.user.id;

      if (!id) {
        return res.status(400).json({
          success: false,
          message: 'Notification ID is required'
        });
      }

      const notification = await notificationService.markAsRead(id, userId);

      res.status(200).json({
        success: true,
        message: 'Notification marked as read',
        data: notification
      });
    } catch (error) {
      const statusCode = error.message.includes('not found') ? 404 :
                         error.message.includes('not authorized') ? 403 : 500;

      res.status(statusCode).json({
        success: false,
        message: error.message
      });
    }
  }

  async updateNotification(req, res) {
    try {
      const { id } = req.params;
      const { title, message, type, actionUrl } = req.body;

      if (!id) {
        return res.status(400).json({
          success: false,
          message: 'Notification ID is required'
        });
      }

      if (!title || !message) {
        return res.status(400).json({
          success: false,
          message: 'Title and message are required'
        });
      }

      const notification = await notificationService.updateNotification(id, {
        title,
        message,
        type,
        actionUrl
      });

      res.status(200).json({
        success: true,
        message: 'Notification updated successfully',
        data: notification
      });
    } catch (error) {
      const statusCode = error.message.includes('not found') ? 404 : 500;

      res.status(statusCode).json({
        success: false,
        message: error.message
      });
    }
  }

  async deleteNotification(req, res) {
    try {
      const { id } = req.params;

      if (!id) {
        return res.status(400).json({
          success: false,
          message: 'Notification ID is required'
        });
      }

      await notificationService.deleteNotification(id);

      res.status(200).json({
        success: true,
        message: 'Notification deleted successfully'
      });
    } catch (error) {
      const statusCode = error.message.includes('not found') ? 404 : 500;

      res.status(statusCode).json({
        success: false,
        message: error.message
      });
    }
  }
}

module.exports = new NotificationController();
