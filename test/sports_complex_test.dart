import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/storage/token_storage.dart';
import 'package:nahata_app/models/sports_complex_model.dart';
import 'package:nahata_app/repositories/sports_complex_repository.dart';

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

const Map<String, dynamic> _complexes = {
  'success': true,
  'data': {
    'sportsComplexes': [
      {'id': 1, 'name': 'Sinhagad Road', 'city': 'Pune'},
      {'id': 2, 'name': 'Gangadham Chowk', 'city': 'Pune'},
    ]
  }
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<Uri> requests;

  setUp(() async {
    _secureStore.clear();
    SharedPreferences.setMockInitialValues({});
    _mockSecureStorage();
    await TokenStorage.instance.clear();

    SportsComplexRepository.instance.invalidateCache();
    requests = <Uri>[];
  });

  tearDown(() => ApiClient.instance.overrideHttpClient(http.Client()));

  void serve(Object body, {int status = 200}) {
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      requests.add(request.url);
      return http.Response(jsonEncode(body), status);
    }));
  }

  test('asks for active, front-facing venues', () async {
    serve(_complexes);
    await SportsComplexRepository.instance.fetchComplexes();

    expect(requests.single.path, '/api/sports-complexes');
    expect(requests.single.queryParameters['status'], 'Active');
    expect(requests.single.queryParameters['showOnFrontend'], 'true');
  });

  test('parses id, name and city', () async {
    serve(_complexes);
    final complexes = await SportsComplexRepository.instance.fetchComplexes();

    expect(complexes.map((c) => c.id), [1, 2]);
    expect(complexes.first.name, 'Sinhagad Road');
    expect(complexes.first.city, 'Pune');
    expect(complexes.first.label, 'Sinhagad Road, Pune');
  });

  test('a venue without a city is labelled by name alone', () {
    final complex = SportsComplex.fromJson(const {'id': 3, 'name': 'Kothrud'});
    expect(complex?.label, 'Kothrud');
  });

  test('entries missing an id or name are skipped', () async {
    serve({
      'success': true,
      'data': {
        'sportsComplexes': [
          {'id': 1, 'name': 'Sinhagad Road'},
          {'name': 'No id'},
          {'id': 4, 'name': ''},
        ]
      }
    });

    final complexes = await SportsComplexRepository.instance.fetchComplexes();
    expect(complexes.map((c) => c.name), ['Sinhagad Road']);
  });

  test('the list is fetched once and reused', () async {
    serve(_complexes);

    await SportsComplexRepository.instance.fetchComplexes();
    await SportsComplexRepository.instance.fetchComplexes();

    expect(requests, hasLength(1));
  });

  test('refresh forces a new request', () async {
    serve(_complexes);

    await SportsComplexRepository.instance.fetchComplexes();
    await SportsComplexRepository.instance.fetchComplexes(refresh: true);

    expect(requests, hasLength(2));
  });

  test('looks an id up by name, ignoring case', () async {
    serve(_complexes);

    expect(await SportsComplexRepository.instance.idFor('Sinhagad Road'), 1);
    expect(await SportsComplexRepository.instance.idFor('gangadham chowk'), 2);
    expect(await SportsComplexRepository.instance.idFor('Nowhere'), isNull);
  });

  test('a failure yields no venues rather than an error', () async {
    serve({'success': false, 'message': 'boom'}, status: 500);

    expect(await SportsComplexRepository.instance.fetchComplexes(), isEmpty);
  });
}
