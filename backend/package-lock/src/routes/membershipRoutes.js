const express = require('express');
const membershipController = require('../controllers/membershipController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');

const router = express.Router();

// Memberships are an admin-panel feature (the public site does not consume these
// endpoints). Every route now requires a valid session; all reads and writes are
// restricted to admin roles. The admin panel already sends its Bearer token on
// every request, so this is transparent to it.
//
// Role variants ('admin'/'super_admin') are handled by allowRoles' case-insensitive
// match; COMPLEX_ADMIN is included so per-complex admins can manage memberships.
const ADMIN_ROLES = ['ADMIN', 'SUPER_ADMIN', 'COMPLEX_ADMIN'];

router.use(authenticateToken);
router.use(allowRoles(...ADMIN_ROLES));

// ── Reads (admin only) ────────────────────────────────────────────────────────
router.get('/', membershipController.getAllMemberships);
router.get('/stats', membershipController.getMembershipStats);
router.get('/user/:userId', membershipController.getMembershipsByUserId);
router.get('/user/:userId/active', membershipController.getActiveMembership);
router.get('/:id', membershipController.getMembershipById);

// ── Writes (admin only) ───────────────────────────────────────────────────────
router.post('/', membershipController.createMembership);
router.put('/:id', membershipController.updateMembership);
router.patch('/:id/status', membershipController.updateMembershipStatus);
router.patch('/:id/payment-status', membershipController.updatePaymentStatus);
router.patch('/:id/cancel', membershipController.cancelMembership);
router.post('/:id/renew', membershipController.renewMembership);
router.delete('/:id', membershipController.deleteMembership);

// Maintenance job trigger — admin only (should ideally be moved to a scheduler).
router.post('/check-expired', membershipController.checkExpiredMemberships);

module.exports = router;
