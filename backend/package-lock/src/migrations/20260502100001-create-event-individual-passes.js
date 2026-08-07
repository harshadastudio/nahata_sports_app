'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    // Individual pass records — one row per physical pass (e.g. booking of 10 → 10 rows)
    await queryInterface.createTable('EventIndividualPasses', {
      id: {
        type: Sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true,
        allowNull: false,
      },
      bookingId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: { model: 'EventPassBookings', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      eventPassId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: { model: 'EventPasses', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      slotId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: { model: 'EventPassSlots', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      passNumber: {
        // e.g. 1 of 10, 2 of 10 …
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 1,
      },
      holderName: {
        type: Sequelize.STRING(255),
        allowNull: false,
      },
      holderEmail: {
        type: Sequelize.STRING(255),
        allowNull: false,
      },
      passCode: {
        // unique scannable code  e.g. "EVTPASS-2026-000042-001"
        type: Sequelize.STRING(100),
        allowNull: false,
        unique: true,
      },
      qrCode: {
        // URL of the QR image
        type: Sequelize.STRING(600),
        allowNull: true,
      },
      scanStatus: {
        type: Sequelize.ENUM('NotScanned', 'In', 'Out'),
        defaultValue: 'NotScanned',
        allowNull: false,
      },
      scannedInAt: {
        type: Sequelize.DATE,
        allowNull: true,
      },
      scannedOutAt: {
        type: Sequelize.DATE,
        allowNull: true,
      },
      isValid: {
        // set to false after event ends or pass is cancelled
        type: Sequelize.BOOLEAN,
        defaultValue: true,
        allowNull: false,
      },
      createdAt: { allowNull: false, type: Sequelize.DATE },
      updatedAt: { allowNull: false, type: Sequelize.DATE },
    });

    await queryInterface.addIndex('EventIndividualPasses', ['bookingId']);
    await queryInterface.addIndex('EventIndividualPasses', ['eventPassId']);
    await queryInterface.addIndex('EventIndividualPasses', ['slotId']);
    await queryInterface.addIndex('EventIndividualPasses', ['passCode'], { unique: true });
    await queryInterface.addIndex('EventIndividualPasses', ['scanStatus']);
  },

  async down(queryInterface) {
    await queryInterface.dropTable('EventIndividualPasses');
  },
};
