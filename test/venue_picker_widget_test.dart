import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/bottombar/profile.dart';
import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/services/selected_ground.dart';
import 'package:nahata_app/core/storage/token_storage.dart';
import 'package:nahata_app/repositories/coaching_repository.dart';

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
      default:
        return null;
    }
  });
}

String _sportsFor(String? ground) {
  if (ground == 'Gangadham Chowk') {
    return jsonEncode({
      'success': true,
      'data': [
        {'id': 8, 'name': 'Basketball', 'category': 'Outdoor', 'status': 'Active'}
      ]
    });
  }
  if (ground == 'Sinhagad Road') {
    return jsonEncode({
      'success': true,
      'data': [
        {'id': 19, 'name': 'Badminton', 'category': 'Indoor', 'status': 'Active'},
        {'id': 26, 'name': 'Basketball', 'category': 'Outdoor', 'status': 'Active'},
      ]
    });
  }
  // All venues.
  return jsonEncode({
    'success': true,
    'data': [
      {'id': 19, 'name': 'Badminton', 'category': 'Indoor', 'status': 'Active'},
      {'id': 8, 'name': 'Basketball', 'category': 'Outdoor', 'status': 'Active'},
      {'id': 26, 'name': 'Basketball', 'category': 'Outdoor', 'status': 'Active'},
    ]
  });
}

const String _venuesJson = '''
{"success": true, "data": {"sportsComplexes": [
  {"id": 1, "name": "Sinhagad Road"},
  {"id": 2, "name": "Gangadham Chowk"}
]}}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Requests seen, so we can assert what the picker actually asked for.
  late List<Uri> requests;

  setUp(() async {
    _secureStore.clear();
    SharedPreferences.setMockInitialValues({});
    _mockSecureStorage();
    CoachingRepository.instance.invalidateCache();
    await SelectedGround.instance.clear();

    await TokenStorage.instance.clear();
    await TokenStorage.instance
        .saveTokens(accessToken: 'access-1', refreshToken: 'refresh-1');

    requests = <Uri>[];
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      requests.add(request.url);
      if (request.url.path.endsWith('/sports-complexes')) {
        return http.Response(_venuesJson, 200);
      }
      return http.Response(
          _sportsFor(request.url.queryParameters['ground']), 200);
    }));
  });

  tearDown(() => ApiClient.instance.overrideHttpClient(http.Client()));

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SportsScreen()));
    await tester.pumpAndSettle();
  }

  // The venue name also appears as each grid card's subtitle, so the picker is
  // targeted by key rather than by text.
  final pickerLabel = find.byKey(const Key('venue_picker_label'));
  Finder venueOption(String value) =>
      find.byKey(ValueKey('venue_option_$value'));

  String labelText(WidgetTester tester) =>
      tester.widget<Text>(pickerLabel).data!;

  Future<void> openPicker(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('venue_picker')));
    await tester.pumpAndSettle();
  }

  Uri lastSportsCall() =>
      requests.lastWhere((u) => u.path.endsWith('/sports'));

  testWidgets('shows "All venues" until a venue is chosen', (tester) async {
    await pumpScreen(tester);

    expect(find.text('Available coaches'), findsOneWidget);
    expect(labelText(tester), 'All venues');

    // Unfiltered: no ground parameter is sent.
    expect(lastSportsCall().queryParameters.containsKey('ground'), isFalse);
  });

  testWidgets('opening the picker lists every venue plus All venues',
      (tester) async {
    await pumpScreen(tester);
    await openPicker(tester);

    expect(venueOption('__all_venues__'), findsOneWidget);
    expect(venueOption('Sinhagad Road'), findsOneWidget);
    expect(venueOption('Gangadham Chowk'), findsOneWidget);
  });

  testWidgets('choosing a venue refetches sports for that ground',
      (tester) async {
    await pumpScreen(tester);
    await openPicker(tester);

    await tester.tap(venueOption('Gangadham Chowk'));
    await tester.pumpAndSettle();

    // Label updated…
    expect(labelText(tester), 'Gangadham Chowk');

    // …and the request carried the ground.
    expect(lastSportsCall().queryParameters['ground'], 'Gangadham Chowk');
  });

  testWidgets('the chosen venue is persisted for the batch screens',
      (tester) async {
    await pumpScreen(tester);
    await openPicker(tester);

    await tester.tap(venueOption('Sinhagad Road'));
    await tester.pumpAndSettle();

    expect(await SelectedGround.instance.read(), 'Sinhagad Road');
  });

  testWidgets('a persisted venue is restored on the next visit',
      (tester) async {
    await SelectedGround.instance.save('Sinhagad Road');

    await pumpScreen(tester);

    expect(labelText(tester), 'Sinhagad Road');
    expect(lastSportsCall().queryParameters['ground'], 'Sinhagad Road');
  });

  testWidgets('switching back to All venues clears the filter',
      (tester) async {
    await SelectedGround.instance.save('Sinhagad Road');
    await pumpScreen(tester);

    await openPicker(tester);
    await tester.tap(venueOption('__all_venues__'));
    await tester.pumpAndSettle();

    expect(labelText(tester), 'All venues');
    expect(await SelectedGround.instance.read(), isNull);
    expect(lastSportsCall().queryParameters.containsKey('ground'), isFalse);
  });

  testWidgets('the grid shows the sports for the selected venue',
      (tester) async {
    await SelectedGround.instance.save('Gangadham Chowk');
    await pumpScreen(tester);

    expect(find.text('Basketball'), findsOneWidget);
    expect(find.text('Badminton'), findsNothing);
  });

  testWidgets('the picker is hidden when there are no venues to choose from',
      (tester) async {
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      if (request.url.path.endsWith('/sports-complexes')) {
        return http.Response(
            jsonEncode({'success': true, 'data': {'sportsComplexes': []}}), 200);
      }
      return http.Response(_sportsFor(null), 200);
    }));

    await pumpScreen(tester);

    // The row falls back to exactly what it looked like before the picker.
    expect(find.text('Available coaches'), findsOneWidget);
    expect(find.byKey(const Key('venue_picker')), findsNothing);
  });

  testWidgets('an empty venue shows the empty state, not an error',
      (tester) async {
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      if (request.url.path.endsWith('/sports-complexes')) {
        return http.Response(_venuesJson, 200);
      }
      return http.Response(
          jsonEncode({'success': true, 'data': []}), 200);
    }));

    await pumpScreen(tester);

    expect(find.text('No sports found'), findsOneWidget);
    expect(find.text('Retry'), findsNothing);
  });
}
