'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    // Create ENUM type first (for PostgreSQL compatibility)
    await queryInterface.sequelize.query(`
      DO $$ BEGIN
        CREATE TYPE "enum_StudentBatches_status" AS ENUM ('Active', 'Completed', 'Dropped', 'Transferred');
      EXCEPTION
        WHEN duplicate_object THEN null;
      END $$;
    `);

    await queryInterface.createTable('StudentBatches', {
      id: {
        type: Sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true,
        allowNull: false,
      },
      studentId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'Students',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      batchId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'Batches',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      enrollmentDate: {
        type: Sequelize.DATEONLY,
        allowNull: false,
      },
      status: {
        type: Sequelize.ENUM('Active', 'Completed', 'Dropped', 'Transferred'),
        defaultValue: 'Active',
        allowNull: false,
      },
      feesPaid: {
        type: Sequelize.BOOLEAN,
        defaultValue: false,
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
    await queryInterface.addIndex('StudentBatches', ['studentId']);
    await queryInterface.addIndex('StudentBatches', ['batchId']);
    await queryInterface.addIndex('StudentBatches', ['status']);
    
    // Add unique constraint to prevent duplicate student-batch enrollments
    await queryInterface.addIndex('StudentBatches', ['studentId', 'batchId'], {
      unique: true,
      name: 'unique_student_batch'
    });
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.dropTable('StudentBatches');
    // Drop ENUM type
    await queryInterface.sequelize.query('DROP TYPE IF EXISTS "enum_StudentBatches_status";');
  }
};
