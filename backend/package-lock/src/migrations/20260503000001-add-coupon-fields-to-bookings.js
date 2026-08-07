'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    const tables = await queryInterface.showAllTables();

    // ── Bookings table ────────────────────────────────────────────────────────
    if (tables.includes('Bookings')) {
      const bookingsCols = await queryInterface.describeTable('Bookings');

      if (!bookingsCols.couponCode) {
        await queryInterface.addColumn('Bookings', 'couponCode', {
          type: Sequelize.STRING(50),
          allowNull: true,
          defaultValue: null,
          after: 'totalAmount',
        });
        console.log('✅ Added couponCode to Bookings');
      }

      if (!bookingsCols.discountAmount) {
        await queryInterface.addColumn('Bookings', 'discountAmount', {
          type: Sequelize.DECIMAL(10, 2),
          allowNull: false,
          defaultValue: 0,
          after: 'couponCode',
        });
        console.log('✅ Added discountAmount to Bookings');
      }

      if (!bookingsCols.originalAmount) {
        await queryInterface.addColumn('Bookings', 'originalAmount', {
          type: Sequelize.DECIMAL(10, 2),
          allowNull: true,
          defaultValue: null,
          after: 'discountAmount',
        });
        console.log('✅ Added originalAmount to Bookings');
      }
    }

    // ── EventPassBookings table ───────────────────────────────────────────────
    if (tables.includes('EventPassBookings')) {
      const eventCols = await queryInterface.describeTable('EventPassBookings');

      if (!eventCols.couponCode) {
        await queryInterface.addColumn('EventPassBookings', 'couponCode', {
          type: Sequelize.STRING(50),
          allowNull: true,
          defaultValue: null,
          after: 'totalAmount',
        });
        console.log('✅ Added couponCode to EventPassBookings');
      }

      if (!eventCols.discountAmount) {
        await queryInterface.addColumn('EventPassBookings', 'discountAmount', {
          type: Sequelize.DECIMAL(10, 2),
          allowNull: false,
          defaultValue: 0,
          after: 'couponCode',
        });
        console.log('✅ Added discountAmount to EventPassBookings');
      }

      if (!eventCols.originalAmount) {
        await queryInterface.addColumn('EventPassBookings', 'originalAmount', {
          type: Sequelize.DECIMAL(10, 2),
          allowNull: true,
          defaultValue: null,
          after: 'discountAmount',
        });
        console.log('✅ Added originalAmount to EventPassBookings');
      }
    }
  },

  async down(queryInterface) {
    const tables = await queryInterface.showAllTables();

    if (tables.includes('Bookings')) {
      const cols = await queryInterface.describeTable('Bookings');
      if (cols.couponCode)    await queryInterface.removeColumn('Bookings', 'couponCode');
      if (cols.discountAmount) await queryInterface.removeColumn('Bookings', 'discountAmount');
      if (cols.originalAmount) await queryInterface.removeColumn('Bookings', 'originalAmount');
    }

    if (tables.includes('EventPassBookings')) {
      const cols = await queryInterface.describeTable('EventPassBookings');
      if (cols.couponCode)    await queryInterface.removeColumn('EventPassBookings', 'couponCode');
      if (cols.discountAmount) await queryInterface.removeColumn('EventPassBookings', 'discountAmount');
      if (cols.originalAmount) await queryInterface.removeColumn('EventPassBookings', 'originalAmount');
    }
  },
};
