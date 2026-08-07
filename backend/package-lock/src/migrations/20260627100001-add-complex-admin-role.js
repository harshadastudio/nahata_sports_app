'use strict';

/**
 * Per-Complex Admin separation — Phase 1b.
 *
 *  - Adds 'COMPLEX_ADMIN' to the Users.role enum.
 *  - Adds 'complex_admin' to the RolePermissions.role enum (kept available for parity).
 *  - Inserts a Roles row "Complex Admin" mirroring ADMIN's permission set, so a complex
 *    admin sees the same menus an admin does; the panel then hides super-admin-only
 *    sections based on the isComplexAdmin flag, and the API enforces the data scope.
 *
 * Postgres only (the app's dialect). Enum values are added with IF NOT EXISTS so the
 * migration is safe to re-run.
 *
 * @type {import('sequelize-cli').Migration}
 */
module.exports = {
  async up(queryInterface) {
    const sequelize = queryInterface.sequelize;
    const isPostgres = sequelize.getDialect() === 'postgres';

    if (isPostgres) {
      await sequelize.query(
        `ALTER TYPE "enum_Users_role" ADD VALUE IF NOT EXISTS 'COMPLEX_ADMIN';`
      );
      console.log("✅ Added 'COMPLEX_ADMIN' to enum_Users_role");

      // RolePermissions enum may not exist on very old DBs; guard it.
      try {
        await sequelize.query(
          `ALTER TYPE "enum_RolePermissions_role" ADD VALUE IF NOT EXISTS 'complex_admin';`
        );
        console.log("✅ Added 'complex_admin' to enum_RolePermissions_role");
      } catch (e) {
        console.log('⏭️  Skipped enum_RolePermissions_role:', e.message);
      }
    } else {
      console.log('⏭️  Non-postgres dialect: skipping enum ALTER (handled by model sync)');
    }

    // Insert the Roles row, mirroring ADMIN's permissions. Avoid duplicates.
    await sequelize.query(`
      INSERT INTO "Roles" (name, display_name, description, permissions, is_active, is_system, "createdAt", "updatedAt")
      SELECT 'COMPLEX_ADMIN',
             'Complex Admin',
             'Manages a single sports complex (bookings, coaches, employees, security, fees, courts, sports).',
             COALESCE((SELECT permissions FROM "Roles" WHERE name = 'ADMIN' LIMIT 1), '{}'),
             true,
             true,
             NOW(),
             NOW()
      WHERE NOT EXISTS (SELECT 1 FROM "Roles" WHERE name = 'COMPLEX_ADMIN');
    `);
    console.log('✅ Ensured Roles row for COMPLEX_ADMIN');
  },

  async down(queryInterface) {
    const sequelize = queryInterface.sequelize;
    // Remove only the Roles row. Postgres cannot drop a single enum value safely, so the
    // enum labels are intentionally left in place (harmless, and avoids data loss).
    await sequelize.query(`DELETE FROM "Roles" WHERE name = 'COMPLEX_ADMIN';`);
    console.log('✅ Removed Roles row for COMPLEX_ADMIN (enum labels left intact)');
  },
};
