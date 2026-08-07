'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class ContactUs extends Model {
    static associate(models) {
      ContactUs.belongsTo(models.SportComplex, { foreignKey: 'sportComplexId', as: 'sportComplex' });
    }
  }

  ContactUs.init(
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
        allowNull: false,
      },
      fullName: {
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
      subject: {
        type: DataTypes.STRING,
        allowNull: false,
      },
      message: {
        type: DataTypes.TEXT,
        allowNull: false,
      },
      status: {
        type: DataTypes.ENUM('new', 'read', 'replied'),
        defaultValue: 'new',
        allowNull: false,
      },
      referenceNumber: {
        type: DataTypes.STRING,
        allowNull: false,
        unique: true,
      },
      sportComplexId: {
        type: DataTypes.INTEGER,
        allowNull: true,
        references: { model: 'SportComplexes', key: 'id' },
        comment: 'The complex this enquiry is directed to',
      },
      ipAddress: {
        type: DataTypes.STRING,
        allowNull: true,
      },
      userAgent: {
        type: DataTypes.TEXT,
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
      deletedAt: {
        allowNull: true,
        type: DataTypes.DATE,
      },
    },
    {
      sequelize,
      modelName: 'ContactUs',
      tableName: 'contact_us',
      paranoid: true, // Enables soft delete via deletedAt
      scopes: {
        // Scope: only active (non-deleted) records — paranoid handles this by default,
        // but exposing it explicitly for clarity in service queries
        active: {
          where: { deletedAt: null },
        },
        // Scope: filter by a given status value
        byStatus(statusValue) {
          return { where: { status: statusValue } };
        },
      },
    }
  );

  return ContactUs;
};
