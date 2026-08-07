'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up (queryInterface, Sequelize) {
    await queryInterface.createTable('EntryLogs', {
      id: {
        type: Sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true,
      },
      visitorPassId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'VisitorPasses',
          key: 'id',
        },
      },
      userId: {
        type: Sequelize.INTEGER,
        references: {
          model: 'Users',
          key: 'id',
        },
      },
      entryTime: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      exitTime: {
        type: Sequelize.DATE,
      },
      gateNumber: {
        type: Sequelize.STRING,
      },
      securityGuardId: {
        type: Sequelize.INTEGER,
        references: {
          model: 'Users',
          key: 'id',
        },
      },
      scanType: {
        type: Sequelize.ENUM('Entry', 'Exit', 'Both'),
        defaultValue: 'Entry',
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
    await queryInterface.dropTable('EntryLogs');
  }
};