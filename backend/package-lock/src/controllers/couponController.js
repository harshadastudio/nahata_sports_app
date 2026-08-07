const couponService = require('../services/couponService');
const { resolveComplexId, isComplexAdmin, assertComplexAccess } = require('../middleware/complexScope');
const { resolveClientPlatform } = require('../utils/clientPlatform');

/** '' / null / undefined → undefined (= "don't enforce"), otherwise the id. */
const optionalId = (value) =>
  value != null && value !== '' ? value : undefined;

class CouponController {
  // Get all coupons
  async getAllCoupons(req, res) {
    try {
      const { page = 1, limit = 10, search = '', status = '' } = req.query;

      // Per-complex admin scoping (null = all complexes for super admin)
      const complexId = resolveComplexId(req);
      const result = await couponService.getAllCoupons(page, limit, search, status, complexId);

      res.status(200).json({
        success: true,
        data: result.data,
        pagination: result.pagination
      });
    } catch (error) {
      console.error('Error fetching coupons:', error);
      res.status(500).json({
        success: false,
        message: 'Internal server error',
        error: error.message
      });
    }
  }

  // Get single coupon
  async getCouponById(req, res) {
    try {
      const { id } = req.params;

      const coupon = await couponService.getCouponById(id);

      // Complex admins can only view their own complex's coupons
      if (!assertComplexAccess(req, res, coupon.sportComplexId)) return;

      res.status(200).json({
        success: true,
        data: coupon
      });
    } catch (error) {
      console.error('Error fetching coupon:', error);
      
      if (error.message === 'Coupon not found') {
        return res.status(404).json({
          success: false,
          message: 'Coupon not found'
        });
      }

      res.status(500).json({
        success: false,
        message: 'Internal server error',
        error: error.message
      });
    }
  }

  // Get coupon by code
  async getCouponByCode(req, res) {
    try {
      const { code } = req.params;

      const coupon = await couponService.getCouponByCode(code);

      res.status(200).json({
        success: true,
        data: coupon
      });
    } catch (error) {
      console.error('Error fetching coupon by code:', error);
      
      if (error.message === 'Coupon not found') {
        return res.status(404).json({
          success: false,
          message: 'Coupon not found'
        });
      }

      res.status(500).json({
        success: false,
        message: 'Internal server error',
        error: error.message
      });
    }
  }

  // Create coupon
  async createCoupon(req, res) {
    try {
      const { code, discountType, discountValue, validUntil, usageLimit, status } = req.body;

      // Validate required fields
      if (!code || !discountType || !discountValue || !validUntil) {
        return res.status(400).json({
          success: false,
          message: 'Missing required fields: code, discountType, discountValue, validUntil'
        });
      }

      // Complex admins can only create Court coupons for their own complex.
      if (isComplexAdmin(req)) {
        req.body.appliesTo = 'Court';
        req.body.sportComplexId = req.user.sportComplexId;
      }

      const coupon = await couponService.createCoupon(req.body);

      res.status(201).json({
        success: true,
        data: coupon,
        message: 'Coupon created successfully'
      });
    } catch (error) {
      console.error('Error creating coupon:', error);

      // Bad scope combinations (unknown / mismatched sport or event) are the
      // caller's mistake, not a server fault.
      if (
        error.message === 'Coupon code already exists' ||
        /not found|does not belong/i.test(error.message)
      ) {
        return res.status(400).json({
          success: false,
          message: error.message
        });
      }

      res.status(500).json({
        success: false,
        message: 'Internal server error',
        error: error.message
      });
    }
  }

  // Update coupon
  async updateCoupon(req, res) {
    try {
      const { id } = req.params;

      // Complex admins may only edit their own complex's coupons, and cannot move
      // a coupon to another complex.
      if (isComplexAdmin(req)) {
        const existing = await couponService.getCouponById(id);
        if (!assertComplexAccess(req, res, existing.sportComplexId)) return;
        req.body.appliesTo = 'Court';
        req.body.sportComplexId = req.user.sportComplexId;
      }

      const coupon = await couponService.updateCoupon(id, req.body);

      res.status(200).json({
        success: true,
        data: coupon,
        message: 'Coupon updated successfully'
      });
    } catch (error) {
      console.error('Error updating coupon:', error);

      if (error.message === 'Coupon not found') {
        return res.status(404).json({
          success: false,
          message: 'Coupon not found'
        });
      }

      if (/not found|does not belong/i.test(error.message)) {
        return res.status(400).json({
          success: false,
          message: error.message
        });
      }

      res.status(500).json({
        success: false,
        message: 'Internal server error',
        error: error.message
      });
    }
  }

