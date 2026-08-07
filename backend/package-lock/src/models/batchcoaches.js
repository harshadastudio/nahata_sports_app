'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class BatchCoaches extends Model {
    static associate(models) {
      BatchCoaches.belongsTo(models.Batch, { foreignKey: 'batchId' });
      BatchCoaches.belongsTo(models.User, { foreignKey: 'coachId' });
    }
  }
  
  BatchCoaches.init({
    id: {
      type: DataTypes.INTEGER,
      autoIncrement: true,
      primaryKey: true,
    },
    batchId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'Batches',
        key: 'id',
      },
    },
    coachId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'Users',
        key: 'id',
      },
    },
    role: {
      type: DataTypes.ENUM('Head Coach', 'Assistant Coach', 'Trainer'),
      defaultValue: 'Head Coach',
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
    modelName: 'BatchCoaches',
    tableName: 'BatchCoaches',
  });
  
  return BatchCoaches;
};