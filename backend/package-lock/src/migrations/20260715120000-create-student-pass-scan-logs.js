'use strict';

/**
 * Student gate-pass scan attribution.
 *
 * Each row records ONE student gate-pass scan at the gate, tagged with who
 * scanned it (Security / Coach / Employee / Admin / Complex Admin), whether
 * that scan marked attendance (only Coach scans do), and the complex it
 * belongs to. Lets the Security Dashboard and Admin Panel show a date-wise
 * scan log, mirroring the EventPassScanLogs pattern.
 *
 * @type {import('sequelize-cli').Migration}
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    const tables = await queryInterface.showAllTables();
    if (tables.includes('StudentPassScanLogs')) {
      console.log('⏭️  Skipped: StudentPassScanLogs already exists');
      return;
    }
    await queryInterface.createTable('StudentPassScanLogs', {
      id: { type: Sequelize.INTEGER, autoIncrement: true, primaryKey: true },
      studentBatchId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: { model: 'StudentBatches', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      scannedBy: {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: { model: 'Users', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
        comment: 'User who performed the scan; NULL if scanned by an unauthenticated device.',
      },
      scannerRole: {
        type: Sequelize.STRING,
        allowNull: true,
        comment: 'Role of the scanner at scan time (COACH, SECURITY, EMPLOYEE, ADMIN, COMPLEX_ADMIN).',
      },
      attendanceMarked: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: false,
        comment: 'True only when this scan also marked the student Present (Coach scans).',
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
    await queryInterface.addIndex('StudentPassScanLogs', ['studentBatchId']);
    await queryInterface.addIndex('StudentPassScanLogs', ['scannedBy']);
    await queryInterface.addIndex('StudentPassScanLogs', ['createdAt']);
    console.log('✅ Created StudentPassScanLogs');
  },

  async down(queryInterface) {
    const tables = await queryInterface.showAllTables();
    if (!tables.includes('StudentPassScanLogs')) return;
    await queryInterface.dropTable('StudentPassScanLogs');
    console.log('✅ Dropped StudentPassScanLogs');
  },
};
