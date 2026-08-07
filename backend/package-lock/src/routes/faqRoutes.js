'use strict';
const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/faqController');

router.get('/', ctrl.getPublicFAQs);
router.get('/all', ctrl.getAllFAQs);
router.post('/', ctrl.createFAQ);
router.put('/:id', ctrl.updateFAQ);
router.patch('/:id/toggle', ctrl.toggleFAQ);
router.delete('/:id', ctrl.deleteFAQ);

module.exports = router;
