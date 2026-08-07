'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class StudentParentSectionSettings extends Model {
    static associate() {}
  }

  StudentParentSectionSettings.init({
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    image1: { type: DataTypes.STRING(500), allowNull: true, defaultValue: null },
    image2: { type: DataTypes.STRING(500), allowNull: true, defaultValue: null },
    // Stats counter shown above the features (array of { value, suffix, label, color }).
    counters: { type: DataTypes.JSON, allowNull: true, defaultValue: null },
    createdAt: { allowNull: false, type: DataTypes.DATE },
    updatedAt: { allowNull: false, type: DataTypes.DATE },
  }, {
    sequelize,
    modelName: 'StudentParentSectionSettings',
    tableName: 'StudentParentSectionSettings',
  });

  return StudentParentSectionSettings;
};
