'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class SecurityGuard extends Model {
    static associate(models) {
      // SecurityGuard belongs to User
      SecurityGuard.belongsTo(models.User, { foreignKey: 'userId', as: 'user' });
      // SecurityGuard belongs to a single sports complex (per-complex admin scoping)
      SecurityGuard.belongsTo(models.SportComplex, { foreignKey: 'sportComplexId', as: 'sportComplex' });
    }
  }
  
  SecurityGuard.init({
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },
    userId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'Users',
        key: 'id',
      },
      onUpdate: 'CASCADE',
      onDelete: 'CASCADE',
    },
    sportComplexId: {
      type: DataTypes.INTEGER,
      allowNull: true,
      references: {
        model: 'SportComplexes',
        key: 'id',
      },
      comment: 'The sports complex this guard is assigned to',
    },
    guardId: {
      type: DataTypes.STRING,
      unique: true,
      allowNull: false,
    },
    licenseNumber: {
      type: DataTypes.STRING,
    },
    shift: {
      type: DataTypes.ENUM('Morning', 'Evening', 'Night'),
      allowNull: false,
    },
    assignedArea: {
      type: DataTypes.ENUM('Main Gate', 'Parking', 'Courts', 'Building', 'Perimeter'),
      allowNull: false,
    },
    joiningDate: {
      type: DataTypes.DATEONLY,
      allowNull: false,
    },
    salary: {
      type: DataTypes.DECIMAL(10, 2),
    },
    status: {
      type: DataTypes.ENUM('Active', 'Inactive', 'On Leave'),
      defaultValue: 'Active',
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
    modelName: 'SecurityGuard',
    tableName: 'SecurityGuards',
  });
  
  return SecurityGuard;
};
