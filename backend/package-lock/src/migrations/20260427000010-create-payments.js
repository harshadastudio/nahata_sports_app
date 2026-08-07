'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up (queryInterface, Sequelize) {
    await queryInterface.createTable('Payments', {
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
      bookingId: {
        type: Sequelize.INTEGER,
        references: {
          model: 'Bookings',
          key: 'id',
        },
      },
      amount: {
        type: Sequelize.DECIMAL(10, 2),
        allowNull: false,
      },
      paymentMethod: {
        type: Sequelize.ENUM('Cash', 'Online', 'Card', 'UPI', 'BankTransfer'),
        defaultValue: 'Online',
      },
      transactionId: {
        type: Sequelize.STRING,
        unique: true,
      },
      paymentStatus: {
        type: Sequelize.ENUM('Pending', 'Completed', 'Failed', 'Refunded'),
        defaultValue: 'Pending',
      },
      paymentDate: {
        type: Sequelize.DATE,
      },
      refundAmount: {
        type: Sequelize.DECIMAL(10, 2),
        defaultValue: 0,
      },
      refundReason: {
        type: Sequelize.TEXT,
      },
      notes: {
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
    await queryInterface.dropTable('Payments');
  }
};