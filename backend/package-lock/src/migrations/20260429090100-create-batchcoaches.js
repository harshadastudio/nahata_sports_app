'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('BatchCoaches', {
      id: {
        type: Sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true,
        allowNull: false,
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
      coachId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'Users',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      role: {
        type: Sequelize.ENUM('Head Coach', 'Assistant Coach', 'Trainer'),
        defaultValue: 'Head Coach',
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
    await queryInterface.addIndex('BatchCoaches', ['batchId']);
    await queryInterface.addIndex('BatchCoaches', ['coachId']);
    
    // Add unique constraint to prevent duplicate batch-coach assignments
    await queryInterface.addIndex('BatchCoaches', ['batchId', 'coachId'], {
      unique: true,
      name: 'unique_batch_coach'
    });
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.dropTable('BatchCoaches');
  }
};
