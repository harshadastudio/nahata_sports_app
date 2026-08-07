'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    const tableDescription = await queryInterface.describeTable('Bookings');

    const removeIfExists = async (columnName) => {
      if (tableDescription[columnName]) {
        await queryInterface.removeColumn('Bookings', columnName);
        console.log(`✅ Removed column: ${columnName}`);
      } else {
        console.log(`⏭️  Skipped (already removed): ${columnName}`);
      }
    };

    await removeIfExists('players');
    await removeIfExists('amount');
    await removeIfExists('paymentMode');
    await removeIfExists('notes');
    await removeIfExists('status');
    await removeIfExists('cancellationReason');
  },

  async down(queryInterface, Sequelize) {
    const tableDescription = await queryInterface.describeTable('Bookings');

    const addIfMissing = async (columnName, definition) => {
      if (!tableDescription[columnName]) {
        await queryInterface.addColumn('Bookings', columnName, definition);
      }
    };

    await addIfMissing('players', {
      type: Sequelize.INTEGER,
      defaultValue: 1,
    });
    await addIfMissing('amount', {
      type: Sequelize.DECIMAL(10, 2),
      allowNull: true,
    });
    await addIfMissing('paymentMode', {
      type: Sequelize.ENUM('Cash', 'Online', 'Card', 'UPI'),
      defaultValue: 'Online',
    });
    await addIfMissing('notes', {
      type: Sequelize.TEXT,
      allowNull: true,
    });
    await addIfMissing('status', {
      type: Sequelize.STRING,
      allowNull: true,
    });
    await addIfMissing('cancellationReason', {
      type: Sequelize.TEXT,
      allowNull: true,
    });
  },
};
