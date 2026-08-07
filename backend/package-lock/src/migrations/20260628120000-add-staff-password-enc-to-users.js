'use strict';

/**
 * Staff credential viewing — store a recoverable (encrypted-at-rest) copy of the
 * admin-set password for staff login accounts (EMPLOYEE / SECURITY / COACH).
 *
 * `password` stays bcrypt-hashed for authentication. `staff_password_enc` holds
 * an AES-256-GCM ciphertext (see src/utils/secretCrypto.js) that an ADMIN /
 * COMPLEX_ADMIN can decrypt to view the staff member's password. NULL for every
 * other account (regular users, super admins) — they have no viewable password.
 *
 * @type {import('sequelize-cli').Migration}
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    const desc = await queryInterface.describeTable('Users');
    if (desc.staff_password_enc) {
      console.log('⏭️  Skipped: Users.staff_password_enc already exists');
      return;
    }
    await queryInterface.addColumn('Users', 'staff_password_enc', {
      type: Sequelize.TEXT,
      allowNull: true,
      defaultValue: null,
      comment: 'AES-256-GCM encrypted admin-set password for staff logins; viewable by admins. NULL = not stored.',
    });
    console.log('✅ Added staff_password_enc to Users');
  },

  async down(queryInterface) {
    const desc = await queryInterface.describeTable('Users');
    if (!desc.staff_password_enc) return;
    await queryInterface.removeColumn('Users', 'staff_password_enc');
    console.log('✅ Removed staff_password_enc from Users');
  },
};
