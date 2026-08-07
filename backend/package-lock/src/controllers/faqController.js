'use strict';
const { FAQ } = require('../models');

// GET /api/faqs  — public, active only, sorted
exports.getPublicFAQs = async (req, res) => {
  try {
    const faqs = await FAQ.findAll({
      where: { isActive: true },
      order: [['sortOrder', 'ASC'], ['createdAt', 'ASC']],
    });
    res.json({ success: true, data: faqs });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// GET /api/faqs/all  — admin, all
exports.getAllFAQs = async (req, res) => {
  try {
    const faqs = await FAQ.findAll({ order: [['sortOrder', 'ASC'], ['createdAt', 'ASC']] });
    res.json({ success: true, data: faqs, total: faqs.length });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// POST /api/faqs
exports.createFAQ = async (req, res) => {
  try {
    const { question, answer, sortOrder, isActive } = req.body;
    if (!question?.trim() || !answer?.trim()) {
      return res.status(400).json({ success: false, message: 'Question and answer are required.' });
    }
    const faq = await FAQ.create({
      question: question.trim(),
      answer: answer.trim(),
      sortOrder: sortOrder ?? 0,
      isActive: isActive !== undefined ? isActive : true,
    });
    res.status(201).json({ success: true, message: 'FAQ created.', data: faq });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// PUT /api/faqs/:id
exports.updateFAQ = async (req, res) => {
  try {
    const faq = await FAQ.findByPk(req.params.id);
    if (!faq) return res.status(404).json({ success: false, message: 'FAQ not found.' });
    const { question, answer, sortOrder, isActive } = req.body;
    await faq.update({
      question: question !== undefined ? question.trim() : faq.question,
      answer: answer !== undefined ? answer.trim() : faq.answer,
      sortOrder: sortOrder !== undefined ? sortOrder : faq.sortOrder,
      isActive: isActive !== undefined ? isActive : faq.isActive,
    });
    res.json({ success: true, message: 'FAQ updated.', data: faq });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// PATCH /api/faqs/:id/toggle
exports.toggleFAQ = async (req, res) => {
  try {
    const { isActive } = req.body;
    if (typeof isActive !== 'boolean') {
      return res.status(400).json({ success: false, message: 'isActive must be boolean.' });
    }
    const faq = await FAQ.findByPk(req.params.id);
    if (!faq) return res.status(404).json({ success: false, message: 'FAQ not found.' });
    await faq.update({ isActive });
    res.json({ success: true, message: `FAQ ${isActive ? 'activated' : 'deactivated'}.`, data: faq });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// DELETE /api/faqs/:id
exports.deleteFAQ = async (req, res) => {
  try {
    const faq = await FAQ.findByPk(req.params.id);
    if (!faq) return res.status(404).json({ success: false, message: 'FAQ not found.' });
    await faq.destroy();
    res.json({ success: true, message: 'FAQ deleted.' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};
