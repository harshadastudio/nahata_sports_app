'use strict';

/**
 * Structured JSON logger — zero external dependencies.
 *
 * Why not winston/pino? The project currently has 500+ raw `console.*` calls and
 * no logging dependency. Adding a heavy logger + transport config is out of scope
 * and risky; this gives us structured, redacted, level-based logging with no new
 * dependency, and can be swapped for pino later behind the same interface.
 *
 * Design goals:
 *   - One JSON object per line (machine-parseable; ready for Loki/Datadog/CloudWatch).
 *   - Never leak secrets. Every logged object is deep-redacted (see SENSITIVE_KEYS).
 *   - Levels with an env-configurable threshold (LOG_LEVEL).
 *   - child() loggers carry contextual fields (e.g. { module: 'payment' }).
 *
 * Usage:
 *   const logger = require('../utils/logger');
 *   logger.info('payment.verified', { bookingId, amount });
 *   const log = logger.child({ module: 'whatsapp-worker' });
 *   log.error('send.failed', { err });
 */

const LEVELS = { debug: 10, info: 20, warn: 30, error: 40 };
const THRESHOLD = LEVELS[(process.env.LOG_LEVEL || 'info').toLowerCase()] || LEVELS.info;

// Any object key whose lowercased, non-alphanumeric-stripped form matches one of
// these is replaced with '[REDACTED]'. Guards against passwords / JWTs / secrets /
// OTPs / signatures ever reaching the logs, per the security requirement.
const SENSITIVE_KEYS = new Set([
  'password', 'newpassword', 'oldpassword', 'currentpassword', 'confirmpassword',
  'staffpassword', 'staffpasswordenc', 'passwordhash',
  'token', 'accesstoken', 'refreshtoken', 'idtoken', 'jwt', 'authorization',
  'cookie', 'setcookie', 'secret', 'clientsecret', 'jwtaccesssecret', 'jwtrefreshsecret',
  'apikey', 'apisecret', 'keysecret', 'razorpaykeysecret', 'razorpaysignature',
  'whatsappapikey', 'emailapikey', 'emailpass', 'cloudinaryapisecret',
  'otp', 'resetotp', 'otpexpiry', 'emailverificationtoken', 'passcode', 'staffsecretkey',
  'webhooksecret', 'whatsappwebhooksecret',
]);

const MAX_DEPTH = 6;

function normalizeKey(key) {
  return String(key).toLowerCase().replace(/[^a-z0-9]/g, '');
}

function redact(value, depth = 0, seen = new WeakSet()) {
  if (value == null) return value;

  if (value instanceof Error) {
    return { name: value.name, message: value.message, stack: value.stack };
  }

  if (typeof value !== 'object') {
    // Redact anything that *looks* like a JWT even if it arrives as a bare string.
    if (typeof value === 'string' && /^ey[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+$/.test(value)) {
      return '[REDACTED_JWT]';
    }
    return value;
  }

  if (depth >= MAX_DEPTH) return '[Object]';
  if (seen.has(value)) return '[Circular]';
  seen.add(value);

  if (Array.isArray(value)) {
    return value.slice(0, 50).map((v) => redact(v, depth + 1, seen));
  }

  const out = {};
  for (const [k, v] of Object.entries(value)) {
    if (SENSITIVE_KEYS.has(normalizeKey(k))) {
      out[k] = '[REDACTED]';
    } else {
      out[k] = redact(v, depth + 1, seen);
    }
  }
  return out;
}

function emit(level, context, event, meta) {
  if (LEVELS[level] < THRESHOLD) return;

  const record = {
    ts: new Date().toISOString(),
    level,
    event: typeof event === 'string' ? event : String(event),
    ...context,
    ...(meta && typeof meta === 'object' ? redact(meta) : meta != null ? { detail: meta } : {}),
  };

  const line = safeStringify(record);
  if (level === 'error') process.stderr.write(line + '\n');
  else process.stdout.write(line + '\n');
}

function safeStringify(obj) {
  try {
    return JSON.stringify(obj);
  } catch (_e) {
    return JSON.stringify({ ts: new Date().toISOString(), level: 'error', event: 'logger.stringify_failed' });
  }
}

function createLogger(context = {}) {
  return {
    debug: (event, meta) => emit('debug', context, event, meta),
    info: (event, meta) => emit('info', context, event, meta),
    warn: (event, meta) => emit('warn', context, event, meta),
    error: (event, meta) => emit('error', context, event, meta),
    child: (extra = {}) => createLogger({ ...context, ...extra }),
  };
}

module.exports = createLogger();
module.exports.createLogger = createLogger;
module.exports.redact = redact;
