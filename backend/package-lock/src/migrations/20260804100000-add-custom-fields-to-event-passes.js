'use strict';

/**
 * Admin-defined extra inputs for an event's public booking form.
 *
 * Shape: [{ key, label, type, required, placeholder, options }]
 *   key         stable slug derived from the label — links a definition to a
 *               submitted value, so renaming the label never orphans answers
 *   type        text | textarea | number | email | phone | date | select
 *   options     only for type 'select'
 *
 * The submitted answers live on EventPassBookings.customFieldValues.
 *
 * @type {import('sequelize-cli').Migration}
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    const tables = await queryInterface.showAllTables();
    if (!tables.includes('EventPasses')) return;

    const cols = await queryInterface.describeTable('EventPasses');
    if (cols.customFields) {
      console.log('ℹ️  EventPasses.customFields already exists — skipped');
      return;
    }

    await queryInterface.addColumn('EventPasses', 'customFields', {
      type: Sequelize.JSONB,
      allowNull: false,
      defaultValue: [],
    });
    console.log('✅ Added customFields to EventPasses');
  },

  async down(queryInterface) {
    const tables = await queryInterface.showAllTables();
    if (!tables.includes('EventPasses')) return;

    const cols = await queryInterface.describeTable('EventPasses');
    if (cols.customFields) await queryInterface.removeColumn('EventPasses', 'customFields');
  },
};
