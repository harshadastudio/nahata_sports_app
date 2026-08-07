'use strict';

const { Model } = require('sequelize');

/**
 * RevokedToken — a denylist enabling immediate invalidation of individual JWTs
 * WITHOUT lowering the (deliberately long) token expiry that Huddle / KheloMore
 * integrations depend on.
 *
 * Two lookup keys, so BOTH new and legacy tokens can be revoked:
 *   - jti:       the unique id embedded in tokens we now issue (fast, indexed).
 *   - tokenHash: sha256 of the raw token, for legacy/partner tokens that predate
 *                jti. Lets us revoke a leaked partner token by value.
 *
 * `expiresAt` mirrors the token's own exp so a scheduled cleanup can prune rows
 * once the underlying token would have expired anyway.
 */
module.exports = (sequelize, DataTypes) => {
  class RevokedToken extends Model {}

  RevokedToken.init(
    {
      id: { type: DataTypes.INTEGER, autoIncrement: true, primaryKey: true },
      jti: { type: DataTypes.STRING(64), allowNull: true, unique: true },
      tokenHash: { type: DataTypes.STRING(64), allowNull: true, unique: true },
      userId: { type: DataTypes.INTEGER, allowNull: true },
      reason: { type: DataTypes.STRING(255), allowNull: true },
      // The token's own expiry; NULL for immortal tokens (kept forever).
      expiresAt: { type: DataTypes.DATE, allowNull: true },
      createdAt: { allowNull: false, type: DataTypes.DATE },
      updatedAt: { allowNull: false, type: DataTypes.DATE },
    },
    {
      sequelize,
      modelName: 'RevokedToken',
      tableName: 'RevokedTokens',
    }
  );

  return RevokedToken;
};
