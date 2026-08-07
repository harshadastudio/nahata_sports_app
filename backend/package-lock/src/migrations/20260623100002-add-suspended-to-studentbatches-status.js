'use strict';

/**
 * Program -> Batch consolidation (Phase 1, step 2).
 * Adds the 'Suspended' value to the StudentBatches.status enum so that
 * StudentPrograms (which can be 'Suspended') can be copied into StudentBatches
 * without loss. Enum-only migration (see note in the batches-status migration).
 */
module.exports = {
  async up(queryInterface) {
    await queryInterface.sequelize.query(
      `ALTER TYPE "enum_StudentBatches_status" ADD VALUE IF NOT EXISTS 'Suspended';`
    );
  },

  async down() {
    // PostgreSQL cannot remove a value from an enum type. No-op.
  },
};
