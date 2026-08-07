'use strict';

/**
 * BookingMembers — the "allowed members" of a court booking pass.
 * Unlike event-pass members, each court member has its OWN unique passCode + QR
 * (individual QR per member), so each can be scanned individually at the gate.
 * @type {import('sequelize-cli').Migration}
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('BookingMembers', {
      id: {
        type: Sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true,
        allowNull: false,
      },
      bookingId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: { model: 'Bookings', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      name: {
        type: Sequelize.STRING(255),
        allowNull: false,
      },
      phone: {
        // WhatsApp number — stored with country code e.g. "919876543210"
        type: Sequelize.STRING(20),
        allowNull: false,
      },
      email: {
        // Optional — enables sharing the member's pass by email too
        type: Sequelize.STRING(255),
        allowNull: true,
      },
      // Each member gets a unique, individually-scannable pass
      passCode: {
        type: Sequelize.STRING(100),
        allowNull: false,
        unique: true,
      },
      qrCode: {
        type: Sequelize.STRING(600),
        allowNull: true,
      },
      // Per-member scan tracking
      scanStatus: {
        type: Sequelize.ENUM('NotScanned', 'In', 'Out'),
        defaultValue: 'NotScanned',
        allowNull: false,
      },
      scannedInAt:  { type: Sequelize.DATE, allowNull: true },
      scannedOutAt: { type: Sequelize.DATE, allowNull: true },
      createdAt: { allowNull: false, type: Sequelize.DATE },
      updatedAt: { allowNull: false, type: Sequelize.DATE },
    });

    await queryInterface.addIndex('BookingMembers', ['bookingId']);
    await queryInterface.addIndex('BookingMembers', ['phone']);
    await queryInterface.addIndex('BookingMembers', ['passCode'], { unique: true });
  },

  async down(queryInterface) {
    await queryInterface.dropTable('BookingMembers');
  },
};
