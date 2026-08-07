'use strict';

/** @type {import('sequelize-cli').Migration} */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('contact_info', {
      id: {
        type: Sequelize.UUID,
        defaultValue: Sequelize.UUIDV4,
        primaryKey: true,
        allowNull: false,
      },
      address: {
        type: Sequelize.TEXT,
        allowNull: false,
      },
      phone: {
        type: Sequelize.STRING,
        allowNull: false,
      },
      email: {
        type: Sequelize.STRING,
        allowNull: false,
      },
      hours: {
        type: Sequelize.STRING,
        allowNull: false,
        defaultValue: 'Daily: 06:00 AM - 10:00 PM',
      },
      mapEmbedUrl: {
        type: Sequelize.TEXT,
        allowNull: true,
      },
      isActive: {
        type: Sequelize.BOOLEAN,
        defaultValue: true,
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

    // Insert default contact information
    await queryInterface.bulkInsert('contact_info', [
      {
        id: Sequelize.literal('gen_random_uuid()'),
        address: 'Sinhagad Road, Pune, 411030',
        phone: '+91 98765 43210',
        email: 'info@nahatasports.com',
        hours: 'Daily: 06:00 AM - 10:00 PM',
        mapEmbedUrl: null,
        isActive: true,
        createdAt: new Date(),
        updatedAt: new Date(),
      },
    ]);
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.dropTable('contact_info');
  },
};
