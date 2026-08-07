'use strict';

/**
 * Event-pass scan attribution.
 *
 * Each row records ONE event-pass scan action (IN or OUT) performed at the gate,
 * tagged with the security guard (User) who did it and the complex it belongs to.
 * This lets the Security Dashboard show "how many event passes this guard scanned"
 * (total + today), and keeps a per-complex audit trail.
 *
 * @type {import('sequelize-cli').Migration}
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    const tables = await queryInterface.showAllTables();
    if (tables.includes('EventPassScanLogs')) {
      console.log('⏭️  Skipped: EventPassScanLogs already exists');
      return;
    }
    await queryInterface.createTable('EventPassScanLogs', {
      id: { type: Sequelize.INTEGER, autoIncrement: true, primaryKey: true },
      individualPassId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: { model: 'EventIndividualPasses', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      eventPassId: {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: { model: 'EventPasses', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
      },
      scannedBy: {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: { model: 'Users', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
        comment: 'User (security guard) who performed the scan; NULL if scanned by an unauthenticated device.',
      },
      scanType: {
        type: Sequelize.ENUM('In', 'Out'),
        allowNull: false,
      },
      sportComplexId: {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: { model: 'SportComplexes', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
      },
      createdAt: { type: Sequelize.DATE, allowNull: false },
      updatedAt: { type: Sequelize.DATE, allowNull: false },
    });
    await queryInterface.addIndex('EventPassScanLogs', ['scannedBy']);
    await queryInterface.addIndex('EventPassScanLogs', ['eventPassId']);
    console.log('✅ Created EventPassScanLogs');
  },

  async down(queryInterface, Sequelize) {
    const tables = await queryInterface.showAllTables();
    if (!tables.includes('EventPassScanLogs')) return;
    await queryInterface.dropTable('EventPassScanLogs');
    // Drop the ENUM type left behind on Postgres.
    if (queryInterface.sequelize.getDialect() === 'postgres') {
      await queryInterface.sequelize.query('DROP TYPE IF EXISTS "enum_EventPassScanLogs_scanType";');
    }
    console.log('✅ Dropped EventPassScanLogs');
  },
};
