'use strict';

/**
 * Employee module permissions.
 *
 * Employee access is configured by the admin in Roles Management, which writes
 * the permission set for the `employee` role into the RolePermissions table.
 * The website sidebar already honours it; this middleware enforces the SAME set
 * on the API, so unticking a module in Roles Management actually blocks the
 * requests too rather than only hiding the menu entry.
 *
 * Only EMPLOYEE is gated. Every other role (ADMIN, COMPLEX_ADMIN, COACH, …)
 * passes straight through, so no existing behaviour changes.
 *
 * NOTE: this checks WHAT an employee may do. WHERE they may do it (their own
 * sports complex) is already enforced separately by complexScope.js, which
 * lists EMPLOYEE in COMPLEX_SCOPED_ROLES.
 */

const { RolePermission } = require('../models');

// Permission ids used by the employee dashboard modules. Kept here so the API
// and the admin panel's EMPLOYEE_PERMISSIONS list stay in step.
const EMPLOYEE_PERMISSIONS = {
  SPORTS: 'employee_sports',
  COURTS: 'employee_courts',
  SLOTS: 'employee_slots',
  BATCHES: 'employee_batches',
  BLOCKED_SLOTS: 'employee_blocked_slots',
  FEES_MANAGEMENT: 'employee_fees_management',
};

// The permission set changes rarely and is read on nearly every request, so it
// is cached briefly. The TTL keeps an admin's change visible within seconds.
const CACHE_TTL_MS = 30_000;
let cache = { at: 0, set: null };

async function loadEmployeePermissions() {
  if (cache.set && Date.now() - cache.at < CACHE_TTL_MS) return cache.set;
  const rows = await RolePermission.findAll({
    where: { role: 'employee', isActive: true },
    attributes: ['permission'],
  });
  cache = { at: Date.now(), set: new Set(rows.map((r) => r.permission)) };
  return cache.set;
}

/** Drop the cache — call after the admin saves a new permission set. */
function invalidateEmployeePermissionCache() {
  cache = { at: 0, set: null };
}

/**
 * Express guard: require the permission when the caller is an EMPLOYEE.
 * @param {string|string[]} permissionId one of EMPLOYEE_PERMISSIONS, or a list
 *        of alternatives — holding ANY one of them grants access. The list form
 *        is for endpoints shared by two modules (e.g. the slot toggle, used by
 *        both the Slot page and Blocked Slots).
 */
function requireEmployeePermission(permissionId) {
  const required = Array.isArray(permissionId) ? permissionId : [permissionId];
  return async (req, res, next) => {
    const role = String(req.user && req.user.role ? req.user.role : '').toUpperCase();
    if (role !== 'EMPLOYEE') return next();

    try {
      const granted = await loadEmployeePermissions();
      if (required.some((id) => granted.has(id))) return next();
      return res.status(403).json({
        success: false,
        message: 'You do not have permission for this module. Please contact your admin.',
      });
    } catch (err) {
      console.error('❌ requireEmployeePermission error:', err);
      return res.status(500).json({ success: false, message: 'Permission check failed' });
    }
  };
}

module.exports = {
  EMPLOYEE_PERMISSIONS,
  requireEmployeePermission,
  invalidateEmployeePermissionCache,
};
