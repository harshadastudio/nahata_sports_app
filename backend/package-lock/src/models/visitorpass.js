'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class VisitorPass extends Model {
    static associate(models) {
      VisitorPass.belongsTo(models.Visitor, { foreignKey: 'visitorId' });
      VisitorPass.belongsTo(models.User, { foreignKey: 'issuedBy' });
      VisitorPass.hasMany(models.EntryLog, { foreignKey: 'visitorPassId' });
      VisitorPass.belongsTo(models.SportComplex, { foreignKey: 'sportComplexId', as: 'sportComplex' });
    }
  }
  
  VisitorPass.init({
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },
    visitorId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'Visitors',
        key: 'id',
      },
    },
    sportComplexId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: 'SportComplexes',
        key: 'id',
      },
      comment: 'The sports complex this visitor pass is for',
    },
    passNumber: {
      type: DataTypes.STRING,
      unique: true,
      allowNull: false,
    },
    validFrom: {
      type: DataTypes.DATE,
      allowNull: false,
    },
    validUntil: {
      type: DataTypes.DATE,
      allowNull: false,
    },
    issuedBy: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'Users',
        key: 'id',
      },
    },
    qrCode: {
      type: DataTypes.STRING,
    },
    status: {
      // 'Used' is legacy (pre check-in/check-out passes) and is read as 'CheckedIn'.
      type: DataTypes.ENUM('Active', 'Used', 'CheckedIn', 'CheckedOut', 'Expired', 'Cancelled'),
      defaultValue: 'Active',
    },
    checkInTime: {
      type: DataTypes.DATE,
    },
    checkOutTime: {
      type: DataTypes.DATE,
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
    modelName: 'VisitorPass',
    tableName: 'VisitorPasses',
  });
  
  return VisitorPass;
};