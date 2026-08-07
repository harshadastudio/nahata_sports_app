'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up (queryInterface, Sequelize) {
    await queryInterface.createTable('Courts', {
      id: {
        type: Sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true,
      },
      sportComplexId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'SportComplexes',
          key: 'id',
        },
      },
      sportId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'Sports',
          key: 'id',
        },
      },
      name: {
        type: Sequelize.STRING,
        allowNull: false,
      },
      description: {
        type: Sequelize.TEXT,
      },
      capacity: {
        type: Sequelize.INTEGER,
      },
      surfaceType: {
        type: Sequelize.ENUM('Grass', 'Clay', 'Hard', 'Synthetic', 'Wood'),
        defaultValue: 'Synthetic',
      },
      lightingAvailable: {
        type: Sequelize.BOOLEAN,
        defaultValue: false,
      },
      equipmentAvailable: {
        type: Sequelize.TEXT,
      },
      hourlyRate: {
        type: Sequelize.DECIMAL(10, 2),
        allowNull: false,
      },
      status: {
        type: Sequelize.ENUM('Available', 'Maintenance', 'Booked', 'Closed'),
        defaultValue: 'Available',
      },
      image: {
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
    await queryInterface.dropTable('Courts');
  }
};