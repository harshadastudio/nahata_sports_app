'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('Reports', {
      id: {
        type: Sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true,
        allowNull: false,
      },
      reportType: {
        type: Sequelize.ENUM('Booking', 'Revenue', 'Attendance', 'Student', 'Visitor', 'Inventory'),
        allowNull: false,
      },
      generatedBy: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'Users',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      parameters: {
        type: Sequelize.TEXT,
        allowNull: true,
      },
      data: {
        type: Sequelize.TEXT,
        allowNull: true,
      },
      filePath: {
        type: Sequelize.STRING,
        allowNull: true,
      },
      status: {
        type: Sequelize.ENUM('Generating', 'Completed', 'Failed'),
        defaultValue: 'Generating',
        allowNull: false,
      },
      scheduled: {
        type: Sequelize.BOOLEAN,
        defaultValue: false,
        allowNull: false,
      },
      generatedAt: {
        type: Sequelize.DATE,
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
    await queryInterface.addIndex('Reports', ['generatedBy']);
    await queryInterface.addIndex('Reports', ['reportType']);
    await queryInterface.addIndex('Reports', ['status']);
    await queryInterface.addIndex('Reports', ['generatedAt']);
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.dropTable('Reports');
  }
};
