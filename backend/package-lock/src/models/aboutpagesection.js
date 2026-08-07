'use strict';
const { Model } = require('sequelize');
module.exports = (sequelize, DataTypes) => {
  class AboutPageSection extends Model {
    static associate() {}
  }
  AboutPageSection.init({
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    label: { type: DataTypes.STRING(100), allowNull: true },
    heading: { type: DataTypes.STRING(500), allowNull: true },
    description: { type: DataTypes.TEXT, allowNull: true },
    image: { type: DataTypes.STRING(500), allowNull: true },
    bulletPoints: { type: DataTypes.JSON, allowNull: true },
    extraText: { type: DataTypes.TEXT, allowNull: true },
    imagePosition: {
      type: DataTypes.ENUM('left', 'right'),
      allowNull: false,
      defaultValue: 'left',
    },
    sortOrder: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 0 },
    createdAt: { allowNull: false, type: DataTypes.DATE },
    updatedAt: { allowNull: false, type: DataTypes.DATE },
  }, { sequelize, modelName: 'AboutPageSection', tableName: 'AboutPageSections' });
  return AboutPageSection;
};
