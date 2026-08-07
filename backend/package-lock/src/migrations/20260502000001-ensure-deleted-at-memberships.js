'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    const tableDescription = await queryInterface.describeTable('Memberships');

    // Add features column if missing
    if (!tableDescription.features) {
      await queryInterface.addColumn('Memberships', 'features', {
        type: Sequelize.TEXT,
        allowNull: true,
        comment: 'Comma-separated list of features',
      });
    }

    // Add deletedAt column if missing
    if (!tableDescription.deletedAt) {
      await queryInterface.addColumn('Memberships', 'deletedAt', {
        type: Sequelize.DATE,
        allowNull: true,
        comment: 'Soft delete timestamp',
      });
    }

    // Add index only if it doesn't already exist
    const indexes = await queryInterface.showIndex('Memberships');
    const indexExists = indexes.some(idx => idx.name === 'memberships_deleted_at_idx');
    if (!indexExists) {
      await queryInterface.addIndex('Memberships', ['deletedAt'], {
        name: 'memberships_deleted_at_idx',
      });
    }
  },

  down: async (queryInterface, Sequelize) => {
    const indexes = await queryInterface.showIndex('Memberships');
    const indexExists = indexes.some(idx => idx.name === 'memberships_deleted_at_idx');
    if (indexExists) {
      await queryInterface.removeIndex('Memberships', 'memberships_deleted_at_idx');
    }

    const tableDescription = await queryInterface.describeTable('Memberships');
    if (tableDescription.deletedAt) {
      await queryInterface.removeColumn('Memberships', 'deletedAt');
    }
    if (tableDescription.features) {
      await queryInterface.removeColumn('Memberships', 'features');
    }
  },
};
