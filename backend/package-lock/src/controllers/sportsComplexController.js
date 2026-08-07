const sportsComplexService = require('../services/sportsComplexService');

// Get all sports complexes
exports.getAllSportsComplexes = async (req, res) => {
  try {
    const { status, city, state, search, showOnFrontend, page = 1, limit = 10 } = req.query;
    
    const filters = {};
    if (status) filters.status = status;
    if (city) filters.city = city;
    if (state) filters.state = state;
    if (search) filters.search = search;
    if (showOnFrontend !== undefined) filters.showOnFrontend = showOnFrontend === 'true';
    
    const result = await sportsComplexService.getAllSportsComplexes(
      filters,
      parseInt(page),
      parseInt(limit)
    );
    
    res.status(200).json({
      success: true,
      message: 'Sports complexes retrieved successfully',
      data: result,
    });
  } catch (error) {
    console.error('Error fetching sports complexes:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch sports complexes',
      error: error.message,
    });
  }
};

// Get sports complex by ID
exports.getSportsComplexById = async (req, res) => {
  try {
    const { id } = req.params;
    const { includeCourts } = req.query;
    
    const complex = await sportsComplexService.getSportsComplexById(id, {
      includeCourts: includeCourts === 'true',
    });
    
    if (!complex) {
      return res.status(404).json({
        success: false,
        message: 'Sports complex not found',
      });
    }
    
    res.status(200).json({
      success: true,
      data: complex,
    });
  } catch (error) {
    console.error('Error fetching sports complex:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch sports complex',
      error: error.message,
    });
  }
};

// Create a new sports complex
exports.createSportsComplex = async (req, res) => {
  try {
    const complexData = req.body;
    
    // Validate required fields
    if (!complexData.name) {
      return res.status(400).json({
        success: false,
        message: 'Sports complex name is required',
      });
    }
    
    if (!complexData.address) {
      return res.status(400).json({
        success: false,
        message: 'Address is required',
      });
    }
    
    if (!complexData.city) {
      return res.status(400).json({
        success: false,
        message: 'City is required',
      });
    }
    
    if (!complexData.state) {
      return res.status(400).json({
        success: false,
        message: 'State is required',
      });
    }
    
    if (!complexData.contactPhone) {
      return res.status(400).json({
        success: false,
        message: 'Contact phone is required',
      });
    }
    
    const newComplex = await sportsComplexService.createSportsComplex(complexData);
    
    res.status(201).json({
      success: true,
      message: 'Sports complex created successfully',
      data: newComplex,
    });
  } catch (error) {
    console.error('Error creating sports complex:', error);
    
    if (error.message.includes('not found')) {
      return res.status(404).json({
        success: false,
        message: error.message,
      });
    }
    
    res.status(500).json({
      success: false,
      message: 'Failed to create sports complex',
      error: error.message,
    });
  }
};

// Update sports complex
exports.updateSportsComplex = async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;
    
    const updatedComplex = await sportsComplexService.updateSportsComplex(id, updateData);
    
    if (!updatedComplex) {
      return res.status(404).json({
        success: false,
        message: 'Sports complex not found',
      });
    }
    
    res.status(200).json({
      success: true,
      message: 'Sports complex updated successfully',
      data: updatedComplex,
    });
  } catch (error) {
    console.error('Error updating sports complex:', error);
    
    if (error.message.includes('not found')) {
      return res.status(404).json({
        success: false,
        message: error.message,
      });
    }
    
    res.status(500).json({
      success: false,
      message: 'Failed to update sports complex',
      error: error.message,
    });
  }
};

// Update sports complex status
exports.updateSportsComplexStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    
    if (!status || !['Active', 'Maintenance', 'Closed'].includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Valid status is required (Active, Maintenance, or Closed)',
      });
    }
    
    const updatedComplex = await sportsComplexService.updateSportsComplexStatus(id, status);
    
    if (!updatedComplex) {
      return res.status(404).json({
        success: false,
        message: 'Sports complex not found',
      });
    }
    
    res.status(200).json({
      success: true,
      message: 'Sports complex status updated successfully',
      data: updatedComplex,
    });
  } catch (error) {
    console.error('Error updating sports complex status:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update sports complex status',
      error: error.message,
    });
  }
};

// Delete sports complex
exports.deleteSportsComplex = async (req, res) => {
  try {
    const { id } = req.params;
    
    const deleted = await sportsComplexService.deleteSportsComplex(id);
    
    if (!deleted) {
      return res.status(404).json({
        success: false,
        message: 'Sports complex not found',
      });
    }
    
    res.status(200).json({
      success: true,
      message: 'Sports complex deleted successfully',
    });
  } catch (error) {
    console.error('Error deleting sports complex:', error);
    
    if (error.message.includes('existing courts')) {
      return res.status(400).json({
        success: false,
        message: error.message,
      });
    }
    
    res.status(500).json({
      success: false,
      message: 'Failed to delete sports complex',
      error: error.message,
    });
  }
};

// Get sports complexes by city
exports.getSportsComplexesByCity = async (req, res) => {
  try {
    const { city } = req.params;
    
    const complexes = await sportsComplexService.getSportsComplexesByCity(city);
    
    res.status(200).json({
      success: true,
      data: complexes,
    });
  } catch (error) {
    console.error('Error fetching sports complexes by city:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch sports complexes',
      error: error.message,
    });
  }
};

// Get sports complexes by state
exports.getSportsComplexesByState = async (req, res) => {
  try {
    const { state } = req.params;
    
    const complexes = await sportsComplexService.getSportsComplexesByState(state);
    
    res.status(200).json({
      success: true,
      data: complexes,
    });
  } catch (error) {
    console.error('Error fetching sports complexes by state:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch sports complexes',
      error: error.message,
    });
  }
};

// Get sports complex statistics
exports.getSportsComplexStats = async (req, res) => {
  try {
    const { id } = req.params;
    
    const stats = await sportsComplexService.getSportsComplexStats(id);
    
    res.status(200).json({
      success: true,
      data: stats,
    });
  } catch (error) {
    console.error('Error fetching sports complex stats:', error);
    
    if (error.message === 'Sports complex not found') {
      return res.status(404).json({
        success: false,
        message: error.message,
      });
    }
    
    res.status(500).json({
      success: false,
      message: 'Failed to fetch sports complex statistics',
      error: error.message,
    });
  }
};

// Toggle showOnFrontend
exports.toggleShowOnFrontend = async (req, res) => {
  try {
    const { showOnFrontend } = req.body;
    if (typeof showOnFrontend !== 'boolean') {
      return res.status(400).json({ success: false, message: 'showOnFrontend must be a boolean' });
    }
    const complex = await sportsComplexService.toggleShowOnFrontend(req.params.id, showOnFrontend);
    if (!complex) return res.status(404).json({ success: false, message: 'Sports complex not found' });
    res.status(200).json({
      success: true,
      message: `Center ${showOnFrontend ? 'shown on' : 'hidden from'} frontend`,
      data: complex,
    });
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
};
