'use strict';

/**
 * Coach fee-collection workflow: track HOW a fee was collected and WHO
 * (which staff login — normally the coach) recorded the collection, separate
 * from `approvedBy` (the admin/employee who later approves it).
 *
 * Idempotent: every addColumn is guarded by describeTable.
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    const studentBatches = await queryInterface.describeTable('StudentBatches');

    if (!studentBatches.paymentMode) {
      await queryInterface.addColumn('StudentBatches', 'paymentMode', {
        type: Sequelize.ENUM('Cash', 'UPI', 'Card', 'BankTransfer', 'Cheque', 'Other'),
        allowNull: true,
      });
    }

    if (!studentBatches.receivedBy) {
      await queryInterface.addColumn('StudentBatches', 'receivedBy', {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: { model: 'Users', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
      });
    }
  },

  async down(queryInterface) {
    for (const name of ['paymentMode', 'receivedBy']) {
      await queryInterface.removeColumn('StudentBatches', name).catch(() => {});
    }
    await queryInterface.sequelize.query('DROP TYPE IF EXISTS "enum_StudentBatches_paymentMode";').catch(() => {});
  },
};
