const { Notification, User } = require('../models');
const { Op } = require('sequelize');

/**
 * Titles of the auto-generated admin alerts raised by notifyAdmins(). These
 * belong to the notification bell only — they are hidden from the "Send
 * Notification" admin table, which lists admin-composed messages.
 *
 * Keep in sync with the notifyAdmins() call sites:
 *   - 'New Court Booking'    → services/courtService.js
 *   - 'New Coaching Enquiry' → controllers/coachingEnquiryController.js (x2)
 *   - 'New Event Booking'    → services/eventPassService.js
 */
const AUTO_ADMIN_NOTIFICATION_TITLES = [
  'New Court Booking',
  'New Coaching Enquiry',
  'New Event Booking',
];

class NotificationService {
  /**
   * Notify the admins responsible for an event: every Super Admin (role ADMIN),
   * plus the Complex Admin(s) of the event's complex (role COMPLEX_ADMIN with a
   * matching sportComplexId). Creates one Notification row per admin so each sees
   * it in their own bell. Non-fatal — never throws into the calling flow.
   */
  async notifyAdmins({ type, title, message, actionUrl = '', sportComplexId = null }) {
    try {
      const roleConds = [{ role: 'ADMIN' }]; // super admins see everything
      if (sportComplexId != null) {
        roleConds.push({ role: 'COMPLEX_ADMIN', sportComplexId: Number(sportComplexId) });
      }
      const admins = await User.findAll({
        where: { status: 'Active', [Op.or]: roleConds },
        attributes: ['id'],
      });
      if (!admins.length) return;
      await Notification.bulkCreate(
        admins.map((a) => ({
          userId: a.id,
          title,
          message,
          type: type || 'System',
          actionUrl: actionUrl || '',
          isRead: false,
          sentAt: new Date(),
        }))
      );
    } catch (err) {
      console.error('❌ notifyAdmins failed:', err.message);
    }
  }

  async createNotification({ userId, title, message, type, actionUrl }) {
    // Verify user exists
    const user = await User.findByPk(userId);
    if (!user) {
      throw new Error('User not found');
    }

    const notification = await Notification.create({
      userId,
      title,
      message,
      type: type || 'System',
      actionUrl,
      isRead: false,
      sentAt: new Date()
    });

    return notification;
  }

  async createMultipleNotifications({ userIds, title, message, type, actionUrl }) {
    // Verify all users exist
    const users = await User.findAll({
      where: {
        id: userIds,
        status: 'Active'
      },
      attributes: ['id']
    });

    if (users.length === 0) {
      throw new Error('No valid users found');
    }

    if (users.length !== userIds.length) {
      console.warn(`⚠️ Some users not found or inactive. Requested: ${userIds.length}, Found: ${users.length}`);
    }

    console.log(`📤 Sending notification to ${users.length} selected users`);

    // Create notifications for selected users
    const notifications = await Notification.bulkCreate(
      users.map(user => ({
        userId: user.id,
        title,
        message,
        type: type || 'System',
        actionUrl,
        isRead: false,
        sentAt: new Date()
      }))
    );

    console.log(`✅ Notifications sent to ${notifications.length} users`);

    return {
      count: notifications.length,
      notifications: notifications.slice(0, 10) // Return first 10 for preview
    };
  }

  /**
   * Resolve the User ids reached by a "coach-wise" send: the selected coaches
   * themselves PLUS every student enrolled in any of their batches.
   *
   * Two hops, because the schema has no direct coach→student link:
   *   coach  → User          (matched on email — the Coaches table has no
   *                           userId column; this is the same link coachScope
   *                           and the coach dashboard already use)
   *   coach → Batch.coachId → StudentBatches → Student.userId → User
   *
   * Returns { userIds, coachUserIds, studentUserIds } with duplicates removed —
   * a coach who is also enrolled as a student is notified once, not twice.
   */
  async resolveCoachAudience(coachIds) {
    const { Coach, Batch, StudentBatches, Student } = require('../models');

    const ids = (Array.isArray(coachIds) ? coachIds : [])
      .map(Number)
      .filter((n) => Number.isFinite(n));
    if (ids.length === 0) return { userIds: [], coachUserIds: [], studentUserIds: [] };

    const coaches = await Coach.findAll({ where: { id: ids }, attributes: ['id', 'email'] });
    const emails = coaches.map((c) => c.email).filter(Boolean);

    // The coaches' own logins.
    const coachUsers = emails.length
      ? await User.findAll({ where: { email: emails }, attributes: ['id'] })
      : [];

    // Every student in any batch owned by one of those coaches.
    const batches = await Batch.findAll({ where: { coachId: ids }, attributes: ['id'] });
    const batchIds = batches.map((b) => b.id);

    let studentUsers = [];
    if (batchIds.length > 0) {
      const enrolments = await StudentBatches.findAll({
        where: { batchId: batchIds },
        attributes: ['studentId'],
        group: ['studentId'],
      });
      const studentIds = enrolments.map((e) => e.studentId);
      if (studentIds.length > 0) {
        const students = await Student.findAll({
          where: { id: studentIds },
          attributes: ['userId'],
        });
        const userIds = students.map((s) => s.userId).filter((v) => v != null);
        if (userIds.length > 0) {
          studentUsers = await User.findAll({ where: { id: userIds }, attributes: ['id'] });
        }
      }
    }

    const coachUserIds = coachUsers.map((u) => u.id);
    const studentUserIds = studentUsers.map((u) => u.id);
    return {
      userIds: [...new Set([...coachUserIds, ...studentUserIds])],
      coachUserIds,
      studentUserIds,
    };
  }

