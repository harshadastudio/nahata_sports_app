'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    // Add new columns to Memberships table
    await queryInterface.addColumn('Memberships', 'planName', {
      type: Sequelize.STRING,
      allowNull: true, // Temporarily allow null for existing records
    });

    await queryInterface.addColumn('Memberships', 'price', {
      type: Sequelize.DECIMAL(10, 2),
      allowNull: true, // Temporarily allow null for existing records
    });

    await queryInterface.addColumn('Memberships', 'validity', {
      type: Sequelize.INTEGER,
      allowNull: true, // Temporarily allow null for existing records
      comment: 'Duration in days',
    });

    await queryInterface.addColumn('Memberships', 'bookings', {
      type: Sequelize.INTEGER,
      allowNull: false,
      defaultValue: 0,
      comment: 'Number of bookings allowed',
    });

    await queryInterface.addColumn('Memberships', 'discount', {
      type: Sequelize.DECIMAL(5, 2),
      defaultValue: 0,
      comment: 'Discount percentage',
    });

    // Create ENUM type for accessType
    await queryInterface.sequelize.query(`
      DO $$ BEGIN
        CREATE TYPE "enum_Memberships_accessType" AS ENUM ('Peak', 'Non-Peak', 'Both');
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryInterface.addColumn('Memberships', 'accessType', {
      type: Sequelize.ENUM('Peak', 'Non-Peak', 'Both'),
      allowNull: false,
      defaultValue: 'Both',
    });

    // Update existing status ENUM to include 'Inactive'
    await queryInterface.sequelize.query(`
      ALTER TYPE "enum_Memberships_status" ADD VALUE IF NOT EXISTS 'Inactive';
    `);

    // Set default values for existing records (if any)
    await queryInterface.sequelize.query(`
      UPDATE "Memberships" 
      SET 
        "planName" = 'Legacy Plan',
        "price" = "totalAmount",
        "validity" = DATE_PART('day', "endDate"::timestamp - "startDate"::timestamp)::integer
      WHERE "planName" IS NULL;
    `);

    // Now make the columns NOT NULL
    await queryInterface.changeColumn('Memberships', 'planName', {
      type: Sequelize.STRING,
      allowNull: false,
    });

    await queryInterface.changeColumn('Memberships', 'price', {
      type: Sequelize.DECIMAL(10, 2),
      allowNull: false,
    });

    await queryInterface.changeColumn('Memberships', 'validity', {
      type: Sequelize.INTEGER,
      allowNull: false,
      comment: 'Duration in days',
    });
  },

  down: async (queryInterface, Sequelize) => {
    // Remove added columns
    await queryInterface.removeColumn('Memberships', 'planName');
    await queryInterface.removeColumn('Memberships', 'price');
    await queryInterface.removeColumn('Memberships', 'validity');
    await queryInterface.removeColumn('Memberships', 'bookings');
    await queryInterface.removeColumn('Memberships', 'discount');
    await queryInterface.removeColumn('Memberships', 'accessType');

    // Drop the ENUM type
    await queryInterface.sequelize.query(`
      DROP TYPE IF EXISTS "enum_Memberships_accessType";
    `);

    // Note: Cannot remove 'Inactive' from status ENUM in PostgreSQL
    // You would need to recreate the ENUM type to remove a value
  }
};
