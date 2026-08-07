const { DataTypes } = require('sequelize');

module.exports = (sequelize) => {
  const HeroSlide = sequelize.define('HeroSlide', {
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true
    },
    title: {
      type: DataTypes.STRING(500),
      allowNull: false,
      comment: 'Headline line 1 (plain color), e.g. "PLAY AT YOUR"'
    },
    titleHighlight: {
      type: DataTypes.STRING(500),
      allowNull: true,
      comment: 'Headline line 2, shown in gradient/highlight color, e.g. "BEST LEVEL."'
    },
    subtitle: {
      type: DataTypes.STRING(255),
      allowNull: true,
      comment: 'Small badge text above title (e.g., "Premier Sports Facility in Pune")'
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    backgroundImage: {
      type: DataTypes.STRING(500),
      allowNull: true,
      comment: 'Main hero background image URL (primary image)'
    },
    backgroundImages: {
      type: DataTypes.JSON,
      allowNull: true,
      defaultValue: [],
      comment: 'Array of additional background image URLs for carousel/slideshow'
    },
    button1Text: {
      type: DataTypes.STRING(100),
      allowNull: true
    },
    button1Url: {
      type: DataTypes.STRING(255),
      allowNull: true
    },
    button2Text: {
      type: DataTypes.STRING(100),
      allowNull: true
    },
    button2Url: {
      type: DataTypes.STRING(255),
      allowNull: true
    },
    stat1Value: {
      type: DataTypes.STRING(50),
      allowNull: true,
      defaultValue: '12+',
      comment: 'First statistic value (e.g., "12+")'
    },
    stat1Label: {
      type: DataTypes.STRING(100),
      allowNull: true,
      defaultValue: 'Sports Available',
      comment: 'First statistic label'
    },
    stat2Value: {
      type: DataTypes.STRING(50),
      allowNull: true,
      defaultValue: '500+',
      comment: 'Second statistic value (e.g., "500+")'
    },
    stat2Label: {
      type: DataTypes.STRING(100),
      allowNull: true,
      defaultValue: 'Active Players',
      comment: 'Second statistic label'
    },
    stat3Value: {
      type: DataTypes.STRING(50),
      allowNull: true,
      defaultValue: '4.8★',
      comment: 'Third statistic value (e.g., "4.8★")'
    },
    stat3Label: {
      type: DataTypes.STRING(100),
      allowNull: true,
      defaultValue: 'Service Rating',
      comment: 'Third statistic label'
    },
    featureCard1Title: {
      type: DataTypes.STRING(255),
      allowNull: true,
      comment: 'First feature card title (e.g., "FIFA Certified Turfs")'
    },
    featureCard1Description: {
      type: DataTypes.STRING(255),
      allowNull: true,
      comment: 'First feature card description (e.g., "Starting at ₹800/hr")'
    },
    featureCard1Badge: {
      type: DataTypes.STRING(100),
      allowNull: true,
      comment: 'First feature card badge text (e.g., "Hot Deal")'
    },
    featureCard2Title: {
      type: DataTypes.STRING(255),
      allowNull: true,
      comment: 'Second feature card title (e.g., "Indoor Badminton")'
    },
    featureCard2Description: {
      type: DataTypes.STRING(255),
      allowNull: true,
      comment: 'Second feature card description (e.g., "Olympic grade flooring")'
    },
    displayOrder: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
      comment: 'Order in which slides appear (lower numbers first)'
    },
    status: {
      type: DataTypes.ENUM('Active', 'Inactive'),
      allowNull: false,
      defaultValue: 'Active'
    },
    showOnFrontend: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true,
      comment: 'Whether this slide should be displayed on the frontend'
    }
  }, {
    tableName: 'HeroSlides',
    timestamps: true,
    indexes: [
      {
        fields: ['status']
      },
      {
        fields: ['showOnFrontend']
      },
      {
        fields: ['displayOrder']
      }
    ]
  });

  return HeroSlide;
};
