'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('Batches', 'sportComplexId', {
      type: Sequelize.INTEGER,
      allowNull: true,
      references: {
        model: 'SportComplexes',
        key: 'id',
      },
      onUpdate: 'CASCADE',
      onDelete: 'SET NULL',
    });
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.removeColumn('Batches', 'sportComplexId');
  }
};
