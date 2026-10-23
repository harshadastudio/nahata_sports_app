import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/features/admin/data/models/revenue_split_model.dart';
import 'package:nahata_app/features/admin/data/repositories/revenue_split_repository_impl.dart';
import 'package:nahata_app/features/admin/domain/entities/revenue_split.dart';

/// The verbatim `GET /revenue-splits` row from the Postman collection's
/// captured example.
const Map<String, dynamic> _capturedRule = {
  'id': 7,
  'scope': 'batch',
  'batchId': 53,
  'sportId': null,
  'coachId': null,
  'sportComplexId': 1,
  'coachPercent': 40,
  'nahataPercent': 60,
  'effectiveFrom': '2026-08-01',
  'notes': 'Evening badminton batch - agreed rate',
  'isActive': true,
  'createdBy': 1,
  'updatedBy': 1,
  'createdAt': '2026-08-01T05:12:44.000Z',
  'updatedAt': '2026-08-01T05:12:44.000Z',
  'batch': {
    'id': 53,
    'name': 'Regular (Evening)',
    'sportId': 19,
    'sportComplexId': 1,
    'fees': '3000.00',
    'schedule': 'Mon-Fri',
    'startTime': '18:00:00',
    'endTime': '19:00:00',
    'days': '5',
    'sport': {'id': 19, 'name': 'Badminton'},
    'coach': {'id': 23, 'name': 'Dashrath Birhamane'},
  },
  'sport': null,
  'coach': null,
  'sportComplex': {'id': 1, 'name': 'Sinhagad Road', 'city': 'Pune'},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() => ApiClient.instance.overrideHttpClient(http.Client()));

  // ───────────────────────────────────────────────────────────────────────────
  group('RevenueSplitScope', () {
    test('the wire values are exactly what the API documents', () {
      expect(RevenueSplitScope.batch.wire, 'batch');
      expect(RevenueSplitScope.sportCoach.wire, 'sport_coach');
      expect(RevenueSplitScope.sport.wire, 'sport');
    });

    test('parses the wire spelling back, and nothing else', () {
      expect(RevenueSplitScope.tryParse('sport_coach'), RevenueSplitScope.sportCoach);
      expect(RevenueSplitScope.tryParse('SPORT'), RevenueSplitScope.sport);
      expect(RevenueSplitScope.tryParse('coach'), isNull);
      expect(RevenueSplitScope.tryParse(null), isNull);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('RevenueSplitDraft.toBody', () {
    test('a batch-scope draft carries only batchId', () {
      final body = RevenueSplitDraft(
        scope: RevenueSplitScope.batch,
        batchId: 53,
        sportId: 999, // must be nulled — batch beats everything
        coachId: 999,
        coachPercent: 40,
        effectiveFrom: DateTime(2026, 8, 1),
        notes: 'Evening badminton batch - agreed rate',
      ).toBody();

      expect(body['scope'], 'batch');
      expect(body['batchId'], 53);
      expect(body['sportId'], isNull);
      expect(body['coachId'], isNull);
      expect(body['coachPercent'], 40);
      expect(body['effectiveFrom'], '2026-08-01');
      expect(body['notes'], 'Evening badminton batch - agreed rate');
    });

    test('a sport_coach-scope draft carries sportId and coachId, no batch', () {
      final body = RevenueSplitDraft(
        scope: RevenueSplitScope.sportCoach,
        batchId: 999,
        sportId: 19,
        coachId: 23,
        coachPercent: 45,
        effectiveFrom: DateTime(2026, 8, 1),
      ).toBody();

      expect(body['scope'], 'sport_coach');
      expect(body['batchId'], isNull);
      expect(body['sportId'], 19);
      expect(body['coachId'], 23);
    });

    test('a sport-scope draft nulls coachId too', () {
      final body = RevenueSplitDraft(
        scope: RevenueSplitScope.sport,
        sportId: 19,
        coachId: 23,
        coachPercent: 35,
        effectiveFrom: DateTime(2026, 8, 1),
      ).toBody();

      expect(body['scope'], 'sport');
      expect(body['batchId'], isNull);
      expect(body['sportId'], 19);
      expect(body['coachId'], isNull);
    });

    test('blank notes are sent as null, not an empty string', () {
      final body = RevenueSplitDraft(
        scope: RevenueSplitScope.sport,
        sportId: 19,
        coachPercent: 35,
        effectiveFrom: DateTime(2026, 8, 1),
        notes: '   ',
      ).toBody();

      expect(body['notes'], isNull);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('RevenueSplitMapper — the captured payload', () {
    test('reads the rule, its joined batch and the derived Nahata share', () {
      final rule = RevenueSplitMapper.fromJson(_capturedRule);

      expect(rule.id, 7);
      expect(rule.scope, RevenueSplitScope.batch);
      expect(rule.batchId, 53);
      expect(rule.coachPercent, 40);
      expect(rule.nahataPercent, 60);
      expect(rule.effectiveFrom, DateTime.parse('2026-08-01'));
      expect(rule.isActive, isTrue);
      expect(rule.batchName, 'Regular (Evening)');
      expect(rule.sportName, 'Badminton');
      expect(rule.coachName, 'Dashrath Birhamane');
      expect(rule.complexName, 'Sinhagad Road');
      expect(rule.complexCity, 'Pune');
      expect(rule.targetLabel, 'Regular (Evening)');
    });

    test('the Nahata share is derived when the server omits it', () {
      final json = Map<String, dynamic>.from(_capturedRule)
        ..remove('nahataPercent');
      final rule = RevenueSplitMapper.fromJson(json);
      expect(rule.nahataPercent, 60);
    });

    test('listFrom drops rows with no id and reads the bare array', () {
      final body = {
        'success': true,
        'data': [_capturedRule, {'scope': 'sport'}],
      };
      final rules = RevenueSplitMapper.listFrom(body);
      expect(rules.length, 1);
      expect(rules.first.id, 7);
    });

    test('a sport_coach rule reads its top-level sport and coach', () {
      final json = {
        'id': 9,
        'scope': 'sport_coach',
        'sportId': 19,
        'coachId': 23,
        'coachPercent': 45,
        'sport': {'id': 19, 'name': 'Badminton'},
        'coach': {'id': 23, 'name': 'Dashrath Birhamane'},
      };
      final rule = RevenueSplitMapper.fromJson(json);
      expect(rule.targetLabel, 'Dashrath Birhamane · Badminton');
    });

    test('options reads all four lists from the data envelope', () {
      final body = {
        'success': true,
        'data': {
          'sports': [
            {'id': 19, 'name': 'Badminton', 'sportComplexId': 1},
          ],
          'coaches': [
            {'id': 23, 'name': 'Dashrath Birhamane', 'sportId': 19},
          ],
          'batches': [
            {
              'id': 53,
              'name': 'Regular (Evening)',
              'sportId': 19,
              'coachId': 23,
              'fees': 3000,
            },
          ],
          'complexes': [
            {'id': 1, 'name': 'Sinhagad Road', 'city': 'Pune'},
          ],
        },
      };

      final options = RevenueSplitMapper.optionsFrom(body);
      expect(options.sports.single.displayName, 'Badminton');
      expect(options.coaches.single.displayName, 'Dashrath Birhamane');
      expect(options.batches.single.displayName, 'Regular (Evening)');
      expect(options.complexes.single.displayName, 'Sinhagad Road');
    });

    test('coverage reads clear, gaps and the summary', () {
      final body = {
        'success': true,
        'data': {
          'clear': true,
          'gaps': <dynamic>[],
          'uncoveredAmount': 0,
          'summary': {
            'enrolments': 26,
            'pending': 26,
            'totalReceived': 31405,
            'pendingCoachTotal': 14800,
            'pendingNahataTotal': 16605,
            'reconciles': true,
          },
        },
      };

      final coverage = RevenueSplitMapper.coverageFrom(body);
      expect(coverage.clear, isTrue);
      expect(coverage.gaps, isEmpty);
      expect(coverage.summary.enrolments, 26);
      expect(coverage.summary.pendingCoachTotal, 14800);
    });

    test('resolve reads a matched rule and an unmatched one', () {
      final matched = RevenueSplitMapper.resolutionFrom({
        'success': true,
        'data': {
          'matched': true,
          'rule': _capturedRule,
          'coachPercent': 40,
          'nahataPercent': 60,
          'needsSplitRule': false,
          'context': {'batchId': 53, 'paidOn': '2026-09-02', 'batchFee': 3000},
        },
      });
      expect(matched.matched, isTrue);
      expect(matched.rule?.id, 7);
      expect(matched.needsSplitRule, isFalse);

      final unmatched = RevenueSplitMapper.resolutionFrom({
        'success': true,
        'data': {
          'matched': false,
          'rule': null,
          'coachPercent': 0,
          'nahataPercent': 100,
          'needsSplitRule': true,
          'context': {'batchId': 61, 'sportId': 20, 'coachId': 31},
        },
      });
      expect(unmatched.matched, isFalse);
      expect(unmatched.rule, isNull);
      expect(unmatched.needsSplitRule, isTrue);
      expect(unmatched.nahataPercent, 100);
    });

    test('backfill apply reads written/skipped/ledgerTotal', () {
      final result = RevenueSplitMapper.applyResultFrom({
        'success': true,
        'message': 'Backfilled 26 payment(s) totalling Rs.31405.',
        'data': {
          'written': 26,
          'skipped': 0,
          'ledgerTotal': 31405,
          'expected': 31405,
        },
      });
      expect(result.written, 26);
      expect(result.skipped, 0);
      expect(result.ledgerTotal, 31405);
      expect(result.message, contains('Backfilled 26'));
    });

    test('backfill dry-run reads the preview and its rows', () {
      final preview = RevenueSplitMapper.previewFrom({
        'success': true,
        'data': {
          'wouldWrite': 1,
          'canApply': true,
          'blockedReason': null,
          'coverage': {'clear': true, 'gaps': <dynamic>[], 'summary': {}},
          'totals': {'pending': 1, 'totalReceived': 3000},
          'rows': [
            {
              'studentBatchId': 5,
              'batchId': 53,
              'batchName': 'Regular (Evening)',
              'amountReceived': 3000,
              'rule': {'id': 7, 'scope': 'batch', 'coachPercent': 40},
              'coachPercent': 40,
              'nahataPercent': 60,
              'coachAmount': 1200,
              'nahataAmount': 1800,
              'needsSplitRule': false,
              'status': 'pending',
            },
          ],
        },
      });

      expect(preview.wouldWrite, 1);
      expect(preview.canApply, isTrue);
      expect(preview.rows.single.batchName, 'Regular (Evening)');
      expect(preview.rows.single.ruleId, 7);
      expect(preview.rows.single.isPending, isTrue);
    });
  });

  // ───────────────────────────────────────────────────────────────────────────
  group('RevenueSplitRepositoryImpl — the wire', () {
    test(
      'includeInactive is sent as the literal string "true" only when set',
      () async {
        final calls = <Uri>[];
        ApiClient.instance.overrideHttpClient(
          MockClient((request) async {
            calls.add(request.url);
            return http.Response(jsonEncode({'success': true, 'data': []}), 200);
          }),
        );

        final repository = RevenueSplitRepositoryImpl();
        await repository.getRules();
        await repository.getRules(includeInactive: true);
        await repository.getRules(scope: 'batch', batchId: 53);

        expect(calls[0].queryParameters.containsKey('includeInactive'), isFalse);
        expect(calls[1].queryParameters['includeInactive'], 'true');
        expect(calls[2].queryParameters['scope'], 'batch');
        expect(calls[2].queryParameters['batchId'], '53');
      },
    );

    test('create posts the documented body and reads the created rule', () async {
      late Map<String, dynamic> body;
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({'success': true, 'data': _capturedRule}),
            201,
          );
        }),
      );

      final rule = await RevenueSplitRepositoryImpl().createRule(
        RevenueSplitDraft(
          scope: RevenueSplitScope.batch,
          batchId: 53,
          coachPercent: 40,
          effectiveFrom: DateTime(2026, 8, 1),
          notes: 'Evening badminton batch - agreed rate',
        ),
      );

      expect(body['scope'], 'batch');
      expect(body['batchId'], 53);
      expect(rule.id, 7);
    });

    test('update PUTs to the id route and reads affectedExistingPayments', () async {
      String? method;
      String? path;
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          method = request.method;
          path = request.url.path;
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Rule updated.',
              'data': _capturedRule,
              'affectedExistingPayments': 12,
            }),
            200,
          );
        }),
      );

      final (rule, affected) = await RevenueSplitRepositoryImpl().updateRule(
        7,
        RevenueSplitDraft(
          scope: RevenueSplitScope.batch,
          batchId: 53,
          coachPercent: 42,
          effectiveFrom: DateTime(2026, 9, 1),
        ),
      );

      expect(method, 'PUT');
      expect(path, endsWith('/revenue-splits/7'));
      expect(rule.id, 7);
      expect(affected, 12);
    });

    test('deactivate and reactivate PATCH the same route with isActive', () async {
      final bodies = <Map<String, dynamic>>[];
      final paths = <String>[];
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          paths.add(request.url.path);
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      final repository = RevenueSplitRepositoryImpl();
      await repository.deactivateRule(7);
      await repository.reactivateRule(7);

      expect(paths[0], endsWith('/revenue-splits/7/deactivate'));
      expect(paths[1], endsWith('/revenue-splits/7/deactivate'));
      expect(bodies[0]['isActive'], isFalse);
      expect(bodies[1]['isActive'], isTrue);
    });

    test('resolve sends batchId and paidOn as yyyy-MM-dd', () async {
      Uri? url;
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          url = request.url;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'matched': false,
                'coachPercent': 0,
                'nahataPercent': 100,
                'needsSplitRule': true,
              },
            }),
            200,
          );
        }),
      );

      await RevenueSplitRepositoryImpl().resolve(
        batchId: 53,
        paidOn: DateTime(2026, 8, 15),
      );

      expect(url!.queryParameters['batchId'], '53');
      expect(url!.queryParameters['paidOn'], '2026-08-15');
    });

    test('backfill apply and rollback always send {confirm: true}', () async {
      final bodies = <Map<String, dynamic>>[];
      final paths = <String>[];
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          paths.add(request.url.path);
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode({'success': true, 'data': {}}),
            200,
          );
        }),
      );

      final repository = RevenueSplitRepositoryImpl();
      await repository.applyBackfill();
      await repository.rollbackBackfill();

      expect(paths[0], endsWith('/revenue-splits/backfill/apply'));
      expect(paths[1], endsWith('/revenue-splits/backfill/rollback'));
      expect(bodies[0]['confirm'], isTrue);
      expect(bodies[1]['confirm'], isTrue);
    });

    test('backfill dry-run posts an empty body', () async {
      late Map<String, dynamic> body;
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'wouldWrite': 0, 'canApply': false},
            }),
            200,
          );
        }),
      );

      final preview = await RevenueSplitRepositoryImpl().dryRunBackfill();
      expect(body, isEmpty);
      expect(preview.canApply, isFalse);
    });
  });
}
