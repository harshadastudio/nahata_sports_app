'use strict';

/**
 * Google / passwordless sign-ups create a User with no password, but the
 * Users.password column was still NOT NULL at the DB level (schema drift from
 * the original create-users migration). New Google users therefore failed with
 * "null value in column \"password\" ... violates not-null constraint".
 * This aligns the DB with the model (user.js: password allowNull: true).
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.changeColumn('Users', 'password', {
      type: Sequelize.STRING,
      allowNull: true,
    });
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.changeColumn('Users', 'password', {
      type: Sequelize.STRING,
      allowNull: false,
    });
  },
};
