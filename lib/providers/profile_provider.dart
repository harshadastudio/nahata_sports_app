import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/network/api_exception.dart';
import '../core/services/permission_service.dart';
import '../core/services/session_manager.dart';
import '../core/storage/token_storage.dart';
import '../core/utils/app_logger.dart';
import '../models/profile_model.dart';
import '../repositories/auth_repository.dart';

enum ProfileStatus { initial, loading, ready, error }

/// Single source of truth for the signed-in user's profile.
///
/// Every screen that shows the user's name, avatar, membership, role or e-mail
/// listens to this provider, so one successful `/auth/profile` call updates
/// Home, More, the profile editor and the dashboard at the same time — no
/// manual refresh, no duplicated fetches.
class ProfileProvider extends ChangeNotifier {
  ProfileProvider({AuthRepository? repository})
      : _repository = repository ?? AuthRepository.instance {
    SessionManager.instance.addSignOutListener(_onSignedOut);
    _instance = this;
  }

  /// The provider owned by the widget tree. Exposed so plain (non-widget) code
  /// such as the login service can push a freshly fetched profile in without
  /// needing a [BuildContext]. Widgets should always go through
  /// `context.watch<ProfileProvider>()` instead.
  static ProfileProvider? _instance;

  static ProfileProvider? get maybeInstance => _instance;

  final AuthRepository _repository;

  ProfileModel? _profile;
  ProfileStatus _status = ProfileStatus.initial;
  String? _errorMessage;
  bool _isRefreshing = false;

  /// De-duplicates concurrent `refresh()` calls from several screens' initState.
  Future<void>? _inFlight;

  DateTime? _lastFetchedAt;

  /// Successive fetches inside this window reuse the cached profile.
  static const Duration _minFetchInterval = Duration(seconds: 30);

  // ---------------------------------------------------------------------------
  // Read API used by the widgets
  // ---------------------------------------------------------------------------

  ProfileModel? get profile => _profile;
  ProfileStatus get status => _status;
  String? get errorMessage => _errorMessage;

  bool get isLoading => _status == ProfileStatus.loading;
  bool get isRefreshing => _isRefreshing;
  bool get hasProfile => _profile != null && _profile!.isNotEmpty;

  String get name => _profile?.displayName ?? '';
  String get initial => _profile?.initial ?? '?';
  String get email => _profile?.email ?? '';
  String get phoneNumber => _profile?.phoneNumber ?? '';
  String get membership => _profile?.membershipLabel ?? 'N/A';
  String get role => _profile?.roleLabel ?? '';
  String get statusLabel => _profile?.status ?? '';
  String get joinDate => _profile?.joinDate ?? '';
  String? get imageUrl => _profile?.imageUrl;
  int get totalBookings => _profile?.totalBookings ?? 0;
  String? get userId => _profile?.id?.toString();

  bool hasPermission(String permission) =>
      PermissionService.instance.hasPermission(permission);

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  /// App start-up: show the cached profile immediately, then reconcile with
  /// the server in the background.
  Future<void> bootstrap() async {
    await loadFromCache();

    if (await TokenStorage.instance.hasSession) {
      // Not awaited — the UI is already painted from cache.
      unawaited(refresh(force: true));
    }
  }

  /// Instant, offline-capable load. Never touches the network.
  Future<void> loadFromCache() async {
    final cached = await _repository.cachedProfile();
    if (cached != null) {
      _profile = cached;
      PermissionService.instance.sync(cached);
      _status = ProfileStatus.ready;
      notifyListeners();
    }
  }

  /// Fetches `/auth/profile` and fans the result out to every listener.
  ///
  /// Concurrent callers share one request. Within [_minFetchInterval] of the
  /// last success the cached value is returned instead, unless [force] is set.
  Future<void> refresh({bool force = false}) {
    final existing = _inFlight;
    if (existing != null) return existing;

    if (!force && _isFresh) return Future<void>.value();

    final future = _fetch();
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  bool get _isFresh {
    final last = _lastFetchedAt;
    if (last == null || _profile == null) return false;
    return DateTime.now().difference(last) < _minFetchInterval;
  }

  Future<void> _fetch() async {
    if (!await TokenStorage.instance.hasSession) {
      _profile = null;
      _status = ProfileStatus.initial;
      notifyListeners();
      return;
    }

    if (_profile == null) {
      _status = ProfileStatus.loading;
      notifyListeners();
    } else {
      _isRefreshing = true;
    }

    try {
      final fresh = await _repository.fetchProfile();
      _lastFetchedAt = DateTime.now();
      _errorMessage = null;
      _status = ProfileStatus.ready;

      final changed = _profile != fresh;
      _profile = fresh;

      // Only rebuild the tree when something actually differs.
      if (changed || _isRefreshing) notifyListeners();
    } on UnauthorizedException catch (e) {
      // SessionManager already handled the redirect; just clear local state.
      _errorMessage = e.message;
      if (e.sessionExpired) {
        _profile = null;
        _status = ProfileStatus.initial;
      }
      notifyListeners();
    } on ApiException catch (e) {
      AppLogger.error('Profile refresh failed', name: 'Profile', error: e.message);
      _errorMessage = e.message;
      // Keep showing the cached profile rather than blanking the UI.
      _status = _profile == null ? ProfileStatus.error : ProfileStatus.ready;
      notifyListeners();
    } catch (e, s) {
      AppLogger.error('Profile refresh error',
          name: 'Profile', error: e, stackTrace: s);
      _errorMessage = 'Unable to load your profile right now.';
      _status = _profile == null ? ProfileStatus.error : ProfileStatus.ready;
      notifyListeners();
    } finally {
      _isRefreshing = false;
    }
  }

  /// Applies a profile the app already has (e.g. straight after login or a
  /// successful edit) without another round trip.
  void adopt(ProfileModel profile) {
    _profile = profile;
    _lastFetchedAt = DateTime.now();
    _status = ProfileStatus.ready;
    _errorMessage = null;
    PermissionService.instance.sync(profile);
    notifyListeners();
  }

  /// Called after the profile editor saves — forces a re-read so every screen
  /// picks up the new name/photo.
  Future<void> profileUpdated() => refresh(force: true);

  void _onSignedOut() {
    _profile = null;
    _lastFetchedAt = null;
    _errorMessage = null;
    _status = ProfileStatus.initial;
    notifyListeners();
  }

  @override
  void dispose() {
    SessionManager.instance.removeSignOutListener(_onSignedOut);
    if (identical(_instance, this)) _instance = null;
    super.dispose();
  }
}
