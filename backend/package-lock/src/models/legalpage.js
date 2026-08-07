'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class LegalPage extends Model {
    static associate() {}
  }
  LegalPage.init({
    id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
    type: {
      type: DataTypes.ENUM('privacy', 'cancellation', 'disclaimer', 'terms', 'holidays', 'equipment'),
      allowNull: false,
      unique: true,
    },
    title: { type: DataTypes.STRING(255), allowNull: false },
    content: { type: DataTypes.TEXT('long'), allowNull: false },
    createdAt: { allowNull: false, type: DataTypes.DATE },
    updatedAt: { allowNull: false, type: DataTypes.DATE },
  }, { sequelize, modelName: 'LegalPage', tableName: 'LegalPages' });
  return LegalPage;
};
