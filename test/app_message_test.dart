import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nahata_app/core/services/app_navigator.dart';

/// The sign-in message used to be a blocking `AlertDialog` in the middle of the
/// page that closed itself on a two-second timer — which also raced the
/// navigation timer beside it. These pin down what replaced it.
void main() {
  Widget host() => MaterialApp(
        navigatorKey: AppNavigator.key,
        scaffoldMessengerKey: AppNavigator.messengerKey,
        home: const Scaffold(body: Center(child: Text('sign in'))),
      );

  /// Shows the bar and runs out its entry animation.
  Future<void> settleBar(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  /// Lets the bar time out, so no timer outlives the test.
  Future<void> expireBar(WidgetTester t) async {
    await t.pump(const Duration(seconds: 5));
    await t.pumpAndSettle();
  }

  testWidgets('shows a snackbar, not a dialog', (t) async {
    await t.pumpWidget(host());

    AppNavigator.showMessage('Login successful', tone: AppMessageTone.success);
    await settleBar(t);

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Login successful'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(Dialog), findsNothing);

    await expireBar(t);
  });

  testWidgets('stays on screen after the page it came from is replaced',
      (t) async {
    await t.pumpWidget(host());

    AppNavigator.showMessage('Login successful', tone: AppMessageTone.success);
    await settleBar(t);

    // What a successful sign-in does next.
    AppNavigator.navigator!.pushReplacement(
      MaterialPageRoute(
        builder: (_) => const Scaffold(body: Center(child: Text('dashboard'))),
      ),
    );
    await t.pumpAndSettle();

    expect(find.text('dashboard'), findsOneWidget);
    expect(find.text('Login successful'), findsOneWidget);

    await expireBar(t);
  });

  testWidgets('a failure reads as a failure', (t) async {
    await t.pumpWidget(host());

    AppNavigator.showMessage('Login failed', tone: AppMessageTone.error);
    await settleBar(t);

    final bar = t.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.backgroundColor, AppMessageTone.error.background);
    expect(find.byIcon(Icons.error_rounded), findsOneWidget);

    await expireBar(t);
  });
}
