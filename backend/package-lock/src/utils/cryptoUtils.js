const crypto = require('crypto');

const generateSecureToken = () => {
  return crypto.randomBytes(32).toString('hex');
};

const hashToken = (token) => {
  return crypto.createHash('sha256').update(token).digest('hex');
};

const verifyHashedToken = (token, hashedToken) => {
  const tokenHash = hashToken(token);
  return tokenHash === hashedToken;
};

const calculateTokenExpiry = (minutes = 15) => {
  const now = new Date();
  return new Date(now.getTime() + minutes * 60 * 1000);
};

const isTokenExpired = (expiryDate) => {
  return new Date() > expiryDate;
};

module.exports = {
  generateSecureToken,
  hashToken,
  verifyHashedToken,
  calculateTokenExpiry,
  isTokenExpired
};
