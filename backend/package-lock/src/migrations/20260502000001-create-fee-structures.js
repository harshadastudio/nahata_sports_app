'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.createTable('FeeStructures', {
      id: {
        type: Sequelize.INTEGER,
        primaryKey: true,
        autoIncrement: true,
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
        allowNull: true,
        references: {
          model: 'Sports',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
      },
      programId: {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: {
          model: 'Programs',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
      },
      name: {
        type: Sequelize.STRING,
        allowNull: false,
      },
      description: {
        type: Sequelize.TEXT,
        allowNull: true,
      },
      feeType: {
        type: Sequelize.ENUM('Monthly', 'Quarterly', 'Yearly', 'One-Time', 'Per-Session'),
        allowNull: false,
        defaultValue: 'Monthly',
      },
      amount: {
        type: Sequelize.DECIMAL(10, 2),
        allowNull: false,
      },
      currency: {
        type: Sequelize.STRING(3),
        allowNull: false,
        defaultValue: 'INR',
      },
      discountPercentage: {
        type: Sequelize.DECIMAL(5, 2),
        allowNull: true,
        defaultValue: 0,
      },
      discountAmount: {
        type: Sequelize.DECIMAL(10, 2),
        allowNull: true,
        defaultValue: 0,
      },
      finalAmount: {
        type: Sequelize.DECIMAL(10, 2),
        allowNull: false,
      },
      validFrom: {
        type: Sequelize.DATE,
        allowNull: true,
      },
      validUntil: {
        type: Sequelize.DATE,
        allowNull: true,
      },
      status: {
        type: Sequelize.ENUM('Active', 'Inactive', 'Archived'),
        allowNull: false,
        defaultValue: 'Active',
      },
      approvalStatus: {
        type: Sequelize.ENUM('Pending', 'Approved', 'Rejected'),
        allowNull: false,
        defaultValue: 'Pending',
      },
      approvedBy: {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: {
          model: 'Users',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
      },
      approvedAt: {
        type: Sequelize.DATE,
        allowNull: true,
      },
      rejectionReason: {
        type: Sequelize.TEXT,
        allowNull: true,
      },
      notes: {
        type: Sequelize.TEXT,
        allowNull: true,
      },
      createdAt: {
        type: Sequelize.DATE,
        allowNull: false,
        defaultValue: Sequelize.literal('CURRENT_TIMESTAMP'),
      },
      updatedAt: {
        type: Sequelize.DATE,
        allowNull: false,
        defaultValue: Sequelize.literal('CURRENT_TIMESTAMP'),
      },
    });

    // Add indexes
    await queryInterface.addIndex('FeeStructures', ['coachId']);
    await queryInterface.addIndex('FeeStructures', ['sportId']);
    await queryInterface.addIndex('FeeStructures', ['programId']);
    await queryInterface.addIndex('FeeStructures', ['status']);
    await queryInterface.addIndex('FeeStructures', ['approvalStatus']);
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.dropTable('FeeStructures');
  },
};
