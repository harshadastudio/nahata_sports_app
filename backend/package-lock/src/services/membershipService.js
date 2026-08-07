const { Membership, User } = require('../models');
const { Op } = require('sequelize');

class MembershipService {
  // Create a new membership
  async createMembership(membershipData) {
    try {
      const {
        userId,
        planId,
        planName,
        price,
        validity,
        bookings,
        discount,
        accessType,
        features,
        startDate,
        endDate,
        autoRenew,
        discountApplied,
        totalAmount
      } = membershipData;

      // For admin panel: Use a default userId (1) if not provided
      const finalUserId = userId || 1;

      // Check if user exists (only if userId is provided)
      if (userId) {
        const user = await User.findByPk(userId);
        if (!user) {
          throw new Error('User not found');
        }

        // Check if user already has an active membership
        const existingMembership = await Membership.findOne({
          where: {
            userId,
            status: 'Active',
            endDate: {
              [Op.gte]: new Date()
            }
          }
        });

        if (existingMembership) {
          throw new Error('User already has an active membership');
        }
      }

      // Create membership
      const membership = await Membership.create({
        userId: finalUserId,
        planId,
        planName,
        price,
        validity,
        bookings: bookings || 0,
        discount: discount || 0,
        accessType: accessType || 'Both',
        features: features || '',
        startDate,
        endDate,
        status: 'Active',
        paymentStatus: 'Pending',
        autoRenew: autoRenew || false,
        discountApplied: discountApplied || 0,
        totalAmount
      });

      return membership;
    } catch (error) {
      throw new Error(`Failed to create membership: ${error.message}`);
    }
  }

  // Get all memberships with optional filters
  async getAllMemberships(filters = {}) {
    try {
      const { status, paymentStatus, userId, page = 1, limit = 10 } = filters;
      
      const whereClause = {};
      
      if (status) whereClause.status = status;
      if (paymentStatus) whereClause.paymentStatus = paymentStatus;
      if (userId) whereClause.userId = userId;

      const offset = (page - 1) * limit;

      const { count, rows } = await Membership.findAndCountAll({
        where: whereClause,
        include: [
          {
            model: User,
            attributes: ['id', 'name', 'email', 'phone_number'],
            required: false, // LEFT JOIN - don't require user to exist
          }
        ],
        limit: parseInt(limit),
        offset: parseInt(offset),
        order: [['createdAt', 'DESC']]
      });

      return {
        memberships: rows,
        totalCount: count,
        currentPage: parseInt(page),
        totalPages: Math.ceil(count / limit)
      };
    } catch (error) {
      throw new Error(`Failed to fetch memberships: ${error.message}`);
    }
  }

  // Get membership by ID
  async getMembershipById(id) {
    try {
      const membership = await Membership.findByPk(id, {
        include: [
          {
            model: User,
            attributes: ['id', 'name', 'email', 'phone_number'],
            required: false,
          }
        ]
      });

      if (!membership) {
        throw new Error('Membership not found');
      }

      return membership;
    } catch (error) {
      throw new Error(`Failed to fetch membership: ${error.message}`);
    }
  }

  // Get memberships by user ID
  async getMembershipsByUserId(userId) {
    try {
      const memberships = await Membership.findAll({
        where: { userId },
        include: [
          {
            model: User,
            attributes: ['id', 'name', 'email', 'phone_number'],
            required: false,
          }
        ],
        order: [['createdAt', 'DESC']]
      });

      return memberships;
    } catch (error) {
      throw new Error(`Failed to fetch user memberships: ${error.message}`);
    }
  }

  // Update membership
  async updateMembership(id, updateData) {
    try {
      const membership = await Membership.findByPk(id);

      if (!membership) {
        throw new Error('Membership not found');
      }

      // Update membership
      await membership.update(updateData);

      return membership;
    } catch (error) {
      throw new Error(`Failed to update membership: ${error.message}`);
    }
  }

  // Update membership status
  async updateMembershipStatus(id, status) {
    try {
      const validStatuses = ['Active', 'Expired', 'Cancelled', 'Suspended', 'Inactive'];
      
      if (!validStatuses.includes(status)) {
        throw new Error('Invalid status');
      }

      const membership = await Membership.findByPk(id);

      if (!membership) {
        throw new Error('Membership not found');
      }

      await membership.update({ status });

      return membership;
    } catch (error) {
      throw new Error(`Failed to update membership status: ${error.message}`);
    }
  }

  // Update payment status
  async updatePaymentStatus(id, paymentStatus) {
    try {
      const validPaymentStatuses = ['Paid', 'Pending', 'Overdue'];
      
      if (!validPaymentStatuses.includes(paymentStatus)) {
        throw new Error('Invalid payment status');
      }

      const membership = await Membership.findByPk(id);

      if (!membership) {
        throw new Error('Membership not found');
      }

      await membership.update({ paymentStatus });

      return membership;
    } catch (error) {
      throw new Error(`Failed to update payment status: ${error.message}`);
    }
  }

