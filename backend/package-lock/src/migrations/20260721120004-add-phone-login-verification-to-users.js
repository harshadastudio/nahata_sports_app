'use strict';

/**
 * Phone/WhatsApp login + verification support on Users.
 *   - phone_verified       : true once the user has proven ownership via OTP.
 *   - phone_verify_otp      : sha256 of the current 6-digit code (never plaintext).
 *   - phone_verify_expiry   : when that code stops being valid.
 *   - index on phone_number : fast lookups for "log in with WhatsApp number".
 *
 * NOTE: a DB-level UNIQUE constraint on phone_number is intentionally NOT added
 * here — the 454 existing users may contain NULLs and duplicates that would make
 * such a migration fail. Uniqueness is enforced at the application layer on every
 * new write (register / profile update / verify). Add a partial unique index
 * (`WHERE phone_number IS NOT NULL`) later, AFTER de-duplicating existing data.
 * @type {import('sequelize-cli').Migration}
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('Users', 'phone_verified', {
      type: Sequelize.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    });
    await queryInterface.addColumn('Users', 'phone_verify_otp', {
      type: Sequelize.STRING(64),
      allowNull: true,
      defaultValue: null,
    });
    await queryInterface.addColumn('Users', 'phone_verify_expiry', {
      type: Sequelize.DATE,
      allowNull: true,
      defaultValue: null,
    });
    await queryInterface.addIndex('Users', ['phone_number'], { name: 'users_phone_number' });
  },

  async down(queryInterface) {
    await queryInterface.removeIndex('Users', 'users_phone_number');
    await queryInterface.removeColumn('Users', 'phone_verify_expiry');
    await queryInterface.removeColumn('Users', 'phone_verify_otp');
    await queryInterface.removeColumn('Users', 'phone_verified');
  },
};
