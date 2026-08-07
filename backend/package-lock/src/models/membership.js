'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class Membership extends Model {
    static associate(models) {
      Membership.belongsTo(models.User, { foreignKey: 'userId' });
    }
  }
  
  Membership.init({
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },
    userId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'Users',
        key: 'id',
      },
    },
    planId: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    planName: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    price: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: false,
    },
    validity: {
      type: DataTypes.INTEGER,
      allowNull: false,
      comment: 'Duration in days',
    },
    bookings: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
      comment: 'Number of bookings allowed',
    },
    discount: {
      type: DataTypes.DECIMAL(5, 2),
      defaultValue: 0,
      comment: 'Discount percentage',
    },
    accessType: {
      type: DataTypes.ENUM('Peak', 'Non-Peak', 'Both'),
      allowNull: false,
      defaultValue: 'Both',
    },
    features: {
      type: DataTypes.TEXT,
      allowNull: true,
      comment: 'Comma-separated list of features',
    },
    startDate: {
      type: DataTypes.DATEONLY,
      allowNull: false,
    },
    endDate: {
      type: DataTypes.DATEONLY,
      allowNull: false,
    },
    status: {
      type: DataTypes.ENUM('Active', 'Expired', 'Cancelled', 'Suspended', 'Inactive'),
      defaultValue: 'Active',
    },
    paymentStatus: {
      type: DataTypes.ENUM('Paid', 'Pending', 'Overdue'),
      defaultValue: 'Pending',
    },
    autoRenew: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
    discountApplied: {
      type: DataTypes.DECIMAL(10, 2),
      defaultValue: 0,
    },
    totalAmount: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: false,
    },
    createdAt: {
      allowNull: false,
      type: DataTypes.DATE,
    },
    updatedAt: {
      allowNull: false,
      type: DataTypes.DATE,
    },
    deletedAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
  }, {
    sequelize,
    modelName: 'Membership',
    tableName: 'Memberships',
    paranoid: true, // Enable soft deletes
    timestamps: true,
  });
  
  return Membership;
};