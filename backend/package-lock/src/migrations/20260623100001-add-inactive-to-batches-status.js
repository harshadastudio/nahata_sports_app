'use strict';

/**
 * Program -> Batch consolidation (Phase 1, step 1).
 * Adds the 'Inactive' value to the Batches.status enum so that Programs
 * (which have an 'Inactive' status) can be copied into Batches without loss.
 *
 * NOTE: This is an enum-only migration on purpose. PostgreSQL's
 * `ALTER TYPE ... ADD VALUE` cannot be used in the same transaction that later
 * references the new value, so the enum change is isolated in its own file and
 * the data backfill that uses 'Inactive' runs in a later migration.
 */
module.exports = {
  async up(queryInterface) {
    await queryInterface.sequelize.query(
      `ALTER TYPE "enum_Batches_status" ADD VALUE IF NOT EXISTS 'Inactive';`
    );
  },

  async down() {
    // PostgreSQL cannot remove a value from an enum type. No-op.
  },
};
