'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('Announcements', 'icon', {
      type: Sequelize.STRING(50),
      allowNull: true,
      defaultValue: 'Star',
    });
    await queryInterface.addColumn('Announcements', 'showOnFrontend', {
      type: Sequelize.BOOLEAN,
      allowNull: false,
      defaultValue: true,
    });
  },
  async down(queryInterface) {
    await queryInterface.removeColumn('Announcements', 'icon');
    await queryInterface.removeColumn('Announcements', 'showOnFrontend');
  },
};
