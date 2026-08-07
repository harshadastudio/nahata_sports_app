'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    const tableDescription = await queryInterface.describeTable('Bookings');

    // Only remove timeSlot if it still exists
    if (tableDescription['timeSlot']) {
      await queryInterface.removeColumn('Bookings', 'timeSlot');
      console.log('✅ Removed column: timeSlot');
    } else {
      console.log('⏭️  Skipped (already removed): timeSlot');
    }
  },

  async down(queryInterface, Sequelize) {
    const tableDescription = await queryInterface.describeTable('Bookings');

    if (!tableDescription['timeSlot']) {
      await queryInterface.addColumn('Bookings', 'timeSlot', {
        type: Sequelize.STRING,
        allowNull: true,
      });
    }
  },
};
