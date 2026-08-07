'use strict';
const { Model } = require('sequelize');
module.exports = (sequelize, DataTypes) => {
  class AboutPageSettings extends Model {
    // No association needed — sections are independent
    static associate() {}
  }
  AboutPageSettings.init({
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    heroTitle: { type: DataTypes.STRING(255), allowNull: false, defaultValue: 'About Us' },
    whyChooseHeading: { type: DataTypes.STRING(255), allowNull: true },
    whyChoosePoints: { type: DataTypes.JSON, allowNull: true },
    createdAt: { allowNull: false, type: DataTypes.DATE },
    updatedAt: { allowNull: false, type: DataTypes.DATE },
  }, { sequelize, modelName: 'AboutPageSettings', tableName: 'AboutPageSettings' });
  return AboutPageSettings;
};
