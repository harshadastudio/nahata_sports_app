'use strict';

/**
 * Per-Complex Admin separation — Phase 1c (backfill).
 *
 * Assigns all existing un-scoped rows to complex #1 (Sinhagad Road). The Super Admin
 * reassigns any Gangadham Chowk (#2) records afterwards via the admin panel.
 *
 * Idempotent: only touches rows where sportComplexId IS NULL.
 * Users are intentionally NOT backfilled — an ADMIN keeps sportComplexId = NULL (super admin),
 * and COMPLEX_ADMINs are assigned explicitly when created.
 *
 * @type {import('sequelize-cli').Migration}
 */
const DEFAULT_COMPLEX_ID = 1;

const TABLES = [
  'Sports',
  'Batches',
  'Coaches',
  'Employees',
  'Enquiries',
  'CoachingEnquiries',
  'SecurityGuards',
  'VisitorPasses',
  'EventPasses',
];

module.exports = {
  async up(queryInterface) {
    const allTables = await queryInterface.showAllTables();
    for (const table of TABLES) {
      if (!allTables.includes(table)) {
        console.log(`⏭️  Skipped backfill: ${table} does not exist`);
        continue;
      }
      const desc = await queryInterface.describeTable(table);
      if (!desc.sportComplexId) {
        console.log(`⏭️  Skipped backfill: ${table}.sportComplexId missing`);
        continue;
      }
      const [, meta] = await queryInterface.sequelize.query(
        `UPDATE "${table}" SET "sportComplexId" = ${DEFAULT_COMPLEX_ID} WHERE "sportComplexId" IS NULL;`
      );
      const rows = (meta && (meta.rowCount ?? meta.affectedRows)) || 0;
      console.log(`✅ Backfilled ${table}: ${rows} row(s) → complex #${DEFAULT_COMPLEX_ID}`);
    }
  },

  async down() {
    // Non-reversible data backfill. Leaving rows assigned is safe; no-op on rollback.
    console.log('⏭️  Backfill is data-only; down() is a no-op.');
  },
};
