import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/config/api_config.dart';
import 'package:nahata_app/core/network/api_client.dart';
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
      case 'deleteAll':
        _secureStore.clear();
        return null;
      default:
        return null;
    }
  });
}

Map<String, dynamic> _batch({
  required int id,
  required int sportId,
  required String sportName,
  String? sportImage,
  int coachId = 23,
  String coachName = 'Sudhanshu Medsikar',
  String status = 'Active',
  String fees = '2500.00',
}) =>
    {
      'id': id,
      'name': 'Batch $id',
      'sportId': sportId,
      'coachId': coachId,
      'schedule': '7:00 PM to 8:00 PM',
      'days': 'Monday,Tuesday',
      'startDate': '2026-07-01',
      'maxStudents': 25,
      'currentStudents': 1,
      'status': status,
      'fees': fees,
      'ageGroup': '5 To 50 Years',
      'sport': {
        'id': sportId,
        'name': sportName,
        'category': 'Indoor',
        if (sportImage != null) 'image': sportImage,
      },
      'coach': {'id': coachId, 'name': coachName, 'ground': 'Sinhagad Road'},
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Resolved inside setUp: touching the singleton constructs an http.Client,
  // which must happen inside the test zone.
  late CoachingRepository repo;

  setUp(() async {
    repo = CoachingRepository.instance;
    _secureStore.clear();
    SharedPreferences.setMockInitialValues({});
    _mockSecureStorage();
    ApiClient.instance.onSessionExpired = null;
    repo.invalidateCache();

    await TokenStorage.instance.clear();
    await TokenStorage.instance
        .saveTokens(accessToken: 'access-1', refreshToken: 'refresh-1');
  });

  tearDown(() => ApiClient.instance.overrideHttpClient(http.Client()));

  test('fetchBatchPage sends the documented query parameters', () async {
    Uri? seen;
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      seen = request.url;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'batches': [_batch(id: 53, sportId: 19, sportName: 'Badminton')],
            'currentPage': 1,
            'totalPages': 1,
            'totalItems': 1,
            'itemsPerPage': 10,
          }
        }),
        200,
      );
    }));

    final page = await repo.fetchBatchPage(page: 2, limit: 25);

    expect(seen!.path, '/api/batches');
    expect(seen!.queryParameters['status'], 'Active');
    expect(seen!.queryParameters['page'], '2');
    expect(seen!.queryParameters['limit'], '25');
    expect(page.batches, hasLength(1));
  });

  test('fetchAllBatches walks every page', () async {
    var requests = 0;
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      requests++;
      final page = int.parse(request.url.queryParameters['page']!);
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'batches': [
              _batch(id: page * 10, sportId: 19, sportName: 'Badminton'),
            ],
            'currentPage': page,
            'totalPages': 4,
            'totalItems': 4,
            'itemsPerPage': 1,
          }
        }),
        200,
      );
    }));

    final batches = await repo.fetchAllBatches();

    expect(requests, 4);
    expect(batches, hasLength(4));
  });

  test('fetchAllBatches stops at the page cap instead of looping forever',
      () async {
    var requests = 0;
    // A server that always claims there is another page.
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      requests++;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': {
            'batches': [_batch(id: requests, sportId: 19, sportName: 'X')],
            'currentPage': 1,
            'totalPages': 9999,
          }
        }),
        200,
      );
    }));

    await repo.fetchAllBatches(maxPages: 3);
    expect(requests, 3);
  });

  // `fetchSports` is covered end-to-end in sports_by_ground_test.dart — it now
  // calls the real `GET /sports` endpoint instead of deriving the list from
  // `/batches`.

  test('fetchBatchesBySport reads the bare list shape', () async {
    Uri? seen;
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      seen = request.url;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [
            _batch(id: 53, sportId: 19, sportName: 'Badminton'),
            _batch(id: 43, sportId: 19, sportName: 'Badminton'),
          ]
        }),
        200,
      );
    }));

    final batches = await repo.fetchBatchesBySport(19);

    expect(seen!.path, '/api/batches/sport/19');
    expect(batches, hasLength(2));
    expect(batches.first.coach!.ground, 'Sinhagad Road');
  });

  test('fetchBatchesBySport caches per sport', () async {
    var requests = 0;
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      requests++;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [_batch(id: 53, sportId: 19, sportName: 'Badminton')]
        }),
        200,
      );
    }));

    await repo.fetchBatchesBySport(19);
    await repo.fetchBatchesBySport(19);
    expect(requests, 1, reason: 'batches + coaches share one round trip');

    await repo.fetchBatchesBySport(19, forceRefresh: true);
    expect(requests, 2);
  });

  test('concurrent lookups for the same sport share one request', () async {
    var requests = 0;
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      requests++;
      // Delay so both callers are genuinely in flight together.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [_batch(id: 53, sportId: 19, sportName: 'Badminton')]
        }),
        200,
      );
    }));

    // This is what BatchScreen does: batches and their coaches at once.
    await Future.wait([
      repo.fetchBatchesBySport(19),
      repo.fetchBatchesBySport(19),
    ]);

    expect(requests, 1);
  });

  test('a failed request is not cached, so a retry can succeed', () async {
    var attempt = 0;
    ApiClient.instance.overrideHttpClient(MockClient((_) async {
      attempt++;
      if (attempt == 1) return http.Response('boom', 500);
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [_batch(id: 53, sportId: 19, sportName: 'Badminton')]
        }),
        200,
      );
    }));

    await expectLater(repo.fetchBatchesBySport(19), throwsA(anything));

    // The retry must actually hit the network again rather than replaying the
    // cached failure.
    final batches = await repo.fetchBatchesBySport(19);
    expect(batches, hasLength(1));
    expect(attempt, 2);
  });

  group('ground filter', () {
    test('sends ?ground= when a ground is supplied', () async {
      Uri? seen;
      ApiClient.instance.overrideHttpClient(MockClient((request) async {
        seen = request.url;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [_batch(id: 53, sportId: 19, sportName: 'Badminton')]
          }),
          200,
        );
      }));

      await repo.fetchBatchesBySport(19, ground: 'Sinhagad Road');

      expect(seen!.path, '/api/batches/sport/19');
      expect(seen!.queryParameters['ground'], 'Sinhagad Road');
      // The space must be encoded, not sent raw.
      expect(seen!.query, contains('ground=Sinhagad+Road'));
    });

    test('omits the parameter when the ground is null or blank', () async {
      final seen = <Uri>[];
      ApiClient.instance.overrideHttpClient(MockClient((request) async {
        seen.add(request.url);
        return http.Response(
            jsonEncode({'success': true, 'data': []}), 200);
      }));

      await repo.fetchBatchesBySport(19);
      await repo.fetchBatchesBySport(20, ground: '   ');

      expect(seen[0].queryParameters.containsKey('ground'), isFalse);
      expect(seen[1].queryParameters.containsKey('ground'), isFalse);
    });

    test('filtered and unfiltered lookups do not share a cache entry',
        () async {
      var requests = 0;
      ApiClient.instance.overrideHttpClient(MockClient((request) async {
        requests++;
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [_batch(id: 53, sportId: 19, sportName: 'Badminton')]
          }),
          200,
        );
      }));

      await repo.fetchBatchesBySport(19);
      await repo.fetchBatchesBySport(19, ground: 'Sinhagad Road');
      expect(requests, 2, reason: 'different filters, different results');

      // …but each is cached independently.
      await repo.fetchBatchesBySport(19);
      await repo.fetchBatchesBySport(19, ground: 'Sinhagad Road');
      expect(requests, 2);
    });

    test('fetchGroundsForSport lists the distinct grounds', () async {
      ApiClient.instance.overrideHttpClient(MockClient((_) async {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              _batch(id: 1, sportId: 19, sportName: 'Badminton'),
              _batch(id: 2, sportId: 19, sportName: 'Badminton'),
              {
                ..._batch(id: 3, sportId: 19, sportName: 'Badminton'),
                'coach': {'id': 30, 'name': 'Other', 'ground': 'Kothrud'},
              },
            ]
          }),
          200,
        );
      }));

      // Sinhagad Road appears on two batches — must be de-duplicated.
      expect(await repo.fetchGroundsForSport(19), ['Kothrud', 'Sinhagad Road']);
    });
  });

  test('the sports list never overwrites the richer per-sport batch cache',
      () async {
    // `/sports` and `/batches/sport/{id}` are separate caches: loading the
    // grid must not blank `coach.ground` on the details screen.
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      if (request.url.path.endsWith('/sports')) {
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {'id': 19, 'name': 'Badminton', 'category': 'Indoor'}
            ]
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'success': true,
          'data': [_batch(id: 53, sportId: 19, sportName: 'Badminton')]
        }),
        200,
      );
    }));

    await repo.fetchSports(ground: 'Sinhagad Road');
    final batches = await repo.fetchBatchesBySport(19, ground: 'Sinhagad Road');

    expect(batches.first.coach!.ground, 'Sinhagad Road');
  });

  test('fetchBatch requests includeStudents and unwraps the object', () async {
    Uri? seen;
    ApiClient.instance.overrideHttpClient(MockClient((request) async {
      seen = request.url;
      return http.Response(
        jsonEncode({
          'success': true,
          'data': _batch(id: 53, sportId: 19, sportName: 'Badminton'),
        }),
        200,
      );
    }));

    final batch = await repo.fetchBatch(53);

    expect(seen!.path, '/api/batches/53');
    expect(seen!.queryParameters['includeStudents'], 'false');
    expect(batch!.id, 53);
  });

  test('fetchBatchStats returns null rather than throwing on failure',
      () async {
    ApiClient.instance.overrideHttpClient(
        MockClient((_) async => http.Response('{"message":"nope"}', 404)));

    expect(await repo.fetchBatchStats(53), isNull);
  });

  group('submitEnquiry', () {
    test('posts the documented body and returns the reference number',
        () async {
      Map<String, dynamic>? sentBody;
      String? auth;

      ApiClient.instance.overrideHttpClient(MockClient((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        auth = request.headers['Authorization'];
        return http.Response(
          jsonEncode({
            'success': true,
            'message': 'Your enquiry has been sent!',
            'data': {
              'id': 51,
              'referenceNumber': 'NSC-20260729-F0DAK',
              'status': 'Pending',
            }
          }),
          200,
        );
      }));

      final result = await repo.submitEnquiry(
        batchId: 53,
        sportId: 19,
        coachId: 23,
        name: 'Rahul Sharma',
        email: 'rahul.sharma@example.com',
        phone: '9876543210',
        message: 'Interested in the morning batch.',
      );

      expect(result.success, isTrue);
      expect(result.referenceNumber, 'NSC-20260729-F0DAK');
      expect(result.id, 51);
      expect(result.message, 'Your enquiry has been sent!');

      expect(sentBody, {
        'batchId': 53,
        'sportId': 19,
        'coachId': 23,
        'name': 'Rahul Sharma',
        'email': 'rahul.sharma@example.com',
        'phone': '9876543210',
        'message': 'Interested in the morning batch.',
      });
      // The user is identified by the token, not a body field.
      expect(auth, 'Bearer access-1');
      expect(sentBody!.containsKey('user_id'), isFalse);
    });

    test('omits null ids and an empty message', () async {
      Map<String, dynamic>? sentBody;
      ApiClient.instance.overrideHttpClient(MockClient((request) async {
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
            jsonEncode({'success': true, 'data': {'id': 1}}), 200);
      }));

      await repo.submitEnquiry(
        name: 'A',
        email: 'a@b.c',
        phone: '1',
        batchId: null,
        message: '',
      );

      expect(sentBody!.keys, ['name', 'email', 'phone']);
    });

    test('surfaces a validation failure as a message, not an exception',
        () async {
      ApiClient.instance.overrideHttpClient((MockClient((_) async =>
          http.Response(
              jsonEncode({'message': 'Phone number is invalid'}), 422))));

      final result = await repo.submitEnquiry(
        name: 'A',
        email: 'a@b.c',
        phone: 'bad',
      );

      expect(result.success, isFalse);
      expect(result.message, 'Phone number is invalid');
    });

    test('surfaces an offline device as a friendly message', () async {
      ApiClient.instance.overrideHttpClient(MockClient(
          (_) async => throw const SocketException('No route to host')));

      final result =
          await repo.submitEnquiry(name: 'A', email: 'a@b.c', phone: '1');

      expect(result.success, isFalse);
      expect(result.message, AuthMessages.noInternet);
    });

    test('an unexpected exception is still reported, never thrown raw',
        () async {
      ApiClient.instance.overrideHttpClient(
          MockClient((_) async => throw StateError('plugin exploded')));

      final result =
          await repo.submitEnquiry(name: 'A', email: 'a@b.c', phone: '1');

      expect(result.success, isFalse);
      expect(result.message, AuthMessages.unknown);
    });
  });
}
