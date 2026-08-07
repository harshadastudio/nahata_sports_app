'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('Coupons', {
      id: {
        type: Sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true,
        allowNull: false,
      },
      code: {
        type: Sequelize.STRING,
        unique: true,
        allowNull: false,
      },
      discountType: {
        type: Sequelize.ENUM('Percentage', 'Flat'),
        defaultValue: 'Percentage',
        allowNull: false,
      },
      discountValue: {
        type: Sequelize.DECIMAL(10, 2),
        allowNull: false,
      },
      validUntil: {
        type: Sequelize.DATE,
        allowNull: false,
      },
      usageLimit: {
        type: Sequelize.INTEGER,
        defaultValue: 100,
        allowNull: false,
      },
      usedCount: {
        type: Sequelize.INTEGER,
        defaultValue: 0,
        allowNull: false,
      },
      status: {
        type: Sequelize.ENUM('Active', 'Expired'),
        defaultValue: 'Active',
        allowNull: false,
      },
      createdAt: {
        allowNull: false,
        type: Sequelize.DATE,
      },
      updatedAt: {
        allowNull: false,
        type: Sequelize.DATE,
      },
    });

    // Add indexes for better query performance
    await queryInterface.addIndex('Coupons', ['code'], { unique: true });
    await queryInterface.addIndex('Coupons', ['status']);
    await queryInterface.addIndex('Coupons', ['validUntil']);
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.dropTable('Coupons');
  }
};
