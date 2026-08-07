'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    // Change image column from STRING to TEXT to support base64 images
    await queryInterface.changeColumn('Coaches', 'image', {
      type: Sequelize.TEXT,
      allowNull: true,
      comment: 'Coach profile image (base64 or URL)',
    });
  },

  async down(queryInterface, Sequelize) {
    // Revert back to STRING
    await queryInterface.changeColumn('Coaches', 'image', {
      type: Sequelize.STRING,
      allowNull: true,
      comment: 'Coach profile image URL',
    });
  }
};
