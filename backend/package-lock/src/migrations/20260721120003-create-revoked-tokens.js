'use strict';

/**
 * RevokedTokens — JWT denylist for immediate revocation without changing token
 * expiry (keeps Huddle / KheloMore long-lived tokens valid until explicitly
 * revoked). See models/revokedtoken.js.
 * @type {import('sequelize-cli').Migration}
 */
module.exports = {
  async up(queryInterface, Sequelize) {
    await queryInterface.createTable('RevokedTokens', {
      id: { type: Sequelize.INTEGER, autoIncrement: true, primaryKey: true, allowNull: false },
      jti: { type: Sequelize.STRING(64), allowNull: true, unique: true },
      tokenHash: { type: Sequelize.STRING(64), allowNull: true, unique: true },
      userId: { type: Sequelize.INTEGER, allowNull: true },
      reason: { type: Sequelize.STRING(255), allowNull: true },
      expiresAt: { type: Sequelize.DATE, allowNull: true },
      createdAt: { allowNull: false, type: Sequelize.DATE },
      updatedAt: { allowNull: false, type: Sequelize.DATE },
    });

    await queryInterface.addIndex('RevokedTokens', ['jti'], { name: 'revoked_tokens_jti', unique: true });
    await queryInterface.addIndex('RevokedTokens', ['tokenHash'], { name: 'revoked_tokens_token_hash', unique: true });
    await queryInterface.addIndex('RevokedTokens', ['expiresAt'], { name: 'revoked_tokens_expires_at' });
  },

  async down(queryInterface) {
    await queryInterface.dropTable('RevokedTokens');
  },
};
