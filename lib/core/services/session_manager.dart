import 'dart:async';

import 'package:flutter/material.dart';

import '../../auth/login.dart' show LoginScreen;
import '../../repositories/auth_repository.dart';
import '../config/api_config.dart';
import '../network/api_client.dart';
import '../utils/app_logger.dart';
import 'app_navigator.dart';

/// Owns the "the session ended" path.
///
/// [ApiClient] calls [handleSessionExpired] when `/auth/refresh` is rejected.
/// This class then wipes local state, shows the standard message and returns
/// the user to Login. It is idempotent — several failing requests landing at
/// once produce exactly one navigation.
class SessionManager {
  SessionManager._();

  static final SessionManager instance = SessionManager._();

  bool _handling = false;

  /// Called by [ProfileProvider] and others that want to react to sign-out.
  final List<VoidCallback> _listeners = <VoidCallback>[];

  void addSignOutListener(VoidCallback listener) => _listeners.add(listener);

  void removeSignOutListener(VoidCallback listener) =>
      _listeners.remove(listener);

  /// Wires the interceptor to this manager. Call once during app start-up.
  void attach() {
    ApiClient.instance.onSessionExpired = handleSessionExpired;
  }

  /// Invoked by the interceptor when refresh is rejected.
  Future<void> handleSessionExpired() async {
    if (_handling) return;
    _handling = true;

    AppLogger.debug('Session expired — signing out', name: 'Auth');

    try {
      await AuthRepository.instance.clearSession();
      _notifyListeners();
    } finally {
      // Defer to the next frame: this can fire from deep inside an await chain
      // while a build is in progress.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _goToLogin(AuthMessages.sessionExpired);
        } finally {
          _handling = false;
        }
      });
      // Guarantee a frame so the callback above always runs, even if the app
      // is otherwise idle — otherwise the guard would latch permanently.
      WidgetsBinding.instance.ensureVisualUpdate();
    }
  }

  /// Explicit sign-out (the user tapped Logout). No "expired" message.
  ///
  /// Tells the server first (`POST /auth/logout`) so the refresh token is
  /// revoked, then wipes local state.
  Future<void> signOut({bool navigateToLogin = true}) async {
    await AuthRepository.instance.logout();
    _notifyListeners();
    if (navigateToLogin) _goToLogin(null);
  }

  void _notifyListeners() {
    for (final listener in List<VoidCallback>.from(_listeners)) {
      try {
        listener();
      } catch (e) {
        AppLogger.error('Sign-out listener failed', name: 'Auth', error: e);
      }
    }
  }

  void _goToLogin(String? message) {
    final navigator = AppNavigator.navigator;
    if (navigator == null) {
      AppLogger.debug(
        'No navigator available for logout redirect',
        name: 'Auth',
      );
      return;
    }

    navigator.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );

    if (message != null) AppNavigator.showMessage(message);
  }
}
