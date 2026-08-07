'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class EventPass extends Model {
    static associate(models) {
      EventPass.hasMany(models.EventPassSlot, {
        foreignKey: 'eventPassId',
        as: 'slots',
        onDelete: 'CASCADE',
      });
      EventPass.hasMany(models.EventPassBooking, {
        foreignKey: 'eventPassId',
        as: 'bookings',
      });
      EventPass.hasMany(models.EventIndividualPass, {
        foreignKey: 'eventPassId',
        as: 'individualPasses',
      });
      EventPass.belongsTo(models.SportComplex, { foreignKey: 'sportComplexId', as: 'sportComplex' });
    }
  }

  EventPass.init(
    {
      id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
      sportComplexId: {
        type: DataTypes.INTEGER,
        allowNull: true,
        references: { model: 'SportComplexes', key: 'id' },
        comment: 'The sports complex this event pass belongs to',
      },
      title: { type: DataTypes.STRING(255), allowNull: false },
      description: { type: DataTypes.TEXT, allowNull: true },
      image: { type: DataTypes.STRING(500), allowNull: true },
      // Per-event FAQs: array of { question, answer } shown on the public events card
      faqs: { type: DataTypes.JSONB, allowNull: false, defaultValue: [] },
      // Admin-defined extra inputs rendered on the public booking form:
      // [{ key, label, type, required, placeholder, options }]
      customFields: { type: DataTypes.JSONB, allowNull: false, defaultValue: [] },
      status: {
        type: DataTypes.ENUM('Active', 'Inactive'),
        defaultValue: 'Active',
        allowNull: false,
      },
      createdAt: { allowNull: false, type: DataTypes.DATE },
      updatedAt: { allowNull: false, type: DataTypes.DATE },
    },
    { sequelize, modelName: 'EventPass', tableName: 'EventPasses' }
  );

  return EventPass;
};
