'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    // Check if isDeleted column exists
    const tableDescription = await queryInterface.describeTable('Bookings');
    
    if (!tableDescription.isDeleted) {
      await queryInterface.addColumn('Bookings', 'isDeleted', {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: false,
      });
      
      console.log('✅ Added isDeleted column to Bookings table');
    } else {
      console.log('ℹ️  isDeleted column already exists');
    }
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.removeColumn('Bookings', 'isDeleted');
  }
};
