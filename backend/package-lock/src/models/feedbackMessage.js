'use strict';

const { Model } = require('sequelize');

module.exports = (sequelize, DataTypes) => {
  class FeedbackMessage extends Model {
    static associate(models) {
      FeedbackMessage.belongsTo(models.UserFeedback, {
        foreignKey: 'feedbackId',
        as: 'feedback',
        onDelete: 'CASCADE',
      });
    }
  }

  FeedbackMessage.init(
    {
      id: {
        type: DataTypes.UUID,
        defaultValue: DataTypes.UUIDV4,
        primaryKey: true,
        allowNull: false,
      },
      feedbackId: {
        type: DataTypes.UUID,
        allowNull: false,
      },
      senderType: {
        type: DataTypes.ENUM('user', 'admin'),
        allowNull: false,
      },
      senderId: {
        type: DataTypes.INTEGER,
        allowNull: true,
      },
      senderName: {
        type: DataTypes.STRING,
        allowNull: false,
        defaultValue: 'User',
      },
      message: {
        type: DataTypes.TEXT,
        allowNull: false,
      },
    },
    {
      sequelize,
      modelName: 'FeedbackMessage',
      tableName: 'feedback_messages',
    }
  );

  return FeedbackMessage;
};
