'use strict';

const Razorpay = require('razorpay');
const crypto = require('crypto');

const razorpay = new Razorpay({
  key_id: process.env.RAZORPAY_KEY_ID,
  key_secret: process.env.RAZORPAY_KEY_SECRET,
});

const CURRENCY = process.env.RAZORPAY_CURRENCY || 'INR';
// Razorpay expects amount in smallest currency unit (paise for INR)
const MULTIPLIER = parseInt(process.env.RAZORPAY_AMOUNT_MULTIPLIER || '100', 10);

/**
 * Create a Razorpay order.
 * @param {number} amount  - Amount in rupees (e.g. 500)
 * @param {string} receipt - Unique receipt string (e.g. "BOOKING_42")
 * @param {object} notes   - Optional key-value metadata stored on the order
 * @returns {{ orderId, amount, currency, keyId }}
 */
async function createOrder(amount, receipt, notes = {}) {
  const options = {
    amount: Math.round(amount * MULTIPLIER), // convert to paise
    currency: CURRENCY,
    receipt: receipt.substring(0, 40), // Razorpay receipt max 40 chars
    notes,
  };

  const order = await razorpay.orders.create(options);

  return {
    orderId: order.id,
    amount: order.amount,
    currency: order.currency,
    keyId: process.env.RAZORPAY_KEY_ID,
  };
}

/**
 * Verify Razorpay payment signature.
 * Must be called after the frontend returns payment details.
 * @param {string} razorpayOrderId
 * @param {string} razorpayPaymentId
 * @param {string} razorpaySignature
 * @returns {boolean}
 */
function verifyPayment(razorpayOrderId, razorpayPaymentId, razorpaySignature) {
  const body = `${razorpayOrderId}|${razorpayPaymentId}`;
  const expectedSignature = crypto
    .createHmac('sha256', process.env.RAZORPAY_KEY_SECRET)
    .update(body)
    .digest('hex');

  return safeEqualHex(expectedSignature, razorpaySignature);
}

/**
 * Constant-time hex-string comparison to avoid timing side-channels on the
 * signature check. Falsy/length-mismatched inputs return false without throwing.
 */
function safeEqualHex(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string') return false;
  const bufA = Buffer.from(a, 'utf8');
  const bufB = Buffer.from(b, 'utf8');
  if (bufA.length !== bufB.length) return false;
  return crypto.timingSafeEqual(bufA, bufB);
}

/**
 * Fetch the authoritative payment record from Razorpay. Used at verify-time to
 * confirm the payment is actually captured, belongs to the expected order, and
 * matches the expected amount — defense-in-depth beyond the signature check.
 * @param {string} paymentId
 * @returns {Promise<object>} razorpay payment entity ({ id, order_id, status, amount, ... })
 */
async function fetchPayment(paymentId) {
  return razorpay.payments.fetch(paymentId);
}

/**
 * Verify a Razorpay webhook signature (X-Razorpay-Signature) over the RAW body,
 * using RAZORPAY_WEBHOOK_SECRET. For when the server-to-server payment webhook is
 * wired up (recommended so confirmation no longer depends on the browser).
 * @param {string|Buffer} rawBody
 * @param {string} signature
 * @returns {boolean}
 */
function verifyWebhookSignature(rawBody, signature) {
  const secret = process.env.RAZORPAY_WEBHOOK_SECRET;
  if (!secret) return false;
  const expected = crypto.createHmac('sha256', secret).update(rawBody).digest('hex');
  return safeEqualHex(expected, signature);
}

module.exports = {
  createOrder,
  verifyPayment,
  fetchPayment,
  verifyWebhookSignature,
  MULTIPLIER,
};
