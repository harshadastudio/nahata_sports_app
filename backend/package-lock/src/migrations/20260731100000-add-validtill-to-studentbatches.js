'use strict';

/**
 * Per-student enrollment validity: the date up to which a student's enrollment
 * (and therefore their gate pass) stays valid. Entered by the coach on the fee
 * record, and shown to the student under Students / Parents → Enrollments.
 *
 * Distinct from Batch.endDate, which is the batch-wide end date: a student who
 * paid for 3 months of a running batch has their own valid-till. When this is
 * null the batch end date is used as before.
 *
 * Idempotent: the addColumn is guarded by describeTable.
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    const studentBatches = await queryInterface.describeTable('StudentBatches');

    if (!studentBatches.validTill) {
      await queryInterface.addColumn('StudentBatches', 'validTill', {
        type: Sequelize.DATEONLY,
        allowNull: true,
      });
    }
  },

  async down(queryInterface) {
    await queryInterface.removeColumn('StudentBatches', 'validTill').catch(() => {});
  },
};
