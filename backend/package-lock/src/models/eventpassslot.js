'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class EventPassSlot extends Model {
    static associate(models) {
      EventPassSlot.belongsTo(models.EventPass, {
        foreignKey: 'eventPassId',
        as: 'event',
      });
      EventPassSlot.hasMany(models.EventPassBooking, {
        foreignKey: 'slotId',
        as: 'bookings',
      });
    }
  }

  EventPassSlot.init(
    {
      id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
      eventPassId: {
        type: DataTypes.INTEGER,
        allowNull: false,
        references: { model: 'EventPasses', key: 'id' },
      },
      name: { type: DataTypes.STRING(255), allowNull: false },
      date: { type: DataTypes.DATEONLY, allowNull: false },
      price: { type: DataTypes.DECIMAL(10, 2), allowNull: false, defaultValue: 0 },
      passType: { type: DataTypes.STRING(100), allowNull: true },
      startTime: { type: DataTypes.TIME, allowNull: true },
      endTime: { type: DataTypes.TIME, allowNull: true },
      status: {
        type: DataTypes.ENUM('Active', 'Inactive'),
        defaultValue: 'Active',
        allowNull: false,
      },
      createdAt: { allowNull: false, type: DataTypes.DATE },
      updatedAt: { allowNull: false, type: DataTypes.DATE },
    },
    { sequelize, modelName: 'EventPassSlot', tableName: 'EventPassSlots' }
  );

  return EventPassSlot;
};
