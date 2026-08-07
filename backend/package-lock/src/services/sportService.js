const { Sport, SportComplex, Court, Batch, User } = require('../models');
const { Op } = require('sequelize');

// Get all sports with filters and pagination
exports.getAllSports = async (filters, page = 1, limit = 10) => {
  try {
    const where = {};
    
    // Apply filters
    if (filters.status) {
      where.status = filters.status;
    }
    
    if (filters.category) {
      where.category = filters.category;
    }

    if (filters.sportComplexId) {
      where.sportComplexId = filters.sportComplexId;
    }

    if (filters.showOnFrontend !== undefined) {
      where.showOnFrontend = filters.showOnFrontend;
    }
    
    if (filters.search) {
      where[Op.or] = [
        { name: { [Op.like]: `%${filters.search}%` } },
        { description: { [Op.like]: `%${filters.search}%` } },
      ];
    }
    
    const offset = (page - 1) * limit;
    
    const { count, rows } = await Sport.findAndCountAll({
      where,
      limit,
      offset,
      order: [['name', 'ASC']],
      attributes: {
        exclude: ['createdAt', 'updatedAt'],
      },
      include: [
        {
          model: Batch,
          as: 'Batches',
          attributes: ['id', 'name', 'status'],
          where: { status: 'Active' },
          required: false, // LEFT JOIN to include sports without batches
        },
        {
          model: Court,
          attributes: ['id', 'status'],
          required: false, // LEFT JOIN to include sports without courts
        },
        {
          model: SportComplex,
          attributes: ['id', 'name'],
          required: false, // LEFT JOIN to include sports without a complex
        },
      ],
    });

    // Format the response to include batch names and court counts
    // (kept under the legacy programCount/programNames keys for UI compatibility)
    const formattedRows = rows.map(sport => {
      const sportData = sport.toJSON();
      const courts = sportData.Courts || [];
      const batches = sportData.Batches || [];
      return {
        ...sportData,
        programCount: batches.length,
        programNames: batches.map(b => b.name).join(', '),
        courtCount: courts.length,
        availableCourts: courts.filter(c => c.status === 'Active').length,
      };
    });
    
    return {
      sports: formattedRows,
      currentPage: page,
      totalPages: Math.ceil(count / limit),
      totalItems: count,
      itemsPerPage: limit,
    };
  } catch (error) {
    throw error;
  }
};

// Get sport by ID with optional related data
exports.getSportById = async (sportId, options = {}) => {
  try {
    const include = [];
    
    if (options.includeGrounds) {
      include.push({
        model: Court,
        include: [
          {
            model: SportComplex,
            attributes: ['id', 'name', 'address', 'city', 'contactPhone'],
          },
        ],
      });
    }
    
    if (options.includeBatches) {
      include.push({
        model: Batch,
        where: { status: 'Active' },
        required: false,
        include: [
          {
            model: User,
            as: 'BatchCoaches',
            attributes: ['id', 'firstName', 'lastName', 'email'],
            through: { attributes: [] },
          },
        ],
      });
    }
    
    const sport = await Sport.findByPk(sportId, {
      include: include.length > 0 ? include : undefined,
    });
    
    return sport;
  } catch (error) {
    throw error;
  }
};

// Create a new sport
exports.createSport = async (sportData) => {
  try {
    const newSport = await Sport.create({
      name: sportData.name,
      sportComplexId: sportData.sportComplexId || null,
      description: sportData.description,
      category: sportData.category || 'Outdoor',
      minAge: sportData.minAge,
      maxAge: sportData.maxAge,
      duration: sportData.duration,
      equipmentRequired: sportData.equipmentRequired,
      image: sportData.image,
      allowedMembers: sportData.allowedMembers || 0,
      achievements: sportData.achievements,
      completeInformation: sportData.completeInformation,
      status: sportData.status || 'Active',
      showOnFrontend: sportData.showOnFrontend !== undefined ? sportData.showOnFrontend : true,
    });
    
    return newSport;
  } catch (error) {
    throw error;
  }
};

// Update sport
exports.updateSport = async (sportId, updateData) => {
  try {
    const sport = await Sport.findByPk(sportId);
    
    if (!sport) {
      return null;
    }
    
    await sport.update(updateData);
    
    return sport;
  } catch (error) {
    throw error;
  }
};

// Update sport status
exports.updateSportStatus = async (sportId, status) => {
  try {
    const sport = await Sport.findByPk(sportId);
    
    if (!sport) {
      return null;
    }
    
    await sport.update({ status });
    
    return sport;
  } catch (error) {
    throw error;
  }
};

// Delete sport
exports.deleteSport = async (sportId) => {
  try {
    const sport = await Sport.findByPk(sportId);
    
    if (!sport) {
      return false;
    }
    
    // Check if sport has associated batches or bookings
    const batchCount = await Batch.count({ where: { sportId } });
    
    if (batchCount > 0) {
      throw new Error('Cannot delete sport with associated batches');
    }
    
    await sport.destroy();
    
    return true;
  } catch (error) {
    throw error;
  }
};

