'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.addColumn('Memberships', 'deletedAt', {
      type: Sequelize.DATE,
      allowNull: true,
      comment: 'Soft delete timestamp',
    });

    // Add index for better query performance on soft-deleted records
    await queryInterface.addIndex('Memberships', ['deletedAt'], {
      name: 'memberships_deleted_at_idx',
    });
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.removeIndex('Memberships', 'memberships_deleted_at_idx');
    await queryInterface.removeColumn('Memberships', 'deletedAt');
  }
};
