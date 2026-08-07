'use strict';

/**
 * Add court-reassignment audit fields to Bookings.
 *
 * When the auto-consolidation engine moves an existing booking to an equivalent
 * court to free a continuous block for a new customer, we record where it came
 * from, why, and when — so staff/admin can see the silent move and support can
 * trace it.
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    const t = await queryInterface.describeTable('Bookings');
    if (!t.movedFromCourtId) {
      await queryInterface.addColumn('Bookings', 'movedFromCourtId', {
        type: Sequelize.INTEGER,
        allowNull: true,
        defaultValue: null,
        comment: 'Original court id before auto-consolidation reassignment',
      });
    }
    if (!t.moveReason) {
      await queryInterface.addColumn('Bookings', 'moveReason', {
        type: Sequelize.STRING,
        allowNull: true,
        defaultValue: null,
      });
    }
    if (!t.movedAt) {
      await queryInterface.addColumn('Bookings', 'movedAt', {
        type: Sequelize.DATE,
        allowNull: true,
        defaultValue: null,
      });
    }
  },

  async down(queryInterface) {
    const t = await queryInterface.describeTable('Bookings');
    if (t.movedAt) await queryInterface.removeColumn('Bookings', 'movedAt');
    if (t.moveReason) await queryInterface.removeColumn('Bookings', 'moveReason');
    if (t.movedFromCourtId) await queryInterface.removeColumn('Bookings', 'movedFromCourtId');
  },
};
