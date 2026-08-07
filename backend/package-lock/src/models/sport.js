'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class Sport extends Model {
    static associate(models) {
      Sport.belongsTo(models.SportComplex, { foreignKey: 'sportComplexId' });
      Sport.hasMany(models.Court, { foreignKey: 'sportId' });
      Sport.hasMany(models.Booking, { foreignKey: 'sportId' });
      Sport.hasMany(models.Batch, { foreignKey: 'sportId' });
      Sport.hasMany(models.Performance, { foreignKey: 'sportId' });

      // Many-to-Many: Sport can have multiple Coaches
      Sport.belongsToMany(models.Coach, {
        through: models.CoachSport,
        foreignKey: 'sportId',
        otherKey: 'coachId',
        as: 'coaches'
      });
    }
  }
  
  Sport.init({
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },
    name: {
      type: DataTypes.STRING,
      allowNull: false,
      // Uniqueness is scoped to the sports complex (see indexes below),
      // so the same name can be reused across different complexes.
    },
    sportComplexId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: 'SportComplexes',
        key: 'id',
      },
    },
    description: {
      type: DataTypes.TEXT,
    },
    category: {
      type: DataTypes.ENUM('Indoor', 'Outdoor', 'Aquatic', 'Adventure'),
      defaultValue: 'Outdoor',
    },
    minAge: {
      type: DataTypes.INTEGER,
    },
    maxAge: {
      type: DataTypes.INTEGER,
    },
    duration: {
      type: DataTypes.STRING,
    },
    equipmentRequired: {
      type: DataTypes.TEXT,
    },
    image: {
      type: DataTypes.TEXT,
      allowNull: true,
      comment: 'Sport image (base64 or URL)',
    },
    allowedMembers: {
      type: DataTypes.INTEGER,
      defaultValue: 0,
    },
    achievements: {
      type: DataTypes.TEXT,
    },
    completeInformation: {
      type: DataTypes.TEXT,
    },
    status: {
      type: DataTypes.ENUM('Active', 'Inactive'),
      defaultValue: 'Active',
    },
    showOnFrontend: {
      type: DataTypes.BOOLEAN,
      allowNull: false,
      defaultValue: true,
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
    modelName: 'Sport',
    tableName: 'Sports',
    indexes: [
      {
        unique: true,
        name: 'sports_name_complex_unique',
        fields: ['name', 'sportComplexId'],
      },
    ],
  });
  
  return Sport;
};