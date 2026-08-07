'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('SportComplexes', 'sportsOffered', {
      type: Sequelize.JSON,
      allowNull: true,
      defaultValue: null,
    });
    await queryInterface.addColumn('SportComplexes', 'mapUrl', {
      type: Sequelize.TEXT,
      allowNull: true,
      defaultValue: null,
    });
    await queryInterface.addColumn('SportComplexes', 'showOnFrontend', {
      type: Sequelize.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    });
  },
  async down(queryInterface) {
    await queryInterface.removeColumn('SportComplexes', 'sportsOffered');
    await queryInterface.removeColumn('SportComplexes', 'mapUrl');
    await queryInterface.removeColumn('SportComplexes', 'showOnFrontend');
  },
};
