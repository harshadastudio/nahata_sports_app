'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class EntryLog extends Model {
    static associate(models) {
      EntryLog.belongsTo(models.VisitorPass, { foreignKey: 'visitorPassId' });
      EntryLog.belongsTo(models.User, { foreignKey: 'userId' });
      EntryLog.belongsTo(models.User, { foreignKey: 'securityGuardId' });
    }
  }
  
  EntryLog.init({
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },
    visitorPassId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'VisitorPasses',
        key: 'id',
      },
    },
    userId: {
      type: DataTypes.INTEGER,
      references: {
        model: 'Users',
        key: 'id',
      },
    },
    entryTime: {
      type: DataTypes.DATE,
      allowNull: false,
    },
    exitTime: {
      type: DataTypes.DATE,
    },
    gateNumber: {
      type: DataTypes.STRING,
    },
    securityGuardId: {
      type: DataTypes.INTEGER,
      references: {
        model: 'Users',
        key: 'id',
      },
    },
    scanType: {
      type: DataTypes.ENUM('Entry', 'Exit', 'Both'),
      defaultValue: 'Entry',
    },
    notes: {
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
    modelName: 'EntryLog',
    tableName: 'EntryLogs',
  });
  
  return EntryLog;
};