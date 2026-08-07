const { Batch, Sport, Coach, Student, Court } = require('../models');
const { Op } = require('sequelize');

// Get all batches with filters and pagination
exports.getAllBatches = async (filters, page = 1, limit = 10) => {
  try {
    const where = {};
    
    // Apply filters
    if (filters.status) {
      where.status = filters.status;
    }
    
    if (filters.sportId) {
      where.sportId = filters.sportId;
    }
    
    if (filters.coachId) {
      where.coachId = filters.coachId;
    }

    // Per-complex admin scoping (no-op when not provided)
    if (filters.sportComplexId != null) {
      where.sportComplexId = filters.sportComplexId;
    }

    if (filters.search) {
      where[Op.or] = [
        { name: { [Op.like]: `%${filters.search}%` } },
      ];
    }
    
    const offset = (page - 1) * limit;
    
    const { count, rows } = await Batch.findAndCountAll({
      where,
      limit,
      offset,
      include: [
        {
          model: Sport,
          as: 'sport',
          attributes: ['id', 'name', 'category', 'image'],
          required: false,
        },
        {
          model: Coach,
          as: 'coach',
          attributes: ['id', 'name', 'email', 'phone'],
          required: false,
        },
      ],
      order: [['createdAt', 'DESC']],
    });
    
    return {
      batches: rows,
      currentPage: page,
      totalPages: Math.ceil(count / limit),
      totalItems: count,
      itemsPerPage: limit,
    };
  } catch (error) {
    throw error;
  }
};

// Get batch by ID
exports.getBatchById = async (batchId, options = {}) => {
  try {
    const include = [
      {
        model: Sport,
        as: 'sport',
        attributes: ['id', 'name', 'category', 'image'],
      },
      {
        model: Coach,
        as: 'coach',
        attributes: ['id', 'name', 'email', 'phone', 'experience'],
      },
    ];
    
    if (options.includeStudents) {
      include.push({
        model: Student,
        as: 'students',
        attributes: ['id', 'firstName', 'lastName', 'dateOfBirth', 'gender'],
        through: {
          attributes: ['enrollmentDate', 'status'],
        },
      });
    }
    
    const batch = await Batch.findByPk(batchId, {
      include,
    });
    
    return batch;
  } catch (error) {
    throw error;
  }
};

// Create a new batch
exports.createBatch = async (batchData) => {
  try {
    // Verify sport exists
    const sport = await Sport.findByPk(batchData.sportId);
    if (!sport) {
      throw new Error('Sport not found');
    }
    
    // Verify coach exists if provided
    if (batchData.coachId) {
      const coach = await Coach.findByPk(batchData.coachId);
      if (!coach) {
        throw new Error('Coach not found');
      }
    }
    
    const newBatch = await Batch.create({
      name: batchData.name,
      sportId: batchData.sportId,
      coachId: batchData.coachId,
      sportComplexId: batchData.sportComplexId, // Per-complex admin scoping
      schedule: batchData.schedule,
      days: batchData.days,
      startDate: batchData.startDate,
      endDate: batchData.endDate,
      maxStudents: batchData.maxStudents || 20,
      currentStudents: batchData.currentStudents || 0,
      status: batchData.status || 'Active',
      fees: batchData.fees,
      ageGroup: batchData.ageGroup,
    });
    
    // Fetch with relations
    return await Batch.findByPk(newBatch.id, {
      include: [
        {
          model: Sport,
          as: 'sport',
          attributes: ['id', 'name', 'category'],
        },
        {
          model: Coach,
          as: 'coach',
          attributes: ['id', 'name', 'email'],
        },
      ],
    });
  } catch (error) {
    throw error;
  }
};

