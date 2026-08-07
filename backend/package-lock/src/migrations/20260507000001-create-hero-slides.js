'use strict';

module.exports = {
  up: async (queryInterface, Sequelize) => {
    await queryInterface.createTable('HeroSlides', {
      id: {
        type: Sequelize.INTEGER,
        autoIncrement: true,
        primaryKey: true
      },
      title: {
        type: Sequelize.STRING(500),
        allowNull: false
      },
      subtitle: {
        type: Sequelize.STRING(255),
        allowNull: true,
        comment: 'Small badge text above title'
      },
      description: {
        type: Sequelize.TEXT,
        allowNull: true
      },
      backgroundImage: {
        type: Sequelize.STRING(500),
        allowNull: true,
        comment: 'Main hero background image URL'
      },
      button1Text: {
        type: Sequelize.STRING(100),
        allowNull: true
      },
      button1Url: {
        type: Sequelize.STRING(255),
        allowNull: true
      },
      button2Text: {
        type: Sequelize.STRING(100),
        allowNull: true
      },
      button2Url: {
        type: Sequelize.STRING(255),
        allowNull: true
      },
      stat1Value: {
        type: Sequelize.STRING(50),
        allowNull: true,
        defaultValue: '12+'
      },
      stat1Label: {
        type: Sequelize.STRING(100),
        allowNull: true,
        defaultValue: 'Sports Available'
      },
      stat2Value: {
        type: Sequelize.STRING(50),
        allowNull: true,
        defaultValue: '500+'
      },
      stat2Label: {
        type: Sequelize.STRING(100),
        allowNull: true,
        defaultValue: 'Active Players'
      },
      stat3Value: {
        type: Sequelize.STRING(50),
        allowNull: true,
        defaultValue: '4.8★'
      },
      stat3Label: {
        type: Sequelize.STRING(100),
        allowNull: true,
        defaultValue: 'Service Rating'
      },
      featureCard1Title: {
        type: Sequelize.STRING(255),
        allowNull: true
      },
      featureCard1Description: {
        type: Sequelize.STRING(255),
        allowNull: true
      },
      featureCard1Badge: {
        type: Sequelize.STRING(100),
        allowNull: true
      },
      featureCard2Title: {
        type: Sequelize.STRING(255),
        allowNull: true
      },
      featureCard2Description: {
        type: Sequelize.STRING(255),
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

    // Create indexes
    await queryInterface.addIndex('HeroSlides', ['status']);
    await queryInterface.addIndex('HeroSlides', ['showOnFrontend']);
    await queryInterface.addIndex('HeroSlides', ['displayOrder']);

    // Seed default hero slide matching current frontend
    await queryInterface.bulkInsert('HeroSlides', [{
      title: 'ELEVATE YOUR ATHLETIC EDGE.',
      subtitle: 'Premier Sports Facility in Pune',
      description: 'Experience world-class sports facilities, expert coaching, and a vibrant community dedicated to athletic excellence. Book your slot today.',
      backgroundImage: 'https://images.unsplash.com/photo-1461896756913-c3b6bc943265?w=1200&q=80',
      button1Text: 'Book Your Slot',
      button1Url: '/book',
      button2Text: 'View Programs',
      button2Url: '/coaching',
      stat1Value: '12+',
      stat1Label: 'Sports Available',
      stat2Value: '500+',
      stat2Label: 'Active Players',
      stat3Value: '4.8★',
      stat3Label: 'Service Rating',
      featureCard1Title: 'FIFA Certified Turfs',
      featureCard1Description: 'Starting at ₹800/hr',
      featureCard1Badge: 'Hot Deal',
      featureCard2Title: 'Indoor Badminton',
      featureCard2Description: 'Olympic grade flooring',
      displayOrder: 1,
      status: 'Active',
      showOnFrontend: true,
      createdAt: new Date(),
      updatedAt: new Date()
    }]);
  },

  down: async (queryInterface, Sequelize) => {
    await queryInterface.dropTable('HeroSlides');
  }
};
