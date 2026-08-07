'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up (queryInterface, Sequelize) {
    await queryInterface.createTable('Visitors', {
      id: {
        type: Sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true,
      },
      name: {
        type: Sequelize.STRING,
        allowNull: false,
      },
      email: {
        type: Sequelize.STRING,
      },
      phone: {
        type: Sequelize.STRING,
        allowNull: false,
      },
      purpose: {
        type: Sequelize.ENUM('Meeting', 'Delivery', 'Service', 'Visit', 'Other'),
        defaultValue: 'Visit',
      },
      company: {
        type: Sequelize.STRING,
      },
      visitingPerson: {
        type: Sequelize.STRING,
      },
      expectedTime: {
        type: Sequelize.TIME,
      },
      actualTime: {
        type: Sequelize.TIME,
      },
      status: {
        type: Sequelize.ENUM('Expected', 'CheckedIn', 'CheckedOut', 'Cancelled'),
        defaultValue: 'Expected',
      },
      idProofType: {
        type: Sequelize.ENUM('Aadhar', 'PAN', 'DrivingLicense', 'Passport', 'VoterID'),
      },
      idProofNumber: {
        type: Sequelize.STRING,
      },
      photo: {
        type: Sequelize.STRING,
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
    await queryInterface.dropTable('Visitors');
  }
};