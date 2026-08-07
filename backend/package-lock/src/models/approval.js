'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class Approval extends Model {
    static associate(models) {
      Approval.belongsTo(models.User, { foreignKey: 'approverId' });
    }
  }
  
  Approval.init({
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },
    requestType: {
      type: DataTypes.ENUM('Booking', 'Refund', 'Leave', 'Expense', 'Other'),
      allowNull: false,
    },
    requestId: {
      type: DataTypes.INTEGER,
      allowNull: false,
    },
    approverId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'Users',
        key: 'id',
      },
    },
    status: {
      type: DataTypes.ENUM('Pending', 'Approved', 'Rejected'),
      defaultValue: 'Pending',
    },
    comments: {
      type: DataTypes.TEXT,
    },
    approvedAt: {
      type: DataTypes.DATE,
    },
    rejectionReason: {
      type: DataTypes.TEXT,
    },
    createdAt: {
      allowNull: false,
      type: DataTypes.DATE,
    },
    updatedAt: {
      allowNull: false,
      type: DataTypes.DATE,
    },
  }, {
    sequelize,
    modelName: 'Approval',
    tableName: 'Approvals',
  });
  
  return Approval;
};