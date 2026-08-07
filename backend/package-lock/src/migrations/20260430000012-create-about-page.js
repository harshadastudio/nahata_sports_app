'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('AboutPage', {
      id: { type: Sequelize.INTEGER, autoIncrement: true, primaryKey: true },
      // Hero
      heroTitle: { type: Sequelize.STRING(255), allowNull: false, defaultValue: 'About Us' },
      // Section 1 — Sinhagad Road
      section1Label: { type: Sequelize.STRING(100), allowNull: true, defaultValue: 'Sinhagad Road' },
      section1Heading: { type: Sequelize.STRING(500), allowNull: true },
      section1Description: { type: Sequelize.TEXT, allowNull: true },
      section1Image: { type: Sequelize.STRING(500), allowNull: true },
      section1SportsList: { type: Sequelize.JSON, allowNull: true }, // string[]
      section1BookingText: { type: Sequelize.TEXT, allowNull: true },
      // Section 2 — Gangadham Chowk
      section2Label: { type: Sequelize.STRING(100), allowNull: true, defaultValue: 'Gangadham Chowk' },
      section2Heading: { type: Sequelize.STRING(500), allowNull: true },
      section2Description: { type: Sequelize.TEXT, allowNull: true },
      section2Image: { type: Sequelize.STRING(500), allowNull: true },
      section2FeaturesList: { type: Sequelize.JSON, allowNull: true }, // string[]
      section2CommunityText: { type: Sequelize.TEXT, allowNull: true },
      // Why Choose section
      whyChooseHeading: { type: Sequelize.STRING(255), allowNull: true, defaultValue: 'Why Choose Nahata Sports?' },
      whyChoosePoints: { type: Sequelize.JSON, allowNull: true }, // string[]
      createdAt: { allowNull: false, type: Sequelize.DATE },
      updatedAt: { allowNull: false, type: Sequelize.DATE },
    });

    // Seed default content matching the current hardcoded About page
    await queryInterface.bulkInsert('AboutPage', [{
      heroTitle: 'About Us',
      section1Label: 'Sinhagad Road',
      section1Heading: 'Transforming Future Champions, One Game at a Time',
      section1Description: "At Nahata Sports, we're on a mission to inspire, train, and empower the next generation of athletes across Maharashtra. With facilities at Sinhagad Road and Gangadham Chowk, our multi-center complexes offer world-class training and seamless booking experiences that make sports easily accessible for all.",
      section1Image: 'https://images.unsplash.com/photo-1540747734271-1d7350749312?w=800&q=80',
      section1SportsList: JSON.stringify(['Cricket (Rajasthan Royals Academy)', 'Badminton', 'Basketball', 'Skating', 'Karate', 'Dance & Zumba', 'Fun Fitness (3+ years)']),
      section1BookingText: "Need a space to play or train? Our Book & Play feature lets you reserve courts and grounds in real time—with hassle-free QR code payments offering fast, secure, and convenient access. Available for sports such as Badminton, Football, Pickleball, and Cricket.",
      section2Label: 'Gangadham Chowk',
      section2Heading: 'Designed for You: Students and Parents Love It!',
      section2Description: 'Our systems are built with families in mind:',
      section2Image: 'https://images.unsplash.com/photo-1546519638-68e109498ffc?w=800&q=80',
      section2FeaturesList: JSON.stringify(['Easy access to fee status and receipts', 'Attendance tracking for students', 'Coach feedback visibility', 'A structured program timeline with clear expectations']),
      section2CommunityText: "We're more than just a sports center—we're a community. Stay in the loop with free training camps, tournaments, WhatsApp alerts, and schedule notifications.",
      whyChooseHeading: 'Why Choose Nahata Sports?',
      whyChoosePoints: JSON.stringify(['Convenient locations in Pune with modern amenities', 'Expert instructors across multiple sports', 'Simplified booking and payment systems', 'A supportive environment for athletes of all ages', 'Strong focus on progress, community, and real-time communication']),
      createdAt: new Date(),
      updatedAt: new Date(),
    }]);
  },
  async down(queryInterface) {
    await queryInterface.dropTable('AboutPage');
  },
};
