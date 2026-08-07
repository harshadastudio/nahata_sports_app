'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('SecurityGuards', {
      id: {
        type: Sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true,
      },
      userId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: { model: 'Users', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      guardId: {
        type: Sequelize.STRING,
        unique: true,
        allowNull: false,
      },
      licenseNumber: {
        type: Sequelize.STRING,
      },
      shift: {
        type: Sequelize.ENUM('Morning', 'Evening', 'Night'),
        allowNull: false,
      },
      assignedArea: {
        type: Sequelize.ENUM('Main Gate', 'Parking', 'Courts', 'Building', 'Perimeter'),
        allowNull: false,
      },
      joiningDate: {
        type: Sequelize.DATEONLY,
        allowNull: false,
      },
      salary: {
        type: Sequelize.DECIMAL(10, 2),
      },
      status: {
        type: Sequelize.ENUM('Active', 'Inactive', 'On Leave'),
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
    }, { ifNotExists: true });

    try { await queryInterface.addIndex('SecurityGuards', ['userId']); } catch (_) {}
    try { await queryInterface.addIndex('SecurityGuards', ['guardId']); } catch (_) {}
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.dropTable('SecurityGuards');
  },
};
