const membershipService = require('../services/membershipService');

class MembershipController {
  // Create a new membership
  async createMembership(req, res) {
    try {
      const membershipData = req.body;

      // Validate required fields (userId is now optional for admin panel)
      const requiredFields = ['planId', 'planName', 'price', 'validity', 'startDate', 'endDate', 'totalAmount'];
      const missingFields = requiredFields.filter(field => !membershipData[field]);

      if (missingFields.length > 0) {
        return res.status(400).json({
          success: false,
          message: `Missing required fields: ${missingFields.join(', ')}`
        });
      }

      const membership = await membershipService.createMembership(membershipData);

      res.status(201).json({
        success: true,
        message: 'Membership created successfully',
        data: membership
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }

  // Get all memberships with filters
  async getAllMemberships(req, res) {
    try {
      const filters = {
        status: req.query.status,
        paymentStatus: req.query.paymentStatus,
        userId: req.query.userId,
        page: req.query.page || 1,
        limit: req.query.limit || 10
      };

      const result = await membershipService.getAllMemberships(filters);

      res.status(200).json({
        success: true,
        data: result.memberships,
        pagination: {
          currentPage: result.currentPage,
          totalPages: result.totalPages,
          totalCount: result.totalCount,
          limit: parseInt(filters.limit)
        }
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: error.message
      });
    }
  }

  // Get membership by ID
  async getMembershipById(req, res) {
    try {
      const { id } = req.params;

      if (!id) {
        return res.status(400).json({
          success: false,
          message: 'Membership ID is required'
        });
      }

      const membership = await membershipService.getMembershipById(id);

      res.status(200).json({
        success: true,
        data: membership
      });
    } catch (error) {
      res.status(404).json({
        success: false,
        message: error.message
      });
    }
  }

  // Get memberships by user ID
  async getMembershipsByUserId(req, res) {
    try {
      const { userId } = req.params;

      if (!userId) {
        return res.status(400).json({
          success: false,
          message: 'User ID is required'
        });
      }

      const memberships = await membershipService.getMembershipsByUserId(userId);

      res.status(200).json({
        success: true,
        data: memberships,
        count: memberships.length
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: error.message
      });
    }
  }

  // Get active membership for a user
  async getActiveMembership(req, res) {
    try {
      const { userId } = req.params;

      if (!userId) {
        return res.status(400).json({
          success: false,
          message: 'User ID is required'
        });
      }

      const membership = await membershipService.getActiveMembership(userId);

      if (!membership) {
        return res.status(404).json({
          success: false,
          message: 'No active membership found for this user'
        });
      }

      res.status(200).json({
        success: true,
        data: membership
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: error.message
      });
    }
  }

  // Update membership
  async updateMembership(req, res) {
    try {
      const { id } = req.params;
      const updateData = req.body;

      if (!id) {
        return res.status(400).json({
          success: false,
          message: 'Membership ID is required'
        });
      }

      const membership = await membershipService.updateMembership(id, updateData);

      res.status(200).json({
        success: true,
        message: 'Membership updated successfully',
        data: membership
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }

  // Update membership status
  async updateMembershipStatus(req, res) {
    try {
      const { id } = req.params;
      const { status } = req.body;

      if (!id || !status) {
        return res.status(400).json({
          success: false,
          message: 'Membership ID and status are required'
        });
      }

      const membership = await membershipService.updateMembershipStatus(id, status);

      res.status(200).json({
        success: true,
        message: 'Membership status updated successfully',
        data: membership
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }

  // Update payment status
  async updatePaymentStatus(req, res) {
    try {
      const { id } = req.params;
      const { paymentStatus } = req.body;

      if (!id || !paymentStatus) {
        return res.status(400).json({
          success: false,
          message: 'Membership ID and payment status are required'
        });
      }

      const membership = await membershipService.updatePaymentStatus(id, paymentStatus);

      res.status(200).json({
        success: true,
        message: 'Payment status updated successfully',
        data: membership
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }

  // Cancel membership
  async cancelMembership(req, res) {
    try {
      const { id } = req.params;

      if (!id) {
        return res.status(400).json({
          success: false,
          message: 'Membership ID is required'
        });
      }

      const membership = await membershipService.cancelMembership(id);

      res.status(200).json({
        success: true,
        message: 'Membership cancelled successfully',
        data: membership
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }

  // Renew membership
  async renewMembership(req, res) {
    try {
      const { id } = req.params;

      if (!id) {
        return res.status(400).json({
          success: false,
          message: 'Membership ID is required'
        });
      }

      const membership = await membershipService.renewMembership(id);

      res.status(200).json({
        success: true,
        message: 'Membership renewed successfully',
        data: membership
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }

  // Delete membership (soft delete)
  async deleteMembership(req, res) {
    try {
      const { id } = req.params;

      if (!id) {
        return res.status(400).json({
          success: false,
          message: 'Membership ID is required'
        });
      }

      const result = await membershipService.deleteMembership(id);

      res.status(200).json({
        success: true,
        message: result.message
      });
    } catch (error) {
      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }

  // Check and update expired memberships
  async checkExpiredMemberships(req, res) {
    try {
      const result = await membershipService.checkExpiredMemberships();

      res.status(200).json({
        success: true,
        message: result.message,
        count: result.count
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: error.message
      });
    }
  }

  // Get membership statistics
  async getMembershipStats(req, res) {
    try {
      const stats = await membershipService.getMembershipStats();

      res.status(200).json({
        success: true,
        data: stats
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        message: error.message
      });
    }
  }
}

module.exports = new MembershipController();
