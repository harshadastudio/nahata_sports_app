'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('settings', {
      id: {
        type: Sequelize.INTEGER,
        primaryKey: true,
        autoIncrement: true,
        allowNull: false
      },
      // General Settings
      businessName: {
        type: Sequelize.STRING,
        allowNull: false,
        defaultValue: 'Nahata Sports Complex'
      },
      location: {
        type: Sequelize.STRING,
        allowNull: true
      },
      contactPhone: {
        type: Sequelize.STRING(10),
        allowNull: true
      },
      contactEmail: {
        type: Sequelize.STRING,
        allowNull: true
      },
      website: {
        type: Sequelize.STRING,
        allowNull: true
      },
      address: {
        type: Sequelize.TEXT,
        allowNull: true
      },
      
      // Pricing Settings
      defaultPrice: {
        type: Sequelize.DECIMAL(10, 2),
        allowNull: false,
        defaultValue: 1200.00
      },
      peakHourStart: {
        type: Sequelize.TIME,
        allowNull: true,
        defaultValue: '17:00:00'
      },
      peakHourEnd: {
        type: Sequelize.TIME,
        allowNull: true,
        defaultValue: '22:00:00'
      },
      peakHourMultiplier: {
        type: Sequelize.DECIMAL(3, 2),
        allowNull: false,
        defaultValue: 1.50
      },
      weekendMultiplier: {
        type: Sequelize.DECIMAL(3, 2),
        allowNull: false,
        defaultValue: 1.30
      },
      
      // Integration Settings
      paymentGateway: {
        type: Sequelize.ENUM('stripe', 'razorpay', 'paypal', 'paytm'),
        allowNull: false,
        defaultValue: 'stripe'
      },
      whatsappApiKey: {
        type: Sequelize.STRING,
        allowNull: true
      },
      emailServiceProvider: {
        type: Sequelize.ENUM('sendgrid', 'mailgun', 'ses', 'smtp'),
        allowNull: false,
        defaultValue: 'sendgrid'
      },
      emailApiKey: {
        type: Sequelize.STRING,
        allowNull: true
      },
      googleAnalyticsId: {
        type: Sequelize.STRING,
        allowNull: true
      },
      
      createdAt: {
        type: Sequelize.DATE,
        allowNull: false,
        defaultValue: Sequelize.literal('CURRENT_TIMESTAMP')
      },
      updatedAt: {
        type: Sequelize.DATE,
        allowNull: false,
        defaultValue: Sequelize.literal('CURRENT_TIMESTAMP')
      }
    });

    // Insert default settings
    await queryInterface.bulkInsert('settings', [{
      businessName: 'Nahata Sports Complex',
      location: 'Pune, Maharashtra',
      contactPhone: '9876543210',
      contactEmail: 'info@nahatasports.com',
      website: 'www.nahatasports.com',
      address: '123 Sports Complex Road, Pune - 411001, Maharashtra, India',
      defaultPrice: 1200.00,
      peakHourStart: '17:00:00',
      peakHourEnd: '22:00:00',
      peakHourMultiplier: 1.50,
      weekendMultiplier: 1.30,
      paymentGateway: 'stripe',
      whatsappApiKey: '',
      emailServiceProvider: 'sendgrid',
      emailApiKey: '',
      googleAnalyticsId: '',
      createdAt: new Date(),
      updatedAt: new Date()
    }]);
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.dropTable('settings');
  }
};
