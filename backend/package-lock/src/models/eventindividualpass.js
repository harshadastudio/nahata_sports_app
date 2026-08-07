'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class EventIndividualPass extends Model {
    static associate(models) {
      EventIndividualPass.belongsTo(models.EventPassBooking, {
        foreignKey: 'bookingId',
        as: 'booking',
      });
      EventIndividualPass.belongsTo(models.EventPass, {
        foreignKey: 'eventPassId',
        as: 'event',
      });
      EventIndividualPass.belongsTo(models.EventPassSlot, {
        foreignKey: 'slotId',
        as: 'slot',
      });
      EventIndividualPass.hasMany(models.EventPassMember, {
        foreignKey: 'passId',
        as: 'members',
        onDelete: 'CASCADE',
      });
    }
  }

  EventIndividualPass.init(
    {
      id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
      bookingId: {
        type: DataTypes.INTEGER,
        allowNull: false,
        references: { model: 'EventPassBookings', key: 'id' },
      },
      eventPassId: {
        type: DataTypes.INTEGER,
        allowNull: false,
        references: { model: 'EventPasses', key: 'id' },
      },
      slotId: {
        type: DataTypes.INTEGER,
        allowNull: false,
        references: { model: 'EventPassSlots', key: 'id' },
      },
      holderName:  { type: DataTypes.STRING(255), allowNull: false },
      holderEmail: { type: DataTypes.STRING(255), allowNull: false },
      passCode:    { type: DataTypes.STRING(100), allowNull: false, unique: true },
      qrCode:      { type: DataTypes.STRING(600), allowNull: true },

      // How many persons this single pass covers (= numberOfPasses from booking)
      maxPersons: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 1 },

      // Running counters — incremented on each scan
      scannedInCount:  { type: DataTypes.INTEGER, allowNull: false, defaultValue: 0 },
      scannedOutCount: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 0 },

      // Convenience status — updated on every scan
      scanStatus: {
        type: DataTypes.ENUM('NotScanned', 'In', 'Out'),
        defaultValue: 'NotScanned',
        allowNull: false,
      },

      scannedInAt:  { type: DataTypes.DATE, allowNull: true },
      scannedOutAt: { type: DataTypes.DATE, allowNull: true },
      isValid:      { type: DataTypes.BOOLEAN, defaultValue: true, allowNull: false },
      createdAt:    { allowNull: false, type: DataTypes.DATE },
      updatedAt:    { allowNull: false, type: DataTypes.DATE },
    },
    {
      sequelize,
      modelName: 'EventIndividualPass',
      tableName: 'EventIndividualPasses',
    }
  );

  return EventIndividualPass;
};
