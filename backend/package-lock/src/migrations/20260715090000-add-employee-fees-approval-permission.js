'use strict';

/**
 * Employee-facing fee approval (staff dashboard). RolePermissions is
 * lazily seeded on first GET /api/permissions/:role call, so an 'employee'
 * role that was already seeded before this change never picks up the new
 * 'employee_fees_approval' permission on its own — backfill it here.
 *
 * Only touches roles that already have rows (i.e. were already seeded);
 * a role with zero rows will pick up the permission naturally the first
 * time it's seeded from the updated DEFAULT_PERMISSIONS list.
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    const [existingEmployeeRows] = await queryInterface.sequelize.query(
      `SELECT id FROM "RolePermissions" WHERE role = 'employee' LIMIT 1;`
    );
    if (existingEmployeeRows.length === 0) return;

    const [alreadyHasPermission] = await queryInterface.sequelize.query(
      `SELECT id FROM "RolePermissions" WHERE role = 'employee' AND permission = 'employee_fees_approval' LIMIT 1;`
    );
    if (alreadyHasPermission.length > 0) return;

    await queryInterface.bulkInsert('RolePermissions', [{
      role: 'employee',
      permission: 'employee_fees_approval',
      isActive: true,
      createdAt: new Date(),
      updatedAt: new Date(),
    }]);
  },

  async down(queryInterface) {
    await queryInterface.bulkDelete('RolePermissions', {
      role: 'employee',
      permission: 'employee_fees_approval',
    });
  },
};
