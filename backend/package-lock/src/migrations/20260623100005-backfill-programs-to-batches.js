'use strict';

/**
 * Program -> Batch consolidation (Phase 2).
 *
 * Copies all existing Program data into the (now expanded) Batch tables:
 *   1. Programs            -> Batches            (tagged via legacyProgramId)
 *   2. StudentPrograms     -> StudentBatches     (payment/approval fields preserved)
 *   3. CoachingEnquiries.programId -> .batchId   (re-pointed via the map)
 *   4. FeeStructures.programId     -> .batchId   (re-pointed via the map)
 *
 * Idempotent / re-runnable:
 *   - Step 1 skips programs already copied (legacyProgramId match).
 *   - Step 2 skips (studentId, batchId) pairs that already exist (unique guard).
 *   - Steps 3 & 4 only touch rows whose batchId is still NULL.
 *
 * Field mapping: price -> fees, batchDays -> days, status copied (cast across
 * enum types via ::text), startDate falls back to createdAt::date / today to
 * satisfy Batches.startDate NOT NULL.
 *
 * Enum cross-casts (e.g. p.status::text::"enum_Batches_status") rely on the new
 * enum values added in migrations 20260623100001/2, which committed first.
 */
module.exports = {
  async up(queryInterface) {
    const { sequelize } = queryInterface;

    await sequelize.transaction(async (transaction) => {
      // 1. Programs -> Batches
      await sequelize.query(
        `
        INSERT INTO "Batches"
          ("name", "sportId", "coachId", "days", "startDate", "endDate",
           "maxStudents", "currentStudents", "status", "fees",
           "description", "ageGroup", "duration", "startTime", "endTime",
           "features", "image", "legacyProgramId", "createdAt", "updatedAt")
        SELECT
          p."name", p."sportId", p."coachId", p."batchDays",
          COALESCE(p."startDate", p."createdAt"::date, CURRENT_DATE),
          p."endDate", p."maxStudents", p."currentStudents",
          p."status"::text::"enum_Batches_status", p."price",
          p."description", p."ageGroup", p."duration", p."startTime", p."endTime",
          p."features", p."image", p."id", p."createdAt", p."updatedAt"
        FROM "Programs" p
        WHERE NOT EXISTS (
          SELECT 1 FROM "Batches" b WHERE b."legacyProgramId" = p."id"
        );
        `,
        { transaction }
      );

      // 2. StudentPrograms -> StudentBatches
      await sequelize.query(
        `
        INSERT INTO "StudentBatches"
          ("studentId", "batchId", "enrollmentDate", "status", "feesPaid",
           "paymentStatus", "amountPaid", "notes", "approvalStatus",
           "approvedBy", "approvedAt", "createdAt", "updatedAt")
        SELECT
          sp."studentId", b."id", sp."enrollmentDate",
          (CASE
             WHEN sp."status"::text = 'Suspended' THEN 'Suspended'
             WHEN sp."status"::text = 'Dropped'   THEN 'Dropped'
             WHEN sp."status"::text = 'Completed' THEN 'Completed'
             ELSE 'Active'
           END)::"enum_StudentBatches_status",
          (sp."paymentStatus"::text = 'Paid'),
          sp."paymentStatus"::text::"enum_StudentBatches_paymentStatus",
          sp."amountPaid", sp."notes",
          sp."approvalStatus"::text::"enum_StudentBatches_approvalStatus",
          sp."approvedBy", sp."approvedAt", sp."createdAt", sp."updatedAt"
        FROM "StudentPrograms" sp
        JOIN "Batches" b ON b."legacyProgramId" = sp."programId"
        WHERE NOT EXISTS (
          SELECT 1 FROM "StudentBatches" x
          WHERE x."studentId" = sp."studentId" AND x."batchId" = b."id"
        );
        `,
        { transaction }
      );

      // 3. CoachingEnquiries.programId -> batchId
      await sequelize.query(
        `
        UPDATE "CoachingEnquiries" ce
        SET "batchId" = b."id"
        FROM "Batches" b
        WHERE b."legacyProgramId" = ce."programId" AND ce."batchId" IS NULL;
        `,
        { transaction }
      );

      // 4. FeeStructures.programId -> batchId
      await sequelize.query(
        `
        UPDATE "FeeStructures" fs
        SET "batchId" = b."id"
        FROM "Batches" b
        WHERE b."legacyProgramId" = fs."programId"
          AND fs."programId" IS NOT NULL
          AND fs."batchId" IS NULL;
        `,
        { transaction }
      );
    });
  },

  async down(queryInterface) {
    const { sequelize } = queryInterface;

    // Best-effort reversal: every program-derived batch is tagged via
    // legacyProgramId, so we can cleanly remove the rows this migration created.
    await sequelize.transaction(async (transaction) => {
      await sequelize.query(
        `
        DELETE FROM "StudentBatches" sb
        USING "Batches" b
        WHERE sb."batchId" = b."id" AND b."legacyProgramId" IS NOT NULL;
        `,
        { transaction }
      );
      await sequelize.query(
        `
        UPDATE "CoachingEnquiries" ce
        SET "batchId" = NULL
        FROM "Batches" b
        WHERE ce."batchId" = b."id" AND b."legacyProgramId" IS NOT NULL;
        `,
        { transaction }
      );
      await sequelize.query(
        `
        UPDATE "FeeStructures" fs
        SET "batchId" = NULL
        FROM "Batches" b
        WHERE fs."batchId" = b."id" AND b."legacyProgramId" IS NOT NULL;
        `,
        { transaction }
      );
      await sequelize.query(
        `DELETE FROM "Batches" WHERE "legacyProgramId" IS NOT NULL;`,
        { transaction }
      );
    });
  },
};
