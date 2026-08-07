'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    // Update coaches with "sinhgad" to "Sinhagad Road Complex"
    await queryInterface.sequelize.query(`
      UPDATE "Coaches" 
      SET ground = 'Sinhagad Road Complex' 
      WHERE ground ILIKE '%sinhgad%' OR ground ILIKE '%sinhagad road%';
    `);

    // Update coaches with "Gangadham" to "Gangadham Chowk Complex"
    await queryInterface.sequelize.query(`
      UPDATE "Coaches" 
      SET ground = 'Gangadham Chowk Complex' 
      WHERE ground ILIKE '%gangadham%';
    `);

    console.log('✅ Coach ground names updated successfully');
  },

  down: async (queryInterface, Sequelize) => {
    // Revert changes if needed
    await queryInterface.sequelize.query(`
      UPDATE "Coaches" 
      SET ground = 'sinhgad' 
      WHERE ground = 'Sinhagad Road Complex';
    `);

    await queryInterface.sequelize.query(`
      UPDATE "Coaches" 
      SET ground = 'Gangadham' 
      WHERE ground = 'Gangadham Chowk Complex';
    `);

    console.log('✅ Coach ground names reverted');
  }
};
