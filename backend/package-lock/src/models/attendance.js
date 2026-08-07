'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class Attendance extends Model {
    static associate(models) {
      Attendance.belongsTo(models.Student, { foreignKey: 'studentId', as: 'student' });
      Attendance.belongsTo(models.Batch, { foreignKey: 'batchId', as: 'batch' });
      Attendance.belongsTo(models.User, { foreignKey: 'markedBy', as: 'marker' });
    }
  }
  
  Attendance.init({
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },
    studentId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'Students',
        key: 'id',
      },
    },
    batchId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'Batches',
        key: 'id',
      },
    },
    date: {
      type: DataTypes.DATEONLY,
      allowNull: false,
    },
    status: {
      type: DataTypes.ENUM('Present', 'Absent', 'Late', 'Leave'),
      defaultValue: 'Present',
    },
    checkInTime: {
      type: DataTypes.TIME,
    },
    checkOutTime: {
      type: DataTypes.TIME,
    },
    notes: {
      type: DataTypes.TEXT,
    },
    markedBy: {
      type: DataTypes.INTEGER,
      references: {
        model: 'Users',
        key: 'id',
      },
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
    modelName: 'Attendance',
    tableName: 'Attendances',
  });
  
  return Attendance;
};