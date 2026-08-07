'use strict';

module.exports = {
  async up(queryInterface) {
    await queryInterface.sequelize.query(`
      ALTER TYPE "enum_Notifications_type" ADD VALUE IF NOT EXISTS 'Feedback';
    `);
  },
  async down() {
    // Postgres does not support removing enum values without recreating the type
  },
};
