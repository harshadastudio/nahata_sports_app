const { SecurityGuard, User, SportComplex } = require('../models');
const { Op } = require('sequelize');
const { getDefaultPermissions } = require('../config/rolePermissions');
const { encryptSecret } = require('../utils/secretCrypto');
const { demoteStaffUserToUser } = require('../utils/staffAccount');

class SecurityGuardService {
  async getAllSecurityGuards(page = 1, limit = 10, search = '', sportComplexId = null) {
    const offset = (page - 1) * limit;

    const whereClause = search ? {
      [Op.or]: [
        { guardId: { [Op.iLike]: `%${search}%` } },
        { '$user.name$': { [Op.iLike]: `%${search}%` } },
        { '$user.email$': { [Op.iLike]: `%${search}%` } },
        { '$user.phone_number$': { [Op.iLike]: `%${search}%` } }
      ]
    } : {};

    // Per-complex admin scoping (no-op when not provided)
    if (sportComplexId != null) {
      whereClause.sportComplexId = sportComplexId;
    }

    const { count, rows } = await SecurityGuard.findAndCountAll({
      where: whereClause,
      include: [
        {
          model: User,
          as: 'user',
          attributes: ['id', 'name', 'email', 'phone_number']
        },
        {
          model: SportComplex,
          as: 'sportComplex',
          attributes: ['id', 'name', 'city']
        }
      ],
      limit: parseInt(limit),
      offset: parseInt(offset),
      order: [['createdAt', 'DESC']],
      distinct: true
    });

    return {
      guards: rows,
      pagination: {
        total: count,
        page: parseInt(page),
        limit: parseInt(limit),
        totalPages: Math.ceil(count / limit)
      }
    };
  }

  async getSecurityGuardById(id) {
    const guard = await SecurityGuard.findByPk(id, {
      include: [{
        model: User,
        as: 'user',
        attributes: ['id', 'name', 'email', 'phone_number']
      }]
    });

    if (!guard) {
      throw new Error('Security guard not found');
    }

    return guard;
  }

  async createSecurityGuard(data) {
    const { fullName, email, phone, password, guardId, licenseNumber, shift, assignedArea, joiningDate, salary, status, sportComplexId } = data;

    if (!password || String(password).length < 6) {
      throw new Error('Password is required and must be at least 6 characters');
    }

    // Check if guardId already exists
    const existingGuard = await SecurityGuard.findOne({ where: { guardId } });
    if (existingGuard) {
      throw new Error('Guard ID already exists');
    }

    // Check if email already exists
    const existingUser = await User.findOne({ where: { email } });
    if (existingUser) {
      throw new Error('Email already exists');
    }

    // Create the login user with the admin-assigned password (hashed by model hook)
    const user = await User.create({
      name: fullName,
      email,
      phone_number: phone,
      role: 'SECURITY',
      password,
      // Keep a recoverable copy so an admin can view this staff login later.
      staff_password_enc: encryptSecret(password),
      status: status || 'Active',
      sportComplexId: sportComplexId || null,
      permissions: getDefaultPermissions('SECURITY'),
      isEmailVerified: true,
      join_date: new Date(),
    });

    // Create security guard
    const guard = await SecurityGuard.create({
      userId: user.id,
      guardId,
      licenseNumber: licenseNumber || null,
      shift,
      assignedArea,
      joiningDate,
      salary,
      sportComplexId, // Per-complex admin scoping
      status: status || 'Active'
    });

    // Fetch the created guard with user details
    return await this.getSecurityGuardById(guard.id);
  }

  async updateSecurityGuard(id, data) {
    const guard = await SecurityGuard.findByPk(id, {
      include: [{ model: User, as: 'user' }]
    });

    if (!guard) {
      throw new Error('Security guard not found');
    }

    const { fullName, email, phone, guardId, licenseNumber, shift, assignedArea, joiningDate, salary, status, sportComplexId } = data;

    // Check if guardId is being changed and if it already exists
    if (guardId && guardId !== guard.guardId) {
      const existingGuard = await SecurityGuard.findOne({ where: { guardId } });
      if (existingGuard) {
        throw new Error('Guard ID already exists');
      }
    }

    // Check if email is being changed and if it already exists
    if (email && email !== guard.user.email) {
      const existingUser = await User.findOne({ where: { email, id: { [Op.ne]: guard.userId } } });
      if (existingUser) {
        throw new Error('Email already exists');
      }
    }

    // Update user details
    await guard.user.update({
      name: fullName || guard.user.name,
      email: email || guard.user.email,
      phone_number: phone || guard.user.phone_number
    });

    // Update security guard details
    await guard.update({
      guardId: guardId || guard.guardId,
      licenseNumber: licenseNumber !== undefined ? licenseNumber : guard.licenseNumber,
      shift: shift || guard.shift,
      assignedArea: assignedArea || guard.assignedArea,
      joiningDate: joiningDate || guard.joiningDate,
      salary: salary !== undefined ? salary : guard.salary,
      sportComplexId: sportComplexId !== undefined ? sportComplexId : guard.sportComplexId,
      status: status || guard.status
    });

    return await this.getSecurityGuardById(id);
  }

  async deleteSecurityGuard(id) {
    const guard = await SecurityGuard.findByPk(id);

    if (!guard) {
      throw new Error('Security guard not found');
    }

    const userId = guard.userId;
    const transaction = await SecurityGuard.sequelize.transaction();
    try {
      // Remove the guard record from the list.
      await guard.destroy({ transaction });

      // Downgrade the linked login to a normal USER so the person can still sign
      // in — just as a regular user, no security dashboard. (demoteStaffUserToUser
      // also revokes their sessions so the next login is a clean USER session.)
      if (userId) {
        await demoteStaffUserToUser(userId, { transaction });
      }

      await transaction.commit();
      return { message: 'Security guard deleted successfully' };
    } catch (error) {
      await transaction.rollback();
      throw error;
    }
  }
}

module.exports = new SecurityGuardService();
