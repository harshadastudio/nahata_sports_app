'use strict';
const { LegalPage } = require('../models');

// GET /api/legal/:type  — public, fetch by type
exports.getLegalPage = async (req, res) => {
  try {
    const { type } = req.params;
    if (!['privacy', 'cancellation', 'disclaimer', 'terms', 'holidays', 'equipment'].includes(type)) {
      return res.status(400).json({ success: false, message: 'Invalid type. Must be privacy, cancellation, disclaimer, terms, holidays, or equipment.' });
    }
    const page = await LegalPage.findOne({ where: { type } });
    if (!page) return res.status(404).json({ success: false, message: 'Page not found.' });
    res.json({ success: true, data: page });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// PUT /api/legal/:type  — admin, update by type
exports.updateLegalPage = async (req, res) => {
  try {
    const { type } = req.params;
    if (!['privacy', 'cancellation', 'disclaimer', 'terms', 'holidays', 'equipment'].includes(type)) {
      return res.status(400).json({ success: false, message: 'Invalid type.' });
    }
    const { title, content } = req.body;
    if (!title?.trim() || !content?.trim()) {
      return res.status(400).json({ success: false, message: 'Title and content are required.' });
    }
    let page = await LegalPage.findOne({ where: { type } });
    if (!page) {
      page = await LegalPage.create({ type, title: title.trim(), content: content.trim() });
    } else {
      await page.update({ title: title.trim(), content: content.trim() });
    }
    res.json({ success: true, message: 'Page updated.', data: page });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

module.exports = exports;
