'use strict';
const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/legalPageController');

// GET  /api/legal/:type  — public
router.get('/:type', ctrl.getLegalPage);
// PUT  /api/legal/:type  — admin
router.put('/:type', ctrl.updateLegalPage);

module.exports = router;
