'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    // Update all records with NULL approvalStatus to 'Pending'
    await queryInterface.sequelize.query(`
      UPDATE "StudentPrograms" 
      SET "approvalStatus" = 'Pending' 
      WHERE "approvalStatus" IS NULL;
    `);

    console.log('✅ Updated NULL approvalStatus records to Pending');

    // Count the records
    const [results] = await queryInterface.sequelize.query(`
      SELECT 
        "approvalStatus", 
        COUNT(*) as count 
      FROM "StudentPrograms" 
      GROUP BY "approvalStatus";
    `);

    console.log('📊 Approval Status Distribution:');
    results.forEach(row => {
      console.log(`   ${row.approvalStatus}: ${row.count}`);
    });
  },

  async down(queryInterface, Sequelize) {
    // No rollback needed - we're just fixing data
    console.log('No rollback needed for data fix');
  },
};
