const express = require('express');
const notificationController = require('../controllers/notificationController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');

const router = express.Router();

// Protected routes - require authentication
router.use(authenticateToken);

// Admin routes - Allow ADMIN, EMPLOYEE, and COACH roles to manage notifications
router.post('/send', allowRoles('ADMIN', 'EMPLOYEE', 'COACH'), notificationController.sendNotification);
router.get('/admin', allowRoles('ADMIN', 'EMPLOYEE', 'COACH'), notificationController.getAdminNotifications);
router.get('/users', allowRoles('ADMIN', 'EMPLOYEE', 'COACH'), notificationController.getUsers);
router.patch('/mark-all-read', notificationController.markAllAsRead);
router.patch('/:id', allowRoles('ADMIN', 'EMPLOYEE', 'COACH'), notificationController.updateNotification);
router.delete('/:id', allowRoles('ADMIN', 'EMPLOYEE', 'COACH'), notificationController.deleteNotification);

// Broadcast audience for the employee Send Notification screen — their own
// complex's coaches and students. Must sit before '/:id'-style routes.
router.get('/audience', allowRoles('EMPLOYEE'), notificationController.getBroadcastAudience);

// User routes
router.get('/', notificationController.getUserNotifications);
router.get('/unread-count', notificationController.getUnreadCount);
router.patch('/:id/read', notificationController.markAsRead);

module.exports = router;
