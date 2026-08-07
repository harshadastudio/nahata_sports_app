'use strict';

const announcementService = require('../services/announcementService');

// GET /api/announcements
exports.getAllAnnouncements = async (req, res) => {
  try {
    const { status, search, showOnFrontend, page = 1, limit = 20 } = req.query;

    const filters = {};
    if (status) filters.status = status;
    if (search) filters.search = search;
    if (showOnFrontend !== undefined) filters.showOnFrontend = showOnFrontend === 'true';

    const result = await announcementService.getAllAnnouncements(
      filters,
      parseInt(page),
      parseInt(limit)
    );

    res.status(200).json({
      success: true,
      message: 'Announcements retrieved successfully',
      data: result.announcements,
      pagination: {
        currentPage: result.currentPage,
        totalPages: result.totalPages,
        totalItems: result.totalItems,
        itemsPerPage: result.itemsPerPage,
      },
    });
  } catch (error) {
    console.error('Error in getAllAnnouncements:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to retrieve announcements',
      error: error.message,
    });
  }
};

// GET /api/announcements/:id
exports.getAnnouncementById = async (req, res) => {
  try {
    const { id } = req.params;
    const announcement = await announcementService.getAnnouncementById(id);

    if (!announcement) {
      return res.status(404).json({
        success: false,
        message: 'Announcement not found',
      });
    }

    res.status(200).json({
      success: true,
      message: 'Announcement retrieved successfully',
      data: announcement,
    });
  } catch (error) {
    console.error('Error in getAnnouncementById:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to retrieve announcement',
      error: error.message,
    });
  }
};

// POST /api/announcements
exports.createAnnouncement = async (req, res) => {
  try {
    const { title, description, buttonTitle, buttonUrl, image, eventDate, location, status, icon, showOnFrontend } = req.body;

    if (!title || !title.trim()) {
      return res.status(400).json({ success: false, message: 'Title is required' });
    }
    if (!description || !description.trim()) {
      return res.status(400).json({ success: false, message: 'Description is required' });
    }

    const announcement = await announcementService.createAnnouncement({
      title: title.trim(),
      description: description.trim(),
      buttonTitle: buttonTitle?.trim() || null,
      buttonUrl: buttonUrl?.trim() || null,
      image: image?.trim() || null,
      eventDate: eventDate || null,
      location: location?.trim() || null,
      status: status || 'Active',
      icon: icon || 'Star',
      showOnFrontend: showOnFrontend !== undefined ? showOnFrontend : true,
    });

    res.status(201).json({
      success: true,
      message: 'Announcement created successfully',
      data: announcement,
    });
  } catch (error) {
    console.error('Error in createAnnouncement:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create announcement',
      error: error.message,
    });
  }
};

// PUT /api/announcements/:id
exports.updateAnnouncement = async (req, res) => {
  try {
    const { id } = req.params;
    const updated = await announcementService.updateAnnouncement(id, req.body);

    if (!updated) {
      return res.status(404).json({
        success: false,
        message: 'Announcement not found',
      });
    }

    res.status(200).json({
      success: true,
      message: 'Announcement updated successfully',
      data: updated,
    });
  } catch (error) {
    console.error('Error in updateAnnouncement:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update announcement',
      error: error.message,
    });
  }
};

// DELETE /api/announcements/:id
exports.deleteAnnouncement = async (req, res) => {
  try {
    const { id } = req.params;
    const deleted = await announcementService.deleteAnnouncement(id);

    if (!deleted) {
      return res.status(404).json({
        success: false,
        message: 'Announcement not found',
      });
    }

    res.status(200).json({
      success: true,
      message: 'Announcement deleted successfully',
    });
  } catch (error) {
    console.error('Error in deleteAnnouncement:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete announcement',
      error: error.message,
    });
  }
};
