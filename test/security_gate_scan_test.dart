import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/navigation/role_router.dart';
import 'package:nahata_app/core/navigation/security_routes.dart';
import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/services/permission_service.dart';
import 'package:nahata_app/features/security/data/repositories/gate_scan_repository_impl.dart';
import 'package:nahata_app/features/security/domain/entities/gate_scan.dart';
import 'package:nahata_app/features/security/domain/entities/pass_code_router.dart';
import 'package:nahata_app/features/security/presentation/state/scan_journal.dart';
import 'package:nahata_app/models/profile_model.dart';

final Map<String, String> _secureStore = <String, String>{};

void _mockSecureStorage() {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
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

/// Builds a repository whose transport answers with [handler].
GateScanRepositoryImpl _repositoryThatAnswers(
  Future<http.Response> Function(http.Request request) handler,
) {
  ApiClient.instance.overrideHttpClient(MockClient(handler));
  return GateScanRepositoryImpl();
}

http.Response _json(Object body, {int status = 200}) => http.Response(
      jsonEncode(body),
      status,
      headers: const {'content-type': 'application/json'},
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _secureStore.clear();
    _mockSecureStorage();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  tearDown(() {
    ApiClient.instance.overrideHttpClient(http.Client());
    PermissionService.instance.clear();
  });

  group('PassCodeRouter', () {
    test('identifies each gate from its prefix', () {
      expect(
        PassCodeRouter.identify('GATEPASS-2026-000042'),
        GateScanKind.coaching,
      );
      expect(
        PassCodeRouter.identify('EVTPASS-2026-0003312'),
        GateScanKind.event,
      );
      expect(
        PassCodeRouter.identify('BOOK-2026-004021'),
        GateScanKind.courtBooking,
      );
      expect(PassCodeRouter.identify('VP-8FA23K'), GateScanKind.visitor);
    });

    test('returns null for an unknown format rather than guessing', () {
      // Sending an unknown code to the wrong /scan route would spend a leg of
      // somebody's real pass, so it must not be guessed.
      expect(PassCodeRouter.identify('RANDOM-1234'), isNull);
      expect(PassCodeRouter.identify(''), isNull);
    });

    test('pulls a code out of a URL or JSON payload', () {
      expect(
        PassCodeRouter.extract('https://nahata.app/p/EVTPASS-2026-0003312'),
        'EVTPASS-2026-0003312',
      );
      expect(
        PassCodeRouter.extract('{"passCode":"BOOK-2026-004021"}'),
        'BOOK-2026-004021',
      );
      expect(PassCodeRouter.extract('   gatepass-2026-000042  '),
          'GATEPASS-2026-000042');
      expect(PassCodeRouter.extract('   '), isNull);
    });

    test('resolve hands back both the code and its gate', () {
      final resolved = PassCodeRouter.resolve('  evtpass-2026-1 ');
      expect(resolved?.code, 'EVTPASS-2026-1');
      expect(resolved?.kind, GateScanKind.event);
    });
  });

  group('GateScanOutcome.fromMessage', () {
    test('reads the phrases the backends actually use', () {
      expect(
        GateScanOutcome.fromMessage('Pass already checked out'),
        GateScanOutcome.alreadyCheckedOut,
      );
      expect(
        GateScanOutcome.fromMessage('Visitor already checked in'),
        GateScanOutcome.alreadyCheckedIn,
      );
      expect(
        GateScanOutcome.fromMessage('This booking was cancelled'),
        GateScanOutcome.cancelled,
      );
      expect(
        GateScanOutcome.fromMessage('Pass has expired'),
        GateScanOutcome.expired,
      );
      expect(
        GateScanOutcome.fromMessage('Pass not found in the system.'),
        GateScanOutcome.invalid,
      );
    });

    test('an unrecognised message stays a refusal', () {
      // At a gate, an answer nobody can parse is a refusal, never an entry.
      expect(
        GateScanOutcome.fromMessage('something unexpected'),
        GateScanOutcome.invalid,
      );
    });
  });

  group('GateScanRepositoryImpl', () {
    test('reads a successful check in', () async {
      final repository = _repositoryThatAnswers((request) async {
        expect(request.url.path, endsWith('/visitor-passes/verify'));
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['scanType'], 'In');
        return _json({
          'success': true,
          'valid': true,
          'direction': 'In',
          'data': {
            'visitorName': 'Amit Shah',
            'phoneNumber': '9876543210',
            'visitPurpose': 'Delivery',
            'passCode': 'VP-1234',
            'status': 'Checked In',
          },
        });
      });

      final result = await repository.scanVisitorPass(
        passCode: 'VP-1234',
        direction: GateDirection.inbound,
      );

      expect(result.outcome, GateScanOutcome.granted);
      expect(result.isSuccess, isTrue);
      expect(result.headline, 'Entry Granted');
      expect(result.personName, 'Amit Shah');
      expect(result.direction, GateDirection.inbound);
      expect(
        result.facts.map((fact) => fact.label),
        containsAll(<String>['Phone', 'Purpose', 'Status']),
      );
    });

    test('reads a successful check out', () async {
      final repository = _repositoryThatAnswers(
        (_) async => _json({'success': true, 'valid': true, 'direction': 'Out'}),
      );

      final result = await repository.scanEventPass(
        passCode: 'EVTPASS-1',
        direction: GateDirection.outbound,
      );

      expect(result.outcome, GateScanOutcome.exitRecorded);
      expect(result.headline, 'Exit Recorded');
    });

    test('a 200 saying valid:false is a refusal, with its reason', () async {
      final repository = _repositoryThatAnswers(
        (_) async => _json({
          'success': false,
          'valid': false,
          'message': 'Pass not found in the system.',
        }),
      );

      final result = await repository.scanVisitorPass(
        passCode: 'VP-NOPE',
        direction: GateDirection.inbound,
      );

      expect(result.outcome, GateScanOutcome.invalid);
      expect(result.isSuccess, isFalse);
      expect(result.message, 'Pass not found in the system.');
      expect(result.headline, 'Invalid Visitor Pass');
    });

    test('a 409 refusal keeps the server message and never throws', () async {
      final repository = _repositoryThatAnswers(
        (_) async => _json(
          {'success': false, 'message': 'Booking already checked out'},
          status: 409,
        ),
      );

      final result = await repository.scanCourtBooking(
        passCode: 'BOOK-1',
        direction: GateDirection.outbound,
      );

      expect(result.outcome, GateScanOutcome.alreadyCheckedOut);
      expect(result.message, contains('already checked out'));
    });

    test('a 500 is a failed scan, not a verdict on the pass', () async {
      final repository = _repositoryThatAnswers(
        (_) async => _json({'message': 'boom'}, status: 500),
      );

      final result = await repository.scanCoachingPass('GATEPASS-1');

      // Nothing is known about the pass, so nobody may be let through on it.
      expect(result.outcome, GateScanOutcome.error);
      expect(result.isSuccess, isFalse);
      expect(result.severity, GateScanSeverity.danger);
    });

    test('an empty code is refused before any request goes out', () async {
      var called = false;
      final repository = _repositoryThatAnswers((_) async {
        called = true;
        return _json({'success': true});
      });

      final result = await repository.scanVisitorPass(
        passCode: '   ',
        direction: GateDirection.inbound,
      );

      expect(called, isFalse);
      expect(result.outcome, GateScanOutcome.invalid);
    });

    test('reads the six scan-stats counters', () async {
      final repository = _repositoryThatAnswers(
        (request) async {
          expect(request.url.path, contains('/event-passes/7/scan-stats'));
          return _json({
            'success': true,
            'data': {
              'totalPasses': 12,
              'totalPersons': 30,
              'in': 8,
              'out': 3,
              'notScanned': 4,
              'currentlyInside': 5,
            },
          });
        },
      );

      final stats = await repository.eventScanStats(7);

      expect(stats.totalPasses, 12);
      expect(stats.totalPersons, 30);
      expect(stats.inCount, 8);
      expect(stats.outCount, 3);
      expect(stats.notScanned, 4);
      expect(stats.currentlyInside, 5);
    });

    test('sends courtId and date to the court stats route', () async {
      late Uri seen;
      final repository = _repositoryThatAnswers((request) async {
        seen = request.url;
        return _json({'success': true, 'data': {'totalPasses': 1}});
      });

      await repository.courtScanStats(courtId: 3, date: '2026-08-07');

      expect(seen.queryParameters['courtId'], '3');
      expect(seen.queryParameters['date'], '2026-08-07');
    });

    test('reads the scan log, whatever key wraps the rows', () async {
      final repository = _repositoryThatAnswers(
        (request) async {
          expect(request.url.queryParameters['scannerRole'], 'SECURITY');
          return _json({
            'success': true,
            'data': {
              'logs': [
                {
                  'studentName': 'Riya Shah',
                  'phone': '9800000000',
                  'batchName': 'Evening Batch',
                  'passCode': 'GATEPASS-2026-000042',
                  'scannerName': 'Ravi',
                  'scannerRole': 'SECURITY',
                  'attendance': 'Present',
                  'date': '2026-08-07',
                  'checkInTime': '14:05:00',
                },
              ],
              'pagination': {'page': 1, 'limit': 50, 'total': 1},
            },
          });
        },
      );

      final page = await repository.scanLogs(
        date: '2026-08-07',
        scannerRole: 'SECURITY',
      );

      expect(page.items, hasLength(1));
      final row = page.items.single;
      expect(row.studentName, 'Riya Shah');
      expect(row.attendance, 'Present');
      expect(row.timeLabel, '14:05');
    });

    test('rejects a malformed email before the round trip', () async {
      var called = false;
      final repository = _repositoryThatAnswers((_) async {
        called = true;
        return _json({'success': true});
      });

      await expectLater(
        repository.sendBookingEmail(
          bookingId: 1,
          memberId: 2,
          recipientEmail: 'not-an-email',
        ),
        throwsA(isA<Exception>()),
      );
      expect(called, isFalse);
    });
  });

  group('ScanJournal', () {
    ScanJournalEntry entryFor(GateScanKind kind, GateScanOutcome outcome) =>
        ScanJournalEntry.of(
          GateScanResult(
            kind: kind,
            outcome: outcome,
            passCode: 'X-1',
            at: DateTime.now(),
          ),
        );

    test('counts today per gate, and the refusals', () async {
      final journal = ScanJournal();
      await journal.restore();

      await journal.record(
        GateScanResult(
          kind: GateScanKind.event,
          outcome: GateScanOutcome.granted,
          passCode: 'E-1',
          at: DateTime.now(),
        ),
      );
      await journal.record(
        GateScanResult(
          kind: GateScanKind.coaching,
          outcome: GateScanOutcome.invalid,
          passCode: 'C-1',
          at: DateTime.now(),
        ),
      );

      expect(journal.countToday(GateScanKind.event), 1);
      expect(journal.countToday(GateScanKind.courtBooking), 0);
      expect(journal.totalToday, 2);
      // The refusal no backend stores is exactly what this counter is for.
      expect(journal.failuresToday, 1);
      journal.dispose();
    });

    test('survives a restart', () async {
      final first = ScanJournal();
      await first.restore();
      await first.record(
        GateScanResult(
          kind: GateScanKind.visitor,
          outcome: GateScanOutcome.granted,
          passCode: 'VP-9',
          at: DateTime.now(),
          personName: 'Asha',
        ),
      );
      first.dispose();

      final second = ScanJournal();
      await second.restore();

      expect(second.entries, hasLength(1));
      expect(second.entries.single.personName, 'Asha');
      expect(second.entries.single.kind, GateScanKind.visitor);
      second.dispose();
    });

    test('keeps the newest first and caps the log', () async {
      final journal = ScanJournal();
      await journal.restore();

      for (var i = 0; i < ScanJournal.maxEntries + 20; i++) {
        await journal.record(
          GateScanResult(
            kind: GateScanKind.visitor,
            outcome: GateScanOutcome.granted,
            passCode: 'VP-$i',
            at: DateTime.now().add(Duration(seconds: i)),
          ),
        );
      }

      expect(journal.entries, hasLength(ScanJournal.maxEntries));
      expect(journal.entries.first.at.isAfter(journal.entries.last.at), isTrue);
      journal.dispose();
    });

    test('ignores a corrupt stored journal instead of failing', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'security_scan_journal_v1': 'not json at all',
      });

      final journal = ScanJournal();
      await journal.restore();

      expect(journal.isEmpty, isTrue);
      expect(journal.isRestored, isTrue);
      journal.dispose();
    });

    test('an unreadable entry is dropped, not the whole log', () {
      expect(ScanJournalEntry.fromJson({'kind': 'nonsense'}), isNull);
      expect(ScanJournalEntry.fromJson('rubbish'), isNull);
      expect(entryFor(GateScanKind.event, GateScanOutcome.granted).isSuccess,
          isTrue);
    });
  });

  group('Route access', () {
    void signInAs(String role) {
      PermissionService.instance.sync(
        ProfileModel.fromJson({'id': 1, 'role': role, 'permissions': const []}),
      );
    }

    test('guards, admins and complex admins may open the console', () {
      for (final role in const ['SECURITY', 'ADMIN', 'COMPLEX_ADMIN']) {
        signInAs(role);
        expect(RoleRouter.canOpenSecurity(), isTrue, reason: role);
        expect(
          RoleRouter.securityScreenFor(SecurityRoutes.dashboard),
          isNotNull,
          reason: role,
        );
      }
    });

    test('nobody else can', () {
      for (final role in const ['USER', 'COACH', 'STUDENT', '']) {
        signInAs(role);
        expect(RoleRouter.canOpenSecurity(), isFalse, reason: role);
        expect(
          RoleRouter.securityScreenFor(SecurityRoutes.dashboard),
          isNull,
          reason: role,
        );
      }
    });

    test('a path outside the console is refused even for a guard', () {
      signInAs('SECURITY');
      expect(RoleRouter.securityScreenFor('/admin/users'), isNull);
      expect(SecurityRoutes.owns('/admin/users'), isFalse);
      expect(SecurityRoutes.owns(SecurityRoutes.coachingScanner), isTrue);
    });
  });
}