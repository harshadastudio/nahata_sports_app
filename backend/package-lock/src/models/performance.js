'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class Performance extends Model {
    static associate(models) {
      Performance.belongsTo(models.Student, { 
        foreignKey: 'studentId',
        as: 'student'
      });
      Performance.belongsTo(models.Sport, { 
        foreignKey: 'sportId',
        as: 'sport'
      });
    }
  }
  
  Performance.init({
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
    sportId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'Sports',
        key: 'id',
      },
    },
    assessmentDate: {
      type: DataTypes.DATEONLY,
      allowNull: false,
    },
    skillLevel: {
      type: DataTypes.ENUM('Beginner', 'Intermediate', 'Advanced', 'Expert'),
      defaultValue: 'Beginner',
    },
    fitnessScore: {
      type: DataTypes.INTEGER,
      validate: {
        min: 0,
        max: 100,
      },
    },
    coachNotes: {
      type: DataTypes.TEXT,
    },
    improvementAreas: {
      type: DataTypes.TEXT,
    },
    nextAssessmentDate: {
      type: DataTypes.DATEONLY,
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
    modelName: 'Performance',
    tableName: 'Performances',
  });
  
  return Performance;
};