'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up (queryInterface, Sequelize) {
    await queryInterface.createTable('Approvals', {
      id: {
        type: Sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true,
      },
      requestType: {
        type: Sequelize.ENUM('Booking', 'Refund', 'Leave', 'Expense', 'Other'),
        allowNull: false,
      },
      requestId: {
        type: Sequelize.INTEGER,
        allowNull: false,
      },
      approverId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'Users',
          key: 'id',
        },
      },
      status: {
        type: Sequelize.ENUM('Pending', 'Approved', 'Rejected'),
        defaultValue: 'Pending',
      },
      comments: {
        type: Sequelize.TEXT,
      },
      approvedAt: {
        type: Sequelize.DATE,
      },
      rejectionReason: {
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
    await queryInterface.dropTable('Approvals');
  }
};