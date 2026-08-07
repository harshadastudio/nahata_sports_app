'use strict';

const express = require('express');
const router = express.Router();
const ctrl = require('../controllers/studentParentFeatureController');

// Public — frontend fetches visible features + section settings
router.get('/', ctrl.getPublicFeatures);
router.get('/section-settings', ctrl.getSectionSettings);

// Image upload (Cloudinary)
router.post('/upload-image', 
  ctrl.sectionImageUpload.single('image'), 
  ctrl.uploadToCloudinaryMiddleware('student-parent-section'),
  ctrl.uploadSectionImage
);

// Admin — all features
router.get('/all', ctrl.getAllFeatures);

// Section settings update
router.patch('/section-settings', ctrl.updateSectionSettings);

// Feature CRUD
router.post('/', ctrl.createFeature);
router.put('/:id', ctrl.updateFeature);
router.patch('/:id/toggle', ctrl.toggleVisibility);
router.delete('/:id', ctrl.deleteFeature);

module.exports = router;
