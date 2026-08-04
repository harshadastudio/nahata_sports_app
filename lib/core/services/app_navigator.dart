import 'package:flutter/material.dart';

/// Holds the app-wide navigator/messenger keys so non-widget code (the auth
/// interceptor, push handlers) can navigate and show messages.
class AppNavigator {
  const AppNavigator._();

  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  static NavigatorState? get navigator => key.currentState;

  static BuildContext? get context => key.currentContext;

  static void showMessage(String message, {Color? background}) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), backgroundColor: background),
      );
  }
}
