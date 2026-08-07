'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up (queryInterface, Sequelize) {
    // Create Roles table
    await queryInterface.createTable('Roles', {
      id: {
        allowNull: false,
        autoIncrement: true,
        primaryKey: true,
        type: Sequelize.INTEGER
      },
      name: {
        type: Sequelize.STRING,
        allowNull: false,
        unique: true,
        comment: 'Role name (e.g., ADMIN, USER, EMPLOYEE, COACH, SECURITY)'
      },
      display_name: {
        type: Sequelize.STRING,
        allowNull: false,
        comment: 'Display name for the role (e.g., Administrator, Employee)'
      },
      description: {
        type: Sequelize.TEXT,
        allowNull: true,
        comment: 'Description of the role'
      },
      permissions: {
        type: Sequelize.JSON,
        allowNull: false,
        defaultValue: {},
        comment: 'JSON object containing permissions for this role'
      },
      is_active: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: true,
        comment: 'Whether this role is active'
      },
      is_system: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: false,
        comment: 'System roles cannot be deleted'
      },
      createdAt: {
        allowNull: false,
        type: Sequelize.DATE
      },
      updatedAt: {
        allowNull: false,
        type: Sequelize.DATE
      }
    });

    // Insert default roles with permissions
    await queryInterface.bulkInsert('Roles', [
      {
        name: 'ADMIN',
        display_name: 'Administrator',
        description: 'Full system access with all permissions',
        permissions: JSON.stringify({
          dashboard: { view: true, edit: true, delete: true },
          users: { view: true, create: true, edit: true, delete: true },
          roles: { view: true, create: true, edit: true, delete: true },
          memberships: { view: true, create: true, edit: true, delete: true },
          payments: { view: true, create: true, edit: true, delete: true },
          coupons: { view: true, create: true, edit: true, delete: true },
          reports: { view: true, create: true, edit: true, delete: true },
          sports: { view: true, create: true, edit: true, delete: true },
          courts: { view: true, create: true, edit: true, delete: true },
          sportsComplex: { view: true, create: true, edit: true, delete: true },
          programs: { view: true, create: true, edit: true, delete: true },
          batches: { view: true, create: true, edit: true, delete: true },
          coaches: { view: true, create: true, edit: true, delete: true },
          students: { view: true, create: true, edit: true, delete: true },
          bookings: { view: true, create: true, edit: true, delete: true },
          settings: { view: true, edit: true }
        }),
        is_active: true,
        is_system: true,
        createdAt: new Date(),
        updatedAt: new Date()
      },
      {
        name: 'USER',
        display_name: 'User',
        description: 'Regular user with limited access',
        permissions: JSON.stringify({
          dashboard: { view: true, edit: false, delete: false },
          users: { view: false, create: false, edit: false, delete: false },
          roles: { view: false, create: false, edit: false, delete: false },
          memberships: { view: true, create: false, edit: false, delete: false },
          payments: { view: true, create: true, edit: false, delete: false },
          coupons: { view: true, create: false, edit: false, delete: false },
          reports: { view: false, create: false, edit: false, delete: false },
          sports: { view: true, create: false, edit: false, delete: false },
          courts: { view: true, create: false, edit: false, delete: false },
          sportsComplex: { view: true, create: false, edit: false, delete: false },
          programs: { view: true, create: false, edit: false, delete: false },
          batches: { view: true, create: false, edit: false, delete: false },
          coaches: { view: true, create: false, edit: false, delete: false },
          students: { view: false, create: false, edit: false, delete: false },
          bookings: { view: true, create: true, edit: true, delete: true },
          settings: { view: false, edit: false }
        }),
        is_active: true,
        is_system: true,
        createdAt: new Date(),
        updatedAt: new Date()
      },
      {
        name: 'EMPLOYEE',
        display_name: 'Employee',
        description: 'Staff member with operational access',
        permissions: JSON.stringify({
          dashboard: { view: true, edit: false, delete: false },
          users: { view: true, create: false, edit: false, delete: false },
          roles: { view: false, create: false, edit: false, delete: false },
          memberships: { view: true, create: true, edit: true, delete: false },
          payments: { view: true, create: true, edit: true, delete: false },
          coupons: { view: true, create: false, edit: false, delete: false },
          reports: { view: true, create: false, edit: false, delete: false },
          sports: { view: true, create: false, edit: false, delete: false },
          courts: { view: true, create: false, edit: false, delete: false },
          sportsComplex: { view: true, create: false, edit: false, delete: false },
          programs: { view: true, create: false, edit: false, delete: false },
          batches: { view: true, create: false, edit: false, delete: false },
          coaches: { view: true, create: false, edit: false, delete: false },
          students: { view: true, create: true, edit: true, delete: false },
          bookings: { view: true, create: true, edit: true, delete: false },
          settings: { view: false, edit: false }
        }),
        is_active: true,
        is_system: true,
        createdAt: new Date(),
        updatedAt: new Date()
      },
      {
        name: 'COACH',
        display_name: 'Coach',
        description: 'Sports coach with program management access',
        permissions: JSON.stringify({
          dashboard: { view: true, edit: false, delete: false },
          users: { view: false, create: false, edit: false, delete: false },
          roles: { view: false, create: false, edit: false, delete: false },
          memberships: { view: false, create: false, edit: false, delete: false },
          payments: { view: false, create: false, edit: false, delete: false },
          coupons: { view: false, create: false, edit: false, delete: false },
          reports: { view: true, create: false, edit: false, delete: false },
          sports: { view: true, create: false, edit: false, delete: false },
          courts: { view: true, create: false, edit: false, delete: false },
          sportsComplex: { view: true, create: false, edit: false, delete: false },
          programs: { view: true, create: false, edit: true, delete: false },
          batches: { view: true, create: true, edit: true, delete: false },
          coaches: { view: true, create: false, edit: false, delete: false },
          students: { view: true, create: false, edit: true, delete: false },
          bookings: { view: true, create: false, edit: false, delete: false },
          settings: { view: false, edit: false }
        }),
        is_active: true,
        is_system: true,
        createdAt: new Date(),
        updatedAt: new Date()
      },
      {
        name: 'SECURITY',
        display_name: 'Security Guard',
        description: 'Security personnel with view-only access',
        permissions: JSON.stringify({
          dashboard: { view: true, edit: false, delete: false },
          users: { view: true, create: false, edit: false, delete: false },
          roles: { view: false, create: false, edit: false, delete: false },
          memberships: { view: true, create: false, edit: false, delete: false },
          payments: { view: false, create: false, edit: false, delete: false },
          coupons: { view: false, create: false, edit: false, delete: false },
          reports: { view: false, create: false, edit: false, delete: false },
          sports: { view: true, create: false, edit: false, delete: false },
          courts: { view: true, create: false, edit: false, delete: false },
          sportsComplex: { view: true, create: false, edit: false, delete: false },
          programs: { view: true, create: false, edit: false, delete: false },
          batches: { view: true, create: false, edit: false, delete: false },
          coaches: { view: true, create: false, edit: false, delete: false },
          students: { view: true, create: false, edit: false, delete: false },
          bookings: { view: true, create: false, edit: false, delete: false },
          settings: { view: false, edit: false }
        }),
        is_active: true,
        is_system: true,
        createdAt: new Date(),
        updatedAt: new Date()
      }
    ]);
  },

  async down (queryInterface, Sequelize) {
    await queryInterface.dropTable('Roles');
  }
};
