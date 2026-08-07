'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    // Migrate existing coach-sport relationships to the junction table
    // Get all coaches with sportId
    const coaches = await queryInterface.sequelize.query(
      'SELECT id, "sportId" FROM "Coaches" WHERE "sportId" IS NOT NULL',
      { type: queryInterface.sequelize.QueryTypes.SELECT }
    );

    // Insert into CoachSports junction table
    if (coaches.length > 0) {
      const coachSportsData = coaches.map(coach => ({
        coachId: coach.id,
        sportId: coach.sportId,
        isPrimary: true, // Mark existing relationships as primary
        createdAt: new Date(),
        updatedAt: new Date(),
      }));

      await queryInterface.bulkInsert('CoachSports', coachSportsData);
    }

    // Note: We keep the sportId column in Coaches table for backward compatibility
    // It can be removed in a future migration if needed
  },

  async down(queryInterface, Sequelize) {
    // Remove all records from CoachSports
    await queryInterface.bulkDelete('CoachSports', null, {});
  }
};
