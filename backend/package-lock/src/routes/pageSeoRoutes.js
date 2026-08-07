const express = require('express');
const pageSeoController = require('../controllers/pageSeoController');
const { authenticateToken: authMiddleware } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');

const router = express.Router();

// Public routes (no authentication required) — the public site reads these.
router.get('/', pageSeoController.getAllPageSeo);
router.get('/:pageKey', pageSeoController.getPageSeoByKey);

// Admin routes (no authentication for now, can be protected later — matches the
// existing Blog/About convention).
router.put('/:pageKey', pageSeoController.upsertPageSeo);

// Protected routes (if needed in future)
// router.use(authMiddleware);
// router.put('/:pageKey', allowRoles('ADMIN'), pageSeoController.upsertPageSeo);

module.exports = router;
