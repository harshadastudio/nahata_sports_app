const express = require('express');
const router = express.Router();
const batchController = require('../controllers/batchController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { optionalAuth } = require('../middleware/optionalAuth');
const { allowRoles } = require('../middleware/roleMiddleware');
const { requireEmployeePermission, EMPLOYEE_PERMISSIONS } = require('../middleware/employeePermission');

// Employees may manage batches only when the admin has granted the module.
// Their complex scoping is enforced separately by complexScope.
const empBatches = requireEmployeePermission(EMPLOYEE_PERMISSIONS.BATCHES);

// Public read routes.
// optionalAuth: anonymous = all batches (website); logged-in COMPLEX_ADMIN = own complex only.
router.get('/', optionalAuth, batchController.getAllBatches);
router.get('/sport/:sportId', batchController.getBatchesBySport);
router.get('/coach/:coachId', batchController.getBatchesByCoach);
router.get('/:id', optionalAuth, batchController.getBatchById);
router.get('/:id/stats', batchController.getBatchStats);

// Protected write routes — admins, plus employees holding the Batch module permission
router.post('/', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE'), empBatches, batchController.createBatch);
router.put('/:id', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE'), empBatches, batchController.updateBatch);
router.patch('/:id/status', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE'), empBatches, batchController.updateBatchStatus);
router.delete('/:id', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN', 'EMPLOYEE'), empBatches, batchController.deleteBatch);

module.exports = router;
