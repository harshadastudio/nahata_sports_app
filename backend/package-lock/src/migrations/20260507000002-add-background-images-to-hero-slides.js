'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.addColumn('HeroSlides', 'backgroundImages', {
      type: Sequelize.JSON,
      allowNull: true,
      defaultValue: [],
      comment: 'Array of additional background image URLs for carousel/slideshow'
    });
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.removeColumn('HeroSlides', 'backgroundImages');
  }
};
