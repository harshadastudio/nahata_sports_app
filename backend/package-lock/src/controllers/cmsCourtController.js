const { CmsCourt } = require('../models');
const { Op } = require('sequelize');

// Get all CMS courts with pagination and filters (admin)
exports.getAllCmsCourts = async (req, res) => {
  try {
    const { page = 1, limit = 100, status, sportName, showOnFrontend, search } = req.query;

    const where = {};
    if (status) where.status = status;
    if (sportName) where.sportName = sportName;
    if (showOnFrontend !== undefined) where.showOnFrontend = showOnFrontend === 'true';
    if (search) {
      where[Op.or] = [
        { name: { [Op.iLike]: `%${search}%` } },
        { sportName: { [Op.iLike]: `%${search}%` } },
        { description: { [Op.iLike]: `%${search}%` } }
      ];
    }

    const offset = (parseInt(page) - 1) * parseInt(limit);
    const { count, rows } = await CmsCourt.findAndCountAll({
      where,
      limit: parseInt(limit),
      offset,
      order: [['displayOrder', 'ASC'], ['createdAt', 'DESC']]
    });

    res.status(200).json({
      success: true,
      message: 'CMS courts retrieved successfully',
      data: rows,
      pagination: {
        currentPage: parseInt(page),
        totalPages: Math.ceil(count / parseInt(limit)),
        totalItems: count,
        itemsPerPage: parseInt(limit)
      }
    });
  } catch (error) {
    console.error('Error fetching CMS courts:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch CMS courts', error: error.message });
  }
};

// Get active CMS courts for the public Home page
exports.getFrontendCmsCourts = async (req, res) => {
  try {
    const courts = await CmsCourt.findAll({
      where: { status: 'Active', showOnFrontend: true },
      order: [['displayOrder', 'ASC'], ['createdAt', 'DESC']]
    });
    res.status(200).json({ success: true, message: 'Frontend CMS courts retrieved successfully', data: courts });
  } catch (error) {
    console.error('Error fetching frontend CMS courts:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch frontend CMS courts', error: error.message });
  }
};

// Get single CMS court
exports.getCmsCourtById = async (req, res) => {
  try {
    const court = await CmsCourt.findByPk(req.params.id);
    if (!court) return res.status(404).json({ success: false, message: 'CMS court not found' });
    res.status(200).json({ success: true, message: 'CMS court retrieved successfully', data: court });
  } catch (error) {
    console.error('Error fetching CMS court:', error);
    res.status(500).json({ success: false, message: 'Failed to fetch CMS court', error: error.message });
  }
};

// Create CMS court
exports.createCmsCourt = async (req, res) => {
  try {
    const { sportName, name, image, surfaceType, hourlyRate, description, displayOrder, status, showOnFrontend } = req.body;

    if (!sportName || !sportName.trim()) {
      return res.status(400).json({ success: false, message: 'Sport name is required' });
    }
    if (!name || !name.trim()) {
      return res.status(400).json({ success: false, message: 'Court name is required' });
    }

    const court = await CmsCourt.create({
      sportName: sportName.trim(),
      name: name.trim(),
      image,
      surfaceType: surfaceType || 'Synthetic',
      hourlyRate: hourlyRate !== undefined && hourlyRate !== '' ? hourlyRate : 800,
      description,
      displayOrder: displayOrder || 0,
      status: status || 'Active',
      showOnFrontend: showOnFrontend !== undefined ? showOnFrontend : true
    });

    res.status(201).json({ success: true, message: 'CMS court created successfully', data: court });
  } catch (error) {
    console.error('Error creating CMS court:', error);
    res.status(500).json({ success: false, message: 'Failed to create CMS court', error: error.message });
  }
};

// Update CMS court
exports.updateCmsCourt = async (req, res) => {
  try {
    const court = await CmsCourt.findByPk(req.params.id);
    if (!court) return res.status(404).json({ success: false, message: 'CMS court not found' });
    await court.update(req.body);
    res.status(200).json({ success: true, message: 'CMS court updated successfully', data: court });
  } catch (error) {
    console.error('Error updating CMS court:', error);
    res.status(500).json({ success: false, message: 'Failed to update CMS court', error: error.message });
  }
};

// Toggle showOnFrontend
exports.toggleShowOnFrontend = async (req, res) => {
  try {
    const { showOnFrontend } = req.body;
    if (typeof showOnFrontend !== 'boolean') {
      return res.status(400).json({ success: false, message: 'showOnFrontend must be a boolean' });
    }
    const court = await CmsCourt.findByPk(req.params.id);
    if (!court) return res.status(404).json({ success: false, message: 'CMS court not found' });
    await court.update({ showOnFrontend });
    res.status(200).json({
      success: true,
      message: `CMS court ${showOnFrontend ? 'shown on' : 'hidden from'} Home page`,
      data: court
    });
  } catch (error) {
    console.error('Error toggling CMS court visibility:', error);
    res.status(500).json({ success: false, message: 'Failed to update visibility', error: error.message });
  }
};

// Delete CMS court
exports.deleteCmsCourt = async (req, res) => {
  try {
    const court = await CmsCourt.findByPk(req.params.id);
    if (!court) return res.status(404).json({ success: false, message: 'CMS court not found' });
    await court.destroy();
    res.status(200).json({ success: true, message: 'CMS court deleted successfully' });
  } catch (error) {
    console.error('Error deleting CMS court:', error);
    res.status(500).json({ success: false, message: 'Failed to delete CMS court', error: error.message });
  }
};
