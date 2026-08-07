'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    // Check if the Coupons table exists before attempting to modify it
    const tables = await queryInterface.showAllTables();
    if (!tables.includes('Coupons')) {
      console.log('⏭️  Skipped: Coupons table does not exist');
      return;
    }

    const tableDescription = await queryInterface.describeTable('Coupons');

    const removeIfExists = async (columnName) => {
      if (tableDescription[columnName]) {
        await queryInterface.removeColumn('Coupons', columnName);
        console.log(`✅ Removed column: ${columnName}`);
      } else {
        console.log(`⏭️  Skipped (already removed): ${columnName}`);
      }
    };

    await removeIfExists('minPurchase');
    await removeIfExists('maxDiscount');
    await removeIfExists('validFrom');
    await removeIfExists('applicableSports');
  },

  async down(queryInterface, Sequelize) {
    const tables = await queryInterface.showAllTables();
    if (!tables.includes('Coupons')) return;

    const tableDescription = await queryInterface.describeTable('Coupons');

    const addIfMissing = async (columnName, definition) => {
      if (!tableDescription[columnName]) {
        await queryInterface.addColumn('Coupons', columnName, definition);
      }
    };

    await addIfMissing('minPurchase', { type: Sequelize.DECIMAL(10, 2), defaultValue: 0 });
    await addIfMissing('maxDiscount', { type: Sequelize.DECIMAL(10, 2) });
    await addIfMissing('validFrom',   { type: Sequelize.DATE, allowNull: true });
    await addIfMissing('applicableSports', { type: Sequelize.TEXT });
  },
};
