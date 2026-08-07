'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    try {
      const tableDescription = await queryInterface.describeTable('Blogs');
      if (!tableDescription.featuredImage) {
        await queryInterface.addColumn('Blogs', 'featuredImage', {
          type: Sequelize.STRING,
          allowNull: true,
        });
        console.log('✅ Added featuredImage column to Blogs table');
      } else {
        console.log('⚠️  featuredImage column already exists in Blogs table');
      }
    } catch (error) {
      console.log('⚠️  Migration error:', error.message);
    }
  },

  async down(queryInterface, Sequelize) {
    try {
      const tableDescription = await queryInterface.describeTable('Blogs');
      
      if (tableDescription.featuredImage) {
        await queryInterface.removeColumn('Blogs', 'featuredImage');
      }
    } catch (error) {
      console.log('⚠️  Rollback error:', error.message);
    }
  }
};
