'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    // First, check if the foreign key constraint exists and remove it
    try {
      await queryInterface.removeConstraint('Programs', 'Programs_ibfk_2');
    } catch (error) {
      console.log('Foreign key constraint does not exist or already removed');
    }

    // Update the coachId column to reference Coaches table
    await queryInterface.changeColumn('Programs', 'coachId', {
      type: Sequelize.INTEGER,
      allowNull: true,
      references: {
        model: 'Coaches',
        key: 'id',
      },
      onUpdate: 'CASCADE',
      onDelete: 'SET NULL',
    });
  },

  down: async (queryInterface, Sequelize) => {
    // Revert back to Users table reference
    await queryInterface.changeColumn('Programs', 'coachId', {
      type: Sequelize.INTEGER,
      allowNull: true,
      references: {
        model: 'Users',
        key: 'id',
      },
      onUpdate: 'CASCADE',
      onDelete: 'SET NULL',
    });
  }
};
