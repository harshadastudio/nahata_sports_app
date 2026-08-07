'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    // Check if the Coupons table exists
    const tables = await queryInterface.showAllTables();
    if (!tables.includes('Coupons')) {
      console.log('⏭️  Skipped: Coupons table does not exist');
      return;
    }

    const tableDescription = await queryInterface.describeTable('Coupons');

    // Add maxDiscount field if it doesn't exist
    if (!tableDescription.maxDiscount) {
      await queryInterface.addColumn('Coupons', 'maxDiscount', {
        type: Sequelize.DECIMAL(10, 2),
        allowNull: true,
        after: 'discountValue'
      });
      console.log('✅ Added maxDiscount column to Coupons table');
    } else {
      console.log('⏭️  Skipped: maxDiscount column already exists');
    }

    // Add description field if it doesn't exist
    if (!tableDescription.description) {
      await queryInterface.addColumn('Coupons', 'description', {
        type: Sequelize.TEXT,
        allowNull: true,
        after: 'maxDiscount'
      });
      console.log('✅ Added description column to Coupons table');
    } else {
      console.log('⏭️  Skipped: description column already exists');
    }
  },

  async down(queryInterface, Sequelize) {
    const tables = await queryInterface.showAllTables();
    if (!tables.includes('Coupons')) return;

    const tableDescription = await queryInterface.describeTable('Coupons');

    // Remove maxDiscount field if it exists
    if (tableDescription.maxDiscount) {
      await queryInterface.removeColumn('Coupons', 'maxDiscount');
      console.log('✅ Removed maxDiscount column from Coupons table');
    }

    // Remove description field if it exists
    if (tableDescription.description) {
      await queryInterface.removeColumn('Coupons', 'description');
      console.log('✅ Removed description column from Coupons table');
    }
  }
};
