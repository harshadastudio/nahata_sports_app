'use strict';

/**
 * Alter EventIndividualPasses to support group/multi-person passes.
 * One pass = one QR code, but valid for up to `maxPersons` people.
 * Tracks scannedInCount / scannedOutCount instead of a single scanStatus.
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    // Add maxPersons — how many people this single pass covers
    await queryInterface.addColumn('EventIndividualPasses', 'maxPersons', {
      type: Sequelize.INTEGER,
      allowNull: false,
      defaultValue: 1,
    });

    // Add running counters
    await queryInterface.addColumn('EventIndividualPasses', 'scannedInCount', {
      type: Sequelize.INTEGER,
      allowNull: false,
      defaultValue: 0,
    });

    await queryInterface.addColumn('EventIndividualPasses', 'scannedOutCount', {
      type: Sequelize.INTEGER,
      allowNull: false,
      defaultValue: 0,
    });

    // Remove passNumber — no longer needed (always 1 pass per booking)
    await queryInterface.removeColumn('EventIndividualPasses', 'passNumber');

    // scanStatus is now derived (NotScanned / PartialIn / FullIn / PartialOut / FullOut)
    // but we keep the column for backward compat — just change the ENUM
    // Drop old ENUM column and re-add with new values
    await queryInterface.removeColumn('EventIndividualPasses', 'scanStatus');
    await queryInterface.addColumn('EventIndividualPasses', 'scanStatus', {
      type: Sequelize.ENUM('NotScanned', 'In', 'Out'),
      defaultValue: 'NotScanned',
      allowNull: false,
    });
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.removeColumn('EventIndividualPasses', 'maxPersons');
    await queryInterface.removeColumn('EventIndividualPasses', 'scannedInCount');
    await queryInterface.removeColumn('EventIndividualPasses', 'scannedOutCount');
    await queryInterface.addColumn('EventIndividualPasses', 'passNumber', {
      type: Sequelize.INTEGER,
      allowNull: false,
      defaultValue: 1,
    });
  },
};
