'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.addColumn('CoachingEnquiries', 'studentId', {
      type: Sequelize.INTEGER,
      allowNull: true,
      references: {
        model: 'Students',
        key: 'id'
      },
      onUpdate: 'CASCADE',
      onDelete: 'SET NULL',
      comment: 'Links to the Student record created when enquiry is approved'
    });

    // Add index for better query performance
    await queryInterface.addIndex('CoachingEnquiries', ['studentId'], {
      name: 'coaching_enquiries_student_id_idx'
    });
  },

  down: async (queryInterface, Sequelize) => {
    // Remove index first
    await queryInterface.removeIndex('CoachingEnquiries', 'coaching_enquiries_student_id_idx');
    
    // Remove column
    await queryInterface.removeColumn('CoachingEnquiries', 'studentId');
  }
};
