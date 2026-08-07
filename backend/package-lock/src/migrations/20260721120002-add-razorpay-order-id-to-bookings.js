'use strict';

/**
 * Adds `razorpayOrderId` to Bookings so a payment can be cryptographically bound
 * to the exact order we created server-side. Without this, /payments/verify could
 * be replayed with any booking id (the ₹1-payment bypass). EventPassBookings
 * already has this column; this brings facility bookings to parity.
 * @type {import('sequelize-cli').Migration}
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('Bookings', 'razorpayOrderId', {
      type: Sequelize.STRING(100),
      allowNull: true,
      comment: 'Razorpay order id created at /payments/create-order; bound at verify.',
    });
    await queryInterface.addIndex('Bookings', ['razorpayOrderId'], {
      name: 'bookings_razorpay_order_id',
    });
  },

  async down(queryInterface) {
    await queryInterface.removeIndex('Bookings', 'bookings_razorpay_order_id');
    await queryInterface.removeColumn('Bookings', 'razorpayOrderId');
  },
};
