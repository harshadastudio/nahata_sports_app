'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.addColumn('Memberships', 'features', {
      type: Sequelize.TEXT,
      allowNull: true,
      comment: 'Comma-separated list of features',
    });
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.removeColumn('Memberships', 'features');
  }
};
