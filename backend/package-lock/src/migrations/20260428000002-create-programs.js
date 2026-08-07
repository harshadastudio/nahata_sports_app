'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.createTable('Programs', {
      id: {
        type: Sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true,
        allowNull: false,
      },
      sportId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'Sports',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'RESTRICT',
      },
      name: {
        type: Sequelize.STRING,
        allowNull: false,
      },
      description: {
        type: Sequelize.TEXT,
        allowNull: true,
      },
      ageGroup: {
        type: Sequelize.STRING,
        allowNull: true,
        comment: 'e.g., 5-15 Years',
      },
      duration: {
        type: Sequelize.STRING,
        allowNull: true,
        comment: 'e.g., 1 Month, 3 Months, 6 Months, Annual',
      },
      price: {
        type: Sequelize.DECIMAL(10, 2),
        allowNull: false,
        defaultValue: 0,
      },
      batchDays: {
        type: Sequelize.STRING,
        allowNull: true,
        comment: 'Comma-separated days: Mon,Wed,Fri',
      },
      startTime: {
        type: Sequelize.TIME,
        allowNull: true,
      },
      endTime: {
        type: Sequelize.TIME,
        allowNull: true,
      },
      coachId: {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: {
          model: 'Users',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
      },
      maxStudents: {
        type: Sequelize.INTEGER,
        defaultValue: 20,
      },
      currentStudents: {
        type: Sequelize.INTEGER,
        defaultValue: 0,
      },
      startDate: {
        type: Sequelize.DATEONLY,
        allowNull: true,
      },
      endDate: {
        type: Sequelize.DATEONLY,
        allowNull: true,
      },
      status: {
        type: Sequelize.ENUM('Active', 'Inactive', 'Completed', 'Cancelled'),
        defaultValue: 'Active',
      },
      features: {
        type: Sequelize.TEXT,
        allowNull: true,
        comment: 'JSON array of program features',
      },
      image: {
        type: Sequelize.STRING,
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

    // Add indexes for better query performance
    await queryInterface.addIndex('Programs', ['sportId'], {
      name: 'programs_sport_id_index',
    });

    await queryInterface.addIndex('Programs', ['coachId'], {
      name: 'programs_coach_id_index',
    });

    await queryInterface.addIndex('Programs', ['status'], {
      name: 'programs_status_index',
    });
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.dropTable('Programs');
  }
};
