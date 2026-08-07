'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    try {
      await queryInterface.addColumn('Sports', 'sportComplexId', {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: {
          model: 'SportComplexes',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
      });
    } catch (error) {
      console.log('Column sportComplexId already exists in Sports table, skipping...');
    }
  },
  async down(queryInterface) {
    await queryInterface.removeColumn('Sports', 'sportComplexId');
  },
};
