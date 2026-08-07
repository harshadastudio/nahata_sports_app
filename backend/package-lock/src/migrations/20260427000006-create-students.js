'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up (queryInterface, Sequelize) {
    await queryInterface.createTable('Students', {
      id: {
        type: Sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true,
      },
      userId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        unique: true,
        references: {
          model: 'Users',
          key: 'id',
        },
      },
      parentName: {
        type: Sequelize.STRING,
      },
      parentPhone: {
        type: Sequelize.STRING,
      },
      parentEmail: {
        type: Sequelize.STRING,
      },
      schoolName: {
        type: Sequelize.STRING,
      },
      grade: {
        type: Sequelize.STRING,
      },
      medicalConditions: {
        type: Sequelize.TEXT,
      },
      allergies: {
        type: Sequelize.TEXT,
      },
      previousExperience: {
        type: Sequelize.TEXT,
      },
      achievements: {
        type: Sequelize.TEXT,
      },
      enrollmentDate: {
        type: Sequelize.DATEONLY,
      },
      status: {
        type: Sequelize.ENUM('Active', 'Inactive', 'Graduated', 'Transferred'),
        defaultValue: 'Active',
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
    await queryInterface.dropTable('Students');
  }
};