'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.addColumn('settings', 'facebookUrl', {
      type: Sequelize.STRING(500),
      allowNull: true,
      defaultValue: null
    });
    await queryInterface.addColumn('settings', 'instagramUrl', {
      type: Sequelize.STRING(500),
      allowNull: true,
      defaultValue: null
    });
    await queryInterface.addColumn('settings', 'twitterUrl', {
      type: Sequelize.STRING(500),
      allowNull: true,
      defaultValue: null
    });
  },

  down: async (queryInterface) => {
    await queryInterface.removeColumn('settings', 'facebookUrl');
    await queryInterface.removeColumn('settings', 'instagramUrl');
    await queryInterface.removeColumn('settings', 'twitterUrl');
  }
};
