'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class UserFeedback extends Model {
    static associate(models) {
      // Optional: associate with User if userId is stored
      if (models.User) {
        UserFeedback.belongsTo(models.User, {
          foreignKey: 'userId',
          as: 'user',
          onDelete: 'SET NULL',
        });
      }

      // Conversation thread: replies from the user and admin
      if (models.FeedbackMessage) {
        UserFeedback.hasMany(models.FeedbackMessage, {
          foreignKey: 'feedbackId',
          as: 'messages',
          onDelete: 'CASCADE',
        });
      }
    }
  }

  UserFeedback.init(
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
        allowNull: false,
      },
      userId: {
        type: DataTypes.INTEGER,
        allowNull: true, // null for guest submissions
      },
      fullName: {
        type: DataTypes.STRING,
        allowNull: false,
      },
      email: {
        type: DataTypes.STRING,
        allowNull: false,
        validate: { isEmail: true },
      },
      subject: {
        type: DataTypes.STRING,
        allowNull: false,
      },
      rating: {
        type: DataTypes.INTEGER,
        allowNull: true,
        validate: { min: 1, max: 5 },
      },
      message: {
        type: DataTypes.TEXT,
        allowNull: false,
      },
      status: {
        type: DataTypes.ENUM('new', 'in_progress', 'resolved', 'closed'),
        defaultValue: 'new',
        allowNull: false,
      },
      referenceNumber: {
        type: DataTypes.STRING,
        allowNull: false,
        unique: true,
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
      modelName: 'UserFeedback',
      tableName: 'user_feedback',
      paranoid: true,
    }
  );

  return UserFeedback;
};
