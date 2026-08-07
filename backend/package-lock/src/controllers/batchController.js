const batchService = require('../services/batchService');
const { resolveComplexId, isComplexAdmin, stampComplexId, assertComplexAccess } = require('../middleware/complexScope');

// Get all batches
exports.getAllBatches = async (req, res) => {
  try {
    const { status, sportId, coachId, search, page = 1, limit = 10 } = req.query;

    const filters = {};
    if (status) filters.status = status;
    if (sportId) filters.sportId = sportId;
    if (coachId) filters.coachId = coachId;
    if (search) filters.search = search;

    // Per-complex admin scoping (null for super admin = all complexes)
    const complexId = resolveComplexId(req);
    if (complexId != null) filters.sportComplexId = complexId;

    const result = await batchService.getAllBatches(
      filters,
      parseInt(page),
      parseInt(limit)
    );
    
    res.status(200).json({
      success: true,
      message: 'Batches retrieved successfully',
      data: result,
    });
  } catch (error) {
    console.error('Error fetching batches:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch batches',
      error: error.message,
    });
  }
};

// Get batch by ID
exports.getBatchById = async (req, res) => {
  try {
    const { id } = req.params;
    const { includeStudents } = req.query;
    
    const batch = await batchService.getBatchById(id, {
      includeStudents: includeStudents === 'true',
    });
    
    if (!batch) {
      return res.status(404).json({
        success: false,
        message: 'Batch not found',
      });
    }

    // Complex admins can only view batches in their own complex
    if (!assertComplexAccess(req, res, batch.sportComplexId)) return;

    res.status(200).json({
      success: true,
      data: batch,
    });
  } catch (error) {
    console.error('Error fetching batch:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch batch',
      error: error.message,
    });
  }
};

// Create a new batch
exports.createBatch = async (req, res) => {
  try {
    const batchData = req.body;
    
    // Validate required fields
    if (!batchData.name) {
      return res.status(400).json({
        success: false,
        message: 'Batch name is required',
      });
    }
    
    if (!batchData.sportId) {
      return res.status(400).json({
        success: false,
        message: 'Sport is required',
      });
    }
    
    if (!batchData.startDate) {
      return res.status(400).json({
        success: false,
        message: 'Start date is required',
      });
    }
    
    if (!batchData.fees) {
      return res.status(400).json({
        success: false,
        message: 'Fees is required',
      });
    }

    // Force the complex for a complex admin; honor explicit value for super admin
    stampComplexId(req, batchData);

    const newBatch = await batchService.createBatch(batchData);
    
    res.status(201).json({
      success: true,
      message: 'Batch created successfully',
      data: newBatch,
    });
  } catch (error) {
    console.error('Error creating batch:', error);
    
    if (error.message.includes('not found')) {
      return res.status(404).json({
        success: false,
        message: error.message,
      });
    }
    
    res.status(500).json({
      success: false,
      message: 'Failed to create batch',
      error: error.message,
    });
  }
};

// Update batch
exports.updateBatch = async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;

    // Complex admins may only edit batches in their own complex, and cannot move
    // a batch to a different complex.
    if (isComplexAdmin(req)) {
      const existing = await batchService.getBatchById(id);
      if (!existing) {
        return res.status(404).json({ success: false, message: 'Batch not found' });
      }
      if (!assertComplexAccess(req, res, existing.sportComplexId)) return;
      stampComplexId(req, updateData);
    }

    const updatedBatch = await batchService.updateBatch(id, updateData);
    
    if (!updatedBatch) {
      return res.status(404).json({
        success: false,
        message: 'Batch not found',
      });
    }
    
    res.status(200).json({
      success: true,
      message: 'Batch updated successfully',
      data: updatedBatch,
    });
  } catch (error) {
    console.error('Error updating batch:', error);
    
    if (error.message.includes('not found')) {
      return res.status(404).json({
        success: false,
        message: error.message,
      });
    }
    
    res.status(500).json({
      success: false,
      message: 'Failed to update batch',
      error: error.message,
    });
  }
};

// Update batch status
exports.updateBatchStatus = async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body;
    
    if (!status || !['Active', 'Completed', 'Cancelled'].includes(status)) {
      return res.status(400).json({
        success: false,
        message: 'Valid status is required (Active, Completed, or Cancelled)',
      });
    }

    if (isComplexAdmin(req)) {
      const existing = await batchService.getBatchById(id);
      if (!existing) {
        return res.status(404).json({ success: false, message: 'Batch not found' });
      }
      if (!assertComplexAccess(req, res, existing.sportComplexId)) return;
    }

    const updatedBatch = await batchService.updateBatchStatus(id, status);
    
    if (!updatedBatch) {
      return res.status(404).json({
        success: false,
        message: 'Batch not found',
      });
    }
    
    res.status(200).json({
      success: true,
      message: 'Batch status updated successfully',
      data: updatedBatch,
    });
  } catch (error) {
    console.error('Error updating batch status:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to update batch status',
      error: error.message,
    });
  }
};

// Delete batch
exports.deleteBatch = async (req, res) => {
  try {
    const { id } = req.params;

    if (isComplexAdmin(req)) {
      const existing = await batchService.getBatchById(id);
      if (!existing) {
        return res.status(404).json({ success: false, message: 'Batch not found' });
      }
      if (!assertComplexAccess(req, res, existing.sportComplexId)) return;
    }

    const deleted = await batchService.deleteBatch(id);
    
    if (!deleted) {
      return res.status(404).json({
        success: false,
        message: 'Batch not found',
      });
    }
    
    res.status(200).json({
      success: true,
      message: 'Batch deleted successfully',
    });
  } catch (error) {
    console.error('Error deleting batch:', error);
    
    if (error.message.includes('enrolled students')) {
      return res.status(400).json({
        success: false,
        message: error.message,
      });
    }
    
    res.status(500).json({
      success: false,
      message: 'Failed to delete batch',
      error: error.message,
    });
  }
};

// Get batches by sport
exports.getBatchesBySport = async (req, res) => {
  try {
    const { sportId } = req.params;
    const { ground } = req.query;

    const batches = await batchService.getBatchesBySport(sportId, ground);
    
    res.status(200).json({
      success: true,
      data: batches,
    });
  } catch (error) {
    console.error('Error fetching batches by sport:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch batches',
      error: error.message,
    });
  }
};

// Get batches by coach
exports.getBatchesByCoach = async (req, res) => {
  try {
    const { coachId } = req.params;
    
    const batches = await batchService.getBatchesByCoach(coachId);
    
    res.status(200).json({
      success: true,
      data: batches,
    });
  } catch (error) {
    console.error('Error fetching batches by coach:', error);
    res.status(500).json({
      success: false,
      message: 'Failed to fetch batches',
      error: error.message,
    });
  }
};

// Get batch statistics
exports.getBatchStats = async (req, res) => {
  try {
    const { id } = req.params;
    
    const stats = await batchService.getBatchStats(id);
    
    res.status(200).json({
      success: true,
      data: stats,
    });
  } catch (error) {
    console.error('Error fetching batch stats:', error);
    
    if (error.message === 'Batch not found') {
      return res.status(404).json({
        success: false,
        message: error.message,
      });
    }
    
    res.status(500).json({
      success: false,
      message: 'Failed to fetch batch statistics',
      error: error.message,
    });
  }
};
