'use strict';

const crypto = require('crypto');

/**
 * Lightweight in-memory session store bridging Khelomore's stateless contract
 * (save-booking → booking-summary → finalize-booking) with our stateful flow.
 *
 * A session is created on save-booking and carries the booking context until it
 * is finalized or expires. Keyed by an opaque token returned to Khelomore; we
 * also index by bookingId so summary/finalize can locate it either way.
 *
 * NOTE: in-memory means sessions are lost on restart and are NOT shared across
 * multiple instances. That matches the design (lightweight bridge); if the API
 * is ever horizontally scaled, swap this for Redis with the same interface.
 */

const TTL_MS = (parseInt(process.env.KHELOMORE_SESSION_TTL_MINUTES || '30', 10)) * 60 * 1000;

const byToken = new Map(); // token -> session
const byBookingId = new Map(); // bookingId -> token

function isExpired(s) {
  return s.expiresAt <= Date.now();
}

function sweep() {
  for (const [token, s] of byToken) {
    if (isExpired(s)) {
      byToken.delete(token);
      if (s.bookingId != null) byBookingId.delete(s.bookingId);
    }
  }
}

/** Create a session; returns { token, ...session }. */
function create(context) {
  sweep();
  const token = crypto.randomBytes(18).toString('hex');
  const session = { token, ...context, createdAt: Date.now(), expiresAt: Date.now() + TTL_MS };
  byToken.set(token, session);
  if (context.bookingId != null) byBookingId.set(context.bookingId, token);
  return session;
}

/** Look up a session by its token. */
function getByToken(token) {
  if (!token) return null;
  const s = byToken.get(token);
  if (!s) return null;
  if (isExpired(s)) { remove(token); return null; }
  return s;
}

/** Look up a session by the booking id it created. */
function getByBookingId(bookingId) {
  if (bookingId == null) return null;
  const token = byBookingId.get(Number(bookingId)) || byBookingId.get(String(bookingId));
  return token ? getByToken(token) : null;
}

/** Resolve from a request: prefer explicit token, then booking_id in query/body. */
function resolve(req) {
  const token = req.get('X-Khelomore-Session') || req.query.session_id || req.body?.session_id;
  const byTok = getByToken(token);
  if (byTok) return byTok;
  const bookingId = req.query.booking_id || req.body?.booking_id;
  return getByBookingId(bookingId);
}

function remove(token) {
  const s = byToken.get(token);
  if (s) {
    byToken.delete(token);
    if (s.bookingId != null) byBookingId.delete(s.bookingId);
  }
}

module.exports = { create, getByToken, getByBookingId, resolve, remove };
