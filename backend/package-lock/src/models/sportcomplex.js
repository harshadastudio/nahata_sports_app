'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class SportComplex extends Model {
    static associate(models) {
      SportComplex.hasMany(models.Court, { foreignKey: 'sportComplexId' });
      SportComplex.hasMany(models.Sport, { foreignKey: 'sportComplexId' });
      SportComplex.belongsTo(models.User, { foreignKey: 'managerId' });

      // Per-complex admin scoping: records owned by this complex.
      SportComplex.hasMany(models.User, { foreignKey: 'sportComplexId', as: 'admins' });
      SportComplex.hasMany(models.Coach, { foreignKey: 'sportComplexId', as: 'coaches' });
      SportComplex.hasMany(models.Employee, { foreignKey: 'sportComplexId', as: 'employees' });
      SportComplex.hasMany(models.SecurityGuard, { foreignKey: 'sportComplexId', as: 'securityGuards' });
      SportComplex.hasMany(models.Enquiry, { foreignKey: 'sportComplexId', as: 'enquiries' });
      SportComplex.hasMany(models.CoachingEnquiry, { foreignKey: 'sportComplexId', as: 'coachingEnquiries' });
      SportComplex.hasMany(models.VisitorPass, { foreignKey: 'sportComplexId', as: 'visitorPasses' });
      SportComplex.hasMany(models.EventPass, { foreignKey: 'sportComplexId', as: 'eventPasses' });
    }
  }
  
  SportComplex.init({
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },
    name: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    address: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    city: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    state: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    zipCode: {
      type: DataTypes.STRING,
    },
    contactPhone: {
      type: DataTypes.STRING,
      allowNull: false,
      validate: {
        is: {
          args: /^[0-9]{10}$/,
          msg: 'Contact phone must be exactly 10 digits'
        },
        len: {
          args: [10, 10],
          msg: 'Contact phone must be exactly 10 digits'
        }
      }
    },
    contactEmail: {
      type: DataTypes.STRING,
      validate: {
        isEmail: true,
      },
    },
    managerId: {
      type: DataTypes.INTEGER,
      references: {
        model: 'Users',
        key: 'id',
      },
    },
    facilities: {
      type: DataTypes.TEXT,
    },
    openingHours: {
      type: DataTypes.TEXT,
    },
    status: {
      type: DataTypes.ENUM('Active', 'Maintenance', 'Closed'),
      defaultValue: 'Active',
    },
    latitude: {
      type: DataTypes.DECIMAL(10, 8),
    },
    longitude: {
      type: DataTypes.DECIMAL(11, 8),
    },
    image: {
      type: DataTypes.STRING(500),
      allowNull: true,
      defaultValue: null,
    },
    sportsOffered: {
      type: DataTypes.JSON,
      allowNull: true,
      defaultValue: null,
    },
    mapUrl: {
      type: DataTypes.TEXT,
      allowNull: true,
      defaultValue: null,
    },
    showOnFrontend: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: false,
    },
    externalOrgId: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },
    externalSiteId: {
      type: DataTypes.INTEGER,
      allowNull: true,
    },
    externalSiteUuid: {
      type: DataTypes.STRING(255),
      allowNull: true,
    },
    createdAt: {
      allowNull: false,
      type: DataTypes.DATE,
    },
    updatedAt: {
      allowNull: false,
      type: DataTypes.DATE,
    },
  }, {
    sequelize,
    modelName: 'SportComplex',
    tableName: 'SportComplexes',
  });
  
  return SportComplex;
};