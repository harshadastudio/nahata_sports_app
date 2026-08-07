const { DataTypes } = require('sequelize');

/**
 * CmsCourt — an INDEPENDENT Court/Ground card shown on the Home page
 * "Book a Court or Ground" section.
 *
 * This is a self-contained CMS entity. It is NOT linked to the master `Courts`
 * inventory or any Sport record. Cards are grouped on the Home page by the free-text
 * `sportName` field (which becomes the filter tab label). The admin manages these
 * directly in CMS → Court or Ground.
 */
module.exports = (sequelize) => {
  const CmsCourt = sequelize.define('CmsCourt', {
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true
    },
    sportName: {
      type: DataTypes.STRING(255),
      allowNull: false,
      comment: 'Sport/group label — also used as the Home page filter tab (e.g. "Badminton")'
    },
    name: {
      type: DataTypes.STRING(255),
      allowNull: false,
      comment: 'Court/ground name (e.g. "Court A — Indoor")'
    },
    image: {
      type: DataTypes.TEXT,
      allowNull: true,
      comment: 'Card image URL'
    },
    surfaceType: {
      type: DataTypes.STRING(100),
      allowNull: true,
      defaultValue: 'Synthetic',
      comment: 'Surface label shown on the image pill (e.g. "Synthetic")'
    },
    hourlyRate: {
      type: DataTypes.DECIMAL(10, 2),
      allowNull: false,
      defaultValue: 800,
      comment: 'Price per hour shown on the card'
    },
    description: {
      type: DataTypes.TEXT,
      allowNull: true
    },
    displayOrder: {
      type: DataTypes.INTEGER,
      allowNull: false,
      defaultValue: 0,
      comment: 'Order in which cards appear (lower numbers first)'
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
      comment: 'Whether this card should be displayed on the Home page'
    }
  }, {
    tableName: 'CmsCourts',
    timestamps: true,
    indexes: [
      { fields: ['status'] },
      { fields: ['showOnFrontend'] },
      { fields: ['displayOrder'] }
    ]
  });

  return CmsCourt;
};
