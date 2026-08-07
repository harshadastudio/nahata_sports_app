const express = require('express');
const router = express.Router();
const couponController = require('../controllers/couponController');
const { authenticateToken } = require('../middleware/authMiddleware');
const { allowRoles } = require('../middleware/roleMiddleware');

// ── Public coupon validation (any logged-in user — USER, ADMIN, EMPLOYEE) ─────
// Used by the frontend booking flows to validate & calculate discount before payment.
router.post('/validate', authenticateToken, couponController.validateCoupon);

// ── Active coupons for frontend display (any logged-in user) ─────────────────
// Returns all currently valid, non-expired, non-exhausted coupons.
// The code is shown so users can browse and click-to-apply.
router.get('/active', authenticateToken, couponController.getActiveCoupons);

// ── Admin / Employee / Complex Admin routes ──────────────────────────────────
router.get('/', authenticateToken, allowRoles('ADMIN', 'EMPLOYEE', 'COMPLEX_ADMIN'), couponController.getAllCoupons);
router.get('/:id', authenticateToken, allowRoles('ADMIN', 'EMPLOYEE', 'COMPLEX_ADMIN'), couponController.getCouponById);
router.get('/code/:code', authenticateToken, allowRoles('ADMIN', 'EMPLOYEE', 'COMPLEX_ADMIN'), couponController.getCouponByCode);

// Create / Update / Delete — ADMIN (any complex) or COMPLEX_ADMIN (own complex)
router.post('/', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN'), couponController.createCoupon);
router.put('/:id', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN'), couponController.updateCoupon);
router.delete('/:id', authenticateToken, allowRoles('ADMIN', 'COMPLEX_ADMIN'), couponController.deleteCoupon);

module.exports = router;
