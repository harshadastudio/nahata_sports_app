'use strict';

/**
 * Program -> Batch consolidation (Phase 5 — CONTRACT / DESTRUCTIVE).
 *
 * Run this ONLY after:
 *   1. The Phase 1-2 migrations have run and the verification SQL passed
 *      (every Program copied, every StudentProgram copied, no NULL enquiry batchId).
 *   2. The rewritten backend code (which only reads Batch/StudentBatches) is deployed
 *      and soaked.
 *   3. A fresh database backup has been taken — this migration is effectively
 *      irreversible (the down() recreates empty shells only).
 *
 * It:
 *   - re-runs the backfill (defensive catch-up) — safe because it is guarded;
 *   - enforces CoachingEnquiries.batchId NOT NULL;
 *   - drops the legacy programId columns/FKs from CoachingEnquiries and FeeStructures;
 *   - drops the StudentPrograms and Programs tables.
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    const { sequelize } = queryInterface;

    // 0. Defensive catch-up backfill for any rows created during the soak window.
    await sequelize.query(`
      INSERT INTO "Batches"
        ("name","sportId","coachId","days","startDate","endDate","maxStudents",
         "currentStudents","status","fees","description","ageGroup","duration",
         "startTime","endTime","features","image","legacyProgramId","createdAt","updatedAt")
      SELECT p."name", p."sportId", p."coachId", p."batchDays",
             COALESCE(p."startDate", p."createdAt"::date, CURRENT_DATE),
             p."endDate", p."maxStudents", p."currentStudents",
             p."status"::text::"enum_Batches_status", p."price",
             p."description", p."ageGroup", p."duration", p."startTime", p."endTime",
             p."features", p."image", p."id", p."createdAt", p."updatedAt"
      FROM "Programs" p
      WHERE NOT EXISTS (SELECT 1 FROM "Batches" b WHERE b."legacyProgramId" = p."id");
    `);
    await sequelize.query(`
      UPDATE "CoachingEnquiries" ce SET "batchId" = b."id"
      FROM "Batches" b
      WHERE b."legacyProgramId" = ce."programId" AND ce."batchId" IS NULL;
    `);
    await sequelize.query(`
      UPDATE "FeeStructures" fs SET "batchId" = b."id"
      FROM "Batches" b
      WHERE b."legacyProgramId" = fs."programId" AND fs."programId" IS NOT NULL AND fs."batchId" IS NULL;
    `);

    // Safety guard: refuse to continue if any enquiry would violate NOT NULL.
    const [[{ orphan_count }]] = await sequelize.query(
      `SELECT COUNT(*)::int AS orphan_count FROM "CoachingEnquiries" WHERE "batchId" IS NULL;`
    );
    if (orphan_count > 0) {
      throw new Error(
        `Aborting: ${orphan_count} CoachingEnquiries still have a NULL batchId. ` +
        `Resolve these before dropping Program tables.`
      );
    }

    // 1. Enforce NOT NULL on CoachingEnquiries.batchId.
    await queryInterface.changeColumn('CoachingEnquiries', 'batchId', {
      type: Sequelize.INTEGER,
      allowNull: false,
      references: { model: 'Batches', key: 'id' },
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE',
    });

    // 2. Drop the legacy programId columns (their FKs drop with them).
    const enquiries = await queryInterface.describeTable('CoachingEnquiries');
    if (enquiries.programId) {
      await queryInterface.removeColumn('CoachingEnquiries', 'programId');
    }
    const feeStructures = await queryInterface.describeTable('FeeStructures');
    if (feeStructures.programId) {
      await queryInterface.removeColumn('FeeStructures', 'programId');
    }

    // 3. Drop the legacy tables (StudentPrograms first — it FKs to Programs).
    await queryInterface.dropTable('StudentPrograms');
    await queryInterface.dropTable('Programs');

    // 4. Drop now-orphaned enum types created for those tables.
    for (const t of [
      'enum_StudentPrograms_status',
      'enum_StudentPrograms_paymentStatus',
      'enum_StudentPrograms_approvalStatus',
      'enum_Programs_status',
    ]) {
      await sequelize.query(`DROP TYPE IF EXISTS "${t}";`).catch(() => {});
    }

    // NOTE: Batches.legacyProgramId is intentionally kept for traceability /
    // manual merge review. Drop it in a later migration once no longer needed.
  },

  async down(queryInterface, Sequelize) {
    // Best-effort only: recreates empty table shells + the programId columns.
    // Data is NOT restored — restore from backup instead.
    await queryInterface.createTable('Programs', {
      id: { type: Sequelize.INTEGER, autoIncrement: true, primaryKey: true },
      sportId: { type: Sequelize.INTEGER, allowNull: false },
      name: { type: Sequelize.STRING, allowNull: false },
      description: { type: Sequelize.TEXT },
      ageGroup: { type: Sequelize.STRING },
      duration: { type: Sequelize.STRING },
      price: { type: Sequelize.DECIMAL(10, 2), allowNull: false, defaultValue: 0 },
      batchDays: { type: Sequelize.STRING },
      startTime: { type: Sequelize.TIME },
      endTime: { type: Sequelize.TIME },
      coachId: { type: Sequelize.INTEGER },
      maxStudents: { type: Sequelize.INTEGER, defaultValue: 20 },
      currentStudents: { type: Sequelize.INTEGER, defaultValue: 0 },
      startDate: { type: Sequelize.DATEONLY },
      endDate: { type: Sequelize.DATEONLY },
      status: { type: Sequelize.ENUM('Active', 'Inactive', 'Completed', 'Cancelled'), defaultValue: 'Active' },
      features: { type: Sequelize.TEXT },
      image: { type: Sequelize.STRING },
      createdAt: { allowNull: false, type: Sequelize.DATE },
      updatedAt: { allowNull: false, type: Sequelize.DATE },
    });

    await queryInterface.createTable('StudentPrograms', {
      id: { type: Sequelize.INTEGER, autoIncrement: true, primaryKey: true },
      studentId: { type: Sequelize.INTEGER, allowNull: false, references: { model: 'Students', key: 'id' } },
      programId: { type: Sequelize.INTEGER, allowNull: false, references: { model: 'Programs', key: 'id' } },
      enrollmentDate: { type: Sequelize.DATEONLY, allowNull: false },
      status: { type: Sequelize.ENUM('Active', 'Completed', 'Dropped', 'Suspended'), defaultValue: 'Active' },
      paymentStatus: { type: Sequelize.ENUM('Pending', 'Paid', 'Partial', 'Overdue'), defaultValue: 'Pending' },
      amountPaid: { type: Sequelize.DECIMAL(10, 2), defaultValue: 0 },
      notes: { type: Sequelize.TEXT },
      approvalStatus: { type: Sequelize.ENUM('Pending', 'Approved', 'Rejected'), allowNull: false, defaultValue: 'Pending' },
      approvedBy: { type: Sequelize.INTEGER, references: { model: 'Users', key: 'id' } },
      approvedAt: { type: Sequelize.DATE },
      createdAt: { allowNull: false, type: Sequelize.DATE },
      updatedAt: { allowNull: false, type: Sequelize.DATE },
    });

    await queryInterface.addColumn('FeeStructures', 'programId', {
      type: Sequelize.INTEGER, allowNull: true, references: { model: 'Programs', key: 'id' },
    });
    await queryInterface.addColumn('CoachingEnquiries', 'programId', {
      type: Sequelize.INTEGER, allowNull: true, references: { model: 'Programs', key: 'id' },
    });
  },
};
