import 'dart:convert';

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

/// Verbatim from `/sports?...&ground=Gangadham+Chowk`.
const String _gangadhamJson = '''
{
  "success": true,
  "message": "Sports retrieved successfully",
  "data": [
    {
      "id": 8,
      "name": "Basketball",
      "category": "Outdoor",
      "image": "https://api.nahatasports.com/uploads/nahata-sports/sports/sports-1783573690358-259573364.png",
      "description": "Basketball sport",
      "minAge": null,
      "maxAge": null,
      "status": "Active",
      "coachCount": "1"
    }
  ]
}
''';

/// Verbatim from `/sports?...&ground=Sinhagad+Road`.
const String _sinhagadJson = '''
{
  "success": true,
  "message": "Sports retrieved successfully",
  "data": [
    {"id": 19, "name": "Badminton", "category": "Indoor",
     "image": "https://api.nahatasports.com/uploads/nahata-sports/sports/sports-1783573669024-335965277.png",
     "description": null, "minAge": null, "maxAge": null, "status": "Active", "coachCount": "1"},
    {"id": 26, "name": "Basketball", "category": "Outdoor",
     "image": "https://cdn/basketball.png", "description": null,
     "minAge": null, "maxAge": null, "status": "Active", "coachCount": "1"},
    {"id": 28, "name": "Cricket", "category": "Outdoor",
     "image": "https://cdn/cricket.webp", "description": null,
     "minAge": null, "maxAge": null, "status": "Active", "coachCount": "1"},
    {"id": 32, "name": "Gymnastics (Artistic)", "category": "Indoor",
     "image": "https://cdn/gym.jpeg", "description": null,
     "minAge": null, "maxAge": null, "status": "Active", "coachCount": "1"},
    {"id": 29, "name": "Skating", "category": "Outdoor",
     "image": "https://cdn/skating.jpg", "description": null,
     "minAge": null, "maxAge": null, "status": "Active", "coachCount": "1"},
    {"id": 31, "name": "Zumba", "category": "Indoor",
     "image": "https://cdn/zumba.jpeg", "description": null,
     "minAge": null, "maxAge": null, "status": "Active", "coachCount": "1"}
  ]
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late CoachingRepository repo;

  setUp(() async {
    repo = CoachingRepository.instance;
    _secureStore.clear();
    SharedPreferences.setMockInitialValues({});
    _mockSecureStorage();
    repo.invalidateCache();
    await SelectedGround.instance.clear();

    await TokenStorage.instance.clear();
    await TokenStorage.instance
        .saveTokens(accessToken: 'access-1', refreshToken: 'refresh-1');
  });

  tearDown(() => ApiClient.instance.overrideHttpClient(http.Client()));

  /// Serves whichever ground the request asks for.
  void serveByGround() {
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      final ground = request.url.queryParameters['ground'];
      if (ground == 'Gangadham Chowk') {
        return http.Response(_gangadhamJson, 200);
      }
      return http.Response(_sinhagadJson, 200);
    }));
  }

  group('GET /sports', () {
    test('sends the documented query parameters', () async {
      Uri? seen;
      ApiClient.instance.overrideHttpClient(MockClient((request) async {
        seen = request.url;
        return http.Response(_sinhagadJson, 200);
      }));

      await repo.fetchSports(ground: 'Sinhagad Road');

      expect(seen!.path, '/api/sports');
      expect(seen!.queryParameters['status'], 'Active');
      expect(seen!.queryParameters['showOnFrontend'], 'true');
      expect(seen!.queryParameters['limit'], '100');
      expect(seen!.queryParameters['ground'], 'Sinhagad Road');
      expect(seen!.query, contains('ground=Sinhagad+Road'));
    });

    test('omits ground when none is selected', () async {
      Uri? seen;
      ApiClient.instance.overrideHttpClient(MockClient((request) async {
        seen = request.url;
        return http.Response(_sinhagadJson, 200);
      }));

      await repo.fetchSports();
      expect(seen!.queryParameters.containsKey('ground'), isFalse);
    });

    test('parses every field, including the string coachCount', () async {
      serveByGround();

      final sports = await repo.fetchSports(ground: 'Gangadham Chowk');
      expect(sports, hasLength(1));

      final basketball = sports.single;
      expect(basketball.id, 8);
      expect(basketball.name, 'Basketball');
      expect(basketball.category, 'Outdoor');
      expect(basketball.description, 'Basketball sport');
      expect(basketball.minAge, isNull);
      expect(basketball.maxAge, isNull);
      expect(basketball.status, 'Active');
      expect(basketball.coachCount, 1, reason: 'sent as the string "1"');
      expect(basketball.hasCoaches, isTrue);
      expect(basketball.isActive, isTrue);
      expect(basketball.image, contains('sports-1783573690358'));
    });

    test('stamps each sport with the ground it was fetched for', () async {
      serveByGround();

      final sports = await repo.fetchSports(ground: 'Sinhagad Road');
      expect(sports.every((s) => s.ground == 'Sinhagad Road'), isTrue);
    });

    test('sorts alphabetically', () async {
      serveByGround();

      final names =
          (await repo.fetchSports(ground: 'Sinhagad Road')).map((s) => s.name);
      expect(names, [
        'Badminton',
        'Basketball',
        'Cricket',
        'Gymnastics (Artistic)',
        'Skating',
        'Zumba',
      ]);
    });

    test('an empty or malformed payload yields an empty list', () async {
      ApiClient.instance.overrideHttpClient(MockClient((_) async =>
          http.Response(jsonEncode({'success': true, 'data': null}), 200)));

      expect(await repo.fetchSports(), isEmpty);
    });
  });

  group('per-ground sport ids', () {
    test('the same sport name has a different id at each ground', () async {
      serveByGround();

      final gangadham = await repo.fetchSports(ground: 'Gangadham Chowk');
      final sinhagad = await repo.fetchSports(ground: 'Sinhagad Road');

      final a = gangadham.firstWhere((s) => s.name == 'Basketball');
      final b = sinhagad.firstWhere((s) => s.name == 'Basketball');

      expect(a.id, 8);
      expect(b.id, 26);
      expect(a.id, isNot(b.id),
          reason: 'ids are scoped to a ground — the filter is not cosmetic');
    });

    test('each ground is cached separately', () async {
      var requests = 0;
      ApiClient.instance.overrideHttpClient(MockClient((request) async {
        requests++;
        final ground = request.url.queryParameters['ground'];
        return http.Response(
            ground == 'Gangadham Chowk' ? _gangadhamJson : _sinhagadJson, 200);
      }));

      await repo.fetchSports(ground: 'Gangadham Chowk');
      await repo.fetchSports(ground: 'Sinhagad Road');
      expect(requests, 2);

      // Both are now served from cache.
      await repo.fetchSports(ground: 'Gangadham Chowk');
      await repo.fetchSports(ground: 'Sinhagad Road');
      expect(requests, 2);
    });

    test('concurrent callers for one ground share a request', () async {
      var requests = 0;
      ApiClient.instance.overrideHttpClient(MockClient((_) async {
        requests++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return http.Response(_sinhagadJson, 200);
      }));

      await Future.wait([
        repo.fetchSports(ground: 'Sinhagad Road'),
        repo.fetchSports(ground: 'Sinhagad Road'),
      ]);

      expect(requests, 1);
    });
  });

  group('SelectedGround', () {
    test('round-trips through storage', () async {
      await SelectedGround.instance.save('Sinhagad Road');
      expect(SelectedGround.instance.current, 'Sinhagad Road');
      expect(await SelectedGround.instance.read(), 'Sinhagad Road');
    });

    test('blank input clears the selection', () async {
      await SelectedGround.instance.save('Sinhagad Road');
      await SelectedGround.instance.save('   ');
      expect(await SelectedGround.instance.read(), isNull);
    });

    test('trims whitespace', () async {
      await SelectedGround.instance.save('  Gangadham Chowk  ');
      expect(await SelectedGround.instance.read(), 'Gangadham Chowk');
    });
  });

  group('venue picker data', () {
    test('fetchVenues lists the complex names, sorted and de-duplicated',
        () async {
      ApiClient.instance.overrideHttpClient(MockClient((request) async {
        expect(request.url.path, '/api/sports-complexes');
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {
              'sportsComplexes': [
                {'id': 1, 'name': 'Sinhagad Road'},
                {'id': 2, 'name': 'Gangadham Chowk'},
                {'id': 3, 'name': 'Sinhagad Road'},
                {'id': 4, 'name': '  '},
              ]
            }
          }),
          200,
        );
      }));

      expect(await CoachApiService.fetchVenues(),
          ['Gangadham Chowk', 'Sinhagad Road']);
    });

    test('a failure yields an empty venue list rather than throwing', () async {
      ApiClient.instance.overrideHttpClient(
          MockClient((_) async => http.Response('boom', 500)));

      expect(await CoachApiService.fetchVenues(), isEmpty);
    });

    test('selecting a venue persists it for the batch screens', () async {
      serveByGround();

      await SelectedGround.instance.save('Gangadham Chowk');
      expect(await SelectedGround.instance.read(), 'Gangadham Chowk');

      final sports = await CoachApiService.fetchSports(
          ground: SelectedGround.instance.current);
      expect(sports.single.id, '8');

      // Switching back to "All venues" clears the filter.
      await SelectedGround.instance.save(null);
      expect(await SelectedGround.instance.read(), isNull);
    });

    test('a venue with no sports returns empty instead of throwing', () async {
      ApiClient.instance.overrideHttpClient(MockClient((_) async =>
          http.Response(jsonEncode({'success': true, 'data': []}), 200)));

      // The grid shows its "No sports found" state; this must not be an error.
      expect(await CoachApiService.fetchSports(ground: 'Empty Venue'), isEmpty);
    });

    test('a genuine failure still throws so Retry is offered', () async {
      ApiClient.instance.overrideHttpClient(
          MockClient((_) async => http.Response('gateway down', 503)));

      expect(CoachApiService.fetchSports(ground: 'Sinhagad Road'),
          throwsA(anything));
    });
  });

  group('grid mapping', () {
    test('the subtitle shows the venue when filtered by ground', () async {
      serveByGround();

      final sports = await CoachApiService.fetchSports(ground: 'Sinhagad Road');
      expect(sports.first.ground, 'Sinhagad Road');
    });

    test('falls back to the category when no ground is selected', () async {
      ApiClient.instance.overrideHttpClient(
          MockClient((_) async => http.Response(_sinhagadJson, 200)));

      final sports = await CoachApiService.fetchSports();
      final badminton = sports.firstWhere((s) => s.sportName == 'Badminton');
      expect(badminton.ground, 'Indoor');
    });

    test('carries the ground-specific id through to the batch screen',
        () async {
      serveByGround();

      final sports = await CoachApiService.fetchSports(ground: 'Gangadham Chowk');
      expect(sports.single.id, '8');
    });
  });
}
