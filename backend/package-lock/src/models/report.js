'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class Report extends Model {
    static associate(models) {
      Report.belongsTo(models.User, { foreignKey: 'generatedBy' });
    }
  }
  
  Report.init({
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },
    reportType: {
      type: DataTypes.ENUM('Booking', 'Revenue', 'Attendance', 'Student', 'Visitor', 'Inventory'),
      allowNull: false,
    },
    generatedBy: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'Users',
        key: 'id',
      },
    },
    parameters: {
      type: DataTypes.TEXT,
    },
    data: {
      type: DataTypes.TEXT,
    },
    filePath: {
      type: DataTypes.STRING,
    },
    status: {
      type: DataTypes.ENUM('Generating', 'Completed', 'Failed'),
      defaultValue: 'Generating',
    },
    scheduled: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
    generatedAt: {
      type: DataTypes.DATE,
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
    modelName: 'Report',
    tableName: 'Reports',
  });
  
  return Report;
};