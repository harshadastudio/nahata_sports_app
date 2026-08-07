'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class CourtSlot extends Model {
    static associate(models) {
      CourtSlot.belongsTo(models.Court, { foreignKey: 'courtId', as: 'court' });
    }
  }

  CourtSlot.init(
    {
      id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
      courtId: {
        type: DataTypes.INTEGER,
        allowNull: false,
        references: { model: 'Courts', key: 'id' },
      },
      startTime: { type: DataTypes.TIME, allowNull: false },
      endTime: { type: DataTypes.TIME, allowNull: false },
      // Comma-separated days: "Monday,Wednesday,Friday"
      availableDays: {
        type: DataTypes.STRING(100),
        allowNull: false,
        defaultValue: 'Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday',
      },
      slotType: {
        type: DataTypes.ENUM('Regular', 'Peak'),
        defaultValue: 'Regular',
        allowNull: false,
      },
      priceOverride: { type: DataTypes.DECIMAL(10, 2), allowNull: true },
      status: {
        type: DataTypes.ENUM('Active', 'Inactive'),
        defaultValue: 'Active',
        allowNull: false,
      },
      createdAt: { allowNull: false, type: DataTypes.DATE },
      updatedAt: { allowNull: false, type: DataTypes.DATE },
    },
    { sequelize, modelName: 'CourtSlot', tableName: 'CourtSlots' }
  );

  return CourtSlot;
};
