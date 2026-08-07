'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    try {
      const table = await queryInterface.describeTable('HeroSlides');
      if (!table.titleHighlight) {
        await queryInterface.addColumn('HeroSlides', 'titleHighlight', {
          type: Sequelize.STRING(500),
          allowNull: true,
          comment: 'Headline line 2, shown in gradient/highlight color',
        });
      } else {
        console.log('Column titleHighlight already exists in HeroSlides, skipping...');
      }
    } catch (error) {
      console.log('add-title-highlight-to-hero-slides skipped:', error.message);
    }
  },
  async down(queryInterface) {
    await queryInterface.removeColumn('HeroSlides', 'titleHighlight');
  },
};
