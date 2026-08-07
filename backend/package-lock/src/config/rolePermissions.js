// Default permissions for each role
const DEFAULT_ROLE_PERMISSIONS = {
  ADMIN: {
    dashboard: { view: true, edit: true, delete: true },
    users: { view: true, create: true, edit: true, delete: true },
    memberships: { view: true, create: true, edit: true, delete: true },
    payments: { view: true, create: true, edit: true, delete: true },
    coupons: { view: true, create: true, edit: true, delete: true },
    reports: { view: true, create: true, edit: true, delete: true },
    sports: { view: true, create: true, edit: true, delete: true },
    courts: { view: true, create: true, edit: true, delete: true },
    sportsComplex: { view: true, create: true, edit: true, delete: true },
    programs: { view: true, create: true, edit: true, delete: true },
    batches: { view: true, create: true, edit: true, delete: true },
    coaches: { view: true, create: true, edit: true, delete: true },
    students: { view: true, create: true, edit: true, delete: true },
    bookings: { view: true, create: true, edit: true, delete: true },
    settings: { view: true, edit: true }
  },
  
  // Complex Admin: a per-complex admin. Full control over the modules they manage
  // (data is complex-scoped by the API), but NO access to super-admin-only areas
  // (global users, membership plans, global coupons, sports-complex CRUD, settings).
  COMPLEX_ADMIN: {
    dashboard: { view: true, edit: true, delete: false },
    users: { view: false, create: false, edit: false, delete: false },
    memberships: { view: false, create: false, edit: false, delete: false },
    payments: { view: true, create: false, edit: false, delete: false },
    coupons: { view: true, create: true, edit: true, delete: true },
    reports: { view: true, create: true, edit: false, delete: false },
    sports: { view: true, create: true, edit: true, delete: true },
    courts: { view: true, create: true, edit: true, delete: true },
    sportsComplex: { view: true, create: false, edit: false, delete: false },
    programs: { view: true, create: true, edit: true, delete: true },
    batches: { view: true, create: true, edit: true, delete: true },
    coaches: { view: true, create: true, edit: true, delete: true },
    students: { view: true, create: true, edit: true, delete: true },
    bookings: { view: true, create: true, edit: true, delete: true },
    settings: { view: false, edit: false }
  },

  USER: {
    dashboard: { view: true, edit: false, delete: false },
    users: { view: false, create: false, edit: false, delete: false },
    memberships: { view: true, create: false, edit: false, delete: false },
    payments: { view: true, create: true, edit: false, delete: false },
    coupons: { view: true, create: false, edit: false, delete: false },
    reports: { view: false, create: false, edit: false, delete: false },
    sports: { view: true, create: false, edit: false, delete: false },
    courts: { view: true, create: false, edit: false, delete: false },
    sportsComplex: { view: true, create: false, edit: false, delete: false },
    programs: { view: true, create: false, edit: false, delete: false },
    batches: { view: true, create: false, edit: false, delete: false },
    coaches: { view: true, create: false, edit: false, delete: false },
    students: { view: false, create: false, edit: false, delete: false },
    bookings: { view: true, create: true, edit: true, delete: true },
    settings: { view: false, edit: false }
  },
  
  EMPLOYEE: {
    dashboard: { view: true, edit: false, delete: false },
    users: { view: true, create: false, edit: false, delete: false },
    memberships: { view: true, create: true, edit: true, delete: false },
    payments: { view: true, create: true, edit: true, delete: false },
    coupons: { view: true, create: false, edit: false, delete: false },
    reports: { view: true, create: false, edit: false, delete: false },
    sports: { view: true, create: false, edit: false, delete: false },
    courts: { view: true, create: false, edit: false, delete: false },
    sportsComplex: { view: true, create: false, edit: false, delete: false },
    programs: { view: true, create: false, edit: false, delete: false },
    batches: { view: true, create: false, edit: false, delete: false },
    coaches: { view: true, create: false, edit: false, delete: false },
    students: { view: true, create: true, edit: true, delete: false },
    bookings: { view: true, create: true, edit: true, delete: false },
    settings: { view: false, edit: false }
  },
  
  COACH: {
    dashboard: { view: true, edit: false, delete: false },
    users: { view: false, create: false, edit: false, delete: false },
    memberships: { view: false, create: false, edit: false, delete: false },
    payments: { view: false, create: false, edit: false, delete: false },
    coupons: { view: false, create: false, edit: false, delete: false },
    reports: { view: true, create: false, edit: false, delete: false },
    sports: { view: true, create: false, edit: false, delete: false },
    courts: { view: true, create: false, edit: false, delete: false },
    sportsComplex: { view: true, create: false, edit: false, delete: false },
    programs: { view: true, create: false, edit: true, delete: false },
    batches: { view: true, create: true, edit: true, delete: false },
    coaches: { view: true, create: false, edit: false, delete: false },
    students: { view: true, create: false, edit: true, delete: false },
    bookings: { view: true, create: false, edit: false, delete: false },
    settings: { view: false, edit: false }
  },
  
  SECURITY: {
    dashboard: { view: true, edit: false, delete: false },
    users: { view: true, create: false, edit: false, delete: false },
    memberships: { view: true, create: false, edit: false, delete: false },
    payments: { view: false, create: false, edit: false, delete: false },
    coupons: { view: false, create: false, edit: false, delete: false },
    reports: { view: false, create: false, edit: false, delete: false },
    sports: { view: true, create: false, edit: false, delete: false },
    courts: { view: true, create: false, edit: false, delete: false },
    sportsComplex: { view: true, create: false, edit: false, delete: false },
    programs: { view: true, create: false, edit: false, delete: false },
    batches: { view: true, create: false, edit: false, delete: false },
    coaches: { view: true, create: false, edit: false, delete: false },
    students: { view: true, create: false, edit: false, delete: false },
    bookings: { view: true, create: false, edit: false, delete: false },
    settings: { view: false, edit: false }
  }
};

/**
 * Get default permissions for a role
 * @param {string} role - User role (ADMIN, USER, EMPLOYEE, COACH, SECURITY)
 * @returns {object} Default permissions object
 */
function getDefaultPermissions(role) {
  return DEFAULT_ROLE_PERMISSIONS[role] || DEFAULT_ROLE_PERMISSIONS.USER;
}

/**
 * Check if user has permission for a specific action
 * @param {object} userPermissions - User's permissions object
 * @param {string} module - Module name (e.g., 'users', 'memberships')
 * @param {string} action - Action type ('view', 'create', 'edit', 'delete')
 * @returns {boolean} True if user has permission
 */
function hasPermission(userPermissions, module, action) {
  if (!userPermissions || !userPermissions[module]) {
    return false;
  }
  return userPermissions[module][action] === true;
}

/**
 * Merge custom permissions with default role permissions
 * @param {string} role - User role
 * @param {object} customPermissions - Custom permissions to override defaults
 * @returns {object} Merged permissions object
 */
function mergePermissions(role, customPermissions) {
  const defaultPerms = getDefaultPermissions(role);
  
  if (!customPermissions) {
    return defaultPerms;
  }
  
  // Deep merge custom permissions with defaults
  const merged = { ...defaultPerms };
  
  Object.keys(customPermissions).forEach(module => {
    if (merged[module]) {
      merged[module] = { ...merged[module], ...customPermissions[module] };
    } else {
      merged[module] = customPermissions[module];
    }
  });
  
  return merged;
}

module.exports = {
  DEFAULT_ROLE_PERMISSIONS,
  getDefaultPermissions,
  hasPermission,
  mergePermissions
};