  // Cancel membership
  async cancelMembership(id) {
    try {
      const membership = await Membership.findByPk(id);

      if (!membership) {
        throw new Error('Membership not found');
      }

      if (membership.status === 'Cancelled') {
        throw new Error('Membership is already cancelled');
      }

      await membership.update({ status: 'Cancelled' });

      return membership;
    } catch (error) {
      throw new Error(`Failed to cancel membership: ${error.message}`);
    }
  }

  // Renew membership
  async renewMembership(id) {
    try {
      const membership = await Membership.findByPk(id);

      if (!membership) {
        throw new Error('Membership not found');
      }

      // Calculate new dates
      const newStartDate = new Date();
      const newEndDate = new Date();
      newEndDate.setDate(newEndDate.getDate() + membership.validity);

      await membership.update({
        startDate: newStartDate,
        endDate: newEndDate,
        status: 'Active',
        paymentStatus: 'Pending'
      });

      return membership;
    } catch (error) {
      throw new Error(`Failed to renew membership: ${error.message}`);
    }
  }

  // Soft delete membership
  async deleteMembership(id) {
    try {
      const membership = await Membership.findByPk(id);

      if (!membership) {
        throw new Error('Membership not found');
      }

      await membership.destroy(); // Soft delete (paranoid mode)

      return { message: 'Membership deleted successfully' };
    } catch (error) {
      throw new Error(`Failed to delete membership: ${error.message}`);
    }
  }

  // Get active membership for a user
  async getActiveMembership(userId) {
    try {
      const membership = await Membership.findOne({
        where: {
          userId,
          status: 'Active',
          endDate: {
            [Op.gte]: new Date()
          }
        },
        include: [
          {
            model: User,
            attributes: ['id', 'name', 'email', 'phone_number'],
            required: false,
          }
        ]
      });

      return membership;
    } catch (error) {
      throw new Error(`Failed to fetch active membership: ${error.message}`);
    }
  }

  // Check and update expired memberships
  async checkExpiredMemberships() {
    try {
      const expiredMemberships = await Membership.findAll({
        where: {
          status: 'Active',
          endDate: {
            [Op.lt]: new Date()
          }
        }
      });

      for (const membership of expiredMemberships) {
        await membership.update({ status: 'Expired' });
      }

      return {
        message: `${expiredMemberships.length} memberships marked as expired`,
        count: expiredMemberships.length
      };
    } catch (error) {
      throw new Error(`Failed to check expired memberships: ${error.message}`);
    }
  }

  // Get membership statistics
  async getMembershipStats() {
    try {
      const { fn, col, literal } = require('sequelize');
      
      // Total memberships count
      const totalMemberships = await Membership.count();
      
      // Active memberships count
      const activeMemberships = await Membership.count({ where: { status: 'Active' } });
      
      // Expired memberships count
      const expiredMemberships = await Membership.count({ where: { status: 'Expired' } });
      
      // Cancelled memberships count
      const cancelledMemberships = await Membership.count({ where: { status: 'Cancelled' } });
      
      // Pending payments count
      const pendingPayments = await Membership.count({ where: { paymentStatus: 'Pending' } });
      
      // Total revenue (sum of totalAmount for paid memberships)
      const revenueResult = await Membership.findOne({
        attributes: [[fn('SUM', col('totalAmount')), 'totalRevenue']],
        where: { paymentStatus: 'Paid' },
        raw: true
      });
      const totalRevenue = parseFloat(revenueResult?.totalRevenue || 0);
      
      // Average plan price
      const avgPriceResult = await Membership.findOne({
        attributes: [[fn('AVG', col('price')), 'avgPrice']],
        raw: true
      });
      const avgPlanPrice = parseFloat(avgPriceResult?.avgPrice || 0);
      
      // Average discount
      const avgDiscountResult = await Membership.findOne({
        attributes: [[fn('AVG', col('discount')), 'avgDiscount']],
        raw: true
      });
      const avgDiscount = parseFloat(avgDiscountResult?.avgDiscount || 0);
      
      // Active subscribers (unique users with active memberships)
      const activeSubscribers = await Membership.count({
        where: { status: 'Active' },
        distinct: true,
        col: 'userId'
      });

      return {
        total: totalMemberships,
        active: activeMemberships,
        expired: expiredMemberships,
        cancelled: cancelledMemberships,
        pendingPayments,
        totalRevenue: totalRevenue,
        activeSubscribers: activeSubscribers,
        avgPlanPrice: avgPlanPrice,
        avgDiscount: avgDiscount
      };
    } catch (error) {
      throw new Error(`Failed to fetch membership statistics: ${error.message}`);
    }
  }
}

module.exports = new MembershipService();
