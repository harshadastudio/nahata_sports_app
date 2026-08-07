'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class Booking extends Model {
    static associate(models) {
      Booking.belongsTo(models.User, { foreignKey: 'userId', as: 'user' });
      Booking.belongsTo(models.Sport, { foreignKey: 'sportId', as: 'sport' });
      Booking.belongsTo(models.Court, { foreignKey: 'courtId', as: 'court' });
      Booking.hasMany(models.BookingMember, { foreignKey: 'bookingId', as: 'members', onDelete: 'CASCADE' });
    }
  }
  
  Booking.init({
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },
    userId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'Users',
        key: 'id',
      },
    },
    sportId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'Sports',
        key: 'id',
      },
    },
    courtId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'Courts',
        key: 'id',
      },
    },
    date: {
      type: DataTypes.DATEONLY,
      allowNull: false,
    },
    startTime: {
      type: DataTypes.TIME,
      allowNull: false,
    },
    endTime: {
      type: DataTypes.TIME,
      allowNull: false,
    },
    // VARCHAR, not ENUM: aggregator labels come from the partner registry
    // (config/partnerSources.js) so onboarding a platform needs no migration.
    bookingSource: {
      type: DataTypes.STRING(50),
      defaultValue: 'Direct',
    },
    paymentStatus: {
      type: DataTypes.ENUM('Pending', 'Paid', 'Failed', 'Refunded'),
      defaultValue: 'Pending',
    },
    bookingStatus: {
      type: DataTypes.ENUM('Confirmed', 'Cancelled', 'Completed', 'Pending'),
      defaultValue: 'Confirmed',
      allowNull: false,
    },
    totalAmount: {
      type: DataTypes.DECIMAL(10, 2),
      defaultValue: 0,
      allowNull: false,
    },
    couponCode: {
      type: DataTypes.STRING(50),
      allowNull: true,
    },
    discountAmount: {
      type: DataTypes.DECIMAL(10, 2),
      defaultValue: 0,
      allowNull: false,
    },
    originalAmount: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: true,
    },
    notes: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    // Per-booking display name. Partner bookings (Huddle, KheloMore) all come in
    // under one shared account, so staff need to name each booking separately
    // instead of renaming the shared account. NULL = use the linked user's name.
    customerName: {
      type: DataTypes.STRING(120),
      allowNull: true,
      defaultValue: null,
    },
    transactionId: {
      type: DataTypes.STRING,
    },
    // Razorpay order id created at /payments/create-order. Bound at /verify so a
    // payment cannot be replayed against a different booking. (Facility parity
    // with EventPassBooking.razorpayOrderId.)
    razorpayOrderId: {
      type: DataTypes.STRING(100),
      allowNull: true,
    },
    passCode: {
      type: DataTypes.STRING(50),
      allowNull: true,
      unique: true,
    },
    qrCode: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    maxPersons: {
      type: DataTypes.INTEGER,
      allowNull: true,
      defaultValue: null,
      comment: 'Max persons allowed on this booking pass (from court capacity)',
    },
    scannedInCount: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },
    scannedOutCount: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
    },
    scanStatus: {
      type: DataTypes.ENUM('NotScanned', 'In', 'Out'),
      allowNull: false,
      defaultValue: 'NotScanned',
    },
    scannedInAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    scannedOutAt: {
      type: DataTypes.DATE,
      allowNull: true,
    },
    holdExpiresAt: {
      type: DataTypes.DATE,
      allowNull: true,
      defaultValue: null,
      comment: 'Pending public bookings: slot-hold expiry. NULL once Confirmed/permanent.',
    },
    movedFromCourtId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      defaultValue: null,
      comment: 'Original court id before auto-consolidation reassignment',
    },
    moveReason: {
      type: DataTypes.STRING,
      allowNull: true,
      defaultValue: null,
    },
    movedAt: {
      type: DataTypes.DATE,
      allowNull: true,
      defaultValue: null,
    },
    // A slot block (maintenance, private event, aggregator hold) is stored as a
    // Booking so it occupies the interval through the same conflict scan and
    // availability queries as a real reservation. isBlocked keeps it out of the
    // bookings list/stats; blockedBy is what the Blocked Slots screen badges.
    isBlocked: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
      comment: 'True = a slot block, not a customer booking',
    },
    blockedBy: {
      type: DataTypes.STRING(50),
      allowNull: true,
      defaultValue: null,
      comment: "'Admin' or a partner label ('KheloMore', 'Huddle'); NULL for normal bookings",
    },
    isDeleted: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    },
    createdAt: {
      allowNull: false,
      type: DataTypes.DATE,
    },
    updatedAt: {
      allowNull: false,
      type: DataTypes.DATE,
    },
  }, {
    sequelize,
    modelName: 'Booking',
    tableName: 'Bookings',
  });
  
  return Booking;
};
