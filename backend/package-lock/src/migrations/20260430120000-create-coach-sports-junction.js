'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    // Create CoachSports junction table for many-to-many relationship
    await queryInterface.createTable('CoachSports', {
      id: {
        type: Sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true,
      },
      coachId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'Coaches',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      sportId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'Sports',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      isPrimary: {
        type: Sequelize.BOOLEAN,
        defaultValue: false,
        comment: 'Indicates if this is the primary sport for the coach',
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

    // Add unique constraint to prevent duplicate coach-sport assignments
    await queryInterface.addIndex('CoachSports', ['coachId', 'sportId'], {
      unique: true,
      name: 'unique_coach_sport',
    });

    // Add indexes for better query performance
    await queryInterface.addIndex('CoachSports', ['coachId']);
    await queryInterface.addIndex('CoachSports', ['sportId']);
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.dropTable('CoachSports');
  }
};
