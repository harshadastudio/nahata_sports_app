'use strict';

const express = require('express');
const visitorPassController = require('../controllers/visitorPassController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');

const router = express.Router();

// Roles allowed to manage visitor passes
const canManage = [authenticateToken, allowRoles('admin', 'employee', 'security_guard', 'ADMIN', 'EMPLOYEE', 'SECURITY_GUARD', 'SECURITY', 'COMPLEX_ADMIN')];

// ── POST /api/visitor-passes/verify  — verify / scan a pass (marks it Used) ──
// MUST be defined BEFORE /:id so Express doesn't treat "verify" as an id param
router.post('/verify', ...canManage, visitorPassController.verifyPass);

// ── POST /api/visitor-passes/lookup  — READ-ONLY validity check (no mutation) ─
router.post('/lookup', ...canManage, visitorPassController.lookupPass);

// ── GET /api/visitor-passes          — list all passes (paginated) ────────────
router.get('/', ...canManage, visitorPassController.getAllPasses);

// ── POST /api/visitor-passes         — generate a new visitor pass ────────────
router.post('/', ...canManage, visitorPassController.generatePass);

// ── POST /api/visitor-passes/:id/send-email — email the pass + QR to a recipient
router.post('/:id/send-email', ...canManage, visitorPassController.sendPassByEmail);

// ── GET /api/visitor-passes/:id      — get single pass by id or passCode ──────
router.get('/:id', ...canManage, visitorPassController.getPassById);

// ── DELETE /api/visitor-passes/:id   — delete a pass ─────────────────────────
router.delete('/:id', authenticateToken, allowRoles('admin', 'ADMIN', 'COMPLEX_ADMIN'), visitorPassController.deletePass);

module.exports = router;
