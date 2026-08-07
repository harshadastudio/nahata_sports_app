'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('Employees', {
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
      employeeId: {
        type: Sequelize.STRING,
        unique: true,
        allowNull: false,
      },
      department: {
        type: Sequelize.ENUM('Operations', 'Front Desk', 'Maintenance', 'Housekeeping', 'Accounts', 'Customer Service'),
        allowNull: false,
      },
      designation: {
        type: Sequelize.ENUM('Manager', 'Supervisor', 'Staff', 'Technician', 'Accountant', 'Receptionist'),
        allowNull: false,
      },
      joiningDate: {
        type: Sequelize.DATEONLY,
        allowNull: false,
      },
      salary: {
        type: Sequelize.DECIMAL(10, 2),
      },
      shift: {
        type: Sequelize.ENUM('Morning', 'Evening', 'Night', 'Rotational'),
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

    // Add indexes only if they don't already exist (ignore errors if they do)
    try { await queryInterface.addIndex('Employees', ['userId']); } catch (_) {}
    try { await queryInterface.addIndex('Employees', ['employeeId']); } catch (_) {}
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.dropTable('Employees');
  },
};
