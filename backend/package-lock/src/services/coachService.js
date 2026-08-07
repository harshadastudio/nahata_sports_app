const { Coach, Sport, Batch, CoachSport, User } = require('../models');
const { demoteStaffUserToUser } = require('../utils/staffAccount');
const { Op } = require('sequelize');
const { getDefaultPermissions } = require('../config/rolePermissions');
const { encryptSecret } = require('../utils/secretCrypto');

// Get all coaches with filters and pagination
exports.getAllCoaches = async (filters, page = 1, limit = 10) => {
  try {
    const where = {};
    
    // Apply filters
    if (filters.status) {
      where.status = filters.status;
    }

    // Per-complex admin scoping (no-op when not provided)
    if (filters.sportComplexId != null) {
      where.sportComplexId = filters.sportComplexId;
    }

    // For sportId filter, we need to join through CoachSports
    let sportFilter = null;
    if (filters.sportId) {
      sportFilter = {
        model: Sport,
        as: 'sports',
        where: { id: filters.sportId },
        through: { attributes: [] },
        required: true,
      };
    }
    
    if (filters.ground) {
      where.ground = { [Op.like]: `%${filters.ground}%` };
    }
    
    if (filters.search) {
      where[Op.or] = [
        { name: { [Op.like]: `%${filters.search}%` } },
        { email: { [Op.like]: `%${filters.search}%` } },
      ];
    }
    
    const offset = (page - 1) * limit;
    
    const include = [
      {
        model: Sport,
        as: 'sport',
        attributes: ['id', 'name', 'category', 'image'],
        required: false,
      },
      {
        model: Sport,
        as: 'sports',
        attributes: ['id', 'name', 'category', 'image'],
        through: { 
          attributes: ['isPrimary'],
          as: 'coachSportInfo'
        },
        required: false,
      },
    ];
    
    // If filtering by sport, replace the sports include with the filter
    if (sportFilter) {
      include[1] = sportFilter;
    }
    
    const { count, rows } = await Coach.findAndCountAll({
      where,
      limit,
      offset,
      include,
      order: [['createdAt', 'DESC']],
      distinct: true, // Important for correct count with many-to-many
    });
    
    return {
      coaches: rows,
      currentPage: page,
      totalPages: Math.ceil(count / limit),
      totalItems: count,
      itemsPerPage: limit,
    };
  } catch (error) {
    throw error;
  }
};

// Get coach by ID
exports.getCoachById = async (coachId, options = {}) => {
  try {
    const include = [
      {
        model: Sport,
        as: 'sport',
        attributes: ['id', 'name', 'category', 'image'],
      },
      {
        model: Sport,
        as: 'sports',
        attributes: ['id', 'name', 'category', 'image'],
        through: { 
          attributes: ['isPrimary'],
          as: 'coachSportInfo'
        },
      },
    ];
    
    if (options.includePrograms) {
      include.push({
        model: Batch,
        as: 'programs', // legacy alias -> Batch (see coach.js)
        attributes: ['id', 'name', 'status', 'fees', 'maxStudents', 'currentStudents'],
        where: { status: 'Active' },
        required: false,
      });
    }
    
    const coach = await Coach.findByPk(coachId, {
      include,
    });
    
    return coach;
  } catch (error) {
    throw error;
  }
};

// Create a new coach
exports.createCoach = async (coachData) => {
  // When a password is supplied, this coach also gets a login account (role COACH).
  // Coach has no userId FK — the User is linked by matching email (same convention
  // as authService.createUserByAdmin).
  const wantsLogin = !!coachData.password;
  const transaction = await Coach.sequelize.transaction();
  try {
    if (wantsLogin) {
      if (String(coachData.password).length < 6) {
        throw new Error('Password is required and must be at least 6 characters');
      }
      if (!coachData.email) {
        throw new Error('Email is required to create a coach login');
      }
      const existingUser = await User.findOne({ where: { email: coachData.email } });
      if (existingUser) {
        throw new Error('Email already exists');
      }
      await User.create({
        name: coachData.name,
        email: coachData.email,
        phone_number: coachData.phone,
        password: coachData.password,
        // Keep a recoverable copy so an admin can view this staff login later.
        staff_password_enc: encryptSecret(coachData.password),
        role: 'COACH',
        status: 'Active',
        sportComplexId: coachData.sportComplexId || null,
        permissions: getDefaultPermissions('COACH'),
        isEmailVerified: true,
        join_date: new Date(),
      }, { transaction });
    }

    const newCoach = await Coach.create({
      name: coachData.name,
      email: coachData.email,
      phone: coachData.phone,
      sportId: coachData.sportId, // Keep for backward compatibility
      sportComplexId: coachData.sportComplexId, // Per-complex admin scoping
      ground: coachData.ground,
      price: coachData.price || 0,
      availability: coachData.availability,
      certification: coachData.certification,
      bio: coachData.bio,
      experience: coachData.experience,
      specialization: coachData.specialization,
      qualifications: coachData.qualifications,
      image: coachData.image,
      status: coachData.status || 'Active',
    }, { transaction });

    // Handle multiple sports assignment
    if (coachData.sportIds && Array.isArray(coachData.sportIds) && coachData.sportIds.length > 0) {
      const coachSportsData = coachData.sportIds.map((sportId, index) => ({
        coachId: newCoach.id,
        sportId: sportId,
        isPrimary: index === 0, // First sport is primary
      }));

      await CoachSport.bulkCreate(coachSportsData, { transaction });
    } else if (coachData.sportId) {
      // Fallback: if only single sportId provided, add it
      await CoachSport.create({
        coachId: newCoach.id,
        sportId: coachData.sportId,
        isPrimary: true,
      }, { transaction });
    }

    await transaction.commit();

    // Fetch with sport relations
    return await Coach.findByPk(newCoach.id, {
      include: [
        {
          model: Sport,
          as: 'sport',
          attributes: ['id', 'name', 'category'],
        },
        {
          model: Sport,
          as: 'sports',
          attributes: ['id', 'name', 'category'],
          through: {
            attributes: ['isPrimary'],
            as: 'coachSportInfo'
          },
        },
      ],
    });
  } catch (error) {
    if (transaction && !transaction.finished) {
      try { await transaction.rollback(); } catch { /* already rolled back */ }
    }
    throw error;
  }
};

