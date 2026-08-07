'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('contact_info', 'description', {
      type: Sequelize.TEXT,
      allowNull: true,
      comment: 'Description text displayed in the info banner on frontend',
      after: 'hours',
    });
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.removeColumn('contact_info', 'description');
  },
};
