const express = require('express');
const router = express.Router();
const employeeController = require('../controllers/employeeController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');

// All routes require authentication
router.use(authenticateToken);

// Get all employees (ADMIN and EMPLOYEE can read)
router.get('/', allowRoles('ADMIN', 'EMPLOYEE', 'COMPLEX_ADMIN'), employeeController.getAllEmployees);

// Get single employee (ADMIN and EMPLOYEE can read)
router.get('/:id', allowRoles('ADMIN', 'EMPLOYEE', 'COMPLEX_ADMIN'), employeeController.getEmployeeById);

// Reveal / reset the employee's login password (ADMIN + COMPLEX_ADMIN only)
router.get('/:id/password', allowRoles('ADMIN', 'COMPLEX_ADMIN'), employeeController.revealPassword);
router.post('/:id/reset-password', allowRoles('ADMIN', 'COMPLEX_ADMIN'), employeeController.resetPassword);

// Create employee (ADMIN only)
router.post('/', allowRoles('ADMIN', 'COMPLEX_ADMIN'), employeeController.createEmployee);

// Update employee (ADMIN only)
router.put('/:id', allowRoles('ADMIN', 'COMPLEX_ADMIN'), employeeController.updateEmployee);

// Delete employee (ADMIN only)
router.delete('/:id', allowRoles('ADMIN', 'COMPLEX_ADMIN'), employeeController.deleteEmployee);

module.exports = router;
