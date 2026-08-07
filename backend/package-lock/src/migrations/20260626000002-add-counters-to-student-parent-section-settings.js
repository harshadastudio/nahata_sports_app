'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    try {
      const table = await queryInterface.describeTable('StudentParentSectionSettings');
      if (!table.counters) {
        await queryInterface.addColumn('StudentParentSectionSettings', 'counters', {
          type: Sequelize.JSON,
          allowNull: true,
          defaultValue: null,
        });
      } else {
        console.log('Column counters already exists in StudentParentSectionSettings, skipping...');
      }
    } catch (error) {
      console.log('add-counters-to-student-parent-section-settings skipped:', error.message);
    }
  },
  async down(queryInterface) {
    await queryInterface.removeColumn('StudentParentSectionSettings', 'counters');
  },
};
