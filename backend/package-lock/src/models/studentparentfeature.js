'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class StudentParentFeature extends Model {
    static associate() {}
  }

  StudentParentFeature.init({
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    title: { type: DataTypes.STRING, allowNull: false },
    description: { type: DataTypes.STRING, allowNull: true, defaultValue: null },
    icon: { type: DataTypes.STRING(50), allowNull: true, defaultValue: 'CheckCircle2' },
    sortOrder: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 0 },
    showOnFrontend: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true },
    createdAt: { allowNull: false, type: DataTypes.DATE },
    updatedAt: { allowNull: false, type: DataTypes.DATE },
  }, {
    sequelize,
    modelName: 'StudentParentFeature',
    tableName: 'StudentParentFeatures',
  });

  return StudentParentFeature;
};
