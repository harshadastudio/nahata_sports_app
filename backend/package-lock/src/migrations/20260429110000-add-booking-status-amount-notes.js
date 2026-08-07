'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    const tableDesc = await queryInterface.describeTable('Bookings');

    if (!tableDesc.bookingStatus) {
      await queryInterface.addColumn('Bookings', 'bookingStatus', {
        type: Sequelize.ENUM('Confirmed', 'Cancelled', 'Completed', 'Pending'),
        defaultValue: 'Confirmed',
        allowNull: false,
        after: 'paymentStatus',
      });
    }

    if (!tableDesc.totalAmount) {
      await queryInterface.addColumn('Bookings', 'totalAmount', {
        type: Sequelize.DECIMAL(10, 2),
        defaultValue: 0,
        allowNull: false,
        after: 'bookingStatus',
      });
    }

    if (!tableDesc.notes) {
      await queryInterface.addColumn('Bookings', 'notes', {
        type: Sequelize.TEXT,
        allowNull: true,
        defaultValue: null,
        after: 'totalAmount',
      });
    }
  },

  async down(queryInterface) {
    const tableDesc = await queryInterface.describeTable('Bookings');
    if (tableDesc.notes)          await queryInterface.removeColumn('Bookings', 'notes');
    if (tableDesc.totalAmount)    await queryInterface.removeColumn('Bookings', 'totalAmount');
    if (tableDesc.bookingStatus)  await queryInterface.removeColumn('Bookings', 'bookingStatus');
  },
};
