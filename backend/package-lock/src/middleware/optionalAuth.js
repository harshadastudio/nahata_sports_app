'use strict';

const { verifyAccessToken } = require('../utils/tokenUtils');
const { User } = require('../models');

/**
 * Optional authentication.
 *
 * If a valid Bearer token (or accessToken cookie) is present, attaches the user to
 * req.user; otherwise continues as an anonymous/public request. NEVER rejects.
 *
 * Used on routes that are public (the customer website browses them without logging
 * in) but must ALSO honor per-complex scoping when an admin is logged in. With
 * req.user populated, complexScope.resolveComplexId(req) can scope a COMPLEX_ADMIN
 * to their own complex (and let a super admin opt-in via ?sportComplexId), while
 * anonymous requests stay unscoped exactly as before.
 */
async function optionalAuth(req, res, next) {
  try {
    const authHeader = req.headers.authorization || req.headers.Authorization;
    const token = authHeader && authHeader.startsWith('Bearer ')
      ? authHeader.substring(7)
      : req.cookies?.accessToken;

    if (!token) return next();

    const decoded = verifyAccessToken(token);
    const user = await User.findByPk(decoded.id, { attributes: { exclude: ['password', 'staff_password_enc'] } });
    if (user) req.user = user;
  } catch {
    /* invalid/expired token → treat as anonymous */
  }
  return next();
}

module.exports = { optionalAuth };
