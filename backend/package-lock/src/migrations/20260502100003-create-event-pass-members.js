'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('EventPassMembers', {
      id: {
        type: Sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true,
        allowNull: false,
      },
      // Links to the single group pass (EventIndividualPasses)
      passId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: { model: 'EventIndividualPasses', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      // Member details
      name: {
        type: Sequelize.STRING(255),
        allowNull: false,
      },
      phone: {
        // WhatsApp number — stored with country code e.g. "919876543210"
        type: Sequelize.STRING(20),
        allowNull: false,
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

    await queryInterface.addIndex('EventPassMembers', ['passId']);
    await queryInterface.addIndex('EventPassMembers', ['phone']);
  },

  async down(queryInterface) {
    await queryInterface.dropTable('EventPassMembers');
  },
};
