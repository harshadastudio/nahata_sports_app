'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up (queryInterface, Sequelize) {
    // Helper function to check if column exists
    const columnExists = async (tableName, columnName) => {
      const table = await queryInterface.describeTable(tableName);
      return table[columnName] !== undefined;
    };

    // Add total_bookings if it doesn't exist
    if (!(await columnExists('Users', 'total_bookings'))) {
      await queryInterface.addColumn('Users', 'total_bookings', {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 0
      });
    }

    // Add membership_type if it doesn't exist
    if (!(await columnExists('Users', 'membership_type'))) {
      // Create enum type if it doesn't exist
      await queryInterface.sequelize.query(`
        DO $$ BEGIN
          CREATE TYPE "enum_Users_membership_type" AS ENUM ('Basic', 'Premium', 'VIP', 'Corporate');
        EXCEPTION
          WHEN duplicate_object THEN null;
        END $$;
      `);
      
      await queryInterface.addColumn('Users', 'membership_type', {
        type: Sequelize.ENUM('Basic', 'Premium', 'VIP', 'Corporate'),
        allowNull: true,
        defaultValue: null
      });
    }

    // Add status if it doesn't exist
    if (!(await columnExists('Users', 'status'))) {
      // Drop old enum if it exists with wrong values
      await queryInterface.sequelize.query(`
        DROP TYPE IF EXISTS "enum_Users_status" CASCADE;
      `);
      
      // Create new enum with correct values
      await queryInterface.sequelize.query(`
        CREATE TYPE "enum_Users_status" AS ENUM ('Active', 'Blocked');
      `);
      
      await queryInterface.addColumn('Users', 'status', {
        type: Sequelize.ENUM('Active', 'Blocked'),
        allowNull: false,
        defaultValue: 'Active'
      });
    }

    // Add join_date if it doesn't exist
    if (!(await columnExists('Users', 'join_date'))) {
      await queryInterface.addColumn('Users', 'join_date', {
        type: Sequelize.DATEONLY,
        allowNull: false,
        defaultValue: Sequelize.literal('CURRENT_DATE')
      });
    }

    // Add last_active if it doesn't exist
    if (!(await columnExists('Users', 'last_active'))) {
      await queryInterface.addColumn('Users', 'last_active', {
        type: Sequelize.DATEONLY,
        allowNull: true,
        defaultValue: null
      });
    }

    // Add avatar if it doesn't exist
    if (!(await columnExists('Users', 'avatar'))) {
      await queryInterface.addColumn('Users', 'avatar', {
        type: Sequelize.STRING,
        allowNull: true,
        defaultValue: null
      });
    }

    // Add employee_id if it doesn't exist
    if (!(await columnExists('Users', 'employee_id'))) {
      await queryInterface.addColumn('Users', 'employee_id', {
        type: Sequelize.STRING,
        allowNull: true,
        defaultValue: null
      });
    }

    // Add department if it doesn't exist
    if (!(await columnExists('Users', 'department'))) {
      await queryInterface.addColumn('Users', 'department', {
        type: Sequelize.STRING,
        allowNull: true,
        defaultValue: null
      });
    }

    // Add assigned_sports if it doesn't exist
    if (!(await columnExists('Users', 'assigned_sports'))) {
      await queryInterface.addColumn('Users', 'assigned_sports', {
        type: Sequelize.JSON,
        allowNull: true,
        defaultValue: null
      });
    }

    // Add assigned_location if it doesn't exist
    if (!(await columnExists('Users', 'assigned_location'))) {
      await queryInterface.addColumn('Users', 'assigned_location', {
        type: Sequelize.STRING,
        allowNull: true,
        defaultValue: null
      });
    }
  },

  async down (queryInterface, Sequelize) {
    // Remove columns in reverse order
    await queryInterface.removeColumn('Users', 'assigned_location');
    await queryInterface.removeColumn('Users', 'assigned_sports');
    await queryInterface.removeColumn('Users', 'department');
    await queryInterface.removeColumn('Users', 'employee_id');
    await queryInterface.removeColumn('Users', 'avatar');
    await queryInterface.removeColumn('Users', 'last_active');
    await queryInterface.removeColumn('Users', 'join_date');
    await queryInterface.removeColumn('Users', 'status');
    await queryInterface.removeColumn('Users', 'membership_type');
    await queryInterface.removeColumn('Users', 'total_bookings');
  }
};
