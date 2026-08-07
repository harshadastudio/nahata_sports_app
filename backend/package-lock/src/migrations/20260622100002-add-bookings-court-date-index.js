'use strict';

/**
 * Composite index on Bookings(courtId, date).
 *
 * The availability engine and the atomic rearrange-and-book path scan every
 * equivalent court's bookings for a single date under a row lock. This index
 * keeps those scans fast.
 */
module.exports = {
  async up(queryInterface) {
    try {
      await queryInterface.addIndex('Bookings', ['courtId', 'date'], {
        name: 'bookings_court_id_date_idx',
      });
    } catch (err) {
      if (!/already exists/i.test(err.message)) throw err;
    }
  },

  async down(queryInterface) {
    try {
      await queryInterface.removeIndex('Bookings', 'bookings_court_id_date_idx');
    } catch (err) {
      if (!/does not exist/i.test(err.message)) throw err;
    }
  },
};
