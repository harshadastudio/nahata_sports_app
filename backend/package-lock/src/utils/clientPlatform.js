'use strict';

/**
 * Which client is this request coming from — the website or the mobile app?
 *
 * One backend serves the website, the Android app and the iOS app, so anything
 * that must behave differently per client (today: platform-restricted coupons)
 * needs a single, trustworthy answer to that question.
 *
 * Resolution order — first match wins:
 *
 *   1. An explicit header. This is the contract for the apps:
 *          X-Client-Platform: android | ios | app        → 'App'
 *          X-Client-Platform: web | browser | website    → 'Web'
 *      (`X-Platform` and `X-App-Platform` are accepted as aliases.)
 *   2. An explicit `platform` field in the body / query, for clients that
 *      cannot easily set headers.
 *   3. The User-Agent of a native HTTP stack (okhttp, CFNetwork, Dart/Flutter,
 *      Expo, React Native, Alamofire…) → 'App'. This makes the split work even
 *      if an app build forgets the header.
 *   4. A browser Origin header → 'Web'. Native apps do not send one.
 *   5. A mobile UA with no Origin (native WebView shell) → 'App'.
 *   6. Default → 'Web'.
 *
 * Defaulting to 'Web' is deliberate: the website needs no changes to keep
 * working, and a mis-detected request simply falls back to the widest audience.
 */

const APP_TOKENS = ['android', 'ios', 'app', 'mobile', 'flutter', 'reactnative', 'react-native', 'expo', 'capacitor', 'cordova', 'ionic'];
const WEB_TOKENS = ['web', 'website', 'browser', 'desktop', 'pwa'];

/** Native HTTP clients — a browser never sends these. */
const NATIVE_UA_MARKERS = [
  'okhttp',        // Android (Retrofit / OkHttp)
  'cfnetwork',     // iOS / macOS URLSession
  'darwin',        // iOS URLSession
  'alamofire',     // iOS Swift
  'dart',          // Flutter
  'flutter',
  'react-native',
  'reactnative',
  'expo',
  'capacitor',
  'cordova',
  'ionic',
  'nahatasports',  // custom app UA, e.g. "NahataSportsApp/1.4 (Android 14)"
  'ktor',
  'retrofit',
];

const normalize = (value) => String(value ?? '').trim().toLowerCase();

/** Map a free-form platform string onto 'Web' | 'App', or null when unknown. */
function platformFromToken(raw) {
  const value = normalize(raw);
  if (!value) return null;
  if (APP_TOKENS.includes(value)) return 'App';
  if (WEB_TOKENS.includes(value)) return 'Web';
  return null;
}

/**
 * Resolve the calling client.
 * @param {import('express').Request} req
 * @returns {'Web' | 'App'}
 */
function resolveClientPlatform(req) {
  if (!req) return 'Web';

  const headers = req.headers || {};

  // 1 — explicit header
  const headerValue =
    headers['x-client-platform'] || headers['x-platform'] || headers['x-app-platform'];
  const fromHeader = platformFromToken(headerValue);
  if (fromHeader) return fromHeader;

  // 2 — explicit body / query field
  const fromPayload =
    platformFromToken(req.body && req.body.platform) ||
    platformFromToken(req.query && req.query.platform);
  if (fromPayload) return fromPayload;

  // 3 — native HTTP stack in the User-Agent
  const ua = normalize(headers['user-agent']);
  if (ua && NATIVE_UA_MARKERS.some((marker) => ua.includes(marker))) return 'App';

  // 4 — a browser always sends Origin on cross-origin API calls
  if (headers.origin) return 'Web';

  // 5 — mobile UA without an Origin: a native WebView shell
  if (ua && /android|iphone|ipad|ipod|mobile/.test(ua)) return 'App';

  // 6 — default
  return 'Web';
}

/** Human-readable label, for error messages shown to the user. */
function platformLabel(platform) {
  if (platform === 'App') return 'the mobile app';
  if (platform === 'Web') return 'the website';
  return 'any platform';
}

module.exports = { resolveClientPlatform, platformLabel };