  // Delete coupon
  async deleteCoupon(req, res) {
    try {
      const { id } = req.params;

      // Complex admins may only delete their own complex's coupons
      if (isComplexAdmin(req)) {
        const existing = await couponService.getCouponById(id);
        if (!assertComplexAccess(req, res, existing.sportComplexId)) return;
      }

      const result = await couponService.deleteCoupon(id);

      res.status(200).json({
        success: true,
        message: result.message
      });
    } catch (error) {
      console.error('Error deleting coupon:', error);

      if (error.message === 'Coupon not found') {
        return res.status(404).json({
          success: false,
          message: 'Coupon not found'
        });
      }

      res.status(500).json({
        success: false,
        message: 'Internal server error',
        error: error.message
      });
    }
  }

  // Get active coupons for frontend display (any logged-in user)
  async getActiveCoupons(req, res) {
    try {
      const { appliesTo, sportComplexId, sportId, eventPassId } = req.query;
      const coupons = await couponService.getActiveCoupons({
        appliesTo: appliesTo || undefined,
        sportComplexId: optionalId(sportComplexId),
        sportId: optionalId(sportId),
        eventPassId: optionalId(eventPassId),
        // Only offer coupons this client is allowed to redeem.
        platform: resolveClientPlatform(req),
      });

      res.status(200).json({
        success: true,
        data: coupons
      });
    } catch (error) {
      console.error('Error fetching active coupons:', error);
      res.status(500).json({
        success: false,
        message: 'Internal server error',
        error: error.message
      });
    }
  }

  // Validate coupon
  async validateCoupon(req, res) {    try {
      const { code, amount, appliesTo, sportComplexId, sportId, eventPassId } = req.body;

      if (!code) {
        return res.status(400).json({
          success: false,
          message: 'Coupon code is required'
        });
      }

      const coupon = await couponService.validateCoupon(code, {
        appliesTo: appliesTo || undefined,
        sportComplexId: optionalId(sportComplexId),
        sportId: optionalId(sportId),
        eventPassId: optionalId(eventPassId),
        platform: resolveClientPlatform(req),
      });

      // Calculate discount based on the provided amount (optional)
      let discountAmount = 0;
      let finalAmount = amount ? parseFloat(amount) : null;

      if (finalAmount !== null && !isNaN(finalAmount)) {
        if (coupon.discountType === 'Percentage') {
          discountAmount = (finalAmount * parseFloat(coupon.discountValue)) / 100;
          // Apply maxDiscount cap if set
          if (coupon.maxDiscount && discountAmount > parseFloat(coupon.maxDiscount)) {
            discountAmount = parseFloat(coupon.maxDiscount);
          }
        } else {
          // Flat discount
          discountAmount = parseFloat(coupon.discountValue);
          // Discount cannot exceed the total amount
          if (discountAmount > finalAmount) {
            discountAmount = finalAmount;
          }
        }
        finalAmount = Math.max(0, finalAmount - discountAmount);
      }

      res.status(200).json({
        success: true,
        message: 'Coupon is valid',
        data: {
          id: coupon.id,
          code: coupon.code,
          discountType: coupon.discountType,
          discountValue: parseFloat(coupon.discountValue),
          maxDiscount: coupon.maxDiscount ? parseFloat(coupon.maxDiscount) : null,
          description: coupon.description,
          validUntil: coupon.validUntil,
          // Calculated fields (only present when amount is provided)
          ...(amount !== undefined && {
            discountAmount: Math.round(discountAmount * 100) / 100,
            finalAmount: Math.round(finalAmount * 100) / 100,
            originalAmount: parseFloat(amount),
          }),
        }
      });
    } catch (error) {
      console.error('Error validating coupon:', error);

      res.status(400).json({
        success: false,
        message: error.message
      });
    }
  }
}

module.exports = new CouponController();
