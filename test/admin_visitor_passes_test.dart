import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/config/api_config.dart';
import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/features/admin/data/models/visitor_pass_model.dart';
import 'package:nahata_app/features/admin/data/repositories/visitor_pass_repository_impl.dart';
import 'package:nahata_app/features/admin/domain/entities/admin_role.dart';
import 'package:nahata_app/features/admin/domain/entities/paged.dart';
import 'package:nahata_app/features/admin/domain/entities/visitor_pass.dart';
import 'package:nahata_app/features/admin/domain/repositories/visitor_pass_repository.dart';
import 'package:nahata_app/features/admin/presentation/state/view_state.dart';
import 'package:nahata_app/features/admin/presentation/state/visitor_passes_controller.dart';
import 'package:nahata_app/features/admin/presentation/utils/visitor_pass_code.dart';
import 'package:nahata_app/features/admin/presentation/widgets/visitor_pass_qr_view.dart';
import 'package:nahata_app/models/sports_complex_model.dart';

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

VisitorPass _pass({
  int id = 1,
  String? code = 'NS-4821',
  String? name = 'Mahesh Pawar',
  String? status = 'Pending',
  DateTime? entry,
  DateTime? exit,
}) {
  return VisitorPass(
    id: id,
    passCode: code,
    visitorName: name,
    phoneNumber: '9876543210',
    visitPurpose: 'Meeting the manager',
    statusRaw: status,
    entryTime: entry,
    exitTime: exit,
    sportComplexId: 3,
    sportComplexName: 'Nahata Sports Complex',
  );
}

