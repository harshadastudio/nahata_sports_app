const sportService = require('../services/sportService');
const { resolveComplexId, isComplexAdmin, stampComplexId, assertComplexAccess } = require('../middleware/complexScope');

// Get all sports with optional filters
exports.getAllSports = async (req, res) => {
  try {
    const { status, category, search, ground, showOnFrontend, sportComplexId, page = 1, limit = 100 } = req.query;

    // If ground parameter is provided, use the ground-based filtering
    if (ground) {
      const sports = await sportService.getSportsByGroundName(ground);
      return res.status(200).json({
        success: true,
        message: 'Sports retrieved successfully',
        data: sports,
      });
    }

    // Otherwise, use the standard filtering
    const filters = {};
    if (status) filters.status = status;
    if (category) filters.category = category;
    if (search) filters.search = search;
    if (sportComplexId) filters.sportComplexId = sportComplexId;
    if (showOnFrontend !== undefined) filters.showOnFrontend = showOnFrontend === 'true';

    // Per-complex admin scoping (null for super admin = all complexes; a complex
    // admin is forced to their own complex, overriding any ?sportComplexId).
    // Reuses the existing sportComplexId filter on the list service.
    const complexId = resolveComplexId(req);
    if (complexId != null) filters.sportComplexId = complexId;
    
    const result = await sportService.getAllSports(filters, parseInt(page), parseInt(limit));
    
    res.status(200).json({
      success: true,
      message: 'Sports retrieved successfully',
      data: result.sports,
      pagination: {
        currentPage: result.currentPage,
        totalPages: result.totalPages,
        totalItems: result.totalItems,
        itemsPerPage: result.itemsPerPage,
      },
    });
  } catch (error) {
    console.error('Error in getAllSports:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to retrieve sports',
      error: error.message,
    });
  }
};

// Get sport by ID with related data
exports.getSportById = async (req, res) => {
  try {
    const { id } = req.params;
    const { includeGrounds, includeBatches } = req.query;
    
    const sport = await sportService.getSportById(id, {
      includeGrounds: includeGrounds === 'true',
      includeBatches: includeBatches === 'true',
    });
    
    if (!sport) {
      return res.status(404).json({
        success: false,
        message: 'Sport not found',
      });
    }

    // Complex admins can only view sports in their own complex
    if (!assertComplexAccess(req, res, sport.sportComplexId)) return;

    res.status(200).json({
      success: true,
      message: 'Sport retrieved successfully',
      data: sport,
    });
  } catch (error) {
    console.error('Error in getSportById:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to retrieve sport',
      error: error.message,
    });
  }
};

// Create a new sport
exports.createSport = async (req, res) => {
  try {
    const sportData = req.body;
    
    // Validate required fields
    if (!sportData.name) {
      return res.status(400).json({
        success: false,
        message: 'Sport name is required',
      });
    }

    // Force the complex for a complex admin; honor explicit value for super admin
    stampComplexId(req, sportData);

    const newSport = await sportService.createSport(sportData);
    
    res.status(201).json({
      success: true,
      message: 'Sport created successfully',
      data: newSport,
    });
  } catch (error) {
    console.error('Error in createSport:', error);
    
    if (error.name === 'SequelizeUniqueConstraintError') {
      return res.status(400).json({
        success: false,
        message: 'A sport with this name already exists in this complex',
      });
    }
    
    res.status(500).json({
      success: false,
      message: 'Failed to create sport',
      error: error.message,
    });
  }
};

// Update sport
exports.updateSport = async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;

    // Complex admins may only edit sports in their own complex, and cannot move
    // a sport to a different complex.
    if (isComplexAdmin(req)) {
      const existing = await sportService.getSportById(id);
      if (!existing) {
        return res.status(404).json({ success: false, message: 'Sport not found' });
      }
      if (!assertComplexAccess(req, res, existing.sportComplexId)) return;
      stampComplexId(req, updateData);
    }

    const updatedSport = await sportService.updateSport(id, updateData);
    
    if (!updatedSport) {
      return res.status(404).json({
        success: false,
        message: 'Sport not found',
      });
    }
    
    res.status(200).json({
      success: true,
      message: 'Sport updated successfully',
      data: updatedSport,
    });
  } catch (error) {
    console.error('Error in updateSport:', error);
    
    if (error.name === 'SequelizeUniqueConstraintError') {
      return res.status(400).json({
        success: false,
        message: 'A sport with this name already exists in this complex',
      });
    }
    
    res.status(500).json({
      success: false,
      message: 'Failed to update sport',
      error: error.message,
    });
  }
};

