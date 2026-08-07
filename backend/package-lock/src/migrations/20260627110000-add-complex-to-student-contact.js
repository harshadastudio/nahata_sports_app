'use strict';

/**
 * Per-complex scoping for Students, Contact-Us submissions, and Contact-Info.
 *
 *  - Students.sportComplexId      → the complex a student registered with (so a
 *    self-registered student, who isn't in a batch yet, still scopes correctly).
 *    Backfilled from each student's batch enrollment where available.
 *  - contact_us.sportComplexId    → the complex a website contact enquiry is for.
 *  - contact_info.sportComplexId  → the complex a contact-info entry belongs to.
 *
 * All nullable (NULL = global / unassigned). @type {import('sequelize-cli').Migration}
 */
const TABLES = ['Students', 'contact_us', 'contact_info'];

module.exports = {
  async up(queryInterface, Sequelize) {
    const allTables = await queryInterface.showAllTables();
    for (const table of TABLES) {
      if (!allTables.includes(table)) { console.log(`⏭️  ${table} missing, skip`); continue; }
      const desc = await queryInterface.describeTable(table);
      if (desc.sportComplexId) { console.log(`⏭️  ${table}.sportComplexId exists`); continue; }
      await queryInterface.addColumn(table, 'sportComplexId', {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: { model: 'SportComplexes', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
      });
      console.log(`✅ Added sportComplexId to ${table}`);
    }

    // Backfill each student's home complex from their (first) batch enrollment.
    try {
      const [, meta] = await queryInterface.sequelize.query(`
        UPDATE "Students" s
        SET "sportComplexId" = sub.cid
        FROM (
          SELECT sb."studentId" AS sid, MIN(b."sportComplexId") AS cid
          FROM "StudentBatches" sb
          JOIN "Batches" b ON b.id = sb."batchId"
          WHERE b."sportComplexId" IS NOT NULL
          GROUP BY sb."studentId"
        ) sub
        WHERE s.id = sub.sid AND s."sportComplexId" IS NULL;
      `);
      const rows = (meta && (meta.rowCount ?? meta.affectedRows)) || 0;
      console.log(`✅ Backfilled Students.sportComplexId from batches: ${rows} row(s)`);
    } catch (e) {
      console.log('⏭️  Student backfill skipped:', e.message);
    }
  },

  async down(queryInterface) {
    const allTables = await queryInterface.showAllTables();
    for (const table of TABLES) {
      if (!allTables.includes(table)) continue;
      const desc = await queryInterface.describeTable(table);
      if (desc.sportComplexId) await queryInterface.removeColumn(table, 'sportComplexId');
    }
  },
};