// Assign sport to ground (create court)
exports.assignSportToGround = async (data) => {
  try {
    const { sportId, sportComplexId, courtName, courtType, pricePerHour } = data;
    
    // Verify sport and sport complex exist
    const sport = await Sport.findByPk(sportId);
    const sportComplex = await SportComplex.findByPk(sportComplexId);
    
    if (!sport) {
      throw new Error('Sport not found');
    }
    
    if (!sportComplex) {
      throw new Error('Sport complex not found');
    }
    
    // Create court linking sport to ground
    const court = await Court.create({
      name: courtName || `${sport.name} Court`,
      sportId,
      sportComplexId,
      courtType: courtType || 'Standard',
      pricePerHour: pricePerHour || 0,
      status: 'Active',
    });
    
    return court;
  } catch (error) {
    throw error;
  }
};

// Get sports by ground/sport complex
exports.getSportsByGround = async (sportComplexId) => {
  try {
    const courts = await Court.findAll({
      where: { sportComplexId },
      include: [
        {
          model: Sport,
          attributes: ['id', 'name', 'description', 'category', 'image', 'status'],
        },
      ],
      attributes: ['id', 'name', 'courtType', 'pricePerHour', 'status'],
    });
    
    // Group by sport
    const sportsMap = new Map();
    
    courts.forEach((court) => {
      const sport = court.Sport;
      if (!sportsMap.has(sport.id)) {
        sportsMap.set(sport.id, {
          ...sport.toJSON(),
          courts: [],
        });
      }
      
      sportsMap.get(sport.id).courts.push({
        id: court.id,
        name: court.name,
        courtType: court.courtType,
        pricePerHour: court.pricePerHour,
        status: court.status,
      });
    });
    
    return Array.from(sportsMap.values());
  } catch (error) {
    throw error;
  }
};

// Get sport statistics
exports.getSportStats = async (sportId) => {
  try {
    const sport = await Sport.findByPk(sportId);
    
    if (!sport) {
      throw new Error('Sport not found');
    }
    
    // Get counts
    const totalBatches = await Batch.count({ where: { sportId } });
    const activeBatches = await Batch.count({ 
      where: { sportId, status: 'Active' } 
    });
    
    const totalCourts = await Court.count({ where: { sportId } });
    
    // Get total students enrolled
    const batches = await Batch.findAll({
      where: { sportId },
      attributes: ['currentStudents'],
    });
    
    const totalStudents = batches.reduce((sum, batch) => sum + (batch.currentStudents || 0), 0);
    
    return {
      sportId: sport.id,
      sportName: sport.name,
      totalBatches,
      activeBatches,
      totalCourts,
      totalStudents,
      status: sport.status,
    };
  } catch (error) {
    throw error;
  }
};

// Get all sports with their programs/batches (for frontend)
exports.getSportsWithPrograms = async (status = 'Active') => {
  try {
    const sports = await Sport.findAll({
      where: { status },
      include: [
        {
          model: Batch,
          where: { status: 'Active' },
          required: false,
          attributes: [
            'id',
            'name',
            'schedule',
            'days',
            'startDate',
            'endDate',
            'maxStudents',
            'currentStudents',
            'fees',
            'status',
          ],
          include: [
            {
              model: User,
              as: 'BatchCoaches',
              attributes: ['id', 'firstName', 'lastName', 'email', 'phone'],
              through: { attributes: [] },
            },
          ],
        },
      ],
      order: [
        ['name', 'ASC'],
        [Batch, 'startDate', 'ASC'],
      ],
    });
    
    // Format response for frontend
    return sports.map((sport) => ({
      id: sport.id,
      name: sport.name,
      description: sport.description,
      category: sport.category,
      image: sport.image,
      minAge: sport.minAge,
      maxAge: sport.maxAge,
      equipmentRequired: sport.equipmentRequired,
      programCount: sport.Batches ? sport.Batches.length : 0,
      programs: sport.Batches || [],
    }));
  } catch (error) {
    throw error;
  }
};

// Get sports available at a specific ground (based on coaches)
exports.getSportsByGroundName = async (groundName) => {
  try {
    const { Coach } = require('../models');
    const { sequelize } = require('../models');
    
    // Extract the first word from ground name for partial matching
    // e.g., "Sinhagad Road Complex" → "Sinhagad"
    const groundKeyword = groundName.split(' ')[0];
    
    // Find all sports that have at least one active coach at this ground
    const sports = await Sport.findAll({
      where: { status: 'Active' },
      include: [
        {
          model: Coach,
          as: 'coaches',
          where: { 
            ground: {
              [Op.iLike]: `%${groundKeyword}%` // Partial match, case-insensitive
            },
            status: 'Active'
          },
          through: { attributes: [] },
          required: true, // INNER JOIN - only sports with coaches at this ground
          attributes: [] // Don't include coach data in response
        }
      ],
      attributes: [
        'id', 
        'name', 
        'category', 
        'image', 
        'description', 
        'minAge', 
        'maxAge', 
        'status',
        [sequelize.fn('COUNT', sequelize.fn('DISTINCT', sequelize.col('coaches.id'))), 'coachCount']
      ],
      group: ['Sport.id', 'Sport.name', 'Sport.category', 'Sport.image', 'Sport.description', 'Sport.minAge', 'Sport.maxAge', 'Sport.status'],
      order: [['name', 'ASC']],
      raw: false,
      subQuery: false
    });
    
    return sports;
  } catch (error) {
    console.error('Error in getSportsByGroundName:', error);
    throw error;
  }
};


// ── Toggle showOnFrontend ─────────────────────────────────────────────────────

exports.toggleShowOnFrontend = async (sportId, showOnFrontend) => {
  const sport = await Sport.findByPk(sportId);
  if (!sport) return null;
  await sport.update({ showOnFrontend });
  return sport.reload();
};
