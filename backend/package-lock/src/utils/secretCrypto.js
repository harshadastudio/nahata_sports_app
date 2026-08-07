'use strict';

/**
 * Reversible encryption for sensitive-but-recoverable secrets (currently the
 * admin-set passwords of staff logins, so an admin can view them later).
 *
 * AES-256-GCM. The 32-byte key is derived (scrypt) from `STAFF_SECRET_KEY` in
 * the environment, falling back to JWT_SECRET so the feature still works in dev
 * if a dedicated key was not set.
 *
 * ⚠️  This is NOT for passwords used to authenticate THIS app's own users — those
 * stay one-way bcrypt-hashed. It is only for credentials an admin must be able
 * to read back (e.g. to re-share a staff member's login).
 *
 * Ciphertext format (single base64 string):  iv(12) | authTag(16) | cipher
 */

const crypto = require('crypto');

const ALGO = 'aes-256-gcm';
const IV_LEN = 12;
const TAG_LEN = 16;

let cachedKey = null;

function getKey() {
  if (cachedKey) return cachedKey;
  const secret =
    process.env.STAFF_SECRET_KEY ||
    process.env.JWT_SECRET ||
    'nahata-sports-staff-secret-fallback';
  // Static salt: we need deterministic key derivation across restarts so old
  // ciphertexts stay decryptable. Security rests on the secret, not the salt.
  cachedKey = crypto.scryptSync(secret, 'nahata-staff-cred-salt', 32);
  return cachedKey;
}

/**
 * Encrypt a plaintext secret. Returns a base64 string, or null for empty input.
 * @param {string} plain
 * @returns {string|null}
 */
function encryptSecret(plain) {
  if (plain == null || plain === '') return null;
  const iv = crypto.randomBytes(IV_LEN);
  const cipher = crypto.createCipheriv(ALGO, getKey(), iv);
  const encrypted = Buffer.concat([cipher.update(String(plain), 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return Buffer.concat([iv, tag, encrypted]).toString('base64');
}

/**
 * Decrypt a value produced by encryptSecret. Returns null on empty input or any
 * failure (tampered / wrong key / legacy plaintext), so callers can fall back
 * gracefully rather than crash.
 * @param {string} enc
 * @returns {string|null}
 */
function decryptSecret(enc) {
  if (!enc) return null;
  try {
    const raw = Buffer.from(enc, 'base64');
    const iv = raw.subarray(0, IV_LEN);
    const tag = raw.subarray(IV_LEN, IV_LEN + TAG_LEN);
    const data = raw.subarray(IV_LEN + TAG_LEN);
    const decipher = crypto.createDecipheriv(ALGO, getKey(), iv);
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(data), decipher.final()]).toString('utf8');
  } catch (e) {
    console.warn('⚠️ secretCrypto: failed to decrypt a secret:', e.message);
    return null;
  }
}

module.exports = { encryptSecret, decryptSecret };
