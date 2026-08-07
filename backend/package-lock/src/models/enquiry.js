'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class Enquiry extends Model {
    static associate(models) {
      Enquiry.belongsTo(models.User, { foreignKey: 'assignedTo' });
      Enquiry.belongsTo(models.SportComplex, { foreignKey: 'sportComplexId', as: 'sportComplex' });
    }
  }
  
  Enquiry.init({
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
      allowNull: false,
      validate: {
        isEmail: true,
      },
    },
    phone: {
      type: DataTypes.STRING,
      allowNull: false,
    },
    sportInterest: {
      type: DataTypes.STRING,
    },
    messageType: {
      type: DataTypes.ENUM('Coaching', 'Booking', 'General', 'Feedback', 'Complaint'),
      defaultValue: 'General',
    },
    message: {
      type: DataTypes.TEXT,
      allowNull: false,
    },
    status: {
      type: DataTypes.ENUM('New', 'Follow up', 'Qualified', 'Attempted', 'Closed'),
      defaultValue: 'New',
    },
    assignedTo: {
      type: DataTypes.INTEGER,
      references: {
        model: 'Users',
        key: 'id',
      },
    },
    followUpDate: {
      type: DataTypes.DATE,
    },
    notes: {
      type: DataTypes.TEXT,
    },
    source: {
      type: DataTypes.ENUM('Website', 'Phone', 'Email', 'WalkIn', 'SocialMedia'),
      defaultValue: 'Website',
    },
    sportComplexId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: 'SportComplexes',
        key: 'id',
      },
      comment: 'The sports complex this enquiry belongs to',
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
    modelName: 'Enquiry',
    tableName: 'Enquiries',
  });
  
  return Enquiry;
};