// Update sport status
exports.updateSportStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    
    if (!status || !['Active', 'Inactive'].includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Valid status is required (Active or Inactive)',
      });
    }

    if (isComplexAdmin(req)) {
      const existing = await sportService.getSportById(id);
      if (!existing) {
        return res.status(404).json({ success: false, message: 'Sport not found' });
      }
      if (!assertComplexAccess(req, res, existing.sportComplexId)) return;
    }

    const updatedSport = await sportService.updateSportStatus(id, status);
    
    if (!updatedSport) {
      return res.status(404).json({
        success: false,
        message: 'Sport not found',
      });
    }
    
    res.status(200).json({
      success: true,
      message: `Sport status updated to ${status}`,
      data: updatedSport,
    });
  } catch (error) {
    console.error('Error in updateSportStatus:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update sport status',
      error: error.message,
    });
  }
};

// Delete sport
exports.deleteSport = async (req, res) => {
  try {
    const { id } = req.params;

    if (isComplexAdmin(req)) {
      const existing = await sportService.getSportById(id);
      if (!existing) {
        return res.status(404).json({ success: false, message: 'Sport not found' });
      }
      if (!assertComplexAccess(req, res, existing.sportComplexId)) return;
    }

    const deleted = await sportService.deleteSport(id);
    
    if (!deleted) {
      return res.status(404).json({
        success: false,
        message: 'Sport not found',
      });
    }
    
    res.status(200).json({
      success: true,
      message: 'Sport deleted successfully',
    });
  } catch (error) {
    console.error('Error in deleteSport:', error);
    
    if (error.message.includes('associated')) {
      return res.status(400).json({
        success: false,
        message: 'Cannot delete sport with associated batches or bookings',
      });
    }
    
    res.status(500).json({
      success: false,
      message: 'Failed to delete sport',
      error: error.message,
    });
  }
};

// Assign sport to ground/sport complex
exports.assignSportToGround = async (req, res) => {
  try {
    const { sportId } = req.params;
    const { sportComplexId, courtName, courtType, pricePerHour } = req.body;
    
    if (!sportComplexId) {
      return res.status(400).json({
        success: false,
        message: 'Sport complex ID is required',
      });
    }
    
    const court = await sportService.assignSportToGround({
      sportId,
      sportComplexId,
      courtName,
      courtType,
      pricePerHour,
    });
    
    res.status(201).json({
      success: true,
      message: 'Sport assigned to ground successfully',
      data: court,
    });
  } catch (error) {
    console.error('Error in assignSportToGround:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to assign sport to ground',
      error: error.message,
    });
  }
};

// Get sports by ground/sport complex
exports.getSportsByGround = async (req, res) => {
  try {
    const { sportComplexId } = req.params;
    
    const sports = await sportService.getSportsByGround(sportComplexId);
    
    res.status(200).json({
      success: true,
      message: 'Sports retrieved successfully',
      data: sports,
    });
  } catch (error) {
    console.error('Error in getSportsByGround:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to retrieve sports',
      error: error.message,
    });
  }
};

// Get sport statistics
exports.getSportStats = async (req, res) => {
  try {
    const { id } = req.params;
    
    const stats = await sportService.getSportStats(id);
    
    res.status(200).json({
      success: true,
      message: 'Sport statistics retrieved successfully',
      data: stats,
    });
  } catch (error) {
    console.error('Error in getSportStats:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to retrieve sport statistics',
      error: error.message,
    });
  }
};

// Get all sports with their programs/batches (for frontend coaching page)
exports.getSportsWithPrograms = async (req, res) => {
  try {
    const { status = 'Active' } = req.query;
    
    const sportsWithPrograms = await sportService.getSportsWithPrograms(status);
    
    res.status(200).json({
      success: true,
      message: 'Sports with programs retrieved successfully',
      data: sportsWithPrograms,
    });
  } catch (error) {
    console.error('Error in getSportsWithPrograms:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to retrieve sports with programs',
      error: error.message,
    });
  }
};


// ── Toggle showOnFrontend ─────────────────────────────────────────────────────

exports.toggleShowOnFrontend = async (req, res) => {
  try {
    const { showOnFrontend } = req.body;
    if (typeof showOnFrontend !== 'boolean') {
      return res.status(400).json({ success: false, message: 'showOnFrontend must be a boolean' });
    }
    if (isComplexAdmin(req)) {
      const existing = await sportService.getSportById(req.params.id);
      if (!existing) {
        return res.status(404).json({ success: false, message: 'Sport not found' });
      }
      if (!assertComplexAccess(req, res, existing.sportComplexId)) return;
    }
    const sport = await sportService.toggleShowOnFrontend(req.params.id, showOnFrontend);
    if (!sport) return res.status(404).json({ success: false, message: 'Sport not found' });
    res.status(200).json({
      success: true,
      message: `Sport ${showOnFrontend ? 'shown on' : 'hidden from'} frontend`,
      data: sport,
    });
  } catch (err) {
    res.status(500).json({ success: false, message: err.message });
  }
};
