const express = require('express');
const router = express.Router();
const feesController = require('../controllers/feesController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');
const { requireEmployeePermission, EMPLOYEE_PERMISSIONS } = require('../middleware/employeePermission');

// Creating / editing fee records is the new Fees Management module. Approving
// and rejecting stay under the existing Fees Approval permission, so an admin
// can grant one without the other.
const empFees = requireEmployeePermission(EMPLOYEE_PERMISSIONS.FEES_MANAGEMENT);

// All routes require authentication
router.use(authenticateToken);

// User: get own approved gate passes (must be before admin-only routes)
router.get('/my', feesController.getMyGatePasses);

// Gate: scan a student gate pass → verify (and, only for COACH, mark
// attendance Present for today). Security guards, coaches, employees and
// admins scan at the gate.
router.post(
  '/scan-pass',
  allowRoles('ADMIN', 'COMPLEX_ADMIN', 'COACH', 'SECURITY', 'EMPLOYEE'),
  feesController.scanStudentPass
);

// Date-wise log of every student gate-pass scan.
router.get(
  '/scan-logs',
  allowRoles('ADMIN', 'COMPLEX_ADMIN', 'COACH', 'SECURITY', 'EMPLOYEE'),
  feesController.getScanLogs
);

// Read-only routes — accessible by ADMIN, COACH and EMPLOYEE (Employee needs
// to see records in order to approve/reject them).
router.get('/stats', allowRoles('ADMIN', 'COACH', 'COMPLEX_ADMIN', 'EMPLOYEE'), feesController.getFeesStats);
router.get('/debug-stats', allowRoles('ADMIN', 'COACH', 'COMPLEX_ADMIN', 'EMPLOYEE'), feesController.getDebugStats);
router.get('/retention-stats', allowRoles('ADMIN', 'COACH', 'COMPLEX_ADMIN', 'EMPLOYEE'), feesController.getRetentionStats);
router.get('/', allowRoles('ADMIN', 'COACH', 'COMPLEX_ADMIN', 'EMPLOYEE'), feesController.getAllFees);

// Write routes — ADMIN and COACH, plus employees holding Fees Management
router.post('/', allowRoles('ADMIN', 'COACH', 'COMPLEX_ADMIN', 'EMPLOYEE'), empFees, feesController.createFeeRecord);
router.put('/:id', allowRoles('ADMIN', 'COACH', 'COMPLEX_ADMIN', 'EMPLOYEE'), empFees, feesController.updateFeeRecord);
router.patch('/:id/payment', allowRoles('ADMIN', 'COACH', 'COMPLEX_ADMIN', 'EMPLOYEE'), empFees, feesController.updatePaymentStatus);
router.patch('/:id/approve', allowRoles('ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE'), feesController.approveFeePayment);
router.patch('/:id/reject', allowRoles('ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE'), feesController.rejectFeePayment);
router.delete('/:id', allowRoles('ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE'), empFees, feesController.deleteFeeRecord);

module.exports = router;
