const express = require('express');
const adminController = require('../controllers/adminController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');

const router = express.Router();

// Public route for getting coaches (no auth required)
router.get('/coaches', adminController.getAllUsers);

// User management routes (require authentication and ADMIN or EMPLOYEE role)
router.post('/create-user', authenticateToken, allowRoles('ADMIN'), adminController.createUser);
router.get('/users', authenticateToken, allowRoles('ADMIN', 'EMPLOYEE'), adminController.getAllUsers);
router.get('/users/:id', authenticateToken, allowRoles('ADMIN', 'EMPLOYEE'), adminController.getUserById);
router.put('/users/:id', authenticateToken, allowRoles('ADMIN', 'EMPLOYEE'), adminController.updateUser);
router.delete('/users/:id', authenticateToken, allowRoles('ADMIN'), adminController.deleteUser);

// Statistics route
router.get('/stats', authenticateToken, allowRoles('ADMIN'), adminController.getStats);

// Role permissions routes
router.put('/roles/:role/permissions', authenticateToken, allowRoles('ADMIN'), adminController.saveRolePermissions);
router.get('/roles/:role/permissions', authenticateToken, allowRoles('ADMIN'), adminController.getRolePermissions);

// Security Guard routes
router.get('/security-guards', authenticateToken, allowRoles('ADMIN', 'EMPLOYEE', 'COMPLEX_ADMIN'), adminController.getAllSecurityGuards);
router.get('/security-guards/:id', authenticateToken, allowRoles('ADMIN', 'EMPLOYEE', 'COMPLEX_ADMIN'), adminController.getSecurityGuardById);
router.get('/security-guards/:id/password', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN'), adminController.revealSecurityGuardPassword);
router.post('/security-guards/:id/reset-password', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN'), adminController.resetSecurityGuardPassword);
router.post('/security-guards', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN'), adminController.createSecurityGuard);
router.put('/security-guards/:id', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN'), adminController.updateSecurityGuard);
router.delete('/security-guards/:id', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN'), adminController.deleteSecurityGuard);

module.exports = router;
