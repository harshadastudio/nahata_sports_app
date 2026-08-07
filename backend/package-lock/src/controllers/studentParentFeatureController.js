'use strict';

const { StudentParentFeature } = require('../models');

// GET /api/student-parent-features  — public, returns showOnFrontend=true sorted by sortOrder
exports.getPublicFeatures = async (req, res) => {
  try {
    const features = await StudentParentFeature.findAll({
      where: { showOnFrontend: true },
      order: [['sortOrder', 'ASC'], ['createdAt', 'ASC']],
    });
    res.json({ success: true, data: features });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// GET /api/student-parent-features/all  — admin, returns all
exports.getAllFeatures = async (req, res) => {
  try {
    const features = await StudentParentFeature.findAll({
      order: [['sortOrder', 'ASC'], ['createdAt', 'ASC']],
    });
    res.json({ success: true, data: features });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// POST /api/student-parent-features
exports.createFeature = async (req, res) => {
  try {
    const { title, description, icon, sortOrder, showOnFrontend } = req.body;
    if (!title) return res.status(400).json({ success: false, message: 'Title is required.' });
    const feature = await StudentParentFeature.create({
      title, description: description || null,
      icon: icon || 'CheckCircle2',
      sortOrder: sortOrder ?? 0,
      showOnFrontend: showOnFrontend ?? true,
    });
    res.status(201).json({ success: true, message: 'Feature created.', data: feature });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// PUT /api/student-parent-features/:id
exports.updateFeature = async (req, res) => {
  try {
    const feature = await StudentParentFeature.findByPk(req.params.id);
    if (!feature) return res.status(404).json({ success: false, message: 'Feature not found.' });
    const { title, description, icon, sortOrder, showOnFrontend } = req.body;
    await feature.update({
      title: title ?? feature.title,
      description: description !== undefined ? description : feature.description,
      icon: icon ?? feature.icon,
      sortOrder: sortOrder ?? feature.sortOrder,
      showOnFrontend: showOnFrontend !== undefined ? showOnFrontend : feature.showOnFrontend,
    });
    res.json({ success: true, message: 'Feature updated.', data: feature });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// PATCH /api/student-parent-features/:id/toggle
exports.toggleVisibility = async (req, res) => {
  try {
    const { showOnFrontend } = req.body;
    if (typeof showOnFrontend !== 'boolean') {
      return res.status(400).json({ success: false, message: 'showOnFrontend must be boolean.' });
    }
    const feature = await StudentParentFeature.findByPk(req.params.id);
    if (!feature) return res.status(404).json({ success: false, message: 'Feature not found.' });
    await feature.update({ showOnFrontend });
    res.json({ success: true, message: `Feature ${showOnFrontend ? 'shown' : 'hidden'}.`, data: feature });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// DELETE /api/student-parent-features/:id
exports.deleteFeature = async (req, res) => {
  try {
    const feature = await StudentParentFeature.findByPk(req.params.id);
    if (!feature) return res.status(404).json({ success: false, message: 'Feature not found.' });
    await feature.destroy();
    res.json({ success: true, message: 'Feature deleted.' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── Section Settings (images) ─────────────────────────────────────────────────

const { StudentParentSectionSettings } = require('../models');
const { upload, uploadToCloudinaryMiddleware } = require('../middleware/cloudinaryUploadMiddleware');

// Export upload middleware for routes
exports.sectionImageUpload = upload;
exports.uploadToCloudinaryMiddleware = uploadToCloudinaryMiddleware;

// Default stats-counter values shown above the Student/Parent features on the
// homepage. Used when an admin hasn't customised them yet.
const DEFAULT_COUNTERS = [
  { value: 2, suffix: '', label: 'Venues', color: '#6C52E8' },
  { value: 7, suffix: '+', label: 'Sports', color: '#FF6B2C' },
  { value: 500, suffix: '+', label: 'Members', color: '#059669' },
  { value: 10, suffix: '+', label: 'Pro Coaches', color: '#0891B2' },
];

// Return settings as a plain object with counters defaulted when not set.
const serializeSettings = (settings) => {
  const data = settings.toJSON();
  if (!Array.isArray(data.counters) || data.counters.length === 0) {
    data.counters = DEFAULT_COUNTERS;
  }
  return data;
};

// GET /api/student-parent-features/section-settings
exports.getSectionSettings = async (req, res) => {
  try {
    let settings = await StudentParentSectionSettings.findOne();
    if (!settings) settings = await StudentParentSectionSettings.create({ image1: null, image2: null });
    res.json({ success: true, data: serializeSettings(settings) });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// PATCH /api/student-parent-features/section-settings  — update images and/or counters
exports.updateSectionSettings = async (req, res) => {
  try {
    let settings = await StudentParentSectionSettings.findOne();
    if (!settings) settings = await StudentParentSectionSettings.create({ image1: null, image2: null });
    const { image1, image2, counters } = req.body;
    await settings.update({
      image1: image1 !== undefined ? image1 : settings.image1,
      image2: image2 !== undefined ? image2 : settings.image2,
      counters: Array.isArray(counters) ? counters : settings.counters,
    });
    res.json({ success: true, message: 'Settings updated.', data: serializeSettings(settings) });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// POST /api/student-parent-features/upload-image  — upload image1 or image2 (Cloudinary)
exports.uploadSectionImage = async (req, res) => {
  try {
    if (!req.cloudinaryResult) {
      return res.status(400).json({ success: false, message: 'No file provided.' });
    }
    res.json({ 
      success: true, 
      imageUrl: req.cloudinaryResult.url,
      publicId: req.cloudinaryResult.publicId 
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};
