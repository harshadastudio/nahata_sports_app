'use strict';

const { Announcement } = require('../models');
const { Op } = require('sequelize');

/**
 * Get all announcements with optional filters and pagination
 */
exports.getAllAnnouncements = async (filters = {}, page = 1, limit = 20) => {
  const where = {};

  if (filters.status) {
    where.status = filters.status;
  }

  if (filters.search) {
    where[Op.or] = [
      { title: { [Op.iLike]: `%${filters.search}%` } },
      { description: { [Op.iLike]: `%${filters.search}%` } },
    ];
  }

  if (filters.showOnFrontend !== undefined) {
    where.showOnFrontend = filters.showOnFrontend;
  }

  const offset = (page - 1) * limit;

  const { count, rows } = await Announcement.findAndCountAll({
    where,
    order: [['createdAt', 'DESC']],
    limit,
    offset,
  });

  return {
    announcements: rows,
    currentPage: page,
    totalPages: Math.ceil(count / limit),
    totalItems: count,
    itemsPerPage: limit,
  };
};

/**
 * Get a single announcement by ID
 */
exports.getAnnouncementById = async (id) => {
  return Announcement.findByPk(id);
};

/**
 * Create a new announcement
 */
exports.createAnnouncement = async (data) => {
  return Announcement.create({
    title: data.title,
    description: data.description,
    buttonTitle: data.buttonTitle || null,
    buttonUrl: data.buttonUrl || null,
    image: data.image || null,
    eventDate: data.eventDate || null,
    location: data.location || null,
    status: data.status || 'Active',
    icon: data.icon || 'Star',
    showOnFrontend: data.showOnFrontend !== undefined ? data.showOnFrontend : true,
  });
};

/**
 * Update an existing announcement
 */
exports.updateAnnouncement = async (id, data) => {
  const announcement = await Announcement.findByPk(id);
  if (!announcement) return null;

  await announcement.update({
    title: data.title ?? announcement.title,
    description: data.description ?? announcement.description,
    buttonTitle: data.buttonTitle !== undefined ? data.buttonTitle : announcement.buttonTitle,
    buttonUrl: data.buttonUrl !== undefined ? data.buttonUrl : announcement.buttonUrl,
    image: data.image !== undefined ? data.image : announcement.image,
    eventDate: data.eventDate !== undefined ? data.eventDate : announcement.eventDate,
    location: data.location !== undefined ? data.location : announcement.location,
    status: data.status ?? announcement.status,
    icon: data.icon !== undefined ? data.icon : announcement.icon,
    showOnFrontend: data.showOnFrontend !== undefined ? data.showOnFrontend : announcement.showOnFrontend,
  });

  return announcement;
};

/**
 * Delete an announcement
 */
exports.deleteAnnouncement = async (id) => {
  const announcement = await Announcement.findByPk(id);
  if (!announcement) return false;

  await announcement.destroy();
  return true;
};
