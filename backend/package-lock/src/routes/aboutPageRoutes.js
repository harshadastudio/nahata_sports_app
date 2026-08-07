'use strict';
const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/aboutPageController');

// Public
router.get('/', ctrl.getAboutPage);

// Settings (hero + why-choose)
router.put('/settings', ctrl.updateSettings);

// Image upload (Cloudinary)
router.post('/upload-image', 
  ctrl.upload.single('image'), 
  ctrl.uploadToCloudinaryMiddleware('about'),
  ctrl.uploadImage
);

// Sections CRUD
router.get('/sections', ctrl.getSections);
router.post('/sections', ctrl.createSection);
router.put('/sections/:id', ctrl.updateSection);
router.delete('/sections/:id', ctrl.deleteSection);

module.exports = router;
