'use strict';

/**
 * Program -> Batch consolidation (Phase 1, step 4).
 *
 * Adds a nullable `batchId` FK to CoachingEnquiries and FeeStructures so the
 * backfill can re-point them from Programs to the migrated Batches. `batchId`
 * stays nullable until Phase 5 (after backfill + code cutover), when
 * CoachingEnquiries.batchId becomes NOT NULL and the legacy programId columns
 * are dropped.
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    const enquiries = await queryInterface.describeTable('CoachingEnquiries');
    if (!enquiries.batchId) {
      await queryInterface.addColumn('CoachingEnquiries', 'batchId', {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: { model: 'Batches', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      });
      await queryInterface.addIndex('CoachingEnquiries', ['batchId']);
    }

    const feeStructures = await queryInterface.describeTable('FeeStructures');
    if (!feeStructures.batchId) {
      await queryInterface.addColumn('FeeStructures', 'batchId', {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: { model: 'Batches', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
      });
      await queryInterface.addIndex('FeeStructures', ['batchId']);
    }
  },

  async down(queryInterface) {
    await queryInterface.removeColumn('FeeStructures', 'batchId').catch(() => {});
    await queryInterface.removeColumn('CoachingEnquiries', 'batchId').catch(() => {});
  },
};
