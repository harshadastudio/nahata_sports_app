'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('EventPassBookings', {
      id: {
        type: Sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true,
        allowNull: false,
      },
      eventPassId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'EventPasses',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      slotId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'EventPassSlots',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      userId: {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: {
          model: 'Users',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
      },
      name: {
        type: Sequelize.STRING(255),
        allowNull: false,
      },
      email: {
        type: Sequelize.STRING(255),
        allowNull: false,
      },
      numberOfPasses: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 1,
      },
      totalAmount: {
        type: Sequelize.DECIMAL(10, 2),
        allowNull: false,
        defaultValue: 0,
      },
      status: {
        type: Sequelize.ENUM('Pending', 'Confirmed', 'Cancelled'),
        defaultValue: 'Pending',
        allowNull: false,
      },
      qrCode: {
        type: Sequelize.STRING(500),
        allowNull: true,
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

    // Add indexes for better query performance
    await queryInterface.addIndex('EventPassBookings', ['eventPassId']);
    await queryInterface.addIndex('EventPassBookings', ['slotId']);
    await queryInterface.addIndex('EventPassBookings', ['userId']);
    await queryInterface.addIndex('EventPassBookings', ['status']);
    await queryInterface.addIndex('EventPassBookings', ['email']);
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.dropTable('EventPassBookings');
  }
};