  /**
   * Everyone an EMPLOYEE is allowed to notify: the coaches of their own sports
   * complex, and every student enrolled in a batch at that complex.
   *
   * This is the hard ceiling for an employee broadcast — they can never reach
   * website users, other complexes' coaches/students, or admins.
   *
   * Returns { coaches: [{id,name,email,userId}], students: [{id,name,email}],
   *           userIds } — the id lists power the admin-style pickers.
   */
  async resolveComplexAudience(complexId) {
    const { Coach, Batch, StudentBatches, Student } = require('../models');

    if (complexId == null) return { coaches: [], students: [], userIds: [] };

    // ── Coaches of this complex → their logins (matched on email) ──
    const coachRows = await Coach.findAll({
      where: { sportComplexId: complexId },
      attributes: ['id', 'name', 'email'],
    });
    const coachEmails = coachRows.map((c) => c.email).filter(Boolean);
    const coachUsers = coachEmails.length
      ? await User.findAll({ where: { email: coachEmails }, attributes: ['id', 'email'] })
      : [];
    const userIdByEmail = new Map(coachUsers.map((u) => [u.email, u.id]));
    const coaches = coachRows.map((c) => ({
      id: c.id,
      name: c.name,
      email: c.email,
      userId: c.email ? userIdByEmail.get(c.email) ?? null : null,
    }));

    // ── Students enrolled in any batch at this complex ──
    const batches = await Batch.findAll({ where: { sportComplexId: complexId }, attributes: ['id'] });
    const batchIds = batches.map((b) => b.id);

    let students = [];
    if (batchIds.length > 0) {
      const enrolments = await StudentBatches.findAll({
        where: { batchId: batchIds },
        attributes: ['studentId'],
        group: ['studentId'],
      });
      const studentIds = enrolments.map((e) => e.studentId);
      if (studentIds.length > 0) {
        const studentRows = await Student.findAll({
          where: { id: studentIds },
          attributes: ['id', 'userId'],
          include: [{ model: User, as: 'User', attributes: ['id', 'name', 'email'] }],
        });
        students = studentRows
          .filter((s) => s.User)
          .map((s) => ({ id: s.User.id, name: s.User.name, email: s.User.email }));
      }
    }

    const userIds = [
      ...new Set([
        ...coaches.map((c) => c.userId).filter((v) => v != null),
        ...students.map((s) => s.id),
      ]),
    ];

    return { coaches, students, userIds };
  }

  /**
   * Send one notification to the selected coaches and all of their students.
   */
  async createCoachAudienceNotifications({ coachIds, title, message, type, actionUrl }) {
    const audience = await this.resolveCoachAudience(coachIds);

    if (audience.userIds.length === 0) {
      throw new Error('No coaches or students found for the selected coaches');
    }

    const result = await this.createMultipleNotifications({
      userIds: audience.userIds,
      title,
      message,
      type,
      actionUrl,
    });

    console.log(
      `✅ Coach-wise notification sent — ${audience.coachUserIds.length} coach(es) + ${audience.studentUserIds.length} student(s)`
    );

    return {
      ...result,
      coachCount: audience.coachUserIds.length,
      studentCount: audience.studentUserIds.length,
    };
  }

