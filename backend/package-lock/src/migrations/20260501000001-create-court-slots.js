'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('CourtSlots', {
      id: {
        type: Sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true,
      },
      courtId: {
        type: Sequelize.INTEGER,
        allowNull: false,
        references: {
          model: 'Courts',
          key: 'id',
        },
        onUpdate: 'CASCADE',
        onDelete: 'CASCADE',
      },
      startTime: {
        type: Sequelize.TIME,
        allowNull: false,
      },
      endTime: {
        type: Sequelize.TIME,
        allowNull: false,
      },
      availableDays: {
        type: Sequelize.STRING(100),
        allowNull: false,
        defaultValue: 'Monday,Tuesday,Wednesday,Thursday,Friday,Saturday,Sunday',
      },
      slotType: {
        type: Sequelize.ENUM('Regular', 'Peak'),
        defaultValue: 'Regular',
        allowNull: false,
      },
      priceOverride: {
        type: Sequelize.DECIMAL(10, 2),
        allowNull: true,
      },
      status: {
        type: Sequelize.ENUM('Active', 'Inactive'),
        defaultValue: 'Active',
        allowNull: false,
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
    await queryInterface.addIndex('CourtSlots', ['courtId'], {
      name: 'idx_courtslots_courtid',
    });

    await queryInterface.addIndex('CourtSlots', ['status'], {
      name: 'idx_courtslots_status',
    });
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.dropTable('CourtSlots');
  },
};
