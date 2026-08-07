'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class EventPassMember extends Model {
    static associate(models) {
      EventPassMember.belongsTo(models.EventIndividualPass, {
        foreignKey: 'passId',
        as: 'pass',
      });
    }
  }

  EventPassMember.init(
    {
      id:     { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
      passId: {
        type: DataTypes.INTEGER,
        allowNull: false,
        references: { model: 'EventIndividualPasses', key: 'id' },
      },
      name:  { type: DataTypes.STRING(255), allowNull: false },
      phone: { 
        type: DataTypes.STRING(20),  
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
      scanStatus: {
        type: DataTypes.ENUM('NotScanned', 'In', 'Out'),
        defaultValue: 'NotScanned',
        allowNull: false,
      },
      scannedInAt:  { type: DataTypes.DATE, allowNull: true },
      scannedOutAt: { type: DataTypes.DATE, allowNull: true },
      createdAt: { allowNull: false, type: DataTypes.DATE },
      updatedAt: { allowNull: false, type: DataTypes.DATE },
    },
    {
      sequelize,
      modelName: 'EventPassMember',
      tableName: 'EventPassMembers',
    }
  );

  return EventPassMember;
};
