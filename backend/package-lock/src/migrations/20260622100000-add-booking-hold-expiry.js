'use strict';

/**
 * Add holdExpiresAt to Bookings.
 *
 * Public (website) bookings are now created as bookingStatus='Pending' and hold
 * their slot until holdExpiresAt. The slot is treated as free again once the
 * hold expires (availability/conflict queries ignore expired holds). On payment
 * verification the booking flips to Confirmed and holdExpiresAt is cleared.
 * Admin/staff bookings keep holdExpiresAt = NULL (permanent).
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    const t = await queryInterface.describeTable('Bookings');
    if (!t.holdExpiresAt) {
      await queryInterface.addColumn('Bookings', 'holdExpiresAt', {
        type: Sequelize.DATE,
        allowNull: true,
        defaultValue: null,
        comment: 'Pending public bookings: slot-hold expiry timestamp. NULL once Confirmed/permanent.',
      });
    }
  },

  async down(queryInterface) {
    const t = await queryInterface.describeTable('Bookings');
    if (t.holdExpiresAt) await queryInterface.removeColumn('Bookings', 'holdExpiresAt');
  },
};
