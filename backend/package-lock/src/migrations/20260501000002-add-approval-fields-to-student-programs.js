'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    const tableDescription = await queryInterface.describeTable('StudentPrograms');

    if (!tableDescription.approvalStatus) {
      await queryInterface.addColumn('StudentPrograms', 'approvalStatus', {
        type: Sequelize.ENUM('Pending', 'Approved', 'Rejected'),
        defaultValue: 'Pending',
        allowNull: false,
        after: 'notes',
      });
    }

    if (!tableDescription.approvedBy) {
      await queryInterface.addColumn('StudentPrograms', 'approvedBy', {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: { model: 'Users', key: 'id' },
        after: 'approvalStatus',
      });
    }

    if (!tableDescription.approvedAt) {
      await queryInterface.addColumn('StudentPrograms', 'approvedAt', {
        type: Sequelize.DATE,
        allowNull: true,
        after: 'approvedBy',
      });
    }
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.removeColumn('StudentPrograms', 'approvedAt');
    await queryInterface.removeColumn('StudentPrograms', 'approvedBy');
    await queryInterface.removeColumn('StudentPrograms', 'approvalStatus');
  },
};
