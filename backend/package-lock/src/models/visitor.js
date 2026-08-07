'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class Visitor extends Model {
    static associate(models) {
      Visitor.hasMany(models.VisitorPass, { foreignKey: 'visitorId' });
    }
  }
  
  Visitor.init({
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },
    name: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    email: {
      type: DataTypes.STRING,
      validate: {
        isEmail: true,
      },
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
    purpose: {
      type: DataTypes.ENUM('Meeting', 'Delivery', 'Service', 'Visit', 'Other'),
      defaultValue: 'Visit',
    },
    company: {
      type: DataTypes.STRING,
    },
    visitingPerson: {
      type: DataTypes.STRING,
    },
    expectedTime: {
      type: DataTypes.TIME,
    },
    actualTime: {
      type: DataTypes.TIME,
    },
    status: {
      type: DataTypes.ENUM('Expected', 'CheckedIn', 'CheckedOut', 'Cancelled'),
      defaultValue: 'Expected',
    },
    idProofType: {
      type: DataTypes.ENUM('Aadhar', 'PAN', 'DrivingLicense', 'Passport', 'VoterID'),
    },
    idProofNumber: {
      type: DataTypes.STRING,
    },
    photo: {
      type: DataTypes.STRING,
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
    modelName: 'Visitor',
    tableName: 'Visitors',
  });
  
  return Visitor;
};