'use strict';
const bcrypt = require('bcrypt');
const {
  Model
} = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class RefreshToken extends Model {
    /**
     * Helper method for defining associations.
     * This method is not a part of Sequelize lifecycle.
     * The `models/index` file will call this method automatically.
     */
    static associate(models) {
      RefreshToken.belongsTo(models.User, { foreignKey: 'userId', as: 'user' });
    }
  }
  
  RefreshToken.init({
    token: {
      type: DataTypes.STRING,
      allowNull: false
    },
    userId: {
      type: DataTypes.INTEGER,
      allowNull: false,
      references: {
        model: 'Users',
        key: 'id'
      },
      onDelete: 'CASCADE'
    },
    expiryDate: {
      type: DataTypes.DATE,
      allowNull: false
    },
    isRevoked: {
      type: DataTypes.BOOLEAN,
      defaultValue: false
    }
  }, {
    sequelize,
    modelName: 'RefreshToken',
    hooks: {
      beforeCreate: async (refreshToken) => {
        if (refreshToken.token) {
          refreshToken.token = await bcrypt.hash(refreshToken.token, 12);
        }
      },
      beforeUpdate: async (refreshToken) => {
        if (refreshToken.changed('token')) {
          refreshToken.token = await bcrypt.hash(refreshToken.token, 12);
        }
      }
    }
  });
  
  // Instance method to check token
  RefreshToken.prototype.compareToken = async function(candidateToken) {
    return await bcrypt.compare(candidateToken, this.token);
  };
  
  // Static method to verify if token is expired
  RefreshToken.isExpired = function(token) {
    return new Date() > token.expiryDate;
  };
  
  return RefreshToken;
};