// Update batch
exports.updateBatch = async (batchId, updateData) => {
  try {
    const batch = await Batch.findByPk(batchId);
    
    if (!batch) {
      return null;
    }
    
    // Verify coach exists if updating coachId
    if (updateData.coachId) {
      const coach = await Coach.findByPk(updateData.coachId);
      if (!coach) {
        throw new Error('Coach not found');
      }
    }
    
    await batch.update(updateData);
    
    // Fetch with relations
    return await Batch.findByPk(batchId, {
      include: [
        {
          model: Sport,
          as: 'sport',
          attributes: ['id', 'name', 'category'],
        },
        {
          model: Coach,
          as: 'coach',
          attributes: ['id', 'name', 'email'],
        },
      ],
    });
  } catch (error) {
    throw error;
  }
};

// Update batch status
exports.updateBatchStatus = async (batchId, status) => {
  try {
    const batch = await Batch.findByPk(batchId);
    
    if (!batch) {
      return null;
    }
    
    await batch.update({ status });
    
    return batch;
  } catch (error) {
    throw error;
  }
};

// Delete batch
exports.deleteBatch = async (batchId) => {
  try {
    const batch = await Batch.findByPk(batchId);
    
    if (!batch) {
      return false;
    }
    
    // Check if batch has students
    const studentCount = await batch.countStudents();
    
    if (studentCount > 0) {
      throw new Error('Cannot delete batch with enrolled students');
    }
    
    await batch.destroy();
    
    return true;
  } catch (error) {
    throw error;
  }
};

// Get batches by sport
exports.getBatchesBySport = async (sportId, ground) => {
  try {
    // A batch's ground is derived from its coach's ground. When a ground filter is
    // provided, only return batches whose coach belongs to that ground.
    const coachInclude = {
      model: Coach,
      as: 'coach',
      attributes: ['id', 'name', 'ground'],
    };
    if (ground) {
      coachInclude.where = { ground: { [Op.like]: `%${ground}%` } };
      coachInclude.required = true; // inner join: drop batches whose coach isn't at this ground
    }

    const batches = await Batch.findAll({
      where: {
        sportId,
        status: 'Active'
      },
      include: [
        {
          model: Sport,
          as: 'sport',
          attributes: ['id', 'name', 'category'],
        },
        coachInclude,
      ],
      order: [['startDate', 'ASC']],
    });

    return batches;
  } catch (error) {
    throw error;
  }
};

// Get batches by coach
exports.getBatchesByCoach = async (coachId) => {
  try {
    const batches = await Batch.findAll({
      where: { 
        coachId,
        status: 'Active'
      },
      include: [
        {
          model: Sport,
          as: 'sport',
          attributes: ['id', 'name', 'category'],
        },
      ],
      order: [['startDate', 'ASC']],
    });
    
    return batches;
  } catch (error) {
    throw error;
  }
};

// Get batch statistics
exports.getBatchStats = async (batchId) => {
  try {
    const batch = await Batch.findByPk(batchId, {
      include: [
        {
          model: Sport,
          as: 'sport',
          attributes: ['id', 'name'],
        },
        {
          model: Coach,
          as: 'coach',
          attributes: ['id', 'name'],
        },
      ],
    });
    
    if (!batch) {
      throw new Error('Batch not found');
    }
    
    // Get student count
    const studentCount = await batch.countStudents();
    
    // Calculate occupancy percentage
    const occupancyPercentage = batch.maxStudents > 0 
      ? Math.round((batch.currentStudents / batch.maxStudents) * 100)
      : 0;
    
    // Calculate available slots
    const availableSlots = Math.max(0, batch.maxStudents - batch.currentStudents);
    
    return {
      batchId: batch.id,
      batchName: batch.name,
      sport: batch.sport?.name,
      coach: batch.coach?.name,
      maxStudents: batch.maxStudents,
      currentStudents: batch.currentStudents,
      enrolledStudents: studentCount,
      availableSlots,
      occupancyPercentage,
      status: batch.status,
      fees: batch.fees,
      startDate: batch.startDate,
      endDate: batch.endDate,
    };
  } catch (error) {
    throw error;
  }
};
