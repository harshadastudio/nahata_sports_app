'use strict';

/**
 * Adds Bookings.customerName — a per-booking display name.
 *
 * Partner bookings (Huddle, KheloMore) all arrive under one shared account, so
 * several bookings share the same Users.name. Editing that account name would
 * rename every one of them at once; this column lets staff name each booking
 * individually.
 *
 * NULL means "use the linked account's name", so existing bookings are
 * unaffected. Additive and nullable — no table rewrite, no data touched.
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    const table = await queryInterface.describeTable('Bookings');
    if (!table.customerName) {
      await queryInterface.addColumn('Bookings', 'customerName', {
        type: Sequelize.STRING(120),
        allowNull: true,
        defaultValue: null,
        comment: 'Per-booking display name set by staff; falls back to the linked user name when null',
      });
    }
  },

  async down(queryInterface) {
    const table = await queryInterface.describeTable('Bookings');
    if (table.customerName) {
      await queryInterface.removeColumn('Bookings', 'customerName');
    }
  },
};
