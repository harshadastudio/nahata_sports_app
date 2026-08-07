'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.createTable('CmsSports', {
      id: {
        type: Sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true
      },
      name: {
        type: Sequelize.STRING(255),
        allowNull: false
      },
      location: {
        type: Sequelize.STRING(255),
        allowNull: true,
        defaultValue: 'Nahata Sports Complex'
      },
      image: {
        type: Sequelize.TEXT,
        allowNull: true
      },
      category: {
        type: Sequelize.ENUM('Indoor', 'Outdoor', 'Aquatic', 'Adventure'),
        allowNull: false,
        defaultValue: 'Outdoor'
      },
      venueLabel: {
        type: Sequelize.STRING(100),
        allowNull: true,
        defaultValue: '2 Venues'
      },
      description: {
        type: Sequelize.TEXT,
        allowNull: true
      },
      displayOrder: {
        type: Sequelize.INTEGER,
        allowNull: false,
        defaultValue: 0
      },
      status: {
        type: Sequelize.ENUM('Active', 'Inactive'),
        allowNull: false,
        defaultValue: 'Active'
      },
      showOnFrontend: {
        type: Sequelize.BOOLEAN,
        allowNull: false,
        defaultValue: true
      },
      createdAt: {
        type: Sequelize.DATE,
        allowNull: false,
        defaultValue: Sequelize.literal('CURRENT_TIMESTAMP')
      },
      updatedAt: {
        type: Sequelize.DATE,
        allowNull: false,
        defaultValue: Sequelize.literal('CURRENT_TIMESTAMP')
      }
    });

    await queryInterface.addIndex('CmsSports', ['status']);
    await queryInterface.addIndex('CmsSports', ['showOnFrontend']);
    await queryInterface.addIndex('CmsSports', ['displayOrder']);
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.dropTable('CmsSports');
    // Clean up ENUM types created by Postgres for the ENUM columns.
    if (queryInterface.sequelize.getDialect() === 'postgres') {
      await queryInterface.sequelize.query('DROP TYPE IF EXISTS "enum_CmsSports_category";');
      await queryInterface.sequelize.query('DROP TYPE IF EXISTS "enum_CmsSports_status";');
    }
  }
};
