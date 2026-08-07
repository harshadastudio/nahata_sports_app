'use strict';

/**
 * Partner (aggregator) registry — the single source of truth for "which platform
 * made this booking".
 *
 * KheloMore, Huddle, and any future platform all resell the SAME endpoints, so a
 * booking's source can never be hardcoded. A caller is identified by whichever
 * credential the surface it hit authenticates with, and both resolve to the same
 * partner entry so one platform always carries one consistent label:
 *
 *   /api/khelomore/*   (JWT Bearer)  → the service account they logged in as → `email`
 *   /api/save-booking  (API key)     → the X-Khelomore-Key they sent         → `apiKey`
 *
 * ONBOARDING A NEW PLATFORM — no code change. Append it to PARTNERS_JSON and
 * restart; Bookings.bookingSource is VARCHAR, so no migration either:
 *
 *   PARTNERS_JSON=[{"source":"Playo","email":"playo@nahatasports.com","apiKey":"…"}]
 *
 * `source` is stored verbatim in Bookings.bookingSource and is what the admin
 * panel's Source column renders, so keep it short and display-ready.
 */

/** Stamped when a caller is authenticated but matches no partner entry. */
const DEFAULT_PARTNER_SOURCE = 'KheloMore';

/** Longest label Bookings.bookingSource can store. */
const MAX_SOURCE_LENGTH = 50;

/** Extra partners supplied as JSON, so new platforms need no code change. */
function parseExtraPartners() {
  const raw = process.env.PARTNERS_JSON;
  if (!raw || !raw.trim()) return [];
  try {
    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) throw new Error('expected a JSON array');
    return parsed;
  } catch (err) {
    // Never crash the server over config, but make the mistake impossible to miss:
    // an ignored entry means that partner's bookings get mislabelled.
    console.error(`❌ PARTNERS_JSON is invalid and was IGNORED (${err.message}). Partners from it will not be recognised.`);
    return [];
  }
}

function buildPartners() {
  const builtIn = [
    {
      source: 'KheloMore',
      email: process.env.KHELOMORE_PARTNER_EMAIL || 'khelomore@nahatasports.com',
      // Legacy shared key. Huddle is live on this today, so it keeps resolving to
      // KheloMore until Huddle switches to HUDDLE_API_KEY — nothing breaks mid-migration.
      apiKey: process.env.KHELOMORE_API_KEY,
    },
    {
      source: 'Huddle',
      email: process.env.HUDDLE_PARTNER_EMAIL || 'huddle@nahatasports.com',
      apiKey: process.env.HUDDLE_API_KEY,
    },
  ];

  return [...builtIn, ...parseExtraPartners()]
    .map((p) => ({
      source: typeof p.source === 'string' ? p.source.trim() : '',
      email: typeof p.email === 'string' && p.email.trim() ? p.email.trim().toLowerCase() : null,
      apiKey: typeof p.apiKey === 'string' && p.apiKey.trim() ? p.apiKey : null,
    }))
    .filter((p) => {
      if (!p.source) return false;
      if (p.source.length > MAX_SOURCE_LENGTH) {
        console.error(`❌ Partner source "${p.source}" exceeds ${MAX_SOURCE_LENGTH} chars and was IGNORED.`);
        return false;
      }
      return true;
    });
}

let _partners = null;

/** Registry, built once on first use (after dotenv has populated process.env). */
function getPartners() {
  if (!_partners) _partners = buildPartners();
  return _partners;
}

/** Every known partner label, e.g. ['KheloMore', 'Huddle']. */
function getPartnerSources() {
  return [...new Set(getPartners().map((p) => p.source))];
}

/** True when `source` is a registered partner (case-insensitive). */
function isPartnerSource(source) {
  if (typeof source !== 'string') return false;
  const needle = source.trim().toLowerCase();
  return getPartners().some((p) => p.source.toLowerCase() === needle);
}

/**
 * Source label for a JWT-authenticated caller (req.user).
 * Falls back to DEFAULT_PARTNER_SOURCE, matching the pre-registry behaviour.
 */
function resolvePartnerSource(user) {
  const email = user && typeof user.email === 'string' ? user.email.trim().toLowerCase() : null;
  const match = email ? getPartners().find((p) => p.email === email) : null;
  return match ? match.source : DEFAULT_PARTNER_SOURCE;
}

/** Source label for an adapter API key, or null when the key matches no partner. */
function resolveSourceByApiKey(apiKey) {
  if (typeof apiKey !== 'string' || !apiKey) return null;
  const match = getPartners().find((p) => p.apiKey && p.apiKey === apiKey);
  return match ? match.source : null;
}

/** Service-account email for a partner, or null if it has none configured. */
function getPartnerEmail(source) {
  if (typeof source !== 'string') return null;
  const needle = source.trim().toLowerCase();
  const match = getPartners().find((p) => p.source.toLowerCase() === needle);
  return match ? match.email : null;
}

/** True once at least one partner has an API key — the adapter fails closed otherwise. */
function hasAnyApiKey() {
  return getPartners().some((p) => p.apiKey);
}

/** Test seam: drop the cached registry so env changes are picked up. */
function _resetCache() {
  _partners = null;
}

module.exports = {
  DEFAULT_PARTNER_SOURCE,
  MAX_SOURCE_LENGTH,
  getPartners,
  getPartnerSources,
  isPartnerSource,
  resolvePartnerSource,
  resolveSourceByApiKey,
  getPartnerEmail,
  hasAnyApiKey,
  _resetCache,
};
