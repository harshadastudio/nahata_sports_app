'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    const tables = await queryInterface.showAllTables();

    if (tables.includes('EventPasses')) {
      const cols = await queryInterface.describeTable('EventPasses');

      if (!cols.faqs) {
        await queryInterface.addColumn('EventPasses', 'faqs', {
          type: Sequelize.JSONB,
          allowNull: false,
          defaultValue: [],
        });
        console.log('✅ Added faqs to EventPasses');
      }
    }
  },

  async down(queryInterface) {
    const tables = await queryInterface.showAllTables();

    if (tables.includes('EventPasses')) {
      const cols = await queryInterface.describeTable('EventPasses');
      if (cols.faqs) await queryInterface.removeColumn('EventPasses', 'faqs');
    }
  },
};
