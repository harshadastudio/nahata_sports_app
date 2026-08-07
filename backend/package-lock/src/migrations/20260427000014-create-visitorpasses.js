'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up (queryInterface, Sequelize) {
    await queryInterface.createTable('VisitorPasses', {
      id: {
        type: Sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true,
      },
      visitorId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'Visitors',
          key: 'id',
        },
      },
      passNumber: {
        type: Sequelize.STRING,
        unique: true,
        allowNull: false,
      },
      validFrom: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      validUntil: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      issuedBy: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'Users',
          key: 'id',
        },
      },
      qrCode: {
        type: Sequelize.STRING,
      },
      status: {
        type: Sequelize.ENUM('Active', 'Used', 'Expired', 'Cancelled'),
        defaultValue: 'Active',
      },
      checkInTime: {
        type: Sequelize.DATE,
      },
      checkOutTime: {
        type: Sequelize.DATE,
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
    await queryInterface.dropTable('VisitorPasses');
  }
};