const { HeroSlide } = require('../models');
const { Op } = require('sequelize');

// Get all hero slides with pagination and filters
exports.getAllHeroSlides = async (req, res) => {
  try {
    const {
      page = 1,
      limit = 10,
      status,
      showOnFrontend,
      search
    } = req.query;

    const where = {};

    if (status) {
      where.status = status;
    }

    if (showOnFrontend !== undefined) {
      where.showOnFrontend = showOnFrontend === 'true';
    }

    if (search) {
      where[Op.or] = [
        { title: { [Op.iLike]: `%${search}%` } },
        { description: { [Op.iLike]: `%${search}%` } }
      ];
    }

    const offset = (parseInt(page) - 1) * parseInt(limit);

    const { count, rows } = await HeroSlide.findAndCountAll({
      where,
      limit: parseInt(limit),
      offset,
      order: [['displayOrder', 'ASC'], ['createdAt', 'DESC']]
    });

    res.status(200).json({
      success: true,
      message: 'Hero slides retrieved successfully',
      data: {
        heroSlides: rows,
        pagination: {
          currentPage: parseInt(page),
          totalPages: Math.ceil(count / parseInt(limit)),
          totalItems: count,
          itemsPerPage: parseInt(limit)
        }
      }
    });
  } catch (error) {
    console.error('Error fetching hero slides:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch hero slides',
      error: error.message
    });
  }
};

// Get active hero slides for frontend
exports.getFrontendHeroSlides = async (req, res) => {
  try {
    const slides = await HeroSlide.findAll({
      where: {
        status: 'Active',
        showOnFrontend: true
      },
      order: [['displayOrder', 'ASC'], ['createdAt', 'DESC']]
    });

    res.status(200).json({
      success: true,
      message: 'Frontend hero slides retrieved successfully',
      data: slides
    });
  } catch (error) {
    console.error('Error fetching frontend hero slides:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch frontend hero slides',
      error: error.message
    });
  }
};

// Get single hero slide by ID
exports.getHeroSlideById = async (req, res) => {
  try {
    const { id } = req.params;

    const slide = await HeroSlide.findByPk(id);

    if (!slide) {
      return res.status(404).json({
        success: false,
        message: 'Hero slide not found'
      });
    }

    res.status(200).json({
      success: true,
      message: 'Hero slide retrieved successfully',
      data: slide
    });
  } catch (error) {
    console.error('Error fetching hero slide:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch hero slide',
      error: error.message
    });
  }
};

// Create new hero slide
exports.createHeroSlide = async (req, res) => {
  try {
    const {
      title,
      titleHighlight,
      subtitle,
      description,
      backgroundImage,
      backgroundImages,
      button1Text,
      button1Url,
      button2Text,
      button2Url,
      stat1Value,
      stat1Label,
      stat2Value,
      stat2Label,
      stat3Value,
      stat3Label,
      featureCard1Title,
      featureCard1Description,
      featureCard1Badge,
      featureCard2Title,
      featureCard2Description,
      displayOrder,
      status,
      showOnFrontend
    } = req.body;

    // Validation
    if (!title) {
      return res.status(400).json({
        success: false,
        message: 'Title is required'
      });
    }

    const newSlide = await HeroSlide.create({
      title,
      titleHighlight,
      subtitle,
      description,
      backgroundImage,
      backgroundImages: Array.isArray(backgroundImages) ? backgroundImages : [],
      button1Text,
      button1Url,
      button2Text,
      button2Url,
      stat1Value,
      stat1Label,
      stat2Value,
      stat2Label,
      stat3Value,
      stat3Label,
      featureCard1Title,
      featureCard1Description,
      featureCard1Badge,
      featureCard2Title,
      featureCard2Description,
      displayOrder: displayOrder || 0,
      status: status || 'Active',
      showOnFrontend: showOnFrontend !== undefined ? showOnFrontend : true
    });

    res.status(201).json({
      success: true,
      message: 'Hero slide created successfully',
      data: newSlide
    });
  } catch (error) {
    console.error('Error creating hero slide:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to create hero slide',
      error: error.message
    });
  }
};

// Update hero slide
exports.updateHeroSlide = async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;

    const slide = await HeroSlide.findByPk(id);

    if (!slide) {
      return res.status(404).json({
        success: false,
        message: 'Hero slide not found'
      });
    }

    await slide.update(updateData);

    res.status(200).json({
      success: true,
      message: 'Hero slide updated successfully',
      data: slide
    });
  } catch (error) {
    console.error('Error updating hero slide:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update hero slide',
      error: error.message
    });
  }
};

// Update hero slide status
exports.updateHeroSlideStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;

    if (!['Active', 'Inactive'].includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Invalid status. Must be Active or Inactive'
      });
    }

    const slide = await HeroSlide.findByPk(id);

    if (!slide) {
      return res.status(404).json({
        success: false,
        message: 'Hero slide not found'
      });
    }

    await slide.update({ status });

    res.status(200).json({
      success: true,
      message: 'Hero slide status updated successfully',
      data: slide
    });
  } catch (error) {
    console.error('Error updating hero slide status:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update hero slide status',
      error: error.message
    });
  }
};

// Delete hero slide
exports.deleteHeroSlide = async (req, res) => {
  try {
    const { id } = req.params;

    const slide = await HeroSlide.findByPk(id);

    if (!slide) {
      return res.status(404).json({
        success: false,
        message: 'Hero slide not found'
      });
    }

    await slide.destroy();

    res.status(200).json({
      success: true,
      message: 'Hero slide deleted successfully'
    });
  } catch (error) {
    console.error('Error deleting hero slide:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to delete hero slide',
      error: error.message
    });
  }
};

// Bulk update display order
exports.updateDisplayOrder = async (req, res) => {
  try {
    const { slides } = req.body; // Array of { id, displayOrder }

    if (!Array.isArray(slides)) {
      return res.status(400).json({
        success: false,
        message: 'Slides must be an array'
      });
    }

    // Update each slide's display order
    await Promise.all(
      slides.map(({ id, displayOrder }) =>
        HeroSlide.update({ displayOrder }, { where: { id } })
      )
    );

    res.status(200).json({
      success: true,
      message: 'Display order updated successfully'
    });
  } catch (error) {
    console.error('Error updating display order:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update display order',
      error: error.message
    });
  }
};
