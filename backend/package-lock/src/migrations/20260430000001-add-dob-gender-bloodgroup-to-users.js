'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.addColumn('Users', 'dob', {
      type: Sequelize.DATEONLY,
      allowNull: true,
      defaultValue: null,
    });
    await queryInterface.addColumn('Users', 'gender', {
      type: Sequelize.ENUM('Male', 'Female', 'Other'),
      allowNull: true,
      defaultValue: null,
    });
    await queryInterface.addColumn('Users', 'blood_group', {
      type: Sequelize.STRING(5),
      allowNull: true,
      defaultValue: null,
    });
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.removeColumn('Users', 'dob');
    await queryInterface.removeColumn('Users', 'gender');
    await queryInterface.removeColumn('Users', 'blood_group');
  },
};
