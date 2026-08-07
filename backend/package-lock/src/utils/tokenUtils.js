const jwt = require('jsonwebtoken');
const crypto = require('crypto');

// Pin the signing algorithm so a forged token can't downgrade to "alg":"none"
// or trick us into verifying an HS token against an RS public key, etc.
const ALGS = ['HS256'];
const ISSUER = process.env.JWT_ISSUER || 'nahata-sports-api';

// Validate environment variables
const validateEnvironment = () => {
  const required = ['JWT_ACCESS_SECRET', 'JWT_REFRESH_SECRET'];
  const missing = required.filter(key => !process.env[key]);

  if (missing.length > 0) {
    console.error('❌ Missing JWT environment variables:');
    missing.forEach(key => console.error(`   - ${key}: ${process.env[key] ? 'SET' : 'NOT SET'}`));
    throw new Error(`Missing required environment variables: ${missing.join(', ')}`);
  }
};

/**
 * Secret rotation support.
 *
 * We sign with the CURRENT secret but verify against CURRENT and (optionally) a
 * PREVIOUS secret. To rotate JWT_ACCESS_SECRET without invalidating the
 * long-lived tokens Huddle / KheloMore already hold:
 *   1. Set JWT_ACCESS_SECRET_PREVIOUS = <old secret>, JWT_ACCESS_SECRET = <new>.
 *   2. Deploy. Old partner tokens still verify (via *_PREVIOUS); new tokens use
 *      the new secret.
 *   3. After partners re-issue tokens with the new secret, remove *_PREVIOUS.
 */
const accessSecrets = () =>
  [process.env.JWT_ACCESS_SECRET, process.env.JWT_ACCESS_SECRET_PREVIOUS].filter(Boolean);
const refreshSecrets = () =>
  [process.env.JWT_REFRESH_SECRET, process.env.JWT_REFRESH_SECRET_PREVIOUS].filter(Boolean);

const newJti = () => crypto.randomUUID();

const generateAccessToken = (user) => {
  validateEnvironment();

  return jwt.sign(
    {
      id: user.id,
      email: user.email,
      role: user.role,
    },
    process.env.JWT_ACCESS_SECRET,
    {
      // Expiry intentionally unchanged (partner integrations depend on it).
      expiresIn: process.env.ACCESS_TOKEN_EXPIRY || '100y',
      algorithm: 'HS256',
      issuer: ISSUER,
      jwtid: newJti(), // enables per-token revocation
    }
  );
};

const generateRefreshToken = (user) => {
  return jwt.sign(
    {
      id: user.id,
      email: user.email,
    },
    process.env.JWT_REFRESH_SECRET,
    {
      expiresIn: process.env.REFRESH_TOKEN_EXPIRY || '100y',
      algorithm: 'HS256',
      issuer: ISSUER,
      jwtid: newJti(),
    }
  );
};

/**
 * Verify a token against a list of candidate secrets (current, then previous).
 * Issuer is NOT required — legacy/partner tokens were minted without an `iss`
 * claim, and requiring it would break them. Algorithm is pinned regardless.
 */
const verifyWithSecrets = (token, secrets) => {
  let lastErr;
  for (const secret of secrets) {
    try {
      return jwt.verify(token, secret, { algorithms: ALGS });
    } catch (err) {
      lastErr = err;
    }
  }
  throw lastErr || new Error('Token verification failed');
};

const verifyAccessToken = (token) => verifyWithSecrets(token, accessSecrets());

const verifyRefreshToken = (token) => {
  validateEnvironment();
  return verifyWithSecrets(token, refreshSecrets());
};

// ── Revocation helpers ────────────────────────────────────────────────────────

/** sha256 of the raw token — the denylist key for legacy tokens that lack a jti. */
const hashToken = (token) => crypto.createHash('sha256').update(String(token)).digest('hex');

/** Decode without verifying (used to read jti/exp when revoking a token by value). */
const decodeToken = (token) => {
  try {
    return jwt.decode(token) || null;
  } catch (_e) {
    return null;
  }
};

/**
 * Revoke a token so future requests presenting it are rejected, without touching
 * expiry. Stores the jti (preferred) and/or the token hash. Idempotent.
 *
 * @param {string} token   the raw JWT to revoke
 * @param {object} [opts]
 * @param {string} [opts.reason]
 * @param {number} [opts.userId]
 */
const revokeToken = async (token, opts = {}) => {
  const { RevokedToken } = require('../models');
  const decoded = decodeToken(token) || {};
  const jti = decoded.jti || null;
  const tokenHash = hashToken(token);
  const expiresAt = decoded.exp ? new Date(decoded.exp * 1000) : null;

  // Prefer jti; always also record the hash so legacy tokens are covered.
  const [row] = await RevokedToken.findOrCreate({
    where: tokenHash ? { tokenHash } : { jti },
    defaults: {
      jti,
      tokenHash,
      userId: opts.userId ?? decoded.id ?? null,
      reason: opts.reason || 'revoked',
      expiresAt,
    },
  });
  return row;
};

/**
 * Is this token on the denylist? Looks up by jti OR token hash.
 * @param {object} decoded  the verified payload (may contain jti)
 * @param {string} rawToken the raw token string
 * @returns {Promise<boolean>}
 */
const isTokenRevoked = async (decoded, rawToken) => {
  const { RevokedToken } = require('../models');
  const { Op } = require('sequelize');
  const or = [];
  if (decoded && decoded.jti) or.push({ jti: decoded.jti });
  if (rawToken) or.push({ tokenHash: hashToken(rawToken) });
  if (or.length === 0) return false;

  const hit = await RevokedToken.findOne({ where: { [Op.or]: or }, attributes: ['id'] });
  return !!hit;
};

const calculateExpiryDate = (expiry) => {
  const now = new Date();
  const expiryTime = expiry.includes('d')
    ? parseInt(expiry) * 24 * 60 * 60 * 1000
    : expiry.includes('h')
    ? parseInt(expiry) * 60 * 60 * 1000
    : expiry.includes('m')
    ? parseInt(expiry) * 60 * 1000
    : 15 * 60 * 1000; // Default 15 minutes

  return new Date(now.getTime() + expiryTime);
};

module.exports = {
  generateAccessToken,
  generateRefreshToken,
  verifyAccessToken,
  verifyRefreshToken,
  calculateExpiryDate,
  // Revocation + rotation helpers (new, additive)
  hashToken,
  decodeToken,
  revokeToken,
  isTokenRevoked,
};
