'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('contact_info', 'image', {
      type: Sequelize.TEXT,
      allowNull: true,
      comment: 'URL of the contact image displayed on frontend',
      after: 'id', // Add after id column
    });
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.removeColumn('contact_info', 'image');
  },
};
