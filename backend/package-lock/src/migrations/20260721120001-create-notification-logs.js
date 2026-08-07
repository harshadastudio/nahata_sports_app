'use strict';

/**
 * NotificationLogs — durable outbox + queue for outgoing messages (WhatsApp first).
 * See models/notificationlog.js for the lifecycle. The UNIQUE (refType, refId,
 * template) index enforces send-once idempotency at the database level.
 * @type {import('sequelize-cli').Migration}
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('NotificationLogs', {
      id: { type: Sequelize.INTEGER, autoIncrement: true, primaryKey: true, allowNull: false },

      channel: { type: Sequelize.STRING(30), allowNull: false, defaultValue: 'whatsapp' },
      provider: { type: Sequelize.STRING(50), allowNull: true },
      template: { type: Sequelize.STRING(120), allowNull: false },

      refType: { type: Sequelize.STRING(40), allowNull: false },
      refId: { type: Sequelize.INTEGER, allowNull: true },

      bookingId: {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: { model: 'Bookings', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
      },
      userId: {
        type: Sequelize.INTEGER,
        allowNull: true,
        references: { model: 'Users', key: 'id' },
        onUpdate: 'CASCADE',
        onDelete: 'SET NULL',
      },

      phone: { type: Sequelize.STRING(20), allowNull: false },
      payload: { type: Sequelize.JSONB, allowNull: true },

      status: {
        type: Sequelize.ENUM('queued', 'processing', 'sent', 'delivered', 'read', 'failed', 'dead'),
        allowNull: false,
        defaultValue: 'queued',
      },

      messageId: { type: Sequelize.STRING(191), allowNull: true },

      retryCount: { type: Sequelize.INTEGER, allowNull: false, defaultValue: 0 },
      maxRetries: { type: Sequelize.INTEGER, allowNull: false, defaultValue: 5 },
      nextAttemptAt: { type: Sequelize.DATE, allowNull: true },

      lastError: { type: Sequelize.TEXT, allowNull: true },
      response: { type: Sequelize.JSONB, allowNull: true },

      createdAt: { allowNull: false, type: Sequelize.DATE },
      updatedAt: { allowNull: false, type: Sequelize.DATE },
    });

    // Worker poll: "give me due, not-yet-terminal jobs".
    await queryInterface.addIndex('NotificationLogs', ['status', 'nextAttemptAt'], {
      name: 'notification_logs_status_next_attempt',
    });
    // Delivery-webhook correlation by provider message id.
    await queryInterface.addIndex('NotificationLogs', ['messageId'], {
      name: 'notification_logs_message_id',
    });
    // Send-once idempotency guard.
    await queryInterface.addIndex('NotificationLogs', ['refType', 'refId', 'template'], {
      name: 'notification_logs_ref_template_unique',
      unique: true,
    });
  },

  async down(queryInterface) {
    await queryInterface.dropTable('NotificationLogs');
    // Drop the enum type Postgres created for the `status` column.
    if (queryInterface.sequelize.getDialect() === 'postgres') {
      await queryInterface.sequelize.query('DROP TYPE IF EXISTS "enum_NotificationLogs_status";');
    }
  },
};
