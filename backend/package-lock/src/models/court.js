
'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class Court extends Model {
    static associate(models) {
      Court.belongsTo(models.SportComplex, { foreignKey: 'sportComplexId' });
      Court.belongsTo(models.Sport, { foreignKey: 'sportId' });
      Court.hasMany(models.Booking, { foreignKey: 'courtId' });
      Court.hasMany(models.CourtSlot, { foreignKey: 'courtId', as: 'slots' });
    }
  }
  
  Court.init({
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },
    sportComplexId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'SportComplexes',
        key: 'id',
      },
    },
    sportId: {
      type: DataTypes.INTEGER,
      allowNull: false,
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
    },
    capacity: {
      type: DataTypes.INTEGER,
    },
    surfaceType: {
      type: DataTypes.ENUM('Grass', 'Clay', 'Hard', 'Synthetic', 'Wood'),
      defaultValue: 'Synthetic',
    },
    lightingAvailable: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
    },
    equipmentAvailable: {
      type: DataTypes.TEXT,
    },
    hourlyRate: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: false,
    },
    status: {
      type: DataTypes.ENUM('Active', 'Inactive'),
      defaultValue: 'Active',
    },
    image: {
      type: DataTypes.STRING,
    },
    showOnFrontend: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    },
    externalResourceId: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },
    externalResourceUuid: {
      type: DataTypes.STRING(255),
      allowNull: true,
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
    modelName: 'Court',
    tableName: 'Courts',
  });
  
  return Court;
};