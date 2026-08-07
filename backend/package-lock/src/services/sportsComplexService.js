const { SportComplex, Court, User } = require('../models');
const { Op } = require('sequelize');

// Get all sports complexes with filters and pagination
exports.getAllSportsComplexes = async (filters, page = 1, limit = 10) => {
  try {
    const where = {};
    
    // Apply filters
    if (filters.status) {
      where.status = filters.status;
    }
    
    if (filters.city) {
      where.city = { [Op.like]: `%${filters.city}%` };
    }
    
    if (filters.state) {
      where.state = { [Op.like]: `%${filters.state}%` };
    }
    
    if (filters.search) {
      where[Op.or] = [
        { name: { [Op.like]: `%${filters.search}%` } },
        { city: { [Op.like]: `%${filters.search}%` } },
        { address: { [Op.like]: `%${filters.search}%` } },
      ];
    }
    
    if (filters.showOnFrontend !== undefined) {
      where.showOnFrontend = filters.showOnFrontend;
    }
    
    const offset = (page - 1) * limit;
    
    const { count, rows } = await SportComplex.findAndCountAll({
      where,
      limit,
      offset,
      order: [['createdAt', 'ASC']],
    });
    
    return {
      sportsComplexes: rows,
      currentPage: page,
      totalPages: Math.ceil(count / limit),
      totalItems: count,
      itemsPerPage: limit,
    };
  } catch (error) {
    throw error;
  }
};

// Get sports complex by ID
exports.getSportsComplexById = async (complexId, options = {}) => {
  try {
    const include = [
      {
        model: User,
        as: 'User',
        attributes: ['id', 'name', 'email', 'phone_number'],
        required: false,
      },
    ];
    
    if (options.includeCourts) {
      include.push({
        model: Court,
        as: 'Courts',
        attributes: ['id', 'name', 'sportId', 'type', 'status'],
      });
    }
    
    const complex = await SportComplex.findByPk(complexId, {
      include,
    });
    
    return complex;
  } catch (error) {
    throw error;
  }
};

// Create a new sports complex
exports.createSportsComplex = async (complexData) => {
  try {
    // Verify manager exists if provided
    if (complexData.managerId) {
      const manager = await User.findByPk(complexData.managerId);
      if (!manager) {
        throw new Error('Manager not found');
      }
    }
    
    const newComplex = await SportComplex.create({
      name: complexData.name,
      address: complexData.address,
      city: complexData.city,
      state: complexData.state,
      zipCode: complexData.zipCode,
      contactPhone: complexData.contactPhone,
      contactEmail: complexData.contactEmail,
      managerId: complexData.managerId,
      facilities: complexData.facilities,
      openingHours: complexData.openingHours,
      status: complexData.status || 'Active',
      latitude: complexData.latitude,
      longitude: complexData.longitude,
      image: complexData.image || null,
      sportsOffered: complexData.sportsOffered || null,
      mapUrl: complexData.mapUrl || null,
      showOnFrontend: complexData.showOnFrontend ?? false,
    });
    
    // Fetch with relations
    return await SportComplex.findByPk(newComplex.id, {
      include: [
        {
          model: User,
          as: 'User',
          attributes: ['id', 'name', 'email'],
          required: false,
        },
      ],
    });
  } catch (error) {
    throw error;
  }
};

// Update sports complex
exports.updateSportsComplex = async (complexId, updateData) => {
  try {
    const complex = await SportComplex.findByPk(complexId);
    
    if (!complex) {
      return null;
    }
    
    // Verify manager exists if updating managerId
    if (updateData.managerId) {
      const manager = await User.findByPk(updateData.managerId);
      if (!manager) {
        throw new Error('Manager not found');
      }
    }
    
    await complex.update(updateData);
    
    // Fetch with relations
    return await SportComplex.findByPk(complexId, {
      include: [
        {
          model: User,
          as: 'User',
          attributes: ['id', 'name', 'email'],
          required: false,
        },
      ],
    });
  } catch (error) {
    throw error;
  }
};

// Update sports complex status
exports.updateSportsComplexStatus = async (complexId, status) => {
  try {
    const complex = await SportComplex.findByPk(complexId);
    
    if (!complex) {
      return null;
    }
    
    await complex.update({ status });
    
    return complex;
  } catch (error) {
    throw error;
  }
};

// Delete sports complex
exports.deleteSportsComplex = async (complexId) => {
  try {
    const complex = await SportComplex.findByPk(complexId);
    
    if (!complex) {
      return false;
    }
    
    // Check if complex has courts
    const courtCount = await Court.count({ where: { sportComplexId: complexId } });
    
    if (courtCount > 0) {
      throw new Error('Cannot delete sports complex with existing courts');
    }
    
    await complex.destroy();
    
    return true;
  } catch (error) {
    throw error;
  }
};

// Get sports complexes by city
exports.getSportsComplexesByCity = async (city) => {
  try {
    const complexes = await SportComplex.findAll({
      where: { 
        city: { [Op.like]: `%${city}%` },
        status: 'Active'
      },
      include: [
        {
          model: User,
          as: 'User',
          attributes: ['id', 'name'],
          required: false,
        },
      ],
      order: [['name', 'ASC']],
    });
    
    return complexes;
  } catch (error) {
    throw error;
  }
};

// Get sports complexes by state
exports.getSportsComplexesByState = async (state) => {
  try {
    const complexes = await SportComplex.findAll({
      where: { 
        state: { [Op.like]: `%${state}%` },
        status: 'Active'
      },
      include: [
        {
          model: User,
          as: 'User',
          attributes: ['id', 'name'],
          required: false,
        },
      ],
      order: [['city', 'ASC'], ['name', 'ASC']],
    });
    
    return complexes;
  } catch (error) {
    throw error;
  }
};

// Get sports complex statistics
exports.getSportsComplexStats = async (complexId) => {
  try {
    const complex = await SportComplex.findByPk(complexId, {
      include: [
        {
          model: User,
          as: 'User',
          attributes: ['id', 'name'],
          required: false,
        },
      ],
    });
    
    if (!complex) {
      throw new Error('Sports complex not found');
    }
    
    // Get court count
    const courtCount = await Court.count({ where: { sportComplexId: complexId } });
    
    // Get active courts count
    const activeCourts = await Court.count({ 
      where: { 
        sportComplexId: complexId,
        status: 'Active'
      }
    });
    
    return {
      complexId: complex.id,
      complexName: complex.name,
      city: complex.city,
      state: complex.state,
      manager: complex.User ? `${complex.User.name}` : 'Not Assigned',
      totalCourts: courtCount,
      activeCourts,
      status: complex.status,
      contactPhone: complex.contactPhone,
      contactEmail: complex.contactEmail,
    };
  } catch (error) {
    throw error;
  }
};


// Toggle showOnFrontend
exports.toggleShowOnFrontend = async (complexId, showOnFrontend) => {
  const complex = await SportComplex.findByPk(complexId);
  if (!complex) return null;
  await complex.update({ showOnFrontend });
  return complex.reload();
};
