'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class ContactInfo extends Model {
    static associate(models) {
      ContactInfo.belongsTo(models.SportComplex, { foreignKey: 'sportComplexId', as: 'sportComplex' });
    }
  }

  ContactInfo.init(
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
        allowNull: false,
      },
      image: {
        type: DataTypes.TEXT,
        allowNull: true,
        comment: 'URL of the contact image displayed on frontend',
      },
      address: {
        type: DataTypes.TEXT,
        allowNull: false,
      },
      phone: {
        type: DataTypes.STRING,
        allowNull: false,
        validate: {
          is: {
            args: /^[0-9]{10}$/,
            msg: 'Phone number must be exactly 10 digits'
          },
          len: {
            args: [10, 10],
            msg: 'Phone number must be exactly 10 digits'
          }
        }
      },
      email: {
        type: DataTypes.STRING,
        allowNull: false,
        validate: {
          isEmail: true,
        },
      },
      hours: {
        type: DataTypes.STRING,
        allowNull: false,
        defaultValue: 'Daily: 06:00 AM - 10:00 PM',
      },
      description: {
        type: DataTypes.TEXT,
        allowNull: true,
        comment: 'Description text displayed in the info banner on frontend',
      },
      mapEmbedUrl: {
        type: DataTypes.TEXT,
        allowNull: true,
        comment: 'Google Maps embed URL for location display',
      },
      isActive: {
        type: DataTypes.BOOLEAN,
        defaultValue: true,
        allowNull: false,
        comment: 'Only one contact info can be active at a time',
      },
      sportComplexId: {
        type: DataTypes.INTEGER,
        allowNull: true,
        references: { model: 'SportComplexes', key: 'id' },
        comment: 'The complex this contact info belongs to (NULL = global/default)',
      },
      createdAt: {
        allowNull: false,
        type: DataTypes.DATE,
      },
      updatedAt: {
        allowNull: false,
        type: DataTypes.DATE,
      },
    },
    {
      sequelize,
      modelName: 'ContactInfo',
      tableName: 'contact_info',
      timestamps: true,
    }
  );

  return ContactInfo;
};
