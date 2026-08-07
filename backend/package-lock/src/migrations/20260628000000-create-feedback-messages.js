'use strict';

module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('feedback_messages', {
      id: {
        type: Sequelize.UUID,
        defaultValue: Sequelize.UUIDV4,
        primaryKey: true,
        allowNull: false,
      },
      feedbackId: {
        type: Sequelize.UUID,
        allowNull: false,
        references: { model: 'user_feedback', key: 'id' },
        onDelete: 'CASCADE',
        onUpdate: 'CASCADE',
      },
      senderType: {
        type: Sequelize.ENUM('user', 'admin'),
        allowNull: false,
      },
      senderId: {
        type: Sequelize.INTEGER,
        allowNull: true,
      },
      senderName: {
        type: Sequelize.STRING,
        allowNull: false,
        defaultValue: 'User',
      },
      message: {
        type: Sequelize.TEXT,
        allowNull: false,
      },
      createdAt: {
        allowNull: false,
        type: Sequelize.DATE,
      },
      updatedAt: {
        allowNull: false,
        type: Sequelize.DATE,
      },
    });

    await queryInterface.addIndex('feedback_messages', ['feedbackId']);
  },

  async down(queryInterface, Sequelize) {
    await queryInterface.dropTable('feedback_messages');
    // Drop the ENUM type (PostgreSQL requires this)
    await queryInterface.sequelize.query(
      'DROP TYPE IF EXISTS "enum_feedback_messages_senderType";'
    );
  },
};
