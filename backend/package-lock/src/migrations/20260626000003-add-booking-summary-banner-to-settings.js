'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    try {
      const table = await queryInterface.describeTable('settings');
      if (!table.bookingSummaryBanner) {
        await queryInterface.addColumn('settings', 'bookingSummaryBanner', {
          type: Sequelize.STRING(500),
          allowNull: true,
          defaultValue: null,
        });
      } else {
        console.log('Column bookingSummaryBanner already exists in settings, skipping...');
      }
    } catch (error) {
      console.log('add-booking-summary-banner-to-settings skipped:', error.message);
    }
  },
  async down(queryInterface) {
    await queryInterface.removeColumn('settings', 'bookingSummaryBanner');
  },
};
