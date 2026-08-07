'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    const tableDescription = await queryInterface.describeTable('Memberships');

    // The 'name' column was created by sequelize.sync() and is NOT NULL with no default,
    // blocking all inserts. Make it nullable since the model uses 'planName' instead.
    if (tableDescription.name && !tableDescription.name.allowNull) {
      await queryInterface.changeColumn('Memberships', 'name', {
        type: Sequelize.STRING,
        allowNull: true,
        defaultValue: null,
      });
    }
  },

  down: async (queryInterface, Sequelize) => {
    const tableDescription = await queryInterface.describeTable('Memberships');
    if (tableDescription.name) {
      await queryInterface.changeColumn('Memberships', 'name', {
        type: Sequelize.STRING,
        allowNull: false,
      });
    }
  },
};
