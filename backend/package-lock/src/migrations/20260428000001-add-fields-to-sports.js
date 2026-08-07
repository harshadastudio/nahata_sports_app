'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.addColumn('Sports', 'allowedMembers', {
      type: Sequelize.INTEGER,
      defaultValue: 0,
      after: 'image',
    });

    await queryInterface.addColumn('Sports', 'achievements', {
      type: Sequelize.TEXT,
      allowNull: true,
      after: 'allowedMembers',
    });

    await queryInterface.addColumn('Sports', 'completeInformation', {
      type: Sequelize.TEXT,
      allowNull: true,
      after: 'achievements',
    });
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.removeColumn('Sports', 'allowedMembers');
    await queryInterface.removeColumn('Sports', 'achievements');
    await queryInterface.removeColumn('Sports', 'completeInformation');
  }
};
