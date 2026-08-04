import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/bottombar/profile.dart';
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
      default:
        return null;
    }
  });
}

/// Two batches taught by the SAME coach at different times and prices — the
/// shape that produced the "details don't match" bug.
const String _sportBatchesJson = '''
{
  "success": true,
  "data": [
    {
      "id": 53,
      "name": "3 DAYS( Evening)",
      "sportId": 19,
      "coachId": 23,
      "schedule": "7:00 PM to 8:00 PM",
      "days": "Monday,Tuesday",
      "startDate": "2026-07-01",
      "maxStudents": 25,
      "currentStudents": 1,
      "status": "Active",
      "fees": "2500.00",
      "ageGroup": "5 To 50 Years",
      "sport": {"id": 19, "name": "Badminton", "category": "Indoor"},
      "coach": {"id": 23, "name": "Sudhanshu Medsikar", "ground": "Sinhagad Road"}
    },
    {
      "id": 43,
      "name": "Regular (Morning)",
      "sportId": 19,
      "coachId": 23,
      "schedule": "7:00 AM to 8:00 AM",
      "days": "Monday,Tuesday,Wednesday",
      "startDate": "2026-07-01",
      "maxStudents": 25,
      "currentStudents": 2,
      "status": "Active",
      "fees": "3000.00",
      "ageGroup": "20 and Above",
      "sport": {"id": 19, "name": "Badminton", "category": "Indoor"},
      "coach": {"id": 23, "name": "Sudhanshu Medsikar", "ground": "Sinhagad Road"}
    }
  ]
}
''';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    _secureStore.clear();
    SharedPreferences.setMockInitialValues({});
    _mockSecureStorage();
    CoachingRepository.instance.invalidateCache();

    await TokenStorage.instance.clear();
    await TokenStorage.instance
        .saveTokens(accessToken: 'access-1', refreshToken: 'refresh-1');

    ApiClient.instance.overrideHttpClient(
        MockClient((_) async => http.Response(_sportBatchesJson, 200)));
  });

  tearDown(() => ApiClient.instance.overrideHttpClient(http.Client()));

  test('batch list carries each batch\'s own schedule and fee', () async {
    final batches = await CoachApiService.fetchBatches('19');

    expect(batches, hasLength(2));

    final evening = batches.firstWhere((b) => b.id == '53');
    expect(evening.name, '3 DAYS( Evening)');
    expect(evening.startTime, '7:00 PM');
    expect(evening.endTime, '8:00 PM');
    expect(evening.price, '2500');
    expect(evening.ageGroup, '5 To 50 Years');

    final morning = batches.firstWhere((b) => b.id == '43');
    expect(morning.startTime, '7:00 AM');
    expect(morning.endTime, '8:00 AM');
    expect(morning.price, '3000');
    expect(morning.ageGroup, '20 and Above');
  });

  group('View Details resolves the coach through the tapped batch', () {
    test('each batch maps to a coach carrying that batch\'s data', () async {
      final byBatch = await CoachApiService.fetchCoachesByBatch('19');

      expect(byBatch.keys.toSet(), {'53', '43'});

      // Same coach…
      expect(byBatch['53']!.id, '23');
      expect(byBatch['43']!.id, '23');
      expect(byBatch['53']!.name, 'Sudhanshu Medsikar');

      // …but the batch-dependent fields differ, which is the whole point.
      expect(byBatch['53']!.availability, '7:00 PM to 8:00 PM');
      expect(byBatch['53']!.price, '2500');
      expect(byBatch['53']!.ageGroup, '5 To 50 Years');

      expect(byBatch['43']!.availability, '7:00 AM to 8:00 AM');
      expect(byBatch['43']!.price, '3000');
      expect(byBatch['43']!.ageGroup, '20 and Above');
      expect(byBatch['43']!.days, 'Monday, Tuesday, Wednesday');
    });

    test('every batch has an entry, so the lookup never falls back', () async {
      final batches = await CoachApiService.fetchBatches('19');
      final byBatch = await CoachApiService.fetchCoachesByBatch('19');

      for (final batch in batches) {
        expect(byBatch[batch.id], isNotNull,
            reason: 'batch ${batch.id} must resolve a coach');
        expect(byBatch[batch.id]!.id, batch.coachId);
      }
    });

    test('the coach paired with a batch agrees with that batch', () async {
      final batches = await CoachApiService.fetchBatches('19');
      final byBatch = await CoachApiService.fetchCoachesByBatch('19');

      for (final batch in batches) {
        final coach = byBatch[batch.id]!;
        expect(coach.startTime, batch.startTime);
        expect(coach.endTime, batch.endTime);
        expect(coach.price, batch.price);
        expect(coach.ageGroup, batch.ageGroup);
        expect(coach.days, batch.days);
      }
    });

    test('the coach carries the ground for the header text', () async {
      final byBatch = await CoachApiService.fetchCoachesByBatch('19');
      expect(byBatch['53']!.ground, 'Sinhagad Road');
    });
  });

  test('fetchCoaches still de-duplicates to one entry per coach', () async {
    final coaches = await CoachApiService.fetchCoaches('19');

    expect(coaches, hasLength(1));
    expect(coaches.single.id, '23');
  });

  test('an unparseable sport id yields empty results, not a crash', () async {
    expect(await CoachApiService.fetchBatches('abc'), isEmpty);
    expect(await CoachApiService.fetchCoaches('abc'), isEmpty);
    expect(await CoachApiService.fetchCoachesByBatch('abc'), isEmpty);
  });
}