  async createBroadcastNotifications({ title, message, type, actionUrl }) {
    // Get all users regardless of role (ADMIN, USER, EMPLOYEE, COACH, SECURITY)
    const users = await User.findAll({
      attributes: ['id'],
      where: {
        status: 'Active' // Only send to active users
      }
    });

    if (users.length === 0) {
      throw new Error('No active users found');
    }

    console.log(`📢 Broadcasting notification to ${users.length} users (all roles)`);

    // Limit to 1000 users per request to prevent timeout
    const usersToNotify = users.slice(0, 1000);

    // Create notifications for all users
    const notifications = await Notification.bulkCreate(
      usersToNotify.map(user => ({
        userId: user.id,
        title,
        message,
        type: type || 'System',
        actionUrl,
        isRead: false,
        sentAt: new Date()
      }))
    );

    console.log(`✅ Broadcast complete: ${notifications.length} notifications created`);

    return {
      count: notifications.length,
      notifications: notifications.slice(0, 10) // Return first 10 for preview
    };
  }

  async getAllUsers() {
    // Get all users regardless of role (ADMIN, USER, EMPLOYEE, COACH, SECURITY)
    const users = await User.findAll({
      attributes: ['id', 'name', 'email', 'role'],
      where: {
        status: 'Active' // Only show active users
      },
      order: [
        ['role', 'ASC'], // Group by role first
        ['name', 'ASC']  // Then alphabetically by name
      ]
    });

    console.log(`👥 Retrieved ${users.length} active users for notification targeting`);
    console.log(`📊 Roles breakdown:`, users.reduce((acc, user) => {
      acc[user.role] = (acc[user.role] || 0) + 1;
      return acc;
    }, {}));

    return users;
  }

  async getAdminNotifications(page = 1, limit = 50, type = null) {
    const offset = (page - 1) * limit;
    // Auto-generated admin alerts (new court booking / coaching enquiry / event
    // booking) live in the bell only — keep this table to composed messages.
    const where = { title: { [Op.notIn]: AUTO_ADMIN_NOTIFICATION_TITLES } };
    if (type) where.type = type;

    const { count, rows } = await Notification.findAndCountAll({
      where,
      include: [
        {
          model: User,
          attributes: ['id', 'name', 'email'],
          required: false
        }
      ],
      order: [['sentAt', 'DESC']],
      limit,
      offset
    });

    // The association has no alias, so Sequelize nests the recipient under `User`
    // (capitalized). Expose a lowercase `user` too so the frontend (which reads
    // `row.user`) can show the recipient's name instead of "Unknown".
    const notifications = rows.map((r) => {
      const o = r.toJSON();
      o.user = o.User || null;
      return o;
    });

    return {
      notifications,
      currentPage: page,
      totalPages: Math.ceil(count / limit),
      totalItems: count
    };
  }

  async markAllAsRead(userId) {
    await Notification.update(
      { isRead: true },
      { where: { userId, isRead: false } }
    );
  }

  async getUserNotifications(userId, page = 1, limit = 20) {
    const offset = (page - 1) * limit;

    const { count, rows } = await Notification.findAndCountAll({
      where: { userId },
      order: [['sentAt', 'DESC']],
      limit,
      offset
    });

    return {
      notifications: rows,
      currentPage: page,
      totalPages: Math.ceil(count / limit),
      totalItems: count
    };
  }

  async getUnreadCount(userId) {
    const count = await Notification.count({
      where: {
        userId,
        isRead: false
      }
    });

    return count;
  }

  async markAsRead(notificationId, userId) {
    const notification = await Notification.findByPk(notificationId);

    if (!notification) {
      throw new Error('Notification not found');
    }

    if (notification.userId !== userId) {
      throw new Error('You are not authorized to mark this notification as read');
    }

    notification.isRead = true;
    notification.updatedAt = new Date();
    await notification.save();

    return notification;
  }

  async updateNotification(notificationId, { title, message, type, actionUrl }) {
    const notification = await Notification.findByPk(notificationId);

    if (!notification) {
      throw new Error('Notification not found');
    }

    // Update only allowed fields
    if (title) notification.title = title;
    if (message) notification.message = message;
    if (type) notification.type = type;
    if (actionUrl !== undefined) notification.actionUrl = actionUrl;

    await notification.save();

    return notification;
  }

  async deleteNotification(notificationId) {
    const notification = await Notification.findByPk(notificationId);

    if (!notification) {
      throw new Error('Notification not found');
    }

    await notification.destroy();

    return { message: 'Notification deleted successfully' };
  }
}

module.exports = new NotificationService();
module.exports.AUTO_ADMIN_NOTIFICATION_TITLES = AUTO_ADMIN_NOTIFICATION_TITLES;
