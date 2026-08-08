import 'package:flutter/material.dart';

/// What a message is telling the user, which decides its colour and icon.
enum AppMessageTone {
  /// Something worked — signed in, saved, sent.
  success,

  /// Something failed and the user has to act.
  error,

  /// Neutral progress or information.
  info;

  Color get background => switch (this) {
        AppMessageTone.success => const Color(0xFF15803D),
        AppMessageTone.error => const Color(0xFFDC2626),
        AppMessageTone.info => const Color(0xFF1F2937),
      };

  IconData get icon => switch (this) {
        AppMessageTone.success => Icons.check_circle_rounded,
        AppMessageTone.error => Icons.error_rounded,
        AppMessageTone.info => Icons.info_rounded,
      };
}

/// Holds the app-wide navigator/messenger keys so non-widget code (the auth
/// interceptor, push handlers) can navigate and show messages.
class AppNavigator {
  const AppNavigator._();

  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static NavigatorState? get navigator => key.currentState;

  static BuildContext? get context => key.currentContext;

  /// A one-line message at the bottom of the screen.
  ///
  /// Sent through the app-wide messenger rather than a screen's own, because
  /// these messages usually announce something that immediately navigates: the
  /// messenger sits above the navigator, so a "Login successful" bar stays put
  /// while the dashboard replaces the login page underneath it. A dialog in the
  /// same spot would either block that navigation or race it.
  ///
  /// [context] is only a fallback for the case where the app-wide messenger is
  /// not mounted (a screen pumped on its own in a test, say) — pass it when you
  /// have one, and the message still finds a way to the screen.
  static void showMessage(
    String message, {
    AppMessageTone tone = AppMessageTone.info,
    BuildContext? context,
  }) {
    final messenger = messengerKey.currentState ??
        (context == null ? null : ScaffoldMessenger.maybeOf(context));
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(tone.icon, size: 20, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: tone.background,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 6,
          // An error is the one a user may need to read twice.
          duration: Duration(seconds: tone == AppMessageTone.error ? 4 : 2),
        ),
      );
  }
}
