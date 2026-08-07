const express = require('express');
const { getPermissions, savePermissions } = require('../controllers/permissionsController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');

const router = express.Router();

// GET /api/permissions/:role — public, no auth needed
// Frontend reads this after login to know which modules to show
router.get('/:role', getPermissions);

// POST /api/permissions/:role — admin only
// Admin panel calls this when saving permissions in Roles Management
router.post('/:role', authenticateToken, allowRoles('ADMIN'), savePermissions);

module.exports = router;