VisitorPassDraft _draft({
  String name = 'Mahesh Pawar',
  String phone = '9876543210',
  String purpose = 'Meeting the manager',
  int? complexId = 3,
}) {
  return VisitorPassDraft(
    visitorName: name,
    phoneNumber: phone,
    visitPurpose: purpose,
    sportComplexId: complexId,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _secureStore.clear();
    _mockSecureStorage();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // ---------------------------------------------------------------------------
  group('VisitorPass — the lifecycle', () {
    test('a fresh pass waits for the IN leg', () {
      final pass = _pass();
      expect(pass.status, VisitorPassStatus.pending);
      expect(pass.canCheckIn, isTrue);
      expect(pass.canCheckOut, isFalse);
      expect(pass.isSpent, isFalse);
      expect(pass.nextScan, VisitorScanType.checkIn);
    });

    test('a checked-in pass waits for the OUT leg', () {
      final pass = _pass(status: 'CHECKED_IN');
      expect(pass.status, VisitorPassStatus.checkedIn);
      expect(pass.canCheckIn, isFalse);
      expect(pass.canCheckOut, isTrue);
      expect(pass.nextScan, VisitorScanType.checkOut);
    });

    test('a checked-out pass is spent for good', () {
      final pass = _pass(status: 'Checked Out');
      expect(pass.status, VisitorPassStatus.checkedOut);
      expect(pass.isSpent, isTrue);
      expect(pass.canCheckIn, isFalse);
      expect(pass.canCheckOut, isFalse);
      expect(pass.nextScan, isNull);
    });

    test('expired and invalid are spent too, and never scannable', () {
      expect(_pass(status: 'EXPIRED').isSpent, isTrue);
      expect(_pass(status: 'cancelled').status, VisitorPassStatus.invalid);
      expect(_pass(status: 'cancelled').nextScan, isNull);
    });

    test('the timestamps decide when the status column is missing', () {
      // A list payload that omits the status must not read as Pending when the
      // visitor has demonstrably already left.
      final out = _pass(
        status: null,
        entry: DateTime(2026, 8, 5, 10),
        exit: DateTime(2026, 8, 5, 12),
      );
      expect(out.status, VisitorPassStatus.checkedOut);
      expect(out.isSpent, isTrue);

      final inside = _pass(status: null, entry: DateTime(2026, 8, 5, 10));
      expect(inside.status, VisitorPassStatus.checkedIn);
      expect(inside.canCheckOut, isTrue);

      expect(_pass(status: null).status, VisitorPassStatus.pending);
    });

    test('an unrecognised status is shown verbatim, never coerced', () {
      final pass = _pass(status: 'Awaiting gate clearance');
      expect(pass.status, isNull);
      expect(pass.statusLabel, 'Awaiting gate clearance');
      // Nothing is offered for a state the app does not understand.
      expect(pass.canCheckIn, isFalse);
      expect(pass.canCheckOut, isFalse);
    });

    test('the pass code addresses the record when there is no numeric id', () {
      expect(_pass(id: 0).reference, 'NS-4821');
      expect(_pass(id: 12).reference, '12');
      expect(_pass(id: 0, code: null).hasReference, isFalse);
    });

    test('the shared text carries what a gate needs, dashes and all', () {
      final text = _pass(status: 'Pending').shareText();
      expect(text, contains('Mahesh Pawar'));
      expect(text, contains('NS-4821'));
      expect(text, contains('Pending'));

      final sparse = const VisitorPass(id: 4).shareText();
      expect(sparse, contains('Name: -'));
    });
  });

  // ---------------------------------------------------------------------------
  group('VisitorScanType', () {
    test('the wire values are exactly In and Out', () {
      expect(VisitorScanType.checkIn.slug, 'In');
      expect(VisitorScanType.checkOut.slug, 'Out');
      expect(VisitorScanType.tryParse('out'), VisitorScanType.checkOut);
      expect(VisitorScanType.tryParse('check-in'), VisitorScanType.checkIn);
      expect(VisitorScanType.tryParse('sideways'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('VisitorPassMapper', () {
    test('reads the documented list envelope and its counters', () {
      final page = VisitorPassMapper.pageFrom(
        {
          'success': true,
          'message': 'Success',
          'data': [
            {
              'id': 12,
              'passCode': 'NS-4821',
              'visitorName': 'Mahesh Pawar',
              'phoneNumber': '9876543210',
              'visitPurpose': 'Meeting the manager',
              'status': 'Pending',
              'createdAt': '2026-08-05T09:30:00Z',
            },
            {'id': 13, 'passCode': 'NS-4822', 'visitorName': 'Sana Shaikh'},
          ],
          'total': 47,
          'page': 2,
          'limit': 20,
        },
        fallbackPage: 1,
        fallbackLimit: 20,
      );

      expect(page.items, hasLength(2));
      expect(page.total, 47);
      expect(page.page, 2);
      expect(page.effectiveTotalPages, 3);
      expect(page.items.first.visitorName, 'Mahesh Pawar');
      expect(page.items.first.status, VisitorPassStatus.pending);
    });

    test('snake_case rows read the same as camelCase ones', () {
      final pass = VisitorPassMapper.fromJson({
        'id': 12,
        'pass_code': 'NS-4821',
        'visitor_name': 'Mahesh Pawar',
        'phone_number': '9876543210',
        'visit_purpose': 'Delivery',
        'entry_time': '2026-08-05T10:00:00Z',
        'exit_time': '2026-08-05T12:30:00Z',
        'sport_complex_id': 3,
        'created_at': '2026-08-05T09:30:00Z',
      });

      expect(pass.passCode, 'NS-4821');
      expect(pass.visitorName, 'Mahesh Pawar');
      expect(pass.phoneNumber, '9876543210');
      expect(pass.visitPurpose, 'Delivery');
      expect(pass.entryTime, isNotNull);
      expect(pass.exitTime, isNotNull);
      expect(pass.sportComplexId, 3);
    });

    test('the venue and the issuer are read from nested objects', () {
      final pass = VisitorPassMapper.fromJson({
        'id': 12,
        'passCode': 'NS-4821',
        'sportComplex': {'id': 5, 'name': 'Kothrud Arena'},
        'createdBy': {'id': 91, 'name': 'Reception Desk'},
      });

      expect(pass.sportComplexId, 5);
      expect(pass.sportComplexName, 'Kothrud Arena');
      expect(pass.createdByName, 'Reception Desk');
      // The nested user's id must never become the pass's id.
      expect(pass.id, 12);
    });

    test('a bare createdBy string is still read', () {
      final pass = VisitorPassMapper.fromJson({
        'id': 12,
        'passCode': 'NS-4821',
        'createdBy': 'Reception Desk',
      });
      expect(pass.createdByName, 'Reception Desk');
    });

    test('rows with neither an id nor a code are dropped, not shown inert', () {
      final passes = VisitorPassMapper.listFrom({
        'data': [
          {'visitorName': 'Ghost'},
          {'id': 3, 'visitorName': 'Real'},
        ],
      });
      expect(passes, hasLength(1));
      expect(passes.single.visitorName, 'Real');
    });

    test('a pass nested under its own key is found', () {
      final pass = VisitorPassMapper.maybeFromBody({
        'success': true,
        'data': {
          'visitorPass': {'id': 9, 'passCode': 'NS-9', 'status': 'Checked In'},
        },
      });

      expect(pass, isNotNull);
      expect(pass!.id, 9);
      expect(pass.status, VisitorPassStatus.checkedIn);
    });

    test('a bare envelope carries no pass, rather than an empty one', () {
      expect(
        VisitorPassMapper.maybeFromBody({
          'success': false,
          'message': 'Pass not found',
        }),
        isNull,
      );
    });

    test('a check result keeps the server message and the visitor', () {
      final check = VisitorPassMapper.checkFrom(
        {
          'success': false,
          'message': 'This pass has already been checked out.',
          'data': {
            'id': 12,
            'passCode': 'NS-4821',
            'visitorName': 'Mahesh Pawar',
            'status': 'Checked Out',
          },
        },
        readOnly: false,
        success: false,
        scanType: VisitorScanType.checkOut,
      );

      expect(check.success, isFalse);
      expect(check.message, 'This pass has already been checked out.');
      expect(check.pass?.visitorName, 'Mahesh Pawar');
      expect(check.statusLabel, 'Checked Out');
      expect(check.title, 'Scan refused');
    });

    test('lookup validity falls back to the status when no flag is sent', () {
      final valid = VisitorPassMapper.checkFrom(
        {
          'success': true,
          'data': {'id': 1, 'passCode': 'NS-1', 'status': 'Pending'},
        },
        readOnly: true,
        success: true,
      );
      expect(valid.isValid, isTrue);
      expect(valid.title, 'Valid pass');

      final spent = VisitorPassMapper.checkFrom(
        {
          'success': true,
          'data': {'id': 1, 'passCode': 'NS-1', 'status': 'Checked Out'},
        },
        readOnly: true,
        success: true,
      );
      expect(spent.isValid, isFalse);
      expect(spent.title, 'Not usable');

      // An explicit flag always beats the inference.
      final flagged = VisitorPassMapper.checkFrom(
        {
          'success': true,
          'valid': false,
          'data': {'id': 1, 'passCode': 'NS-1', 'status': 'Pending'},
        },
        readOnly: true,
        success: true,
      );
      expect(flagged.isValid, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('VisitorPassCode', () {
    test('a bare code is taken as it is', () {
      expect(VisitorPassCode.extract(' NS-4821 '), 'NS-4821');
    });

    test('a JSON QR is unwrapped', () {
      expect(
        VisitorPassCode.extract('{"passCode":"NS-4821","type":"visitor"}'),
        'NS-4821',
      );
      expect(VisitorPassCode.extract('{"pass_code":"NS-99"}'), 'NS-99');
    });

    test('a URL QR gives up its code from the query or the path', () {
      expect(
        VisitorPassCode.extract('https://nahatasports.com/v?passCode=NS-4821'),
        'NS-4821',
      );
      expect(
        VisitorPassCode.extract(
          'https://nahatasports.com/visitor-passes/NS-77',
        ),
        'NS-77',
      );
    });

    test('the shared pass text is read back', () {
      expect(
        VisitorPassCode.extract(
          'Nahata Sports — Visitor Pass\nName: Mahesh\nPass code: NS-4821\n',
        ),
        'NS-4821',
      );
    });

    test('an unrelated QR is refused rather than sent to the server', () {
      expect(VisitorPassCode.extract('https://example.com/'), isNull);
      expect(VisitorPassCode.extract('Booking ID: 33\nName: Someone'), isNull);
      expect(VisitorPassCode.extract('  '), isNull);
      expect(VisitorPassCode.extract(null), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('VisitorPassQrSource', () {
    test('an absolute image URL is displayed as it is', () {
      final source = VisitorPassQrSource.of(
        _pass().copyWith(qrCode: 'https://cdn.example.com/qr/ns-4821.png'),
      );
      expect(source.imageUrl, 'https://cdn.example.com/qr/ns-4821.png');
      expect(source.payload, isNull);
    });

    test('a stored path is resolved against the web host', () {
      final source = VisitorPassQrSource.of(
        _pass().copyWith(qrCode: 'uploads/qr/ns-4821.png'),
      );
      expect(
        source.imageUrl,
        '${ApiConfig.attendanceBaseUrl}/uploads/qr/ns-4821.png',
      );
    });

    test('a data URI becomes inline bytes', () {
      // A 1x1 GIF, base64 — enough to prove the decode path.
      const data =
          'data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==';
      final source = VisitorPassQrSource.of(_pass().copyWith(qrCode: data));
      expect(source.imageBytes, isNotNull);
      expect(source.imageUrl, isNull);
    });

    test('a non-image URL is encoded rather than shown as a picture', () {
      final source = VisitorPassQrSource.of(
        _pass().copyWith(qrCode: 'https://nahatasports.com/v?passCode=NS-4821'),
      );
      expect(source.imageUrl, isNull);
      expect(source.payload, 'https://nahatasports.com/v?passCode=NS-4821');
    });

    test('with no QR field at all, the pass code is encoded', () {
      final source = VisitorPassQrSource.of(_pass());
      expect(source.payload, 'NS-4821');
      expect(source.isEmpty, isFalse);

      expect(VisitorPassQrSource.of(const VisitorPass(id: 3)).isEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('VisitorPassRepositoryImpl — the wire', () {
    test('the list route sends paging and only a non-empty search', () async {
      final calls = <Uri>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          calls.add(request.url);
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      final repository = VisitorPassRepositoryImpl();
      await repository.fetchVisitorPasses(page: 2, limit: 50);
      await repository.fetchVisitorPasses(search: 'mahesh');

      expect(calls[0].path, endsWith('/visitor-passes'));
      expect(calls[0].queryParameters['page'], '2');
      expect(calls[0].queryParameters['limit'], '50');
      expect(calls[0].queryParameters.containsKey('search'), isFalse);
      expect(calls[1].queryParameters['search'], 'mahesh');
    });

    test('detail and delete address the record by id or by code', () async {
      final calls = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'id': 12, 'passCode': 'NS-4821'},
            }),
            200,
          );
        }),
      );

      final repository = VisitorPassRepositoryImpl();
      await repository.fetchVisitorPass('12');
      await repository.fetchVisitorPass('NS-4821');
      await repository.deleteVisitorPass('12');

      expect(calls[0], 'GET /api/visitor-passes/12');
      expect(calls[1], 'GET /api/visitor-passes/NS-4821');
      expect(calls[2], 'DELETE /api/visitor-passes/12');
    });

    test('create posts the documented body', () async {
      late Map<String, dynamic> body;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'id': 12, 'passCode': 'NS-4821'},
            }),
            201,
          );
        }),
      );

      final created = await VisitorPassRepositoryImpl().createVisitorPass(
        _draft(phone: '98765 43210'),
      );

      expect(body['visitorName'], 'Mahesh Pawar');
      // Formatting typed into the field never reaches the API.
      expect(body['phoneNumber'], '9876543210');
      expect(body['visitPurpose'], 'Meeting the manager');
      expect(body['sportComplexId'], 3);
      expect(created.passCode, 'NS-4821');
    });

    test(
      'a body the server could only reject never leaves the device',
      () async {
        var called = false;
        ApiClient.instance.overrideHttpClient(
          MockClient((request) async {
            called = true;
            return http.Response(jsonEncode({'success': true}), 200);
          }),
        );

        final repository = VisitorPassRepositoryImpl();

        await expectLater(
          repository.createVisitorPass(_draft(name: '  ')),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          repository.createVisitorPass(_draft(phone: '98765')),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          repository.createVisitorPass(_draft(purpose: '')),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          repository.createVisitorPass(_draft(complexId: null)),
          throwsA(isA<ValidationException>()),
        );

        expect(called, isFalse);
      },
    );

    test(
      'a create the server did not echo is a failure, not a blank pass',
      () async {
        ApiClient.instance.overrideHttpClient(
          MockClient((request) async {
            return http.Response(
              jsonEncode({'success': true, 'message': 'Created'}),
              201,
            );
          }),
        );

        await expectLater(
          VisitorPassRepositoryImpl().createVisitorPass(_draft()),
          throwsA(isA<ServerException>()),
        );
      },
    );

    test('verify posts the pass code and the scan type', () async {
      final bodies = <Map<String, dynamic>>[];
      final paths = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          paths.add(request.url.path);
          bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response(
            jsonEncode({
              'success': true,
              'message': 'Visitor checked in',
              'data': {'id': 12, 'passCode': 'NS-4821', 'status': 'Checked In'},
            }),
            200,
          );
        }),
      );

      final result = await VisitorPassRepositoryImpl().verifyPass(
        passCode: 'NS-4821',
        scanType: VisitorScanType.checkIn,
      );

      expect(paths.single, endsWith('/visitor-passes/verify'));
      expect(bodies.single, {'passCode': 'NS-4821', 'scanType': 'In'});
      expect(result.success, isTrue);
      expect(result.readOnly, isFalse);
      expect(result.pass?.status, VisitorPassStatus.checkedIn);
      expect(result.title, 'Checked in');
    });

    test(
      'a refused scan is reported with its reason and the current state',
      () async {
        final paths = <String>[];

        ApiClient.instance.overrideHttpClient(
          MockClient((request) async {
            paths.add(request.url.path);

            if (request.url.path.endsWith('/verify')) {
              return http.Response(
                jsonEncode({
                  'success': false,
                  'message': 'This pass has already been checked out.',
                }),
                400,
              );
            }

            // The read-only twin fills in who the visitor is and where the pass
            // stands — a 400 body does not survive the typed exception.
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'id': 12,
                  'passCode': 'NS-4821',
                  'visitorName': 'Mahesh Pawar',
                  'status': 'Checked Out',
                },
              }),
              200,
            );
          }),
        );

        final result = await VisitorPassRepositoryImpl().verifyPass(
          passCode: 'NS-4821',
          scanType: VisitorScanType.checkOut,
        );

        expect(result.success, isFalse);
        expect(result.message, 'This pass has already been checked out.');
        expect(result.pass?.visitorName, 'Mahesh Pawar');
        expect(result.statusLabel, 'Checked Out');
        expect(paths, [
          endsWith('/visitor-passes/verify'),
          endsWith('/visitor-passes/lookup'),
        ]);
      },
    );

    test('a session failure during a scan still propagates', () async {
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          return http.Response(
            jsonEncode({'success': false, 'message': 'Forbidden'}),
            403,
          );
        }),
      );

      await expectLater(
        VisitorPassRepositoryImpl().verifyPass(
          passCode: 'NS-4821',
          scanType: VisitorScanType.checkIn,
        ),
        throwsA(isA<ForbiddenException>()),
      );
    });

    test('lookup only ever calls the lookup route', () async {
      final paths = <String>[];
      late Map<String, dynamic> body;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          paths.add(request.url.path);
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'id': 12, 'passCode': 'NS-4821', 'status': 'Pending'},
            }),
            200,
          );
        }),
      );

      final result = await VisitorPassRepositoryImpl().lookupPass('NS-4821');

      expect(paths.single, endsWith('/visitor-passes/lookup'));
      expect(body, {'passCode': 'NS-4821'});
      expect(result.readOnly, isTrue);
      expect(result.scanType, isNull);
      expect(result.isValid, isTrue);
    });

    test(
      'a pass the lookup cannot find is invalid, not an exception',
      () async {
        ApiClient.instance.overrideHttpClient(
          MockClient((request) async {
            return http.Response(
              jsonEncode({'success': false, 'message': 'Invalid pass code'}),
              404,
            );
          }),
        );

        final result = await VisitorPassRepositoryImpl().lookupPass('NOPE-1');
        expect(result.success, isFalse);
        expect(result.isValid, isFalse);
        expect(result.message, 'Invalid pass code');
        expect(result.title, 'Pass not found');
      },
    );

    test(
      'the email route takes the recipient and validates it first',
      () async {
        final paths = <String>[];
        late Map<String, dynamic> body;

        ApiClient.instance.overrideHttpClient(
          MockClient((request) async {
            paths.add(request.url.path);
            body = jsonDecode(request.body) as Map<String, dynamic>;
            return http.Response(
              jsonEncode({
                'success': true,
                'message': 'Visitor Pass sent successfully.',
              }),
              200,
            );
          }),
        );

        final repository = VisitorPassRepositoryImpl();

        await expectLater(
          repository.sendPassEmail(
            idOrCode: '12',
            recipientEmail: 'not-an-email',
            recipientName: 'Mahesh',
          ),
          throwsA(isA<ValidationException>()),
        );

        final message = await repository.sendPassEmail(
          idOrCode: '12',
          recipientEmail: 'visitor@example.com',
          recipientName: 'Mahesh Pawar',
        );

        expect(paths.single, endsWith('/visitor-passes/12/send-email'));
        expect(body, {
          'recipientEmail': 'visitor@example.com',
          'recipientName': 'Mahesh Pawar',
        });
        expect(message, 'Visitor Pass sent successfully.');
      },
    );
  });

  // ---------------------------------------------------------------------------
  group('VisitorPassesController', () {
    test('paging replaces the rows, scrolling appends them', () async {
      final repository = _FakeRepository(total: 5, pageSize: 2);
      final controller = VisitorPassesController(repository);

      await controller.load();
      expect(controller.passes, hasLength(2));
      expect(controller.state, ViewState.ready);

      await controller.loadMore();
      expect(controller.passes, hasLength(4));
      expect(controller.page.page, 2);

      await controller.load(page: 1);
      expect(controller.passes, hasLength(2));

      controller.dispose();
    });

    test('an overlapping page never shows the same pass twice', () async {
      final repository = _FakeRepository(total: 4, pageSize: 2, overlap: true);
      final controller = VisitorPassesController(repository);

      await controller.load();
      await controller.loadMore();

      final codes = controller.passes.map((pass) => pass.passCode).toList();
      expect(codes.toSet(), hasLength(codes.length));

      controller.dispose();
    });

    test('load-more stops at the last page', () async {
      final repository = _FakeRepository(total: 2, pageSize: 2);
      final controller = VisitorPassesController(repository);

      await controller.load();
      expect(controller.hasMore, isFalse);

      await controller.loadMore();
      expect(repository.listCalls, 1);

      controller.dispose();
    });

    test('a failed load keeps the rows already on screen', () async {
      final repository = _FakeRepository(total: 4, pageSize: 2);
      final controller = VisitorPassesController(repository);

      await controller.load();
      repository.failNext = true;
      await controller.load(page: 2);

      expect(controller.state, ViewState.failed);
      expect(controller.error, isNotNull);
      expect(controller.passes, hasLength(2));

      controller.dispose();
    });

    test('a successful scan patches the row rather than reloading', () async {
      final repository = _FakeRepository(total: 2, pageSize: 2);
      final controller = VisitorPassesController(repository);

      await controller.load();
      expect(controller.passes.first.status, VisitorPassStatus.pending);

      final before = repository.listCalls;
      final result = await controller.verify(
        passCode: controller.passes.first.passCode!,
        scanType: VisitorScanType.checkIn,
      );

      expect(result.success, isTrue);
      expect(controller.passes.first.status, VisitorPassStatus.checkedIn);
      expect(repository.listCalls, before);

      controller.dispose();
    });

    test('creating refreshes back to the first page', () async {
      final repository = _FakeRepository(total: 4, pageSize: 2);
      final controller = VisitorPassesController(repository);

      await controller.load(page: 2);
      await controller.create(_draft());

      expect(controller.page.page, 1);
      expect(repository.created, 1);

      controller.dispose();
    });

    test('deleting the last row of a page steps back a page', () async {
      final repository = _FakeRepository(total: 3, pageSize: 1);
      final controller = VisitorPassesController(repository);

      await controller.load(page: 3);
      expect(controller.passes, hasLength(1));

      await controller.delete(controller.passes.first);
      expect(controller.page.page, 2);

      controller.dispose();
    });

    test('delete is offered to ADMIN and COMPLEX_ADMIN only', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'user': jsonEncode({'id': 1, 'name': 'Desk', 'role': 'EMPLOYEE'}),
      });

      final controller = VisitorPassesController(_FakeRepository());
      expect(controller.canDelete, isFalse);

      await controller.loadRole();
      expect(controller.roleLoaded, isTrue);
      expect(controller.canDelete, isFalse);

      // The two roles the module documents as allowed to delete — and only
      // those two.
      expect(VisitorPassesController.deleteRoles, {
        AdminRole.admin,
        AdminRole.complexAdmin,
      });

      controller.dispose();
    });

    test('the venue list is fetched once and reused', () async {
      final repository = _FakeRepository();
      final controller = VisitorPassesController(repository);

      await controller.loadComplexes();
      await controller.loadComplexes();
      expect(repository.complexCalls, 1);

      await controller.loadComplexes(refresh: true);
      expect(repository.complexCalls, 2);

      controller.dispose();
    });
  });
}

