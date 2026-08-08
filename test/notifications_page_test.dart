import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/storage/token_storage.dart';
import 'package:nahata_app/notification.dart';

/// The user inbox used to call `nahatasports.com/api/notifications/status` —
/// the website host, and a path no backend serves. The site answers unknown
/// paths with its React `index.html`, so the screen received a 200 full of HTML
/// and died decoding it. These pin down both halves of the fix: the right call,
/// and what happens when a 200 turns out not to be JSON after all.

final Map<String, String> _secureStore = <String, String>{};

void _mockSecureStorage() {
  const channel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
    final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
    final key = args['key'] as String?;

    switch (call.method) {
      case 'read':
        return _secureStore[key];
      case 'write':
        _secureStore[key!] = args['value'] as String;
        return null;
      case 'delete':
        _secureStore.remove(key);
        return null;
      case 'readAll':
        return Map<String, String>.from(_secureStore);
      case 'deleteAll':
        _secureStore.clear();
        return null;
      case 'containsKey':
        return _secureStore.containsKey(key);
      default:
        return null;
    }
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    _secureStore.clear();
    SharedPreferences.setMockInitialValues({});
    _mockSecureStorage();
    ApiClient.instance.onSessionExpired = null;
    await TokenStorage.instance.clear();
    await TokenStorage.instance.saveTokens(
      accessToken: 'access-1',
      refreshToken: 'refresh-1',
    );
  });

  tearDown(() {
    ApiClient.instance.overrideHttpClient(http.Client());
  });

  /// Pumps past the spinner without pumpAndSettle, which would wait forever on
  /// the CircularProgressIndicator.
  Future<void> load(WidgetTester t) async {
    await t.pumpWidget(const MaterialApp(home: NotificationsPage()));
    await t.pump();
    await t.pump(const Duration(milliseconds: 50));
  }

  testWidgets('reads the inbox off the API, not the website', (t) async {
    Uri? seen;

    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      seen = request.url;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            {
              'id': 1,
              'title': 'Practice moved',
              'message': 'Evening batch shifts to 6pm tomorrow.',
              'type': 'System',
              'isRead': false,
              'sentAt': '2026-08-08T04:30:00.000Z',
            },
          ],
          'pagination': {'currentPage': 1, 'totalPages': 1, 'totalItems': 1},
        }),
        200,
        headers: const {'content-type': 'application/json'},
      );
    }));

    await load(t);

    expect(seen, isNotNull);
    expect(seen!.host, 'api.nahatasports.com');
    expect(seen!.path, '/api/notifications');

    expect(find.text('Practice moved'), findsOneWidget);
    expect(find.text('Evening batch shifts to 6pm tomorrow.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('an HTML page answering 200 is reported, not decoded',
      (t) async {
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      return http.Response(
        '<!doctype html><html><body><div id="root"></div></body></html>',
        200,
        headers: const {'content-type': 'text/html'},
      );
    }));

    await load(t);

    // The old code threw here; now it says so and offers a way back.
    expect(t.takeException(), isNull);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.text('No notifications'), findsNothing);
  });

  testWidgets('an empty inbox reads as empty, not as a failure', (t) async {
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      return http.Response(
        jsonEncode({'success': true, 'data': <dynamic>[]}),
        200,
        headers: const {'content-type': 'application/json'},
      );
    }));

    await load(t);

    expect(find.text('No notifications'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
