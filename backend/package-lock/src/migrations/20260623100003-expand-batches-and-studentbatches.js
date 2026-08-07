'use strict';

/**
 * Program -> Batch consolidation (Phase 1, step 3).
 *
 * Makes Batch a superset of Program, and StudentBatches a superset of
 * StudentProgram, so all Program/StudentProgram data (offerings, fees, gate
 * passes, approvals) can be migrated into the Batch tables without loss.
 *
 *  - Batches gains Program's offering fields + a temporary `legacyProgramId`
 *    column used as the program->batch id map during the data backfill.
 *  - StudentBatches gains StudentProgram's payment/approval columns (the Fees
 *    and Gate-Pass system is built entirely on these columns).
 *
 * Idempotent: every addColumn is guarded by describeTable.
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    const batches = await queryInterface.describeTable('Batches');

    const batchColumns = {
      description: { type: Sequelize.TEXT, allowNull: true },
      ageGroup: { type: Sequelize.STRING, allowNull: true },
      duration: { type: Sequelize.STRING, allowNull: true },
      startTime: { type: Sequelize.TIME, allowNull: true },
      endTime: { type: Sequelize.TIME, allowNull: true },
      features: { type: Sequelize.TEXT, allowNull: true },
      image: { type: Sequelize.STRING, allowNull: true },
      legacyProgramId: { type: Sequelize.INTEGER, allowNull: true },
    };

    for (const [name, spec] of Object.entries(batchColumns)) {
      if (!batches[name]) {
        await queryInterface.addColumn('Batches', name, spec);
      }
    }

    // Index legacyProgramId for the backfill joins (guarded — ignore if it already exists).
    try {
      await queryInterface.addIndex('Batches', ['legacyProgramId'], {
        name: 'batches_legacy_program_id',
      });
    } catch (err) {
      if (!/already exists/i.test(err.message)) throw err;
    }

    const studentBatches = await queryInterface.describeTable('StudentBatches');

    const studentBatchColumns = {
      paymentStatus: {
        type: Sequelize.ENUM('Pending', 'Paid', 'Partial', 'Overdue'),
        allowNull: false,
        defaultValue: 'Pending',
      },
      amountPaid: {
        type: Sequelize.DECIMAL(10, 2),
        allowNull: false,
        defaultValue: 0,
      },
      notes: { type: Sequelize.TEXT, allowNull: true },
      approvalStatus: {
        type: Sequelize.ENUM('Pending', 'Approved', 'Rejected'),
        allowNull: false,
        defaultValue: 'Pending',
      },
      approvedBy: {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: { model: 'Users', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
      },
      approvedAt: { type: Sequelize.DATE, allowNull: true },
    };

    for (const [name, spec] of Object.entries(studentBatchColumns)) {
      if (!studentBatches[name]) {
        await queryInterface.addColumn('StudentBatches', name, spec);
      }
    }
  },

  async down(queryInterface) {
    for (const name of ['paymentStatus', 'amountPaid', 'notes', 'approvalStatus', 'approvedBy', 'approvedAt']) {
      await queryInterface.removeColumn('StudentBatches', name).catch(() => {});
    }
    // Drop the generated enum types so a re-run of up() recreates them cleanly.
    await queryInterface.sequelize.query('DROP TYPE IF EXISTS "enum_StudentBatches_paymentStatus";').catch(() => {});
    await queryInterface.sequelize.query('DROP TYPE IF EXISTS "enum_StudentBatches_approvalStatus";').catch(() => {});

    await queryInterface.removeIndex('Batches', 'batches_legacy_program_id').catch(() => {});
    for (const name of ['description', 'ageGroup', 'duration', 'startTime', 'endTime', 'features', 'image', 'legacyProgramId']) {
      await queryInterface.removeColumn('Batches', name).catch(() => {});
    }
  },
};
