'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.createTable('Coaches', {
      id: {
        allowNull: false,
        autoIncrement: true,
        primaryKey: true,
        type: Sequelize.INTEGER
      },
      name: {
        type: Sequelize.STRING,
        allowNull: false
      },
      email: {
        type: Sequelize.STRING,
        allowNull: true,
        unique: true
      },
      phone: {
        type: Sequelize.STRING,
        allowNull: true
      },
      sportId: {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: {
          model: 'Sports',
          key: 'id'
        },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL'
      },
      ground: {
        type: Sequelize.STRING,
        allowNull: true,
        comment: 'Ground/Complex location'
      },
      experience: {
        type: Sequelize.STRING,
        allowNull: true,
        comment: 'Years of experience'
      },
      specialization: {
        type: Sequelize.TEXT,
        allowNull: true,
        comment: 'Areas of specialization'
      },
      qualifications: {
        type: Sequelize.TEXT,
        allowNull: true,
        comment: 'Certifications and qualifications'
      },
      bio: {
        type: Sequelize.TEXT,
        allowNull: true
      },
      image: {
        type: Sequelize.STRING,
        allowNull: true
      },
      status: {
        type: Sequelize.ENUM('Active', 'Inactive'),
        defaultValue: 'Active'
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

    // Add index on sportId for faster queries
    await queryInterface.addIndex('Coaches', ['sportId']);
    
    // Add index on status
    await queryInterface.addIndex('Coaches', ['status']);
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.dropTable('Coaches');
  }
};
