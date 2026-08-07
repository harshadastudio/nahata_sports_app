/**
 * Permissions Controller
 * Handles saving and retrieving role-based permissions.
 * Admin panel calls POST /api/permissions/:role to save.
 * Frontend calls GET /api/permissions/:role to read.
 *
 * Permissions are persisted in the RolePermissions DB table so they survive
 * server restarts.  The hardcoded defaults below are used only as a seed when
 * no rows exist for a given role.
 */

const { RolePermission } = require('../models');

// Default permissions used to seed the DB on first access per role.
const DEFAULT_PERMISSIONS = {
  user: [
    'user_dashboard', 'user_view_sports', 'user_feedback', 'user_my_bookings',
    'user_my_event_pass', 'user_coaching_enquiries', 'user_students_parents',
    'user_entry_pass', 'user_attendance_sheet', 'user_account', 'user_logout',
  ],
  employee: [
    'employee_dashboard', 'employee_bookings', 'employee_users',
    'employee_payments', 'employee_attendance', 'employee_fees_approval',
    'employee_coaching_enquiries', 'employee_coaches', 'employee_notifications',
  ],
  coach: [
    'coach_dashboard', 'coach_students', 'coach_schedule',
    'coach_attendance', 'coach_performance', 'coach_notifications',
  ],
  security_guard: [
    'security_dashboard', 'security_event_pass_scanner', 'security_court_pass_scanner',
    'security_verify_pass', 'security_generate_pass', 'security_visitor_list',
    'security_notifications',
  ],
};

const VALID_ROLES = ['user', 'employee', 'coach', 'security_guard'];

/**
 * GET /api/permissions/:role
 * Returns the current permission array for a role from the DB.
 * Seeds defaults if no rows exist yet for that role.
 * Public — no auth required (frontend reads this on login).
 */
const getPermissions = async (req, res) => {
  const { role } = req.params;

  if (!VALID_ROLES.includes(role)) {
    return res.status(400).json({
      success: false,
      message: `Invalid role. Must be one of: ${VALID_ROLES.join(', ')}`,
    });
  }

  try {
    let rows = await RolePermission.findAll({
      where: { role, isActive: true },
      attributes: ['permission'],
    });

    // Seed defaults into DB if this role has no rows yet
    if (rows.length === 0) {
      const defaults = DEFAULT_PERMISSIONS[role] || [];
      if (defaults.length > 0) {
        await RolePermission.bulkCreate(
          defaults.map((permission) => ({ role, permission, isActive: true })),
          { ignoreDuplicates: true }
        );
        rows = await RolePermission.findAll({
          where: { role, isActive: true },
          attributes: ['permission'],
        });
        console.log(`ℹ️  Seeded default permissions for role "${role}"`);
      }
    }

    const permissions = rows.map((r) => r.permission);

    return res.status(200).json({ success: true, role, permissions });
  } catch (err) {
    console.error('❌ getPermissions error:', err);
    // Fall back to hardcoded defaults so the frontend never breaks
    return res.status(200).json({
      success: true,
      role,
      permissions: DEFAULT_PERMISSIONS[role] || [],
    });
  }
};

/**
 * POST /api/permissions/:role
 * Replaces the permission set for a role in the DB.
 * Requires ADMIN authentication.
 * Body: { permissions: string[] }
 */
const savePermissions = async (req, res) => {
  const { role } = req.params;
  const { permissions } = req.body;

  if (!VALID_ROLES.includes(role)) {
    return res.status(400).json({
      success: false,
      message: `Invalid role. Must be one of: ${VALID_ROLES.join(', ')}`,
    });
  }

  if (!Array.isArray(permissions)) {
    return res.status(400).json({
      success: false,
      message: 'permissions must be an array of strings',
    });
  }

  try {
    // Delete all existing rows for this role, then insert the new set
    await RolePermission.destroy({ where: { role } });

    if (permissions.length > 0) {
      await RolePermission.bulkCreate(
        permissions.map((permission) => ({ role, permission, isActive: true })),
        { ignoreDuplicates: true }
      );
    }

    // The API-side employee gate caches this set — drop it so the admin's
    // change takes effect immediately instead of after the TTL.
    if (role === 'employee') {
      require('../middleware/employeePermission').invalidateEmployeePermissionCache();
    }

    console.log(`✅ Permissions saved for role "${role}":`, permissions);

    return res.status(200).json({
      success: true,
      message: `Permissions for role "${role}" saved successfully`,
      role,
      permissions,
    });
  } catch (err) {
    console.error('❌ savePermissions error:', err);
    return res.status(500).json({ success: false, message: err.message });
  }
};

module.exports = { getPermissions, savePermissions };
