'use strict';

/**
 * API-key guard for the aggregator adapter endpoints.
 *
 * Every partner (KheloMore, Huddle, …) sends its OWN shared secret in the
 * `X-Khelomore-Key` header. The key identifies the caller, so on success this
 * attaches `req.partnerSource` — the label the booking is stamped with. Keys and
 * labels live in config/partnerSources.js; the header name is deliberately
 * unchanged so live integrations keep working.
 *
 * Fails CLOSED: if no partner key is configured at all, every adapter call is
 * rejected (so the endpoints can never be hit with an empty/unset key).
 */

const { resolveSourceByApiKey, hasAnyApiKey } = require('../config/partnerSources');

module.exports = function khelomoreAuth(req, res, next) {
  if (!hasAnyApiKey()) {
    console.error('❌ No partner API key is configured (KHELOMORE_API_KEY / HUDDLE_API_KEY / PARTNERS_JSON) — rejecting adapter request.');
    return res.status(503).json({ status: false, message: 'Aggregator integration is not configured' });
  }

  const provided = req.get('X-Khelomore-Key') || req.get('x-khelomore-key');
  const source = resolveSourceByApiKey(provided);
  if (!source) {
    return res.status(401).json({ status: false, message: 'Unauthorized' });
  }

  // Which platform this call belongs to — consumed by the adapter controller.
  req.partnerSource = source;
  return next();
};
