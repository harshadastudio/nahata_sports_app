const { DataTypes } = require('sequelize');

/**
 * CmsSport — an INDEPENDENT Sports card shown on the Home page "Sports Programs" section.
 *
 * This is a self-contained CMS entity. It is NOT linked to the master `Sports`
 * table or the sidebar Sports module. The admin adds/edits/deletes these cards
 * directly in CMS → Sports, and only these records drive the Home page section.
 */
module.exports = (sequelize) => {
  const CmsSport = sequelize.define('CmsSport', {
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true
    },
    name: {
      type: DataTypes.STRING(255),
      allowNull: false,
      comment: 'Sport title shown on the card (e.g. "Cricket")'
    },
    location: {
      type: DataTypes.STRING(255),
      allowNull: true,
      defaultValue: 'Nahata Sports Complex',
      comment: 'Location label shown under the title'
    },
    image: {
      type: DataTypes.TEXT,
      allowNull: true,
      comment: 'Card background image URL'
    },
    category: {
      type: DataTypes.ENUM('Indoor', 'Outdoor', 'Aquatic', 'Adventure'),
      allowNull: false,
      defaultValue: 'Outdoor'
    },
    venueLabel: {
      type: DataTypes.STRING(100),
      allowNull: true,
      defaultValue: '2 Venues',
      comment: 'Small top-right badge text (e.g. "2 Venues")'
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
    tableName: 'CmsSports',
    timestamps: true,
    indexes: [
      { fields: ['status'] },
      { fields: ['showOnFrontend'] },
      { fields: ['displayOrder'] }
    ]
  });

  return CmsSport;
};