// Update coach
exports.updateCoach = async (coachId, updateData) => {
  try {
    const coach = await Coach.findByPk(coachId);
    
    if (!coach) {
      return null;
    }
    
    await coach.update(updateData);
    
    // Handle multiple sports assignment update
    if (updateData.sportIds && Array.isArray(updateData.sportIds)) {
      // Remove existing sport assignments
      await CoachSport.destroy({ where: { coachId } });

      // Add new sport assignments
      if (updateData.sportIds.length > 0) {
        const coachSportsData = updateData.sportIds.map((sportId, index) => ({
          coachId: coachId,
          sportId: sportId,
          isPrimary: index === 0, // First sport is primary
        }));

        await CoachSport.bulkCreate(coachSportsData);
      }
    } else if (updateData.sportId) {
      // Fallback: the admin form sends a single sportId (not sportIds).
      // Sync the CoachSport join table so coaching-page lookups (which read
      // CoachSports, not Coaches.sportId) reflect the edited sport.
      await CoachSport.destroy({ where: { coachId } });
      await CoachSport.create({
        coachId: coachId,
        sportId: updateData.sportId,
        isPrimary: true,
      });
    }
    
    // Fetch with sport relations
    return await Coach.findByPk(coachId, {
      include: [
        {
          model: Sport,
          as: 'sport',
          attributes: ['id', 'name', 'category'],
        },
        {
          model: Sport,
          as: 'sports',
          attributes: ['id', 'name', 'category'],
          through: { 
            attributes: ['isPrimary'],
            as: 'coachSportInfo'
          },
        },
      ],
    });
  } catch (error) {
    throw error;
  }
};

// Update coach status
exports.updateCoachStatus = async (coachId, status) => {
  try {
    const coach = await Coach.findByPk(coachId);
    
    if (!coach) {
      return null;
    }
    
    await coach.update({ status });
    
    return coach;
  } catch (error) {
    throw error;
  }
};

// Delete coach
exports.deleteCoach = async (coachId) => {
  try {
    const coach = await Coach.findByPk(coachId);
    
    if (!coach) {
      return false;
    }
    
    // Check if coach has active batches
    const batchCount = await Batch.count({
      where: {
        coachId,
        status: 'Active'
      }
    });

    if (batchCount > 0) {
      throw new Error('Cannot delete coach with active batches');
    }

    // A coach may have a linked login (role COACH, matched by email). On delete,
    // downgrade it to a normal USER so the person can still sign in as a regular
    // user (not the coach dashboard), rather than deleting/blocking the account.
    const email = coach.email;
    const transaction = await Coach.sequelize.transaction();
    try {
      await coach.destroy({ transaction });
      if (email) {
        const user = await User.findOne({ where: { email, role: 'COACH' }, transaction });
        if (user) {
          await demoteStaffUserToUser(user, { transaction });
        }
      }
      await transaction.commit();
      return true;
    } catch (err) {
      await transaction.rollback();
      throw err;
    }
  } catch (error) {
    throw error;
  }
};

// Get coaches by sport
exports.getCoachesBySport = async (sportId) => {
  try {
    const coaches = await Coach.findAll({
      where: { 
        status: 'Active'
      },
      include: [
        {
          model: Sport,
          as: 'sport',
          attributes: ['id', 'name', 'category'],
        },
        {
          model: Sport,
          as: 'sports',
          where: { id: sportId },
          attributes: ['id', 'name', 'category'],
          through: { 
            attributes: ['isPrimary'],
            as: 'coachSportInfo'
          },
          required: true, // Only get coaches that teach this sport
        },
      ],
      order: [['name', 'ASC']],
    });
    
    return coaches;
  } catch (error) {
    throw error;
  }
};

// Get coach statistics
exports.getCoachStats = async (coachId) => {
  try {
    const coach = await Coach.findByPk(coachId);
    
    if (!coach) {
      throw new Error('Coach not found');
    }
    
    // Get batch counts (exposed under the legacy totalPrograms/activePrograms keys)
    const totalPrograms = await Batch.count({ where: { coachId } });
    const activePrograms = await Batch.count({
      where: { coachId, status: 'Active' }
    });

    // Get total students across all batches
    const batches = await Batch.findAll({
      where: { coachId },
      attributes: ['currentStudents'],
    });

    const totalStudents = batches.reduce((sum, batch) => sum + (batch.currentStudents || 0), 0);

    return {
      coachId: coach.id,
      coachName: coach.name,
      totalPrograms,
      activePrograms,
      totalStudents,
      status: coach.status,
    };
  } catch (error) {
    throw error;
  }
};
