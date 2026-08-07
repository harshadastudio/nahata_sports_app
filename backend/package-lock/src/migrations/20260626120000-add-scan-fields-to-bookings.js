'use strict';

/** Add per-booking scan-tracking fields to the Bookings table (counter fallback + aggregate). */
module.exports = {
  async up(queryInterface, Sequelize) {
    const tableDesc = await queryInterface.describeTable('Bookings');

    if (!tableDesc.scannedInCount) {
      await queryInterface.addColumn('Bookings', 'scannedInCount', {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 0,
        after: 'maxPersons',
      });
    }

    if (!tableDesc.scannedOutCount) {
      await queryInterface.addColumn('Bookings', 'scannedOutCount', {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 0,
        after: 'scannedInCount',
      });
    }

    if (!tableDesc.scanStatus) {
      await queryInterface.addColumn('Bookings', 'scanStatus', {
        type: Sequelize.ENUM('NotScanned', 'In', 'Out'),
        allowNull: false,
        defaultValue: 'NotScanned',
        after: 'scannedOutCount',
      });
    }

    if (!tableDesc.scannedInAt) {
      await queryInterface.addColumn('Bookings', 'scannedInAt', {
        type: Sequelize.DATE,
        allowNull: true,
        after: 'scanStatus',
      });
    }

    if (!tableDesc.scannedOutAt) {
      await queryInterface.addColumn('Bookings', 'scannedOutAt', {
        type: Sequelize.DATE,
        allowNull: true,
        after: 'scannedInAt',
      });
    }
  },

  async down(queryInterface) {
    const tableDesc = await queryInterface.describeTable('Bookings');
    if (tableDesc.scannedOutAt)   await queryInterface.removeColumn('Bookings', 'scannedOutAt');
    if (tableDesc.scannedInAt)    await queryInterface.removeColumn('Bookings', 'scannedInAt');
    if (tableDesc.scanStatus)     await queryInterface.removeColumn('Bookings', 'scanStatus');
    if (tableDesc.scannedOutCount) await queryInterface.removeColumn('Bookings', 'scannedOutCount');
    if (tableDesc.scannedInCount)  await queryInterface.removeColumn('Bookings', 'scannedInCount');
    // Postgres keeps the ENUM type after the column is dropped — remove it so a re-run succeeds.
    await queryInterface.sequelize.query('DROP TYPE IF EXISTS "enum_Bookings_scanStatus";');
  },
};
