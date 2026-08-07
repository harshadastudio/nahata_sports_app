const { CmsSport } = require('../models');
const { Op } = require('sequelize');

// Get all CMS sports with pagination and filters (admin)
exports.getAllCmsSports = async (req, res) => {
  try {
    const { page = 1, limit = 100, status, category, showOnFrontend, search } = req.query;

    const where = {};
    if (status) where.status = status;
    if (category) where.category = category;
    if (showOnFrontend !== undefined) where.showOnFrontend = showOnFrontend === 'true';
    if (search) {
      where[Op.or] = [
        { name: { [Op.iLike]: `%${search}%` } },
        { description: { [Op.iLike]: `%${search}%` } }
      ];
    }

    const offset = (parseInt(page) - 1) * parseInt(limit);
    const { count, rows } = await CmsSport.findAndCountAll({
      where,
      limit: parseInt(limit),
      offset,
      order: [['displayOrder', 'ASC'], ['createdAt', 'DESC']]
    });

    res.status(200).json({
      success: true,
      message: 'CMS sports retrieved successfully',
      data: rows,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(count / parseInt(limit)),
        totalItems: count,
        itemsPerPage: parseInt(limit)
      }
    });
  } catch (error) {
    console.error('Error fetching CMS sports:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch CMS sports', error: error.message });
  }
};

// Get active CMS sports for the public Home page
exports.getFrontendCmsSports = async (req, res) => {
  try {
    const sports = await CmsSport.findAll({
      where: { status: 'Active', showOnFrontend: true },
      order: [['displayOrder', 'ASC'], ['createdAt', 'DESC']]
    });
    res.status(200).json({ success: true, message: 'Frontend CMS sports retrieved successfully', data: sports });
  } catch (error) {
    console.error('Error fetching frontend CMS sports:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch frontend CMS sports', error: error.message });
  }
};

// Get single CMS sport
exports.getCmsSportById = async (req, res) => {
  try {
    const sport = await CmsSport.findByPk(req.params.id);
    if (!sport) return res.status(404).json({ success: false, message: 'CMS sport not found' });
    res.status(200).json({ success: true, message: 'CMS sport retrieved successfully', data: sport });
  } catch (error) {
    console.error('Error fetching CMS sport:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch CMS sport', error: error.message });
  }
};

// Create CMS sport
exports.createCmsSport = async (req, res) => {
  try {
    const { name, location, image, category, venueLabel, description, displayOrder, status, showOnFrontend } = req.body;

    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, message: 'Name is required' });
    }

    const sport = await CmsSport.create({
      name: name.trim(),
      location: location || 'Nahata Sports Complex',
      image,
      category: category || 'Outdoor',
      venueLabel,
      description,
      displayOrder: displayOrder || 0,
      status: status || 'Active',
      showOnFrontend: showOnFrontend !== undefined ? showOnFrontend : true
    });

    res.status(201).json({ success: true, message: 'CMS sport created successfully', data: sport });
  } catch (error) {
    console.error('Error creating CMS sport:', error);
    res.status(500).json({ success: false, message: 'Failed to create CMS sport', error: error.message });
  }
};

// Update CMS sport
exports.updateCmsSport = async (req, res) => {
  try {
    const sport = await CmsSport.findByPk(req.params.id);
    if (!sport) return res.status(404).json({ success: false, message: 'CMS sport not found' });
    await sport.update(req.body);
    res.status(200).json({ success: true, message: 'CMS sport updated successfully', data: sport });
  } catch (error) {
    console.error('Error updating CMS sport:', error);
    res.status(500).json({ success: false, message: 'Failed to update CMS sport', error: error.message });
  }
};

// Toggle showOnFrontend
exports.toggleShowOnFrontend = async (req, res) => {
  try {
    const { showOnFrontend } = req.body;
    if (typeof showOnFrontend !== 'boolean') {
      return res.status(400).json({ success: false, message: 'showOnFrontend must be a boolean' });
    }
    const sport = await CmsSport.findByPk(req.params.id);
    if (!sport) return res.status(404).json({ success: false, message: 'CMS sport not found' });
    await sport.update({ showOnFrontend });
    res.status(200).json({
      success: true,
      message: `CMS sport ${showOnFrontend ? 'shown on' : 'hidden from'} Home page`,
      data: sport
    });
  } catch (error) {
    console.error('Error toggling CMS sport visibility:', error);
    res.status(500).json({ success: false, message: 'Failed to update visibility', error: error.message });
  }
};

// Delete CMS sport
exports.deleteCmsSport = async (req, res) => {
  try {
    const sport = await CmsSport.findByPk(req.params.id);
    if (!sport) return res.status(404).json({ success: false, message: 'CMS sport not found' });
    await sport.destroy();
    res.status(200).json({ success: true, message: 'CMS sport deleted successfully' });
  } catch (error) {
    console.error('Error deleting CMS sport:', error);
    res.status(500).json({ success: false, message: 'Failed to delete CMS sport', error: error.message });
  }
};
