'use strict';

/** Add passCode, qrCode, and maxPersons to the Bookings table */
module.exports = {
  async up(queryInterface, Sequelize) {
    const tableDesc = await queryInterface.describeTable('Bookings');

    if (!tableDesc.passCode) {
      await queryInterface.addColumn('Bookings', 'passCode', {
        type: Sequelize.STRING(50),
        allowNull: true,
        unique: true,
        after: 'transactionId',
      });
    }

    if (!tableDesc.qrCode) {
      await queryInterface.addColumn('Bookings', 'qrCode', {
        type: Sequelize.TEXT,
        allowNull: true,
        after: 'passCode',
      });
    }

    if (!tableDesc.maxPersons) {
      await queryInterface.addColumn('Bookings', 'maxPersons', {
        type: Sequelize.INTEGER,
        allowNull: true,
        defaultValue: null,
        comment: 'Max persons allowed on this booking pass (from court capacity)',
        after: 'qrCode',
      });
    }
  },

  async down(queryInterface) {
    const tableDesc = await queryInterface.describeTable('Bookings');
    if (tableDesc.maxPersons) await queryInterface.removeColumn('Bookings', 'maxPersons');
    if (tableDesc.qrCode)     await queryInterface.removeColumn('Bookings', 'qrCode');
    if (tableDesc.passCode)   await queryInterface.removeColumn('Bookings', 'passCode');
  },
};
