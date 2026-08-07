'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class StudentPassScanLog extends Model {
    static associate(models) {
      StudentPassScanLog.belongsTo(models.StudentBatches, {
        foreignKey: 'studentBatchId',
        as: 'studentBatch',
      });
      StudentPassScanLog.belongsTo(models.User, {
        foreignKey: 'scannedBy',
        as: 'scanner',
      });
    }
  }

  StudentPassScanLog.init(
    {
      id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
      studentBatchId: { type: DataTypes.INTEGER, allowNull: false },
      scannedBy: { type: DataTypes.INTEGER, allowNull: true },
      scannerRole: { type: DataTypes.STRING, allowNull: true },
      attendanceMarked: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: false },
      sportComplexId: { type: DataTypes.INTEGER, allowNull: true },
    },
    { sequelize, modelName: 'StudentPassScanLog', tableName: 'StudentPassScanLogs' }
  );

  return StudentPassScanLog;
};
