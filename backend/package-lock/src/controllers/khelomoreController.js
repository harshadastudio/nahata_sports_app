'use strict';

/**
 * Khelomore Adapter controller — maps the 5 Khelomore endpoints to the adapter
 * service and wraps every response in Khelomore's envelope: { status, data } on
 * success, { status:false, message } on error.
 */

const adapter = require('../services/khelomoreAdapterService');
const sessionStore = require('../services/khelomoreSessionStore');

const ok = (res, data, code = 200) => res.status(code).json({ status: true, data });
const fail = (res, status, message) => res.status(status).json({ status: false, message });

/** POST /api/login */
exports.login = async (req, res) => {
  try {
    const { email, password } = req.body || {};
    const data = await adapter.login(email, password);
    return ok(res, data);
  } catch (err) {
    const status = err.status || (/invalid email or password/i.test(err.message) ? 401 : 500);
    return fail(res, status, err.message);
  }
};

/** POST /api/save-booking */
exports.saveBooking = async (req, res) => {
  try {
    // req.partnerSource is set by the API-key guard from the key the caller sent.
    const data = await adapter.saveBooking(req.body || {}, req.partnerSource);
    return ok(res, data, 201);
  } catch (err) {
    const status = err.status || (/already booked/i.test(err.message) ? 409 : 500);
    return fail(res, status, err.message);
  }
};

/** GET /api/booking-summary */
exports.bookingSummary = async (req, res) => {
  try {
    const session = sessionStore.resolve(req);
    if (!session) return fail(res, 404, 'No active booking session (expired or unknown)');
    const data = await adapter.bookingSummary(session);
    return ok(res, data);
  } catch (err) {
    return fail(res, err.status || 500, err.message);
  }
};

/** POST /api/finalize-booking */
exports.finalizeBooking = async (req, res) => {
  try {
    const session = sessionStore.resolve(req);
    if (!session) return fail(res, 404, 'No active booking session (expired or unknown)');
    const data = await adapter.finalizeBooking(session, req.body || {});
    return ok(res, data);
  } catch (err) {
    return fail(res, err.status || 500, err.message);
  }
};

/** POST /api/block-slot — take a slot off sale (no booking, no pass, no revenue) */
exports.blockSlot = async (req, res) => {
  try {
    const data = await adapter.blockSlot(req.body || {}, req.partnerSource);
    return ok(res, data, 201);
  } catch (err) {
    return fail(res, err.status || 500, err.message);
  }
};

/** POST /api/unblock-slot — release a block placed by this partner */
exports.unblockSlot = async (req, res) => {
  try {
    const data = await adapter.unblockSlot(req.body || {}, req.partnerSource);
    return ok(res, data);
  } catch (err) {
    return fail(res, err.status || 500, err.message);
  }
};

/** GET /fetchslots?date=YYYY-MM-DD */
exports.fetchSlots = async (req, res) => {
  try {
    const data = await adapter.fetchSlots(req.query.date);
    return ok(res, data);
  } catch (err) {
    return fail(res, err.status || 500, err.message);
  }
};
