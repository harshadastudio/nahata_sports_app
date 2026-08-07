'use strict';
const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class Settings extends Model {
    static associate(models) {
      // No associations for Settings model
    }
  }
  
  Settings.init({
    id: {
      type: DataTypes.INTEGER,
      primaryKey: true,
      autoIncrement: true
    },
    // General Settings
    businessName: {
      type: DataTypes.STRING,
      allowNull: false,
      defaultValue: 'Nahata Sports Complex'
    },
    location: {
      type: DataTypes.STRING,
      allowNull: true
    },
    contactPhone: {
      type: DataTypes.STRING(10),
      allowNull: true,
      validate: {
        is: /^[0-9]{10}$/,
        len: [10, 10]
      }
    },
    contactEmail: {
      type: DataTypes.STRING,
      allowNull: true,
      validate: {
        isEmail: true
      }
    },
    website: {
      type: DataTypes.STRING,
      allowNull: true
    },
    address: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    
    // Pricing Settings
    defaultPrice: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: false,
      defaultValue: 1200.00
    },
    peakHourStart: {
      type: DataTypes.TIME,
      allowNull: true,
      defaultValue: '17:00:00'
    },
    peakHourEnd: {
      type: DataTypes.TIME,
      allowNull: true,
      defaultValue: '22:00:00'
    },
    peakHourMultiplier: {
      type: DataTypes.DECIMAL(3, 2),
      allowNull: false,
      defaultValue: 1.50
    },
    weekendMultiplier: {
      type: DataTypes.DECIMAL(3, 2),
      allowNull: false,
      defaultValue: 1.30
    },
    
    // Integration Settings
    paymentGateway: {
      type: DataTypes.ENUM('stripe', 'razorpay', 'paypal', 'paytm'),
      allowNull: false,
      defaultValue: 'stripe'
    },
    whatsappApiKey: {
      type: DataTypes.STRING,
      allowNull: true
    },
    emailServiceProvider: {
      type: DataTypes.ENUM('sendgrid', 'mailgun', 'ses', 'smtp'),
      allowNull: false,
      defaultValue: 'sendgrid'
    },
    emailApiKey: {
      type: DataTypes.STRING,
      allowNull: true
    },
    googleAnalyticsId: {
      type: DataTypes.STRING,
      allowNull: true
    },

    // Storefront / CMS
    bookingSummaryBanner: {
      type: DataTypes.STRING(500),
      allowNull: true,
      defaultValue: null,
      comment: 'Fixed banner image shown behind the Booking Summary on the public Book-a-Court page'
    },

    // Social media links (shown in the public site footer)
    facebookUrl: {
      type: DataTypes.STRING(500),
      allowNull: true,
      defaultValue: null
    },
    instagramUrl: {
      type: DataTypes.STRING(500),
      allowNull: true,
      defaultValue: null
    },
    twitterUrl: {
      type: DataTypes.STRING(500),
      allowNull: true,
      defaultValue: null
    }
  }, {
    sequelize,
    modelName: 'Settings',
    tableName: 'settings',
    timestamps: true
  });
  
  return Settings;
};
