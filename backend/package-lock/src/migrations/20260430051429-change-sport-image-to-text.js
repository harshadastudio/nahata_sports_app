'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    // Change image column from STRING to TEXT to support base64 images
    await queryInterface.changeColumn('Sports', 'image', {
      type: Sequelize.TEXT,
      allowNull: true,
      comment: 'Sport image (base64 or URL)',
    });
  },

  async down(queryInterface, Sequelize) {
    // Revert back to STRING
    await queryInterface.changeColumn('Sports', 'image', {
      type: Sequelize.STRING,
      allowNull: true,
    });
  }
};
