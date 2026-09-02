import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../utils/app_logger.dart';

/// Encrypted store for the JWT access/refresh pair.
///
/// Tokens live in Keychain (iOS) / EncryptedSharedPreferences (Android) — never
/// in plain [SharedPreferences]. Tokens written by older builds under the
/// `authToken` / `refreshToken` preference keys are migrated on first access
/// and then deleted from plain storage.
class TokenStorage {
  TokenStorage._();

  static final TokenStorage instance = TokenStorage._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage(
    // aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  // In-memory mirror so the request path does not hit platform channels on
  // every single call.
  String? _accessToken;
  String? _refreshToken;
  bool _loaded = false;
  Future<void>? _loading;

  Future<void> _ensureLoaded() {
    if (_loaded) return Future<void>.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      _accessToken = await _storage.read(key: StorageKeys.accessToken);
      _refreshToken = await _storage.read(key: StorageKeys.refreshToken);
      await _migrateLegacyTokens();
    } catch (e, s) {
      // A corrupt keystore must not brick the app — treat as logged out.
      AppLogger.error(
        'TokenStorage load failed',
        name: 'Auth',
        error: e,
        stackTrace: s,
      );
      _accessToken = null;
      _refreshToken = null;
    } finally {
      _loaded = true;
      _loading = null;
    }
  }

  /// Moves tokens persisted by pre-JWT builds into secure storage.
  Future<void> _migrateLegacyTokens() async {
    final prefs = await SharedPreferences.getInstance();
    final legacyAccess = prefs.getString(StorageKeys.legacyAuthToken);
    final legacyRefresh = prefs.getString(StorageKeys.legacyRefreshToken);

    if (legacyAccess == null && legacyRefresh == null) return;

    if (_accessToken == null &&
        legacyAccess != null &&
        legacyAccess.isNotEmpty) {
      _accessToken = legacyAccess;
      await _storage.write(key: StorageKeys.accessToken, value: legacyAccess);
    }
    if (_refreshToken == null &&
        legacyRefresh != null &&
        legacyRefresh.isNotEmpty) {
      _refreshToken = legacyRefresh;
      await _storage.write(key: StorageKeys.refreshToken, value: legacyRefresh);
    }

    await prefs.remove(StorageKeys.legacyAuthToken);
    await prefs.remove(StorageKeys.legacyRefreshToken);
    AppLogger.debug('Migrated legacy tokens into secure storage', name: 'Auth');
  }

  Future<String?> get accessToken async {
    await _ensureLoaded();
    return _accessToken;
  }

  Future<String?> get refreshToken async {
    await _ensureLoaded();
    return _refreshToken;
  }

  /// Synchronous view of the cached access token. Only valid once any async
  /// accessor has run at least once; used purely for cheap guard checks.
  String? get cachedAccessToken => _accessToken;

  Future<bool> get hasSession async {
    await _ensureLoaded();
    return (_accessToken?.isNotEmpty ?? false) ||
        (_refreshToken?.isNotEmpty ?? false);
  }

  Future<void> saveTokens({
    required String? accessToken,
    required String? refreshToken,
  }) async {
    await _ensureLoaded();

    if (accessToken != null && accessToken.isNotEmpty) {
      _accessToken = accessToken;
      await _storage.write(key: StorageKeys.accessToken, value: accessToken);
    }
    // The refresh endpoint may rotate only the access token; keep the existing
    // refresh token in that case rather than wiping it.
    if (refreshToken != null && refreshToken.isNotEmpty) {
      _refreshToken = refreshToken;
      await _storage.write(key: StorageKeys.refreshToken, value: refreshToken);
    }
  }

  Future<void> clear() async {
    _accessToken = null;
    _refreshToken = null;
    _loaded = true;
    try {
      await _storage.delete(key: StorageKeys.accessToken);
      await _storage.delete(key: StorageKeys.refreshToken);
    } catch (e) {
      AppLogger.error('TokenStorage clear failed', name: 'Auth', error: e);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.legacyAuthToken);
    await prefs.remove(StorageKeys.legacyRefreshToken);
  }

  /// Decodes the `exp` claim without verifying the signature. Returns `true`
  /// when the token is absent, unparseable, or past its expiry (with a small
  /// leeway so we refresh just before the server rejects it).
  bool isExpired(
    String? token, {
    Duration leeway = const Duration(seconds: 30),
  }) {
    if (token == null || token.isEmpty) return true;
    final exp = expiryOf(token);
    if (exp == null) return false; // Opaque token — let the server decide.
    return DateTime.now().add(leeway).isAfter(exp);
  }

  DateTime? expiryOf(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      payload = payload.padRight((payload.length + 3) ~/ 4 * 4, '=');
      final decoded = String.fromCharCodes(
        Uri.parse(
          'data:application/json;base64,$payload',
        ).data!.contentAsBytes(),
      );
      final expMatch = RegExp(r'"exp"\s*:\s*(\d+)').firstMatch(decoded);
      if (expMatch == null) return null;
      final seconds = int.parse(expMatch.group(1)!);
      return DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
    } catch (_) {
      return null;
    }
  }
}
