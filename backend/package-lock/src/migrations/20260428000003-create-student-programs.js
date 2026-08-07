'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.createTable('StudentPrograms', {
      id: {
        type: Sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true,
        allowNull: false,
      },
      studentId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'Students',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      programId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'Programs',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      enrollmentDate: {
        type: Sequelize.DATEONLY,
        allowNull: false,
        defaultValue: Sequelize.literal('CURRENT_DATE'),
      },
      status: {
        type: Sequelize.ENUM('Active', 'Completed', 'Dropped', 'Suspended'),
        defaultValue: 'Active',
      },
      paymentStatus: {
        type: Sequelize.ENUM('Pending', 'Paid', 'Partial', 'Overdue'),
        defaultValue: 'Pending',
      },
      amountPaid: {
        type: Sequelize.DECIMAL(10, 2),
        defaultValue: 0,
      },
      notes: {
        type: Sequelize.TEXT,
        allowNull: true,
      },
      createdAt: {
        allowNull: false,
        type: Sequelize.DATE,
      },
      updatedAt: {
        allowNull: false,
        type: Sequelize.DATE,
      },
    });

    // Add unique constraint to prevent duplicate enrollments
    await queryInterface.addConstraint('StudentPrograms', {
      fields: ['studentId', 'programId'],
      type: 'unique',
      name: 'unique_student_program_enrollment',
    });

    // Add indexes
    await queryInterface.addIndex('StudentPrograms', ['studentId'], {
      name: 'student_programs_student_id_index',
    });

    await queryInterface.addIndex('StudentPrograms', ['programId'], {
      name: 'student_programs_program_id_index',
    });

    await queryInterface.addIndex('StudentPrograms', ['status'], {
      name: 'student_programs_status_index',
    });
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.dropTable('StudentPrograms');
  }
};
