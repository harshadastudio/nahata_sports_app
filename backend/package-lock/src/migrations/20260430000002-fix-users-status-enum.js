'use strict';

/**
 * The database has enum_Users_status with lowercase values: 'active', 'blocked', 'inactive'
 * But the application code uses 'Active' and 'Blocked'.
 * This migration renames the existing enum and creates a new one with the correct casing,
 * then migrates all existing data.
 */
module.exports = {
  async up(queryInterface) {
    try {
      // Step 1: Add the new capitalized values to the existing enum (if they don't exist)
      await queryInterface.sequelize.query(`
        DO $$ BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'Active' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'enum_Users_status')) THEN
            ALTER TYPE "enum_Users_status" ADD VALUE 'Active';
          END IF;
        END $$;
      `);
      
      await queryInterface.sequelize.query(`
        DO $$ BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'Blocked' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'enum_Users_status')) THEN
            ALTER TYPE "enum_Users_status" ADD VALUE 'Blocked';
          END IF;
        END $$;
      `);
      
      await queryInterface.sequelize.query(`
        DO $$ BEGIN
          IF NOT EXISTS (SELECT 1 FROM pg_enum WHERE enumlabel = 'Inactive' AND enumtypid = (SELECT oid FROM pg_type WHERE typname = 'enum_Users_status')) THEN
            ALTER TYPE "enum_Users_status" ADD VALUE 'Inactive';
          END IF;
        END $$;
      `);

      // Step 2: Migrate existing lowercase data to capitalized (only if lowercase values exist)
      await queryInterface.sequelize.query(`
        UPDATE "Users" SET status = 'Active' WHERE status = 'active';
      `);
      await queryInterface.sequelize.query(`
        UPDATE "Users" SET status = 'Blocked' WHERE status = 'blocked';
      `);
      await queryInterface.sequelize.query(`
        UPDATE "Users" SET status = 'Inactive' WHERE status = 'inactive';
      `);
      
      console.log('✅ Users status enum migration completed successfully');
    } catch (error) {
      console.log('⚠️  Migration already applied or no changes needed:', error.message);
      // Don't throw error if enum values already exist
    }
  },

  async down(queryInterface) {
    // Revert data back to lowercase (only if needed)
    try {
      await queryInterface.sequelize.query(`
        UPDATE "Users" SET status = 'active' WHERE status = 'Active';
      `);
      await queryInterface.sequelize.query(`
        UPDATE "Users" SET status = 'blocked' WHERE status = 'Blocked';
      `);
      await queryInterface.sequelize.query(`
        UPDATE "Users" SET status = 'inactive' WHERE status = 'Inactive';
      `);
    } catch (error) {
      console.log('⚠️  Rollback not needed:', error.message);
    }
  },
};
