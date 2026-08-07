'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    const tableDescription = await queryInterface.describeTable('Bookings');

    if (!tableDescription['isDeleted']) {
      await queryInterface.addColumn('Bookings', 'isDeleted', {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: false,
      });
      console.log('✅ Added column: isDeleted');
    } else {
      console.log('⏭️  Skipped (already exists): isDeleted');
    }
  },

  async down(queryInterface, Sequelize) {
    const tableDescription = await queryInterface.describeTable('Bookings');

    if (tableDescription['isDeleted']) {
      await queryInterface.removeColumn('Bookings', 'isDeleted');
    }
  },
};
