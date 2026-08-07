'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class BookingMember extends Model {
    static associate(models) {
      BookingMember.belongsTo(models.Booking, {
        foreignKey: 'bookingId',
        as: 'booking',
      });
    }
  }

  BookingMember.init(
    {
      id:        { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
      bookingId: {
        type: DataTypes.INTEGER,
        allowNull: false,
        references: { model: 'Bookings', key: 'id' },
      },
      name:  { type: DataTypes.STRING(255), allowNull: false },
      phone: {
        // WhatsApp number with country code, e.g. "919876543210"
        type: DataTypes.STRING(20),
        allowNull: false,
        validate: {
          is: {
            args: /^[0-9]{7,15}$/,
            msg: 'Phone number must be 7–15 digits (include country code)',
          },
        },
      },
      email: {
        type: DataTypes.STRING(255),
        allowNull: true,
        validate: { isEmail: { msg: 'Invalid email address' } },
      },
      // Each member is individually scannable
      passCode: { type: DataTypes.STRING(100), allowNull: false, unique: true },
      qrCode:   { type: DataTypes.STRING(600), allowNull: true },

      scanStatus: {
        type: DataTypes.ENUM('NotScanned', 'In', 'Out'),
        defaultValue: 'NotScanned',
        allowNull: false,
      },
      scannedInAt:  { type: DataTypes.DATE, allowNull: true },
      scannedOutAt: { type: DataTypes.DATE, allowNull: true },
      createdAt: { allowNull: false, type: DataTypes.DATE },
      updatedAt: { allowNull: false, type: DataTypes.DATE },
    },
    {
      sequelize,
      modelName: 'BookingMember',
      tableName: 'BookingMembers',
    }
  );

  return BookingMember;
};
