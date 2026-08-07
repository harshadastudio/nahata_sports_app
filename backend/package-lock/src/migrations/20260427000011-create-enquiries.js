'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up (queryInterface, Sequelize) {
    await queryInterface.createTable('Enquiries', {
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
        allowNull: false,
      },
      phone: {
        type: Sequelize.STRING,
        allowNull: false,
      },
      sportInterest: {
        type: Sequelize.STRING,
      },
      messageType: {
        type: Sequelize.ENUM('Coaching', 'Booking', 'General', 'Feedback', 'Complaint'),
        defaultValue: 'General',
      },
      message: {
        type: Sequelize.TEXT,
        allowNull: false,
      },
      status: {
        type: Sequelize.ENUM('New', 'Follow up', 'Qualified', 'Attempted', 'Closed'),
        defaultValue: 'New',
      },
      assignedTo: {
        type: Sequelize.INTEGER,
        references: {
          model: 'Users',
          key: 'id',
        },
      },
      followUpDate: {
        type: Sequelize.DATE,
      },
      notes: {
        type: Sequelize.TEXT,
      },
      source: {
        type: Sequelize.ENUM('Website', 'Phone', 'Email', 'WalkIn', 'SocialMedia'),
        defaultValue: 'Website',
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
    await queryInterface.dropTable('Enquiries');
  }
};