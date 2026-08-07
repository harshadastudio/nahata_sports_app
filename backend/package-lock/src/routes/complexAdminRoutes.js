'use strict';

const express = require('express');
const router = express.Router();
const complexAdminController = require('../controllers/complexAdminController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');

// Complex Admin management is SUPER ADMIN (role ADMIN) only.
router.use(authenticateToken, allowRoles('ADMIN'));

router.get('/', complexAdminController.listComplexAdmins);
router.post('/', complexAdminController.createComplexAdmin);
router.put('/:id', complexAdminController.updateComplexAdmin);
router.delete('/:id', complexAdminController.deactivateComplexAdmin);

module.exports = router;
