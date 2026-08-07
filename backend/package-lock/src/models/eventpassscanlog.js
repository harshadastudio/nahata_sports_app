'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class EventPassScanLog extends Model {
    static associate(models) {
      EventPassScanLog.belongsTo(models.EventIndividualPass, {
        foreignKey: 'individualPassId',
        as: 'individualPass',
      });
      EventPassScanLog.belongsTo(models.EventPass, {
        foreignKey: 'eventPassId',
        as: 'event',
      });
      EventPassScanLog.belongsTo(models.User, {
        foreignKey: 'scannedBy',
        as: 'scanner',
      });
    }
  }

  EventPassScanLog.init(
    {
      id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
      individualPassId: { type: DataTypes.INTEGER, allowNull: false },
      eventPassId: { type: DataTypes.INTEGER, allowNull: true },
      scannedBy: { type: DataTypes.INTEGER, allowNull: true },
      scanType: { type: DataTypes.ENUM('In', 'Out'), allowNull: false },
      sportComplexId: { type: DataTypes.INTEGER, allowNull: true },
    },
    { sequelize, modelName: 'EventPassScanLog', tableName: 'EventPassScanLogs' }
  );

  return EventPassScanLog;
};
