'use strict';

/**
 * Per-Complex Admin separation — Phase 1a.
 *
 * Adds a nullable `sportComplexId` FK (→ SportComplexes.id) to every table that a
 * COMPLEX_ADMIN must be scoped on but that did not already carry the column.
 *
 * Courts / Sports / Batches / Coupons already have sportComplexId, so they are NOT here.
 * Bookings / Students / Fees stay un-columned — they scope through a join
 * (Court.sportComplexId / Batch.sportComplexId).
 *
 * NULL = unassigned / global (e.g. an ADMIN super-admin User).
 *
 * @type {import('sequelize-cli').Migration}
 */
const TABLES = [
  'Users',
  'Coaches',
  'Enquiries',
  'CoachingEnquiries',
  'Employees',
  'SecurityGuards',
  'VisitorPasses',
  'EventPasses',
];

module.exports = {
  async up(queryInterface, Sequelize) {
    const allTables = await queryInterface.showAllTables();
    for (const table of TABLES) {
      if (!allTables.includes(table)) {
        console.log(`⏭️  Skipped: ${table} table does not exist`);
        continue;
      }
      const desc = await queryInterface.describeTable(table);
      if (desc.sportComplexId) {
        console.log(`⏭️  Skipped: ${table}.sportComplexId already exists`);
        continue;
      }
      await queryInterface.addColumn(table, 'sportComplexId', {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: { model: 'SportComplexes', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
      });
      console.log(`✅ Added sportComplexId to ${table}`);
    }
  },

  async down(queryInterface) {
    const allTables = await queryInterface.showAllTables();
    for (const table of TABLES) {
      if (!allTables.includes(table)) continue;
      const desc = await queryInterface.describeTable(table);
      if (!desc.sportComplexId) continue;
      await queryInterface.removeColumn(table, 'sportComplexId');
      console.log(`✅ Removed sportComplexId from ${table}`);
    }
  },
};
