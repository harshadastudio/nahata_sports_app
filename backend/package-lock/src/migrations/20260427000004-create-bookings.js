'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up (queryInterface, Sequelize) {
    await queryInterface.createTable('Bookings', {
      id: {
        type: Sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true,
      },
      userId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'Users',
          key: 'id',
        },
      },
      sportId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'Sports',
          key: 'id',
        },
      },
      courtId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'Courts',
          key: 'id',
        },
      },
      date: {
        type: Sequelize.DATEONLY,
        allowNull: false,
      },
      startTime: {
        type: Sequelize.TIME,
        allowNull: false,
      },
      endTime: {
        type: Sequelize.TIME,
        allowNull: false,
      },
      players: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 1,
      },
      bookingSource: {
        type: Sequelize.ENUM('Direct', 'Playo', 'KheloMore', 'Website', 'MobileApp'),
        defaultValue: 'Direct',
      },
      amount: {
        type: Sequelize.DECIMAL(10, 2),
        allowNull: false,
      },
      paymentStatus: {
        type: Sequelize.ENUM('Pending', 'Paid', 'Failed', 'Refunded'),
        defaultValue: 'Pending',
      },
      paymentMode: {
        type: Sequelize.ENUM('Cash', 'Online', 'Card', 'UPI'),
        defaultValue: 'Online',
      },
      transactionId: {
        type: Sequelize.STRING,
      },
      notes: {
        type: Sequelize.TEXT,
      },
      status: {
        type: Sequelize.ENUM('Confirmed', 'Cancelled', 'Completed'),
        defaultValue: 'Confirmed',
      },
      cancellationReason: {
        type: Sequelize.TEXT,
      },
      createdAt: {
        allowNull: false,
        type: Sequelize.DATE,
      },
      updatedAt: {
        allowNull: false,
        type: Sequelize.DATE,
      },
    });
  },

  async down (queryInterface, Sequelize) {
    await queryInterface.dropTable('Bookings');
  }
};