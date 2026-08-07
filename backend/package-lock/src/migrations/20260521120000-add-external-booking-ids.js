'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    const complexTable = await queryInterface.describeTable('SportComplexes');
    if (!complexTable.externalOrgId) {
      await queryInterface.addColumn('SportComplexes', 'externalOrgId', {
        type: Sequelize.INTEGER,
        allowNull: true,
      });
      console.log('✅ Added externalOrgId column to SportComplexes table');
    }
    if (!complexTable.externalSiteId) {
      await queryInterface.addColumn('SportComplexes', 'externalSiteId', {
        type: Sequelize.INTEGER,
        allowNull: true,
      });
      console.log('✅ Added externalSiteId column to SportComplexes table');
    }
    if (!complexTable.externalSiteUuid) {
      await queryInterface.addColumn('SportComplexes', 'externalSiteUuid', {
        type: Sequelize.STRING(255),
        allowNull: true,
      });
      console.log('✅ Added externalSiteUuid column to SportComplexes table');
    }

    const courtsTable = await queryInterface.describeTable('Courts');
    if (!courtsTable.externalResourceId) {
      await queryInterface.addColumn('Courts', 'externalResourceId', {
        type: Sequelize.INTEGER,
        allowNull: true,
      });
      console.log('✅ Added externalResourceId column to Courts table');
    }
    if (!courtsTable.externalResourceUuid) {
      await queryInterface.addColumn('Courts', 'externalResourceUuid', {
        type: Sequelize.STRING(255),
        allowNull: true,
      });
      console.log('✅ Added externalResourceUuid column to Courts table');
    }
  },

  async down(queryInterface, Sequelize) {
    const complexTable = await queryInterface.describeTable('SportComplexes');
    if (complexTable.externalOrgId) {
      await queryInterface.removeColumn('SportComplexes', 'externalOrgId');
      console.log('✅ Removed externalOrgId column from SportComplexes table');
    }
    if (complexTable.externalSiteId) {
      await queryInterface.removeColumn('SportComplexes', 'externalSiteId');
      console.log('✅ Removed externalSiteId column from SportComplexes table');
    }
    if (complexTable.externalSiteUuid) {
      await queryInterface.removeColumn('SportComplexes', 'externalSiteUuid');
      console.log('✅ Removed externalSiteUuid column from SportComplexes table');
    }

    const courtsTable = await queryInterface.describeTable('Courts');
    if (courtsTable.externalResourceId) {
      await queryInterface.removeColumn('Courts', 'externalResourceId');
      console.log('✅ Removed externalResourceId column from Courts table');
    }
    if (courtsTable.externalResourceUuid) {
      await queryInterface.removeColumn('Courts', 'externalResourceUuid');
      console.log('✅ Removed externalResourceUuid column from Courts table');
    }
  }
};
