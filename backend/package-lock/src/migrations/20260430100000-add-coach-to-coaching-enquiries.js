'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.addColumn('CoachingEnquiries', 'coachId', {
      type: Sequelize.INTEGER,
      allowNull: true,
      references: {
        model: 'Coaches',
        key: 'id'
      },
      onUpdate: 'CASCADE',
      onDelete: 'SET NULL'
    });
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.removeColumn('CoachingEnquiries', 'coachId');
  }
};
