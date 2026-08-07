'use strict';

const express = require('express');
const announcementController = require('../controllers/announcementController');

const router = express.Router();

// Public routes — frontend can read without auth
router.get('/', announcementController.getAllAnnouncements);
router.get('/:id', announcementController.getAnnouncementById);

// Admin routes — no auth required (matches existing pattern in this project)
router.post('/', announcementController.createAnnouncement);
router.put('/:id', announcementController.updateAnnouncement);
router.delete('/:id', announcementController.deleteAnnouncement);

module.exports = router;
