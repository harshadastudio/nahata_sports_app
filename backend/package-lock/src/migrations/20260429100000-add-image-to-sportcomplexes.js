'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('SportComplexes', 'image', {
      type: Sequelize.STRING(500),
      allowNull: true,
      defaultValue: null,
      after: 'longitude', // MySQL only; ignored on other DBs
    });
  },

  async down(queryInterface) {
    await queryInterface.removeColumn('SportComplexes', 'image');
  },
};
