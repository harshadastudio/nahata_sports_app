'use strict';

/**
 * Adds Bookings.isBlocked + Bookings.blockedBy — date-specific slot blocks.
 *
 * A "block" (court unavailable for maintenance, a private event, or reserved by
 * an aggregator) is stored as an ordinary Booking row so it flows through the
 * SAME availability and double-booking machinery as a real reservation: the
 * conflict scan in createCourtBooking, getAvailableSlots, /fetchslots and the
 * auto-shift engine all already exclude occupied intervals, and a block is just
 * an occupied interval nobody paid for.
 *
 * isBlocked marks the row as "not a real booking" so it can be kept out of the
 * bookings list, stats and reports. blockedBy records WHO placed it
 * ('KheloMore', 'Huddle', 'Admin') — it is what the Blocked Slots screen badges.
 *
 * Revenue is unaffected without any report change: blocks are never marked Paid,
 * and every revenue query filters on paymentStatus = 'Paid'.
 *
 * Additive with a default — no table rewrite, existing rows read as isBlocked=false.
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    const table = await queryInterface.describeTable('Bookings');

    if (!table.isBlocked) {
      await queryInterface.addColumn('Bookings', 'isBlocked', {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: false,
        comment: 'True = a slot block (maintenance/partner hold), not a customer booking',
      });
    }

    if (!table.blockedBy) {
      await queryInterface.addColumn('Bookings', 'blockedBy', {
        type: Sequelize.STRING(50),
        allowNull: true,
        defaultValue: null,
        comment: "Who placed the block: 'Admin' or a partner label ('KheloMore', 'Huddle'). NULL for normal bookings",
      });
    }

    // The block lookups are all "what is blocked on this court for this date" —
    // the same shape getAvailableSlots already runs per screen load.
    await queryInterface.addIndex('Bookings', ['courtId', 'date', 'isBlocked'], {
      name: 'bookings_court_date_isblocked_idx',
    }).catch(() => { /* index already present */ });
  },

  async down(queryInterface) {
    await queryInterface.removeIndex('Bookings', 'bookings_court_date_isblocked_idx')
      .catch(() => { /* never created */ });

    const table = await queryInterface.describeTable('Bookings');
    if (table.blockedBy) await queryInterface.removeColumn('Bookings', 'blockedBy');
    if (table.isBlocked) await queryInterface.removeColumn('Bookings', 'isBlocked');
  },
};
