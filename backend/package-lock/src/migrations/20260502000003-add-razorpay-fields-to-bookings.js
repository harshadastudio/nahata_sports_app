'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    // Add razorpay fields to EventPassBookings
    const epbDesc = await queryInterface.describeTable('EventPassBookings');

    if (!epbDesc.razorpayOrderId) {
      await queryInterface.addColumn('EventPassBookings', 'razorpayOrderId', {
        type: Sequelize.STRING(100),
        allowNull: true,
      });
    }
    if (!epbDesc.razorpayPaymentId) {
      await queryInterface.addColumn('EventPassBookings', 'razorpayPaymentId', {
        type: Sequelize.STRING(100),
        allowNull: true,
      });
    }

    // Bookings table already has transactionId — just ensure it exists
    const bookingsDesc = await queryInterface.describeTable('Bookings');
    if (!bookingsDesc.transactionId) {
      await queryInterface.addColumn('Bookings', 'transactionId', {
        type: Sequelize.STRING(100),
        allowNull: true,
      });
    }
  },

  down: async (queryInterface) => {
    const epbDesc = await queryInterface.describeTable('EventPassBookings');
    if (epbDesc.razorpayOrderId) {
      await queryInterface.removeColumn('EventPassBookings', 'razorpayOrderId');
    }
    if (epbDesc.razorpayPaymentId) {
      await queryInterface.removeColumn('EventPassBookings', 'razorpayPaymentId');
    }
  },
};
