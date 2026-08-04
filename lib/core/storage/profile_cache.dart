import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/profile_model.dart';
import '../config/api_config.dart';
import '../utils/app_logger.dart';

/// Local cache for the signed-in user's profile.
///
/// Two representations are written on every save:
///
/// * [StorageKeys.profileCache] — the canonical [ProfileModel] JSON,
/// * [StorageKeys.user] / [StorageKeys.role] — the raw map shape that the
///   existing screens (`AuthService.getUser()`, `ApiService.currentUser`, …)
///   already read, so nothing downstream has to change.
class ProfileCache {
  ProfileCache._();

  static final ProfileCache instance = ProfileCache._();

  ProfileModel? _memory;

  /// Last profile loaded in this process — no disk hit.
  ProfileModel? get cached => _memory;

  Future<ProfileModel?> read() async {
    if (_memory != null) return _memory;

    final prefs = await SharedPreferences.getInstance();

    final fromCache = ProfileModel.decode(
      prefs.getString(StorageKeys.profileCache),
    );
    if (fromCache != null) {
      _memory = fromCache;
      return fromCache;
    }

    // Fall back to the legacy `user` blob so an app updated in place still
    // shows the previous user immediately.
    final legacy = ProfileModel.decode(prefs.getString(StorageKeys.user));
    if (legacy != null) _memory = legacy;
    return _memory;
  }

  Future<void> save(ProfileModel profile) async {
    _memory = profile;
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(StorageKeys.profileCache, profile.encode());
    await prefs.setString(
      StorageKeys.profileCachedAt,
      DateTime.now().toIso8601String(),
    );

    // Keep the legacy contract intact for screens not yet migrated.
    await prefs.setString(
      StorageKeys.user,
      jsonEncode(profile.toLegacyUserMap()),
    );
    await prefs.setBool(StorageKeys.isLoggedIn, true);

    final role = profile.role;
    if (role != null && role.isNotEmpty) {
      await prefs.setString(StorageKeys.role, role);
    }
    await prefs.setStringList(StorageKeys.permissions, profile.permissions);

    AppLogger.debug('Profile cached (id: ${profile.id})', name: 'Profile');
  }

  Future<DateTime?> lastUpdated() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(StorageKeys.profileCachedAt);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  Future<List<String>> readPermissions() async {
    final memory = _memory;
    if (memory != null) return memory.permissions;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(StorageKeys.permissions) ?? const <String>[];
  }

  Future<void> clear() async {
    _memory = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.profileCache);
    await prefs.remove(StorageKeys.profileCachedAt);
    await prefs.remove(StorageKeys.permissions);
    await prefs.remove(StorageKeys.user);
    await prefs.remove(StorageKeys.role);
    await prefs.setBool(StorageKeys.isLoggedIn, false);
  }
}
