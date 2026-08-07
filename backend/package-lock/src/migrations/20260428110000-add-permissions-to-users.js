'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up (queryInterface, Sequelize) {
    // Add permissions column to Users table
    await queryInterface.addColumn('Users', 'permissions', {
      type: Sequelize.JSON,
      allowNull: true,
      defaultValue: null,
      comment: 'JSON object containing role-based permissions for the user'
    });
  },

  async down (queryInterface, Sequelize) {
    // Remove permissions column
    await queryInterface.removeColumn('Users', 'permissions');
  }
};
