'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    // Add price field
    await queryInterface.addColumn('Coaches', 'price', {
      type: Sequelize.DECIMAL(10, 2),
      allowNull: true,
      defaultValue: 0,
      comment: 'Coach price/fee'
    });

    // Add availability field
    await queryInterface.addColumn('Coaches', 'availability', {
      type: Sequelize.STRING,
      allowNull: true,
      comment: 'Comma-separated days: Monday,Tuesday,Wednesday'
    });

    // Add certification field
    await queryInterface.addColumn('Coaches', 'certification', {
      type: Sequelize.TEXT,
      allowNull: true,
      comment: 'Coach certifications and qualifications'
    });
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.removeColumn('Coaches', 'price');
    await queryInterface.removeColumn('Coaches', 'availability');
    await queryInterface.removeColumn('Coaches', 'certification');
  }
};
