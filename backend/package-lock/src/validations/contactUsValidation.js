'use strict';

/**
 * ContactUs Validation Middleware
 * Validates and sanitizes incoming contact form request bodies.
 * Returns HTTP 422 with structured field-level errors on failure.
 */

// ─── Helpers ────────────────────────────────────────────────────────────────

/**
 * Validates a single email address format using a standard RFC-compliant regex.
 * @param {string} email
 * @returns {boolean}
 */
const isValidEmail = (email) => {
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  return emailRegex.test(email);
};

// ─── Validation Rules ────────────────────────────────────────────────────────

/**
 * Validates the contact form submission body.
 * Trims all string fields before validation.
 */
const validateContactSubmission = (req, res, next) => {
  const errors = [];

  // Trim all string fields in-place before validation
  if (req.body.fullName) req.body.fullName = req.body.fullName.trim();
  if (req.body.email)    req.body.email    = req.body.email.trim();
  if (req.body.subject)  req.body.subject  = req.body.subject.trim();
  if (req.body.message)  req.body.message  = req.body.message.trim();

  const { fullName, email, subject, message } = req.body;

  // fullName: required, non-empty, max 100 chars
  if (!fullName || typeof fullName !== 'string' || fullName.length === 0) {
    errors.push({ field: 'fullName', message: 'Full name is required.' });
  } else if (fullName.length > 100) {
    errors.push({ field: 'fullName', message: 'Full name must not exceed 100 characters.' });
  }

  // email: required, valid format
  if (!email || typeof email !== 'string' || email.length === 0) {
    errors.push({ field: 'email', message: 'Email address is required.' });
  } else if (!isValidEmail(email)) {
    errors.push({ field: 'email', message: 'Please provide a valid email address.' });
  }

  // subject: required, non-empty, max 200 chars
  if (!subject || typeof subject !== 'string' || subject.length === 0) {
    errors.push({ field: 'subject', message: 'Subject is required.' });
  } else if (subject.length > 200) {
    errors.push({ field: 'subject', message: 'Subject must not exceed 200 characters.' });
  }

  // message: required, non-empty, max 5000 chars
  if (!message || typeof message !== 'string' || message.length === 0) {
    errors.push({ field: 'message', message: 'Message is required.' });
  } else if (message.length > 5000) {
    errors.push({ field: 'message', message: 'Message must not exceed 5000 characters.' });
  }

  if (errors.length > 0) {
    return res.status(422).json({
      success: false,
      message: 'Validation failed',
      errors,
    });
  }

  next();
};

/**
 * Validates the status update body for admin PATCH endpoint.
 * Ensures status is one of the allowed enum values.
 */
const validateStatusUpdate = (req, res, next) => {
  const errors = [];
  const VALID_STATUSES = ['new', 'read', 'replied'];

  const { status } = req.body;

  if (!status || typeof status !== 'string' || status.trim().length === 0) {
    errors.push({ field: 'status', message: 'Status is required.' });
  } else if (!VALID_STATUSES.includes(status.trim())) {
    errors.push({
      field: 'status',
      message: `Status must be one of: ${VALID_STATUSES.join(', ')}.`,
    });
  } else {
    // Normalize in-place
    req.body.status = status.trim();
  }

  if (errors.length > 0) {
    return res.status(422).json({
      success: false,
      message: 'Validation failed',
      errors,
    });
  }

  next();
};

/**
 * Validates the contact information update body for admin PUT endpoint.
 */
const validateContactInfo = (req, res, next) => {
  const errors = [];

  // Trim all string fields in-place before validation
  if (req.body.address) req.body.address = req.body.address.trim();
  if (req.body.phone) req.body.phone = req.body.phone.trim();
  if (req.body.email) req.body.email = req.body.email.trim();
  if (req.body.hours) req.body.hours = req.body.hours.trim();
  if (req.body.mapEmbedUrl) req.body.mapEmbedUrl = req.body.mapEmbedUrl.trim();

  const { address, phone, email, hours } = req.body;

  // address: required, non-empty
  if (!address || typeof address !== 'string' || address.length === 0) {
    errors.push({ field: 'address', message: 'Address is required.' });
  } else if (address.length > 500) {
    errors.push({ field: 'address', message: 'Address must not exceed 500 characters.' });
  }

  // phone: required, non-empty
  if (!phone || typeof phone !== 'string' || phone.length === 0) {
    errors.push({ field: 'phone', message: 'Phone number is required.' });
  } else if (phone.length > 50) {
    errors.push({ field: 'phone', message: 'Phone number must not exceed 50 characters.' });
  }

  // email: required, valid format
  if (!email || typeof email !== 'string' || email.length === 0) {
    errors.push({ field: 'email', message: 'Email address is required.' });
  } else if (!isValidEmail(email)) {
    errors.push({ field: 'email', message: 'Please provide a valid email address.' });
  }

  // hours: required, non-empty
  if (!hours || typeof hours !== 'string' || hours.length === 0) {
    errors.push({ field: 'hours', message: 'Hours are required.' });
  } else if (hours.length > 200) {
    errors.push({ field: 'hours', message: 'Hours must not exceed 200 characters.' });
  }

  if (errors.length > 0) {
    return res.status(422).json({
      success: false,
      message: 'Validation failed',
      errors,
    });
  }

  next();
};

module.exports = {
  validateContactSubmission,
  validateStatusUpdate,
  validateContactInfo,
};