/// A repository that answers from memory, so the controller can be exercised
/// without a socket.
class _FakeRepository implements VisitorPassRepository {
  _FakeRepository({this.total = 0, this.pageSize = 20, this.overlap = false});

  final int total;
  final int pageSize;

  /// Repeats the last row of the previous page, the way a live list does when
  /// a pass is created while the desk is scrolling.
  final bool overlap;

  bool failNext = false;

  int listCalls = 0;
  int complexCalls = 0;
  int created = 0;
  final List<String> deleted = <String>[];

  @override
  Future<Paged<VisitorPass>> fetchVisitorPasses({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    if (failNext) {
      failNext = false;
      throw const ServerException('Server is temporarily unavailable.');
    }

    listCalls++;

    final start = (page - 1) * pageSize - (overlap && page > 1 ? 1 : 0);
    final items = <VisitorPass>[];
    for (
      var index = start;
      index < start + pageSize && index < total;
      index++
    ) {
      items.add(_pass(id: index + 1, code: 'NS-${index + 1}'));
    }

    return Paged<VisitorPass>(
      items: items,
      page: page,
      limit: pageSize,
      total: total,
      totalPages: (total / pageSize).ceil(),
    );
  }

  @override
  Future<VisitorPass> fetchVisitorPass(String idOrCode) async =>
      _pass(code: idOrCode);

  @override
  Future<VisitorPass> createVisitorPass(VisitorPassDraft draft) async {
    created++;
    return _pass(id: 99, code: 'NS-99', name: draft.visitorName);
  }

  @override
  Future<VisitorPassCheck> verifyPass({
    required String passCode,
    required VisitorScanType scanType,
  }) async {
    return VisitorPassCheck(
      success: true,
      readOnly: false,
      scanType: scanType,
      message: '${scanType.label} recorded.',
      pass: _pass(
        id: 1,
        code: passCode,
        status: scanType == VisitorScanType.checkIn
            ? 'Checked In'
            : 'Checked Out',
      ),
    );
  }

  @override
  Future<VisitorPassCheck> lookupPass(String passCode) async {
    return VisitorPassCheck(
      success: true,
      readOnly: true,
      pass: _pass(code: passCode),
    );
  }

  @override
  Future<String> sendPassEmail({
    required String idOrCode,
    required String recipientEmail,
    required String recipientName,
  }) async => 'Visitor Pass sent successfully.';

  @override
  Future<void> deleteVisitorPass(String idOrCode) async {
    deleted.add(idOrCode);
  }

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async {
    complexCalls++;
    return const [
      SportsComplex(id: 3, name: 'Nahata Sports Complex', city: 'Pune'),
    ];
  }
}
