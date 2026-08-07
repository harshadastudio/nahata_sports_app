/**
 * Phone Number Validation Utility
 * Enforces strict 10-digit phone number validation across the entire system
 * 
 * Rules:
 * - Must be exactly 10 digits
 * - No special characters, spaces, or dashes
 * - Must start with 6, 7, 8, or 9 (Indian mobile format)
 */


/**
 * Validate if phone number is exactly 10 digits and starts with 6-9
 * @param {string} phoneNumber - The phone number to validate
 * @returns {boolean} - True if valid, false otherwise
 */
const isValidPhoneNumber = (phoneNumber) => {
  if (!phoneNumber) return false;
  
  // Remove any spaces, dashes, or special characters
  const cleaned = phoneNumber.toString().replace(/\D/g, '');
  
  // Check if exactly 10 digits and starts with 6, 7, 8, or 9
  return /^[6-9][0-9]{9}$/.test(cleaned);
};

/**
 * Clean phone number by removing non-digit characters
 * @param {string} phoneNumber - The phone number to clean
 * @returns {string} - Cleaned phone number with only digits
 */
const cleanPhoneNumber = (phoneNumber) => {
  if (!phoneNumber) return '';
  return phoneNumber.toString().replace(/\D/g, '');
};

/**
 * Format phone number for display (e.g., 9876543210 -> 987-654-3210)
 * @param {string} phoneNumber - The phone number to format
 * @returns {string} - Formatted phone number
 */
const formatPhoneNumber = (phoneNumber) => {
  const cleaned = cleanPhoneNumber(phoneNumber);
  if (cleaned.length !== 10) return phoneNumber;
  
  return `${cleaned.slice(0, 3)}-${cleaned.slice(3, 6)}-${cleaned.slice(6)}`;
};

/**
 * Validate and throw error if phone number is invalid
 * @param {string} phoneNumber - The phone number to validate
 * @param {string} fieldName - Name of the field for error message
 * @throws {Error} - If phone number is invalid
 * @returns {string} - Cleaned phone number if valid
 */
const validatePhoneNumberOrThrow = (phoneNumber, fieldName = 'Phone number') => {
  if (!phoneNumber) {
    throw new Error(`${fieldName} is required`);
  }
  
  const cleaned = cleanPhoneNumber(phoneNumber);
  
  if (cleaned.length !== 10) {
    throw new Error(`${fieldName} must be exactly 10 digits. Received ${cleaned.length} digits.`);
  }
  
  if (!/^[6-9]/.test(cleaned)) {
    throw new Error(`${fieldName} must start with 6, 7, 8, or 9`);
  }
  
  return cleaned;
};

/**
 * Middleware to validate phone number in request body
 * @param {string} fieldName - Name of the field to validate (default: 'phone_number')
 * @returns {Function} - Express middleware function
 */
const validatePhoneMiddleware = (fieldName = 'phone_number') => {
  return (req, res, next) => {
    const phoneNumber = req.body[fieldName];
    
    if (!phoneNumber) {
      return res.status(400).json({
        success: false,
        message: `${fieldName} is required`
      });
    }
    
    try {
      const cleaned = validatePhoneNumberOrThrow(phoneNumber, fieldName);
      req.body[fieldName] = cleaned; // Store cleaned version
      next();
    } catch (error) {
      return res.status(400).json({
        success: false,
        message: error.message
      });
    }
  };
};

// ─────────────────────────────────────────────────────────────────────────────
// E.164 normalization (added for WhatsApp / cross-system messaging)
//
// The existing helpers above enforce a bare 10-digit Indian mobile and are kept
// UNCHANGED for backward compatibility. WhatsApp and any partner messaging need a
// canonical E.164 number (e.g. "+919876543210"). These new helpers convert to and
// validate E.164 for Indian mobiles WITHOUT altering the legacy behaviour.
// ─────────────────────────────────────────────────────────────────────────────

const DEFAULT_COUNTRY_CODE = '91'; // India

/**
 * Normalize an Indian mobile number to E.164 ("+91XXXXXXXXXX").
 * Accepts inputs like: "9876543210", "09876543210", "+91 98765 43210",
 * "91-9876543210", "0091 9876543210".
 *
 * @param {string|number} input
 * @param {string} defaultCc - default country code digits (no '+'), defaults to '91'
 * @returns {string|null} E.164 string, or null if it cannot be normalized to a
 *                        valid Indian mobile.
 */
const toE164 = (input, defaultCc = DEFAULT_COUNTRY_CODE) => {
  if (input == null) return null;

  let digits = String(input).trim().replace(/\D/g, '');
  if (!digits) return null;

  // Strip international dialing prefix "00" (e.g. 0091...) → treat as country code.
  if (digits.startsWith('00')) digits = digits.slice(2);

  // Case: already carries the 91 country code (12 digits total: 91 + 10).
  if (digits.length === 12 && digits.startsWith(defaultCc)) {
    const local = digits.slice(defaultCc.length);
    return isValidIndianLocal(local) ? `+${defaultCc}${local}` : null;
  }

  // Case: 11 digits with a leading trunk '0' (e.g. 09876543210).
  if (digits.length === 11 && digits.startsWith('0')) {
    const local = digits.slice(1);
    return isValidIndianLocal(local) ? `+${defaultCc}${local}` : null;
  }

  // Case: bare 10-digit local number.
  if (digits.length === 10) {
    return isValidIndianLocal(digits) ? `+${defaultCc}${digits}` : null;
  }

  return null;
};

/** True when `local` is a valid 10-digit Indian mobile (starts 6-9). */
const isValidIndianLocal = (local) => /^[6-9][0-9]{9}$/.test(local);

/**
 * Validate that a string is a well-formed Indian E.164 mobile ("+91XXXXXXXXXX").
 * @param {string} value
 * @returns {boolean}
 */
const isValidE164 = (value) => {
  if (!value) return false;
  const m = /^\+(\d{1,3})(\d{6,14})$/.exec(String(value).trim());
  if (!m) return false;
  const [, cc, rest] = m;
  if (cc === DEFAULT_COUNTRY_CODE) return isValidIndianLocal(rest);
  // Non-Indian numbers: accept generic E.164 shape (total length 8–15 digits).
  const totalDigits = cc.length + rest.length;
  return totalDigits >= 8 && totalDigits <= 15;
};

/**
 * Normalize to E.164 or throw — for use in write paths that must persist a
 * canonical number (e.g. WhatsApp enqueue, booking members).
 * @param {string|number} input
 * @param {string} fieldName
 * @returns {string} E.164 string
 */
const toE164OrThrow = (input, fieldName = 'Phone number') => {
  const e164 = toE164(input);
  if (!e164) {
    throw new Error(`${fieldName} is not a valid Indian mobile number.`);
  }
  return e164;
};

module.exports = {
  isValidPhoneNumber,
  cleanPhoneNumber,
  formatPhoneNumber,
  validatePhoneNumberOrThrow,
  validatePhoneMiddleware,
  // E.164 helpers (new, additive)
  toE164,
  toE164OrThrow,
  isValidE164,
  isValidIndianLocal,
};
