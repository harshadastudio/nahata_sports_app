'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    try {
      await queryInterface.addColumn('Sports', 'showOnFrontend', {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: true,
      });
    } catch (error) {
      console.log('Column showOnFrontend already exists in Sports table, skipping...');
    }
  },
  async down(queryInterface) {
    await queryInterface.removeColumn('Sports', 'showOnFrontend');
  },
};
