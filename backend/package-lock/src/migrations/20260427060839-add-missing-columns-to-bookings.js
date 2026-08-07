'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    // Describe the current table so we can skip columns that already exist
    const tableDescription = await queryInterface.describeTable('Bookings');

    const addIfMissing = async (columnName, definition) => {
      if (!tableDescription[columnName]) {
        await queryInterface.addColumn('Bookings', columnName, definition);
        console.log(`✅ Added column: ${columnName}`);
      } else {
        console.log(`⏭️  Skipped (already exists): ${columnName}`);
      }
    };

    await addIfMissing('startTime', {
      type: Sequelize.TIME,
      allowNull: true,
    });

    await addIfMissing('endTime', {
      type: Sequelize.TIME,
      allowNull: true,
    });

    await addIfMissing('players', {
      type: Sequelize.INTEGER,
      allowNull: false,
      defaultValue: 1,
    });

    await addIfMissing('bookingSource', {
      type: Sequelize.ENUM('Direct', 'Playo', 'KheloMore', 'Website', 'MobileApp'),
      defaultValue: 'Direct',
    });

    await addIfMissing('amount', {
      type: Sequelize.DECIMAL(10, 2),
      allowNull: true,
    });

    await addIfMissing('paymentStatus', {
      type: Sequelize.ENUM('Pending', 'Paid', 'Failed', 'Refunded'),
      defaultValue: 'Pending',
    });

    await addIfMissing('paymentMode', {
      type: Sequelize.ENUM('Cash', 'Online', 'Card', 'UPI'),
      defaultValue: 'Online',
    });

    await addIfMissing('transactionId', {
      type: Sequelize.STRING,
      allowNull: true,
    });

    await addIfMissing('notes', {
      type: Sequelize.TEXT,
      allowNull: true,
    });

    await addIfMissing('cancellationReason', {
      type: Sequelize.TEXT,
      allowNull: true,
    });
  },

  async down(queryInterface, Sequelize) {
    const tableDescription = await queryInterface.describeTable('Bookings');

    const removeIfExists = async (columnName) => {
      if (tableDescription[columnName]) {
        await queryInterface.removeColumn('Bookings', columnName);
      }
    };

    await removeIfExists('startTime');
    await removeIfExists('endTime');
    await removeIfExists('players');
    await removeIfExists('bookingSource');
    await removeIfExists('amount');
    await removeIfExists('paymentStatus');
    await removeIfExists('paymentMode');
    await removeIfExists('transactionId');
    await removeIfExists('notes');
    await removeIfExists('cancellationReason');
  },
};
