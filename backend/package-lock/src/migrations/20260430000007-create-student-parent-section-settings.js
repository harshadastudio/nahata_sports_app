'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('StudentParentSectionSettings', {
      id: {
        type: Sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true,
      },
      image1: {
        type: Sequelize.STRING(500),
        allowNull: true,
        defaultValue: null,
      },
      image2: {
        type: Sequelize.STRING(500),
        allowNull: true,
        defaultValue: null,
      },
      createdAt: { allowNull: false, type: Sequelize.DATE },
      updatedAt: { allowNull: false, type: Sequelize.DATE },
    });

    // Insert the single default row
    await queryInterface.bulkInsert('StudentParentSectionSettings', [{
      image1: null,
      image2: null,
      createdAt: new Date(),
      updatedAt: new Date(),
    }]);
  },
  async down(queryInterface) {
    await queryInterface.dropTable('StudentParentSectionSettings');
  },
};
