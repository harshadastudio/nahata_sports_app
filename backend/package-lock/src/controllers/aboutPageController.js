'use strict';
const { AboutPageSettings, AboutPageSection } = require('../models');
const { upload, uploadToCloudinaryMiddleware } = require('../middleware/cloudinaryUploadMiddleware');

// Export upload middleware for routes
exports.upload = upload;
exports.uploadToCloudinaryMiddleware = uploadToCloudinaryMiddleware;

// ── Helper: get or create settings row ───────────────────────────────────────
const getSettings = async () => {
  let s = await AboutPageSettings.findOne();
  if (!s) s = await AboutPageSettings.create({ heroTitle: 'About Us', whyChooseHeading: 'Why Choose Nahata Sports?', whyChoosePoints: [] });
  return s;
};

// ── GET /api/about  — public: settings + all sections sorted ─────────────────
exports.getAboutPage = async (req, res) => {
  try {
    const settings = await getSettings();
    const sections = await AboutPageSection.findAll({ order: [['sortOrder', 'ASC'], ['createdAt', 'ASC']] });
    res.json({ success: true, data: { settings, sections } });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── PUT /api/about/settings  — update hero + why-choose ──────────────────────
exports.updateSettings = async (req, res) => {
  try {
    const settings = await getSettings();
    const { heroTitle, whyChooseHeading, whyChoosePoints } = req.body;
    await settings.update({
      heroTitle: heroTitle ?? settings.heroTitle,
      whyChooseHeading: whyChooseHeading ?? settings.whyChooseHeading,
      whyChoosePoints: whyChoosePoints !== undefined
        ? (typeof whyChoosePoints === 'string' ? JSON.parse(whyChoosePoints) : whyChoosePoints)
        : settings.whyChoosePoints,
    });
    res.json({ success: true, message: 'Settings updated.', data: settings });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── GET /api/about/sections  — all sections ───────────────────────────────────
exports.getSections = async (req, res) => {
  try {
    const sections = await AboutPageSection.findAll({ order: [['sortOrder', 'ASC'], ['createdAt', 'ASC']] });
    res.json({ success: true, data: sections });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── POST /api/about/sections  — create a new section ─────────────────────────
exports.createSection = async (req, res) => {
  try {
    const { label, heading, description, image, bulletPoints, extraText, imagePosition, sortOrder } = req.body;
    const count = await AboutPageSection.count();
    const section = await AboutPageSection.create({
      label: label || null,
      heading: heading || null,
      description: description || null,
      image: image || null,
      bulletPoints: bulletPoints !== undefined
        ? (typeof bulletPoints === 'string' ? JSON.parse(bulletPoints) : bulletPoints)
        : [],
      extraText: extraText || null,
      imagePosition: imagePosition || 'left',
      sortOrder: sortOrder !== undefined ? parseInt(sortOrder) : count + 1,
    });
    res.status(201).json({ success: true, message: 'Section created.', data: section });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── PUT /api/about/sections/:id  — update a section ──────────────────────────
exports.updateSection = async (req, res) => {
  try {
    const section = await AboutPageSection.findByPk(req.params.id);
    if (!section) return res.status(404).json({ success: false, message: 'Section not found.' });
    const { label, heading, description, image, bulletPoints, extraText, imagePosition, sortOrder } = req.body;
    await section.update({
      label: label !== undefined ? label : section.label,
      heading: heading !== undefined ? heading : section.heading,
      description: description !== undefined ? description : section.description,
      image: image !== undefined ? image : section.image,
      bulletPoints: bulletPoints !== undefined
        ? (typeof bulletPoints === 'string' ? JSON.parse(bulletPoints) : bulletPoints)
        : section.bulletPoints,
      extraText: extraText !== undefined ? extraText : section.extraText,
      imagePosition: imagePosition !== undefined ? imagePosition : section.imagePosition,
      sortOrder: sortOrder !== undefined ? parseInt(sortOrder) : section.sortOrder,
    });
    res.json({ success: true, message: 'Section updated.', data: section });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── DELETE /api/about/sections/:id  — delete a section ───────────────────────
exports.deleteSection = async (req, res) => {
  try {
    const section = await AboutPageSection.findByPk(req.params.id);
    if (!section) return res.status(404).json({ success: false, message: 'Section not found.' });
    await section.destroy();
    res.json({ success: true, message: 'Section deleted.' });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};

// ── POST /api/about/upload-image  — upload image, returns URL (Cloudinary) ───
exports.uploadImage = async (req, res) => {
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
