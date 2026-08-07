'use strict';

const visitorPassService = require('../services/visitorPassService');
const { resolveComplexId, isComplexAdmin, stampComplexId, assertComplexAccess } = require('../middleware/complexScope');

// ── GET /api/visitor-passes ───────────────────────────────────────────────────
exports.getAllPasses = async (req, res) => {
  try {
    const { status, search, date, page = 1, limit = 10 } = req.query;

    const filters = { status, search, date };
    // Per-complex admin scoping (null for super admin = all complexes)
    const complexId = resolveComplexId(req);
    if (complexId != null) filters.sportComplexId = complexId;

    const result = await visitorPassService.getAllPasses(
      filters,
      parseInt(page),
      parseInt(limit)
    );
    res.status(200).json({
      success: true,
      message: 'Visitor passes retrieved successfully',
      data: result.passes,
      pagination: {
        currentPage: result.currentPage,
        totalPages: result.totalPages,
        totalItems: result.totalItems,
        pageSize: result.itemsPerPage,
      },
    });
  } catch (error) {
    console.error('Error in getAllPasses:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to retrieve visitor passes',
      error: error.message,
    });
  }
};

// ── GET /api/visitor-passes/:id ───────────────────────────────────────────────
exports.getPassById = async (req, res) => {
  try {
    const pass = await visitorPassService.getPassById(req.params.id);
    if (!pass) {
      return res.status(404).json({ success: false, message: 'Visitor pass not found' });
    }
    // Complex admins can only view passes in their own complex
    if (!assertComplexAccess(req, res, pass.sportComplexId)) return;
    res.status(200).json({ success: true, data: pass });
  } catch (error) {
    console.error('Error in getPassById:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to retrieve visitor pass',
      error: error.message,
    });
  }
};

// ── POST /api/visitor-passes/:id/send-email ───────────────────────────────────
exports.sendPassByEmail = async (req, res) => {
  try {
    const { recipientEmail, recipientName } = req.body;
    if (!recipientEmail || !recipientEmail.trim()) {
      return res.status(400).json({ success: false, message: 'Recipient email is required' });
    }
    const pass = await visitorPassService.getPassById(req.params.id);
    if (!pass) {
      return res.status(404).json({ success: false, message: 'Visitor pass not found' });
    }
    // Complex admins can only email passes in their own complex
    if (!assertComplexAccess(req, res, pass.sportComplexId)) return;

    await visitorPassService.sendPassByEmail(req.params.id, recipientEmail.trim(), recipientName);
    res.status(200).json({ success: true, message: 'Visitor pass emailed successfully' });
  } catch (error) {
    console.error('Error in sendPassByEmail:', error);
    res.status(500).json({ success: false, message: error.message || 'Failed to email visitor pass' });
  }
};

// ── POST /api/visitor-passes ──────────────────────────────────────────────────
exports.generatePass = async (req, res) => {
  try {
    const { visitorName, phoneNumber, visitPurpose } = req.body;

    // Validation
    if (!visitorName || !visitorName.trim()) {
      return res.status(400).json({ success: false, message: 'Visitor name is required' });
    }
    if (!phoneNumber || !phoneNumber.trim()) {
      return res.status(400).json({ success: false, message: 'Phone number is required' });
    }
    if (!/^\d{10}$/.test(phoneNumber.trim())) {
      return res.status(400).json({ success: false, message: 'Phone number must be 10 digits' });
    }
    if (!visitPurpose || !visitPurpose.trim()) {
      return res.status(400).json({ success: false, message: 'Visit purpose is required' });
    }

    const issuedBy = req.user?.id || null;

    const passData = {
      visitorName: visitorName.trim(),
      phoneNumber: phoneNumber.trim(),
      visitPurpose: visitPurpose.trim(),
      issuedBy,
    };
    // Force the complex for a complex admin; honor explicit value for super admin
    stampComplexId(req, passData);

    const pass = await visitorPassService.generatePass(passData);

    res.status(201).json({
      success: true,
      message: 'Visitor pass generated successfully',
      data: pass,
    });
  } catch (error) {
    console.error('Error in generatePass:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to generate visitor pass',
      error: error.message,
    });
  }
};

// ── POST /api/visitor-passes/verify ──────────────────────────────────────────
exports.verifyPass = async (req, res) => {
  try {
    const { passCode, scanType } = req.body;

    if (!passCode || !passCode.trim()) {
      return res.status(400).json({ success: false, message: 'Pass code is required' });
    }

    const scannedBy = req.user?.id || null;
    // 'In' (check-in) unless the guard explicitly scanned OUT.
    const result = await visitorPassService.verifyPass(passCode.trim(), scannedBy, scanType || 'In');

    // The pass is returned under both `pass` and `data` for frontend compatibility,
    // and on failures too so the UI can show why (already checked out, expired, …).
    // `success` mirrors `valid` so scanners that gate on it don't read a rejected
    // scan (now that a rejection also carries the pass payload) as a granted one.
    res.status(200).json({
      success: result.valid,
      valid: result.valid,
      direction: result.direction || null,
      message: result.message,
      pass: result.data || null,
      data: result.data || null,
    });
  } catch (error) {
    console.error('Error in verifyPass:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to verify visitor pass',
      error: error.message,
    });
  }
};

// ── POST /api/visitor-passes/lookup ──────────────────────────────────────────
// READ-ONLY validity check: returns the pass + status WITHOUT marking it Used.
exports.lookupPass = async (req, res) => {
  try {
    const { passCode } = req.body;

    if (!passCode || !passCode.trim()) {
      return res.status(400).json({ success: false, message: 'Pass code is required' });
    }

    const result = await visitorPassService.lookupPass(passCode.trim());

    // Return the pass under both `pass` and `data` for frontend compatibility.
    res.status(200).json({
      success: true,
      valid: result.valid,
      message: result.message,
      pass: result.data || null,
      data: result.data || null,
    });
  } catch (error) {
    console.error('Error in lookupPass:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to look up visitor pass',
      error: error.message,
    });
  }
};

// ── DELETE /api/visitor-passes/:id ───────────────────────────────────────────
exports.deletePass = async (req, res) => {
  try {
    // Complex admins may only delete passes in their own complex
    if (isComplexAdmin(req)) {
      const existing = await visitorPassService.getPassById(req.params.id);
      if (!existing) {
        return res.status(404).json({ success: false, message: 'Visitor pass not found' });
      }
      if (!assertComplexAccess(req, res, existing.sportComplexId)) return;
    }

    const deleted = await visitorPassService.deletePass(req.params.id);
    if (!deleted) {
      return res.status(404).json({ success: false, message: 'Visitor pass not found' });
    }
    res.status(200).json({ success: true, message: 'Visitor pass deleted successfully' });
  } catch (error) {
    console.error('Error in deletePass:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete visitor pass',
      error: error.message,
    });
  }
};
