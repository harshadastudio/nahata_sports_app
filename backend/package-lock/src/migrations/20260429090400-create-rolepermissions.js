'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('RolePermissions', {
      id: {
        type: Sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true,
        allowNull: false,
      },
      role: {
        type: Sequelize.ENUM('admin', 'user', 'employee', 'coach', 'security_guard'),
        allowNull: false,
      },
      permission: {
        type: Sequelize.STRING,
        allowNull: false,
      },
      description: {
        type: Sequelize.TEXT,
        allowNull: true,
      },
      isActive: {
        type: Sequelize.BOOLEAN,
        defaultValue: true,
        allowNull: false,
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
    await queryInterface.addIndex('RolePermissions', ['role']);
    await queryInterface.addIndex('RolePermissions', ['permission']);
    await queryInterface.addIndex('RolePermissions', ['isActive']);
    
    // Add unique constraint to prevent duplicate role-permission combinations
    await queryInterface.addIndex('RolePermissions', ['role', 'permission'], {
      unique: true,
      name: 'unique_role_permission'
    });
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.dropTable('RolePermissions');
  }
};
