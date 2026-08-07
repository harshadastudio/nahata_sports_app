'use strict';

/**
 * Answers to the event's admin-defined custom fields, captured ONCE PER BOOKING
 * (not per pass).
 *
 * Stored as a self-contained snapshot — [{ key, label, value }] — so the admin
 * panel can render a past booking correctly even after the event's field
 * definitions are edited, renamed, or removed.
 *
 * @type {import('sequelize-cli').Migration}
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    const tables = await queryInterface.showAllTables();
    if (!tables.includes('EventPassBookings')) return;

    const cols = await queryInterface.describeTable('EventPassBookings');
    if (cols.customFieldValues) {
      console.log('ℹ️  EventPassBookings.customFieldValues already exists — skipped');
      return;
    }

    await queryInterface.addColumn('EventPassBookings', 'customFieldValues', {
      type: Sequelize.JSONB,
      allowNull: false,
      defaultValue: [],
    });
    console.log('✅ Added customFieldValues to EventPassBookings');
  },

  async down(queryInterface) {
    const tables = await queryInterface.showAllTables();
    if (!tables.includes('EventPassBookings')) return;

    const cols = await queryInterface.describeTable('EventPassBookings');
    if (cols.customFieldValues) {
      await queryInterface.removeColumn('EventPassBookings', 'customFieldValues');
    }
  },
};
