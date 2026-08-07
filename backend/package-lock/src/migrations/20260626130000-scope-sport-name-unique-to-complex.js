'use strict';

/**
 * Sport names used to be globally unique (Sports_name_key on `name`).
 * Now a sport name only has to be unique *within a sports complex*, so the
 * same name can be reused across different complexes.
 *
 * - Drop the global unique constraint on `name`.
 * - Add a composite unique index on (name, sportComplexId).
 * - Add a partial unique index on (name) for sports with no complex assigned,
 *   so unassigned sports still can't share a name (Postgres treats NULLs as
 *   distinct in composite indexes).
 */
module.exports = {
  async up(queryInterface) {
    // Drop the old global unique constraint on name
    try {
      await queryInterface.removeConstraint('Sports', 'Sports_name_key');
    } catch (error) {
      console.log('Constraint Sports_name_key not found, skipping...');
    }

    // Unique per complex
    try {
      await queryInterface.addIndex('Sports', ['name', 'sportComplexId'], {
        unique: true,
        name: 'sports_name_complex_unique',
      });
    } catch (error) {
      console.log('Index sports_name_complex_unique already exists, skipping...');
    }

    // Unique among unassigned (sportComplexId IS NULL) sports
    try {
      await queryInterface.addIndex('Sports', ['name'], {
        unique: true,
        name: 'sports_name_unassigned_unique',
        where: { sportComplexId: null },
      });
    } catch (error) {
      console.log('Index sports_name_unassigned_unique already exists, skipping...');
    }
  },

  async down(queryInterface, Sequelize) {
    try {
      await queryInterface.removeIndex('Sports', 'sports_name_unassigned_unique');
    } catch (error) {
      console.log('Index sports_name_unassigned_unique not found, skipping...');
    }
    try {
      await queryInterface.removeIndex('Sports', 'sports_name_complex_unique');
    } catch (error) {
      console.log('Index sports_name_complex_unique not found, skipping...');
    }
    // Restore the global unique constraint (best effort)
    try {
      await queryInterface.addConstraint('Sports', {
        fields: ['name'],
        type: 'unique',
        name: 'Sports_name_key',
      });
    } catch (error) {
      console.log('Could not restore Sports_name_key constraint:', error.message);
    }
  },
};
