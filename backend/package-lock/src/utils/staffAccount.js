'use strict';

/**
 * Shared helpers for staff login accounts (Employee / Security / Coach).
 *
 *  - resolveStaffComplexId(req): which complex a new staff account belongs to.
 *      Complex admin → always their own complex (cannot be spoofed).
 *      Super admin   → must supply sportComplexId in the request body.
 *  - emailStaffCredentials(...): fire-and-forget credentials email (never throws).
 *      Pass `details` (array of {label, value}) to include the full Add-form info.
 *  - revealStaffPassword(user): decrypt the stored admin-set password (or null).
 *  - setStaffPassword(user, password): set both the bcrypt login password AND the
 *      recoverable encrypted copy, then persist.
 *  - findStaffUser(...): locate the User login behind an Employee/Security/Coach.
 */

const { User, SportComplex, RefreshToken } = require('../models');
const emailService = require('../services/emailService');
const { isComplexAdmin } = require('../middleware/complexScope');
const { encryptSecret, decryptSecret } = require('./secretCrypto');
const { getDefaultPermissions } = require('../config/rolePermissions');

const ROLE_LABELS = { EMPLOYEE: 'Employee', SECURITY: 'Security', COACH: 'Coach' };

// Roles whose password is admin-managed and viewable.
const MANAGED_STAFF_ROLES = ['EMPLOYEE', 'SECURITY', 'COACH'];

/**
 * Format a salary value for the credentials email: "₹18,000" (Indian grouping).
 * Returns '' for empty/invalid input so the email row is omitted.
 */
function formatSalary(value) {
  if (value == null || String(value).trim() === '') return '';
  const num = Number(value);
  if (Number.isNaN(num)) return String(value);
  return `₹${num.toLocaleString('en-IN')}`;
}

function resolveStaffComplexId(req) {
  if (isComplexAdmin(req)) {
    return req.user.sportComplexId != null ? Number(req.user.sportComplexId) : null;
  }
  const raw = req.body && req.body.sportComplexId;
  return raw != null && raw !== '' ? Number(raw) : null;
}

async function emailStaffCredentials({ to, name, email, password, roleKey, sportComplexId, details = [] }) {
  try {
    let complexName = '';
    if (sportComplexId) {
      const sc = await SportComplex.findByPk(sportComplexId, { attributes: ['name'] });
      complexName = sc ? sc.name : '';
    }
    await emailService.sendStaffCredentialsEmail({
      to,
      name,
      email,
      password,
      role: ROLE_LABELS[roleKey] || roleKey,
      complexName,
      details,
    });
  } catch (e) {
    // Non-fatal: the account is already created; just log if the email fails.
    console.warn('⚠️ Could not send staff credentials email:', e.message);
  }
}

/**
 * Decrypt the stored admin-set password for a staff User row.
 * Returns the plaintext, or null when nothing recoverable is stored
 * (e.g. accounts created before this feature → require a reset).
 */
function revealStaffPassword(user) {
  if (!user || !user.staff_password_enc) return null;
  return decryptSecret(user.staff_password_enc);
}

/**
 * Set a new password on a staff User: updates the bcrypt login password (hashed
 * by the model hook) and the recoverable encrypted copy, in one save.
 */
async function setStaffPassword(user, password) {
  user.password = password;                       // beforeUpdate hook hashes it
  user.staff_password_enc = encryptSecret(password);
  await user.save();
  return user;
}

/**
 * Find the staff login User behind an Employee/Security/Coach record.
 *  - Employee / Security have a `userId`.
 *  - Coach has no FK → linked by matching email.
 * `withSecret` controls whether the encrypted password column is selected.
 */
async function findStaffUser({ userId, email }, { withSecret = false } = {}) {
  const opts = withSecret
    ? {}
    : { attributes: { exclude: ['password', 'staff_password_enc'] } };
  if (userId) return User.findByPk(userId, opts);
  if (email) return User.findOne({ where: { email }, ...opts });
  return null;
}

/**
 * When a staff member (Employee / Security / Coach) is deleted from the admin
 * side, we DON'T delete or block their login — we downgrade it to a normal USER
 * so the person can still sign in, just as a regular user (no staff dashboard).
 *
 * Clears all staff-specific fields, resets permissions to USER defaults, keeps
 * the account Active, and revokes existing sessions so the next login is a clean
 * USER session. Accepts a User instance or a userId. No-op-safe (returns null if
 * the user can't be found). Pass a `transaction` to run inside one.
 */
async function demoteStaffUserToUser(userOrId, { transaction } = {}) {
  const user = (userOrId && typeof userOrId === 'object')
    ? userOrId
    : await User.findByPk(userOrId, { transaction });
  if (!user) return null;

  // Revoke sessions so they re-login cleanly with the new USER role/permissions.
  await RefreshToken.destroy({ where: { userId: user.id }, transaction });

  await user.update({
    role: 'USER',
    status: 'Active',
    permissions: getDefaultPermissions('USER'),
    sportComplexId: null,        // no longer scoped to a complex
    staff_password_enc: null,    // no longer an admin-managed staff login
    employee_id: null,
    department: null,
    assigned_sports: null,
    assigned_location: null,
  }, { transaction });

  return user;
}

module.exports = {
  resolveStaffComplexId,
  emailStaffCredentials,
  formatSalary,
  revealStaffPassword,
  setStaffPassword,
  findStaffUser,
  demoteStaffUserToUser,
  ROLE_LABELS,
  MANAGED_STAFF_ROLES,
};
