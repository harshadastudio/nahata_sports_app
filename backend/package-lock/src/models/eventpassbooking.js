'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class EventPassBooking extends Model {
    static associate(models) {
      EventPassBooking.belongsTo(models.EventPass, {
        foreignKey: 'eventPassId',
        as: 'event',
      });
      EventPassBooking.belongsTo(models.EventPassSlot, {
        foreignKey: 'slotId',
        as: 'slot',
      });
      EventPassBooking.belongsTo(models.User, {
        foreignKey: 'userId',
        as: 'user',
      });
      EventPassBooking.hasMany(models.EventIndividualPass, {
        foreignKey: 'bookingId',
        as: 'individualPasses',
      });
    }
  }

  EventPassBooking.init(
    {
      id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
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
      userId: {
        type: DataTypes.INTEGER,
        allowNull: true,
        references: { model: 'Users', key: 'id' },
      },
      name: { type: DataTypes.STRING(255), allowNull: false },
      email: { type: DataTypes.STRING(255), allowNull: false },
      numberOfPasses: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 1 },
      // Answers to the event's custom fields — one set per booking.
      // Snapshot of [{ key, label, value }] so it survives later edits to the
      // event's field definitions.
      customFieldValues: { type: DataTypes.JSONB, allowNull: false, defaultValue: [] },
      totalAmount: { type: DataTypes.DECIMAL(10, 2), allowNull: false, defaultValue: 0 },
      couponCode: { type: DataTypes.STRING(50), allowNull: true },
      discountAmount: { type: DataTypes.DECIMAL(10, 2), allowNull: false, defaultValue: 0 },
      originalAmount: { type: DataTypes.DECIMAL(10, 2), allowNull: true },
      status: {
        type: DataTypes.ENUM('Pending', 'Confirmed', 'Cancelled'),
        defaultValue: 'Pending',
        allowNull: false,
      },
      qrCode: { type: DataTypes.STRING(500), allowNull: true },
      razorpayOrderId: { type: DataTypes.STRING(100), allowNull: true },
      razorpayPaymentId: { type: DataTypes.STRING(100), allowNull: true },
      createdAt: { allowNull: false, type: DataTypes.DATE },
      updatedAt: { allowNull: false, type: DataTypes.DATE },
    },
    { sequelize, modelName: 'EventPassBooking', tableName: 'EventPassBookings' }
  );

  return EventPassBooking;
};
