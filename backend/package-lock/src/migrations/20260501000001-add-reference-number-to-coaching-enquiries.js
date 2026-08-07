'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('CoachingEnquiries', 'referenceNumber', {
      type: Sequelize.STRING,
      allowNull: true,
      unique: true,
      after: 'message'
    });
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.removeColumn('CoachingEnquiries', 'referenceNumber');
  }
};
