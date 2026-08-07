const { verifyAccessToken, isTokenRevoked } = require('../utils/tokenUtils');
const { User } = require('../models');
const logger = require('../utils/logger');

const authenticateToken = async (req, res, next) => {
  try {
    // Get token from Authorization header (Bearer token) or cookies
    let token = null;
    
    // Check Authorization header first (for Postman/API clients)
    const authHeader = req.headers.authorization || req.headers.Authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      token = authHeader.substring(7); // Remove 'Bearer ' prefix
    }

    // Fallback to cookies (for browser clients)
    if (!token) {
      token = req.cookies?.accessToken;
    }

    if (!token) {
      return res.status(401).json({
        success: false,
        message: 'Access token not provided'
      });
    }

    // Verify token
    const decoded = verifyAccessToken(token);

    // Reject explicitly-revoked tokens (logout / "force sign-out" / leaked token)
    // WITHOUT relying on token expiry. A denylist hit is a hard 401. An infra
    // error checking the denylist must not lock every user out, so we log and
    // fall through — the token is already cryptographically valid at this point.
    try {
      if (await isTokenRevoked(decoded, token)) {
        return res.status(401).json({
          success: false,
          message: 'This session has been revoked. Please log in again.',
        });
      }
    } catch (revokeErr) {
      logger.error('auth.revocation_check_failed', { err: revokeErr, userId: decoded?.id });
    }

    // Get user from database
    const user = await User.findByPk(decoded.id, {
      attributes: { exclude: ['password', 'staff_password_enc', 'phone_verify_otp'] }
    });

    if (!user) {
      return res.status(401).json({
        success: false,
        message: 'User not found'
      });
    }

    // Reject disabled accounts immediately, even if they still hold a valid
    // (un-expired) access token — e.g. a deleted security guard.
    if (user.status === 'Blocked') {
      return res.status(401).json({
        success: false,
        message: 'Your account has been disabled. Please contact the administrator.'
      });
    }

    // Attach user to request object
    req.user = user;
    next();
  } catch (error) {
    return res.status(401).json({
      success: false,
      message: 'Invalid access token',
      debug: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

/**
 * Optional authentication: attach req.user when a valid, non-revoked token is
 * present, otherwise continue as a guest (req.user stays undefined). Never
 * rejects — used on endpoints that must serve both logged-in users and guests
 * (e.g. payment routes, where guest event checkout is allowed but authenticated
 * users get ownership enforcement).
 */
const optionalAuthenticate = async (req, res, next) => {
  try {
    let token = null;
    const authHeader = req.headers.authorization || req.headers.Authorization;
    if (authHeader && authHeader.startsWith('Bearer ')) {
      token = authHeader.substring(7);
    }
    if (!token) token = req.cookies?.accessToken;
    if (!token) return next();

    const decoded = verifyAccessToken(token);
    if (await isTokenRevoked(decoded, token)) return next();

    const user = await User.findByPk(decoded.id, {
      attributes: { exclude: ['password', 'staff_password_enc', 'phone_verify_otp'] },
    });
    if (user && user.status !== 'Blocked') {
      req.user = user;
    }
  } catch (_err) {
    // Invalid/expired token on an optional route → proceed as guest.
  }
  return next();
};

const requireRole = (allowedRoles) => {
  return (req, res, next) => {
    if (!req.user) {
      return res.status(401).json({
        success: false,
        message: 'Authentication required'
      });
    }

    const userRole = req.user.role.toUpperCase();
    const hasPermission = allowedRoles.some(role => role.toUpperCase() === userRole);

    if (!hasPermission) {
      return res.status(403).json({
        success: false,
        message: 'Access denied: insufficient permissions'
      });
    }

    next();
  };
};

module.exports = {
  authenticateToken,
  optionalAuthenticate,
  requireRole
};
