'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class CoachSport extends Model {
    static associate(models) {
      // CoachSport belongs to Coach
      CoachSport.belongsTo(models.Coach, {
        foreignKey: 'coachId',
        as: 'coach'
      });
      
      // CoachSport belongs to Sport
      CoachSport.belongsTo(models.Sport, {
        foreignKey: 'sportId',
        as: 'sport'
      });
    }
  }
  
  CoachSport.init({
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
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
      allowNull: false,
      references: {
        model: 'Sports',
        key: 'id',
      },
    },
    isPrimary: {
      type: DataTypes.BOOLEAN,
      defaultValue: false,
      comment: 'Indicates if this is the primary sport for the coach',
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
    modelName: 'CoachSport',
    tableName: 'CoachSports',
    timestamps: true,
  });
  
  return CoachSport;
};
