'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class FeeStructure extends Model {
    static associate(models) {
      // A fee structure belongs to a coach
      FeeStructure.belongsTo(models.Coach, {
        foreignKey: 'coachId',
        as: 'coach'
      });

      // A fee structure can be linked to a sport
      FeeStructure.belongsTo(models.Sport, {
        foreignKey: 'sportId',
        as: 'sport'
      });

      // A fee structure can be linked to a batch (the offering)
      FeeStructure.belongsTo(models.Batch, {
        foreignKey: 'batchId',
        as: 'batch'
      });
    }
  }

  FeeStructure.init(
    {
      id: {
        type: DataTypes.INTEGER,
        primaryKey: true,
        autoIncrement: true,
      },
      coachId: {
        type: DataTypes.INTEGER,
        allowNull: false,
        references: {
          model: 'Coaches',
          key: 'id',
        },
      },
      sportId: {
        type: DataTypes.INTEGER,
        allowNull: true,
        references: {
          model: 'Sports',
          key: 'id',
        },
      },
      name: {
        type: DataTypes.STRING,
        allowNull: false,
      },
      description: {
        type: DataTypes.TEXT,
        allowNull: true,
      },
      feeType: {
        type: DataTypes.ENUM('Monthly', 'Quarterly', 'Yearly', 'One-Time', 'Per-Session'),
        allowNull: false,
        defaultValue: 'Monthly',
      },
      amount: {
        type: DataTypes.DECIMAL(10, 2),
        allowNull: false,
      },
      currency: {
        type: DataTypes.STRING(3),
        allowNull: false,
        defaultValue: 'INR',
      },
      discountPercentage: {
        type: DataTypes.DECIMAL(5, 2),
        allowNull: true,
        defaultValue: 0,
      },
      discountAmount: {
        type: DataTypes.DECIMAL(10, 2),
        allowNull: true,
        defaultValue: 0,
      },
      finalAmount: {
        type: DataTypes.DECIMAL(10, 2),
        allowNull: false,
      },
      validFrom: {
        type: DataTypes.DATE,
        allowNull: true,
      },
      validUntil: {
        type: DataTypes.DATE,
        allowNull: true,
      },
      status: {
        type: DataTypes.ENUM('Active', 'Inactive', 'Archived'),
        allowNull: false,
        defaultValue: 'Active',
      },
      approvalStatus: {
        type: DataTypes.ENUM('Pending', 'Approved', 'Rejected'),
        allowNull: false,
        defaultValue: 'Pending',
      },
      approvedBy: {
        type: DataTypes.INTEGER,
        allowNull: true,
        references: {
          model: 'Users',
          key: 'id',
        },
      },
      approvedAt: {
        type: DataTypes.DATE,
        allowNull: true,
      },
      rejectionReason: {
        type: DataTypes.TEXT,
        allowNull: true,
      },
      notes: {
        type: DataTypes.TEXT,
        allowNull: true,
      },
      createdAt: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },
      updatedAt: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
      },
    },
    {
      sequelize,
      modelName: 'FeeStructure',
      tableName: 'FeeStructures',
      timestamps: true,
    }
  );

  return FeeStructure;
};
