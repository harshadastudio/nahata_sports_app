/**
 * Email Validation Utility
 * Validates email format and catches common provider-domain typos.
 *
 * Why this exists:
 * A syntactically valid address like "user@gamil.com" passes a normal format
 * check but bounces ("511 no mailbox"), and the bounce returns to the SENDER
 * account — so the user never gets their welcome/booking/enquiry email and it
 * looks like "email is not sending". Rejecting obvious domain typos up front
 * (with a "did you mean gmail.com?" hint) stops bad addresses at registration.
 */

// RFC-5322-lite: good enough to reject malformed input without false negatives.
const EMAIL_REGEX = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/**
 * Map of common misspelled email domains -> the correct domain.
 * Keep this list focused on the high-traffic providers; it only needs to catch
 * fat-finger typos, not every possible domain.
 */
const DOMAIN_TYPOS = {
  // gmail.com
  'gamil.com': 'gmail.com',
  'gmial.com': 'gmail.com',
  'gmai.com': 'gmail.com',
  'gmail.co': 'gmail.com',
  'gmail.con': 'gmail.com',
  'gmail.cm': 'gmail.com',
  'gmaill.com': 'gmail.com',
  'gnail.com': 'gmail.com',
  'gmail.comm': 'gmail.com',
  'gmail.om': 'gmail.com',
  ' gmail.com': 'gmail.com',
  // yahoo.com
  'yaho.com': 'yahoo.com',
  'yahoo.co': 'yahoo.com',
  'yahooo.com': 'yahoo.com',
  'yhaoo.com': 'yahoo.com',
  'yahoo.con': 'yahoo.com',
  // hotmail.com
  'hotmial.com': 'hotmail.com',
  'hotmai.com': 'hotmail.com',
  'hotmail.co': 'hotmail.com',
  'hotmail.con': 'hotmail.com',
  'hotmil.com': 'hotmail.com',
  // outlook.com
  'outlok.com': 'outlook.com',
  'outloo.com': 'outlook.com',
  'outlook.co': 'outlook.com',
  'outlook.con': 'outlook.com',
  // icloud.com
  'iclod.com': 'icloud.com',
  'icloud.co': 'icloud.com',
};

/**
 * Normalize an email: trim and lowercase.
 * @param {string} email
 * @returns {string}
 */
const normalizeEmail = (email) => {
  if (!email) return '';
  return email.toString().trim().toLowerCase();
};

/**
 * Check if email has a valid format.
 * @param {string} email
 * @returns {boolean}
 */
const isValidEmailFormat = (email) => {
  const normalized = normalizeEmail(email);
  return EMAIL_REGEX.test(normalized);
};

/**
 * Return the suggested correct domain if the email's domain looks like a typo,
 * otherwise null.
 * @param {string} email
 * @returns {string|null} suggested full email (e.g. "user@gmail.com") or null
 */
const suggestEmailCorrection = (email) => {
  const normalized = normalizeEmail(email);
  const atIndex = normalized.lastIndexOf('@');
  if (atIndex === -1) return null;

  const localPart = normalized.slice(0, atIndex);
  const domain = normalized.slice(atIndex + 1);
  const correctedDomain = DOMAIN_TYPOS[domain];

  return correctedDomain ? `${localPart}@${correctedDomain}` : null;
};

/**
 * Validate an email and throw a helpful error if it is invalid or a likely typo.
 * Returns the normalized (trimmed + lowercased) email when valid.
 * @param {string} email
 * @param {string} fieldName
 * @throws {Error}
 * @returns {string} normalized email
 */
const validateEmailOrThrow = (email, fieldName = 'Email') => {
  if (!email) {
    throw new Error(`${fieldName} is required`);
  }

  const normalized = normalizeEmail(email);

  if (!EMAIL_REGEX.test(normalized)) {
    throw new Error(`Please enter a valid ${fieldName.toLowerCase()} address`);
  }

  const suggestion = suggestEmailCorrection(normalized);
  if (suggestion) {
    throw new Error(`Did you mean "${suggestion}"? Please check your email address`);
  }

  return normalized;
};

module.exports = {
  isValidEmailFormat,
  normalizeEmail,
  suggestEmailCorrection,
  validateEmailOrThrow,
};
