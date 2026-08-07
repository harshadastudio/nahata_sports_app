'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class Coupon extends Model {
    static associate(models) {
      // A court coupon may be scoped to a single Sports Complex (null = all)
      // and, inside it, to a single Sport (null = every sport).
      Coupon.belongsTo(models.SportComplex, { foreignKey: 'sportComplexId' });
      Coupon.belongsTo(models.Sport, { foreignKey: 'sportId' });
      // An event coupon may be scoped to a single event (null = all events).
      Coupon.belongsTo(models.EventPass, { foreignKey: 'eventPassId', as: 'eventPass' });
    }
  }

  Coupon.init({
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },
    code: {
      type: DataTypes.STRING,
      unique: true,
      allowNull: false,
    },
    discountType: {
      type: DataTypes.ENUM('Percentage', 'Flat'),
      defaultValue: 'Percentage',
    },
    discountValue: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: false,
    },
    maxDiscount: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: true,
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: true,
    },
    validUntil: {
      type: DataTypes.DATE,
      allowNull: false,
    },
    usageLimit: {
      type: DataTypes.INTEGER,
      defaultValue: 100,
    },
    usedCount: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    status: {
      type: DataTypes.ENUM('Active', 'Expired'),
      defaultValue: 'Active',
    },
    // Which booking flow this coupon is valid for.
    appliesTo: {
      type: DataTypes.ENUM('Court', 'Event'),
      allowNull: false,
      defaultValue: 'Court',
    },
    // For court coupons: restrict to a single Sports Complex. NULL = all complexes.
    // Always NULL for event coupons.
    sportComplexId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: { model: 'SportComplexes', key: 'id' },
    },
    // For court coupons: restrict to one sport of that complex. NULL = all sports.
    // Always NULL for event coupons.
    sportId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: { model: 'Sports', key: 'id' },
    },
    // For event coupons: restrict to a single event. NULL = all events.
    // Always NULL for court coupons.
    eventPassId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: { model: 'EventPasses', key: 'id' },
    },
    // Which client may redeem this coupon: the website, the mobile apps, or both.
    platform: {
      type: DataTypes.ENUM('All', 'Web', 'App'),
      allowNull: false,
      defaultValue: 'All',
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
    modelName: 'Coupon',
    tableName: 'Coupons',
  });
  
  return Coupon;
};
