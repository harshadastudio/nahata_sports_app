'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    // Create enum for order status
    await queryInterface.sequelize.query(`
      DO $$ BEGIN
        CREATE TYPE "enum_Orders_status" AS ENUM ('Pending', 'Completed', 'Cancelled', 'Refunded');
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    // Create Orders table
    await queryInterface.createTable('Orders', {
      id: {
        type: Sequelize.INTEGER,
        primaryKey: true,
        autoIncrement: true,
        allowNull: false
      },
      user_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'Users',
          key: 'id'
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE'
      },
      booking_id: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'Bookings',
          key: 'id'
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE'
      },
      total_amount: {
        type: Sequelize.DECIMAL(10, 2),
        allowNull: false
      },
      status: {
        type: Sequelize.ENUM('Pending', 'Completed', 'Cancelled', 'Refunded'),
        allowNull: true,
        defaultValue: 'Pending'
      },
      order_date: {
        type: Sequelize.DATE,
        allowNull: false
      },
      createdAt: {
        type: Sequelize.DATE,
        allowNull: false
      },
      updatedAt: {
        type: Sequelize.DATE,
        allowNull: false
      }
    });

    console.log('✅ Orders table created successfully');
  },

  down: async (queryInterface, Sequelize) => {
    // Drop Orders table
    await queryInterface.dropTable('Orders');

    // Drop enum type
    await queryInterface.sequelize.query(`
      DROP TYPE IF EXISTS "enum_Orders_status";
    `);

    console.log('✅ Orders table dropped successfully');
  }
};
