'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    // Check if deletedAt column exists in Bookings table
    const bookingsTable = await queryInterface.describeTable('Bookings');
    
    if (!bookingsTable.deletedAt) {
      await queryInterface.addColumn('Bookings', 'deletedAt', {
        type: Sequelize.DATE,
        allowNull: true,
        defaultValue: null
      });
      console.log('✅ Added deletedAt column to Bookings table');
    } else {
      console.log('ℹ️  deletedAt column already exists in Bookings table');
    }

    // Check if icon column exists in Sports table
    const sportsTable = await queryInterface.describeTable('Sports');
    
    if (!sportsTable.icon) {
      await queryInterface.addColumn('Sports', 'icon', {
        type: Sequelize.STRING(255),
        allowNull: true,
        defaultValue: null
      });
      console.log('✅ Added icon column to Sports table');
    } else {
      console.log('ℹ️  icon column already exists in Sports table');
    }
  },

  down: async (queryInterface, Sequelize) => {
    // Remove deletedAt column from Bookings
    const bookingsTable = await queryInterface.describeTable('Bookings');
    if (bookingsTable.deletedAt) {
      await queryInterface.removeColumn('Bookings', 'deletedAt');
      console.log('✅ Removed deletedAt column from Bookings table');
    }

    // Remove icon column from Sports
    const sportsTable = await queryInterface.describeTable('Sports');
    if (sportsTable.icon) {
      await queryInterface.removeColumn('Sports', 'icon');
      console.log('✅ Removed icon column from Sports table');
    }
  }
};
