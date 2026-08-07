'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    // New settings table (replaces AboutPage)
    await queryInterface.createTable('AboutPageSettings', {
      id: { type: Sequelize.INTEGER, autoIncrement: true, primaryKey: true },
      heroTitle: { type: Sequelize.STRING(255), allowNull: false, defaultValue: 'About Us' },
      whyChooseHeading: { type: Sequelize.STRING(255), allowNull: true, defaultValue: 'Why Choose Nahata Sports?' },
      whyChoosePoints: { type: Sequelize.JSON, allowNull: true },
      createdAt: { allowNull: false, type: Sequelize.DATE },
      updatedAt: { allowNull: false, type: Sequelize.DATE },
    });

    // Dynamic sections table
    await queryInterface.createTable('AboutPageSections', {
      id: { type: Sequelize.INTEGER, autoIncrement: true, primaryKey: true },
      label: { type: Sequelize.STRING(100), allowNull: true },
      heading: { type: Sequelize.STRING(500), allowNull: true },
      description: { type: Sequelize.TEXT, allowNull: true },
      image: { type: Sequelize.STRING(500), allowNull: true },
      bulletPoints: { type: Sequelize.JSON, allowNull: true },   // string[]
      extraText: { type: Sequelize.TEXT, allowNull: true },
      imagePosition: {
        type: Sequelize.ENUM('left', 'right'),
        allowNull: false,
        defaultValue: 'left',
      },
      sortOrder: { type: Sequelize.INTEGER, allowNull: false, defaultValue: 0 },
      createdAt: { allowNull: false, type: Sequelize.DATE },
      updatedAt: { allowNull: false, type: Sequelize.DATE },
    });

    const now = new Date();

    // Seed settings
    await queryInterface.bulkInsert('AboutPageSettings', [{
      heroTitle: 'About Us',
      whyChooseHeading: 'Why Choose Nahata Sports?',
      whyChoosePoints: JSON.stringify([
        'Convenient locations in Pune with modern amenities',
        'Expert instructors across multiple sports',
        'Simplified booking and payment systems',
        'A supportive environment for athletes of all ages',
        'Strong focus on progress, community, and real-time communication',
      ]),
      createdAt: now,
      updatedAt: now,
    }]);

    // Seed 2 default sections
    await queryInterface.bulkInsert('AboutPageSections', [
      {
        label: 'Sinhagad Road',
        heading: 'Transforming Future Champions, One Game at a Time',
        description: "At Nahata Sports, we're on a mission to inspire, train, and empower the next generation of athletes across Maharashtra. With facilities at Sinhagad Road and Gangadham Chowk, our multi-center complexes offer world-class training and seamless booking experiences that make sports easily accessible for all.",
        image: 'https://images.unsplash.com/photo-1540747734271-1d7350749312?w=800&q=80',
        bulletPoints: JSON.stringify(['Cricket (Rajasthan Royals Academy)', 'Badminton', 'Basketball', 'Skating', 'Karate', 'Dance & Zumba', 'Fun Fitness (3+ years)']),
        extraText: "Need a space to play or train? Our Book & Play feature lets you reserve courts and grounds in real time—with hassle-free QR code payments offering fast, secure, and convenient access.",
        imagePosition: 'left',
        sortOrder: 1,
        createdAt: now,
        updatedAt: now,
      },
      {
        label: 'Gangadham Chowk',
        heading: 'Designed for You: Students and Parents Love It!',
        description: 'Our systems are built with families in mind:',
        image: 'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=800&q=80',
        bulletPoints: JSON.stringify(['Easy access to fee status and receipts', 'Attendance tracking for students', 'Coach feedback visibility', 'A structured program timeline with clear expectations']),
        extraText: "We're more than just a sports center—we're a community. Stay in the loop with free training camps, tournaments, WhatsApp alerts, and schedule notifications.",
        imagePosition: 'right',
        sortOrder: 2,
        createdAt: now,
        updatedAt: now,
      },
    ]);
  },

  async down(queryInterface) {
    await queryInterface.dropTable('AboutPageSections');
    await queryInterface.dropTable('AboutPageSettings');
  },
};
