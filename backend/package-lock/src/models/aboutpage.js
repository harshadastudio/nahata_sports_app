'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class AboutPage extends Model {
    static associate() {}
  }
  AboutPage.init({
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    heroTitle: { type: DataTypes.STRING(255), allowNull: false, defaultValue: 'About Us' },
    section1Label: { type: DataTypes.STRING(100), allowNull: true },
    section1Heading: { type: DataTypes.STRING(500), allowNull: true },
    section1Description: { type: DataTypes.TEXT, allowNull: true },
    section1Image: { type: DataTypes.STRING(500), allowNull: true },
    section1SportsList: { type: DataTypes.JSON, allowNull: true },
    section1BookingText: { type: DataTypes.TEXT, allowNull: true },
    section2Label: { type: DataTypes.STRING(100), allowNull: true },
    section2Heading: { type: DataTypes.STRING(500), allowNull: true },
    section2Description: { type: DataTypes.TEXT, allowNull: true },
    section2Image: { type: DataTypes.STRING(500), allowNull: true },
    section2FeaturesList: { type: DataTypes.JSON, allowNull: true },
    section2CommunityText: { type: DataTypes.TEXT, allowNull: true },
    whyChooseHeading: { type: DataTypes.STRING(255), allowNull: true },
    whyChoosePoints: { type: DataTypes.JSON, allowNull: true },
    createdAt: { allowNull: false, type: DataTypes.DATE },
    updatedAt: { allowNull: false, type: DataTypes.DATE },
  }, { sequelize, modelName: 'AboutPage', tableName: 'AboutPage' });
  return AboutPage;
};
