import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/features/admin/data/models/security_guard_model.dart';
import 'package:nahata_app/features/admin/data/repositories/security_guard_repository_impl.dart';
import 'package:nahata_app/features/admin/domain/entities/admin_role.dart';
import 'package:nahata_app/features/admin/domain/entities/employee_vocabulary.dart';
import 'package:nahata_app/features/admin/domain/entities/paged.dart';
import 'package:nahata_app/features/admin/domain/entities/security_guard.dart';
import 'package:nahata_app/features/admin/domain/repositories/security_guard_repository.dart';
import 'package:nahata_app/features/admin/presentation/state/security_guards_controller.dart';
import 'package:nahata_app/features/admin/presentation/state/view_state.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _secureStore.clear();
    _mockSecureStorage();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // ---------------------------------------------------------------------------
  group('AssignedArea', () {
    test('the members are the database enum, title-cased as the API echoes it',
        () {
      // `Parking` is the one member with live proof: a POST on 2026-08-04 was
      // accepted with it and echoed it back capitalised.
      expect(AssignedArea.values.map((area) => area.slug), [
        'Main Gates',
        'Parking',
        'Courts',
        'Building',
        'Perimeter',
      ]);
    });

    test('reads are case- and separator-insensitive', () {
      // The wire value must be exact, but nothing about a *read* should be
      // brittle — a row stored as `parking` still resolves.
      expect(AssignedArea.tryParse('parking'), AssignedArea.parking);
      expect(AssignedArea.tryParse('MAIN_GATES'), AssignedArea.mainGates);
      expect(AssignedArea.tryParse('main gates'), AssignedArea.mainGates);
      expect(AssignedArea.tryParse('Perimeter'), AssignedArea.perimeter);
      expect(AssignedArea.tryParse(''), isNull);
      expect(AssignedArea.tryParse(null), isNull);
    });

    test('a value outside the enum still renders instead of vanishing', () {
      // "Backgate" is exactly what the server refused; the table must still
      // show it for a row that somehow holds it.
      expect(AssignedArea.labelFor('Backgate'), 'Backgate');
      expect(AssignedArea.labelFor('back_gate'), 'Back Gate');
      expect(AssignedArea.labelFor(null), '—');
    });

    test('the guard entity exposes both the parsed area and a safe label', () {
      const known = SecurityGuard(id: '1', assignedArea: 'parking');
      expect(known.area, AssignedArea.parking);
      expect(known.assignedAreaLabel, 'Parking');

      const legacy = SecurityGuard(id: '2', assignedArea: 'Backgate');
      expect(legacy.area, isNull);
      expect(legacy.assignedAreaLabel, 'Backgate');
    });
  });

  group('SecurityGuardMapper', () {
    // The exact body POST /admin/security-guards returned on 2026-08-04. This
    // is the first live capture of the route, and it caught a real bug: the
    // row embeds a `user`, the mapper used to unwrap into it, and every
    // `/{guardId}` call afterwards addressed the user id instead — the console
    // asked for `/admin/security-guards/582` and got a 404.
    const liveCreateResponse = <String, dynamic>{
      'success': true,
      'message': 'Security guard created successfully',
      'data': {
        'id': 22,
        'userId': 585,
        'sportComplexId': 1,
        'guardId': '567',
        'licenseNumber': null,
        'shift': 'Evening',
        'assignedArea': 'Parking',
        'joiningDate': '2026-08-05',
        'salary': null,
        'status': 'Active',
        'createdAt': '2026-08-04T07:06:33.347Z',
        'updatedAt': '2026-08-04T07:06:33.347Z',
        'user': {
          'id': 585,
          'name': 'Major',
          'email': 'major@gmil.com',
          'phone_number': '9856784565',
        },
      },
    };

    test('the live create response yields the guard id, never the user id', () {
      final guard = SecurityGuardMapper.maybeFromBody(
        liveCreateResponse['data'],
      );

      expect(guard, isNotNull);
      // 22 is the guard record; 585 is the person. Every row action is
      // path-scoped, so getting this wrong is a 404 or someone else's record.
      expect(guard!.id, '22');
      expect(guard.id, isNot('585'));
      expect(guard.guardCode, '567');
    });

    test('the embedded user fills the person fields without hijacking the row',
        () {
      final guard = SecurityGuardMapper.fromJson(
        Map<String, dynamic>.from(liveCreateResponse['data'] as Map),
      );

      // Name, email and phone live only inside `user` — JsonReader.pick still
      // reaches them through its envelope fallback.
      expect(guard.fullName, 'Major');
      expect(guard.email, 'major@gmil.com');
      expect(guard.phone, '9856784565');

      // …while every field that belongs to the guard record survives, which is
      // what unwrapping into `user` destroyed.
      expect(guard.shift, Shift.evening);
      expect(guard.assignedArea, 'Parking');
      expect(guard.status, AdminUserStatus.active);
      expect(guard.sportComplexId, 1);
      expect(guard.joiningDate, DateTime.parse('2026-08-05'));
      expect(guard.licenseNumber, isNull);
      expect(guard.salary, isNull);
    });

    test('a whole envelope unwraps to the guard, not to the nested user', () {
      final guard = SecurityGuardMapper.fromJson(liveCreateResponse);

      expect(guard.id, '22');
      expect(guard.fullName, 'Major');
      expect(guard.assignedArea, 'Parking');
    });

    test('parses a full row, keeping id and guard code distinct', () {
      final guard = SecurityGuardMapper.fromJson({
        'id': 'sg-1',
        'guardId': 'SG-204',
        'fullName': 'Sanjay Pawar',
        'email': 'sanjay@example.com',
        'phone': '9822001100',
        'licenseNumber': 'MH-SEC-9911',
        'assignedArea': 'Main Gate',
        'shift': 'Night',
        'salary': 28000,
        'status': 'Active',
        'joiningDate': '2025-03-14',
        'sportComplex': {'id': 4, 'name': 'Kothrud Arena', 'city': 'Pune'},
      });

      expect(guard.id, 'sg-1');
      expect(guard.guardCode, 'SG-204');
      expect(guard.fullName, 'Sanjay Pawar');
      expect(guard.licenseNumber, 'MH-SEC-9911');
      expect(guard.assignedArea, 'Main Gate');
      expect(guard.shift, Shift.night);
      expect(guard.salary, 28000);
      expect(guard.status, AdminUserStatus.active);
      expect(guard.joiningDate, DateTime.parse('2025-03-14'));
      expect(guard.sportComplexId, 4);
      expect(guard.sportComplexName, 'Kothrud Arena');
      expect(guard.sportComplexCity, 'Pune');
    });

    test('parses snake_case and a salary sent as a formatted string', () {
      final guard = SecurityGuardMapper.fromJson({
        '_id': 'sg-2',
        'guard_id': 'SG-9',
        'full_name': 'Meena Rao',
        'assigned_area': 'Parking',
        'license_number': 'MH-1',
        'salary': '₹28,500.50',
        'joining_date': '15-04-2024',
      });

      expect(guard.id, 'sg-2');
      expect(guard.guardCode, 'SG-9');
      expect(guard.displayName, 'Meena Rao');
      expect(guard.assignedArea, 'Parking');
      expect(guard.licenseNumber, 'MH-1');
      expect(guard.salary, 28500.5);
      expect(guard.joiningDate, DateTime.parse('2024-04-15'));
    });

    test('a row with no database id falls back to the guard code', () {
      // Every row action is path-scoped, so a row with no usable id would be
      // inert — the badge number stands in rather than dropping the row.
      final guard = SecurityGuardMapper.fromJson({
        'guardId': 'SG-77',
        'fullName': 'Only a code',
      });

      expect(guard.id, 'SG-77');
      expect(guard.guardCode, 'SG-77');
    });

    test('drops rows with nothing to identify them by', () {
      final guards = SecurityGuardMapper.listFrom({
        'securityGuards': [
          {'id': 'sg-1', 'fullName': 'Kept'},
          {'fullName': 'Dropped'},
        ],
      });

      expect(guards.map((g) => g.id), ['sg-1']);
    });

    test('unwraps a nested detail envelope', () {
      final guard = SecurityGuardMapper.fromJson({
        'securityGuard': {'id': 'sg-5', 'assignedArea': 'North Wing'},
      });

      expect(guard.id, 'sg-5');
      expect(guard.assignedArea, 'North Wing');
    });

    test('reads pagination meta, and derives pages when it is absent', () {
      final withMeta = SecurityGuardMapper.pageFrom({
        'guards': [
          {'id': 'a'},
          {'id': 'b'},
        ],
        'meta': {'page': 2, 'limit': 20, 'total': 41, 'totalPages': 3},
      }, fallbackPage: 1, fallbackLimit: 20);

      expect(withMeta.page, 2);
      expect(withMeta.total, 41);
      expect(withMeta.effectiveTotalPages, 3);

      final derived = SecurityGuardMapper.pageFrom({
        'data': [
          {'id': 'a'},
        ],
        'total': 45,
      }, fallbackPage: 1, fallbackLimit: 20);

      expect(derived.total, 45);
      expect(derived.effectiveTotalPages, 3);
    });

    test('mergedWith keeps a field the detail route omitted', () {
      const row = SecurityGuard(
        id: 'sg-1',
        guardCode: 'SG-1',
        assignedArea: 'Main Gate',
      );
      const detail = SecurityGuard(id: 'sg-1', licenseNumber: 'MH-1');

      final merged = row.mergedWith(detail);
      expect(merged.assignedArea, 'Main Gate');
      expect(merged.licenseNumber, 'MH-1');
    });
  });

  // ---------------------------------------------------------------------------
  group('SecurityGuardCredentialsMapper', () {
    test('reads the temporary-password shapes', () {
      for (final key in const [
        'temporaryPassword',
        'temporary_password',
        'tempPassword',
        'password',
      ]) {
        final credentials = SecurityGuardCredentialsMapper.fromJson({
          'data': {'email': 'a@b.com', key: 'secret123'},
        });
        expect(credentials.password, 'secret123', reason: key);
        expect(credentials.email, 'a@b.com');
      }
    });

    test('toString never leaks the password', () {
      const credentials = SecurityGuardCredentials(
        email: 'a@b.com',
        password: 'secret123',
      );
      expect(credentials.toString(), isNot(contains('secret123')));
      expect(credentials.toString(), contains('***'));
    });
  });

  // ---------------------------------------------------------------------------
  group('SecurityGuardDraft', () {
    test('the create body carries every documented key', () {
      final body = SecurityGuardDraft(
        fullName: '  Sanjay Pawar ',
        email: ' sanjay@example.com ',
        phone: '9822001100',
        password: 'secret123',
        guardCode: 'SG-204',
        licenseNumber: 'MH-SEC-9911',
        shift: Shift.rotational,
        assignedArea: ' Main Gate ',
        joiningDate: DateTime(2025, 3, 14),
        salary: '28000',
        sportComplexId: 4,
      ).toCreateJson();

      expect(body.keys, {
        'fullName',
        'email',
        'phone',
        'password',
        'guardId',
        'licenseNumber',
        'shift',
        'assignedArea',
        'joiningDate',
        'salary',
        'sportComplexId',
        'status',
      });
      expect(body['fullName'], 'Sanjay Pawar');
      expect(body['email'], 'sanjay@example.com');
      expect(body['guardId'], 'SG-204');
      expect(body['assignedArea'], 'Main Gate');
      expect(body['shift'], 'Rotational');
      expect(body['joiningDate'], '2025-03-14');
      expect(body['sportComplexId'], 4);
      // Nothing chosen on the form means the guard starts Active.
      expect(body['status'], 'Active');
    });

    test('dates are formatted as yyyy-MM-dd with padding', () {
      expect(SecurityGuardDraft.formatDate(DateTime(2025, 1, 5)), '2025-01-05');
      expect(SecurityGuardDraft.formatDate(null), '');
    });

    test('an update carries only the five editable fields', () {
      final body = SecurityGuardDraft(
        fullName: 'New Name',
        phone: '9000000000',
        shift: Shift.evening,
        assignedArea: 'North Wing',
        status: AdminUserStatus.inactive,
        // Everything below is create-only and must not reach the wire.
        email: 'ignored@example.com',
        guardCode: 'SG-999',
        licenseNumber: 'MH-2',
        salary: '99999',
        sportComplexId: 7,
        joiningDate: DateTime(2020, 1, 1),
      ).toUpdateJson();

      expect(body.keys, {
        'fullName',
        'phone',
        'shift',
        'assignedArea',
        'status',
      });
      expect(body['shift'], 'Evening');
      expect(body['status'], 'Inactive');
    });

    test('an update with nothing set is empty', () {
      expect(const SecurityGuardDraft().toUpdateJson(), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  group('SecurityGuardRepositoryImpl', () {
    tearDown(() {
      ApiClient.instance.overrideHttpClient(http.Client());
    });

    test('the list forwards search and every filter', () async {
      late Uri captured;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      await SecurityGuardRepositoryImpl().fetchGuards(
        page: 2,
        limit: 50,
        search: '  sanjay  ',
        status: AdminUserStatus.active,
        shift: Shift.morning,
        sportComplexId: 4,
        assignedArea: ' Main Gate ',
        sortBy: 'fullName',
        descending: true,
      );

      expect(captured.path, endsWith('/admin/security-guards'));
      expect(captured.queryParameters['page'], '2');
      expect(captured.queryParameters['limit'], '50');
      expect(captured.queryParameters['search'], 'sanjay');
      expect(captured.queryParameters['status'], 'Active');
      expect(captured.queryParameters['shift'], 'Morning');
      expect(captured.queryParameters['sportComplexId'], '4');
      expect(captured.queryParameters['assignedArea'], 'Main Gate');
      expect(captured.queryParameters['sortOrder'], 'desc');
    });

    test('an unset filter is never sent as an empty parameter', () async {
      late Uri captured;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      await SecurityGuardRepositoryImpl().fetchGuards(page: 1, limit: 20);

      for (final key in [
        'search',
        'status',
        'shift',
        'assignedArea',
        'sortBy',
      ]) {
        expect(captured.queryParameters.containsKey(key), isFalse, reason: key);
      }
    });

    test('create posts the documented payload', () async {
      String? body;
      String? path;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          body = request.body;
          path = request.url.path;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'id': 'sg-9'},
            }),
            201,
          );
        }),
      );

      final created = await SecurityGuardRepositoryImpl().createGuard(
        SecurityGuardDraft(
          fullName: 'Sanjay',
          email: 'sanjay@example.com',
          phone: '9822001100',
          password: 'secret123',
          guardCode: 'SG-1',
          licenseNumber: 'MH-1',
          shift: Shift.night,
          assignedArea: 'Main Gate',
          joiningDate: DateTime(2025, 6, 1),
          sportComplexId: 4,
        ),
      );

      expect(path, endsWith('/admin/security-guards'));
      final decoded = jsonDecode(body!) as Map<String, dynamic>;
      expect(decoded['guardId'], 'SG-1');
      expect(decoded['shift'], 'Night');
      expect(decoded['assignedArea'], 'Main Gate');
      expect(decoded['sportComplexId'], 4);
      expect(created.id, 'sg-9');
    });

    test('create without a complex fails before the round trip', () async {
      var called = false;
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        SecurityGuardRepositoryImpl().createGuard(
          const SecurityGuardDraft(fullName: 'No complex'),
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(called, isFalse);
    });

    test('an update with nothing changed never reaches the network', () async {
      var called = false;
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        SecurityGuardRepositoryImpl().updateGuard(
          'sg-1',
          const SecurityGuardDraft(),
        ),
        throwsA(isA<BadRequestException>()),
      );
      expect(called, isFalse);
    });

    test('the password routes hit their documented paths', () async {
      final calls = <String>[];
      String? resetBody;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          if (request.method == 'POST') resetBody = request.body;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'email': 'a@b.com', 'temporaryPassword': 'secret123'},
            }),
            200,
          );
        }),
      );

      final repository = SecurityGuardRepositoryImpl();
      final credentials = await repository.fetchCredentials('sg-1');
      await repository.resetPassword('sg-1', 'newSecret123');

      expect(calls[0], endsWith('GET /api/admin/security-guards/sg-1/password'));
      expect(
        calls[1],
        endsWith('POST /api/admin/security-guards/sg-1/reset-password'),
      );
      expect(credentials.password, 'secret123');
      expect(jsonDecode(resetBody!)['password'], 'newSecret123');
    });

    test('delete hits the id-scoped path', () async {
      final calls = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      await SecurityGuardRepositoryImpl().deleteGuard('sg-1');
      expect(calls.single, endsWith('DELETE /api/admin/security-guards/sg-1'));
    });

    test('a rejected write throws with the server message', () async {
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'success': false,
              'message': 'That guard ID is already taken.',
            }),
            409,
          );
        }),
      );

      await expectLater(
        SecurityGuardRepositoryImpl().createGuard(
          const SecurityGuardDraft(fullName: 'Dup', sportComplexId: 1),
        ),
        throwsA(
          isA<ConflictException>().having(
            (e) => e.message,
            'message',
            'That guard ID is already taken.',
          ),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('SecurityGuardsController', () {
    test('changing a filter reloads from page 1', () async {
      final repository = _FakeGuardRepository();
      final controller = SecurityGuardsController(repository);
      addTearDown(controller.dispose);

      await controller.load(page: 3);
      expect(repository.lastPage, 3);

      controller.setShiftFilter(Shift.night);
      await repository.settle();

      expect(repository.lastPage, 1);
      expect(repository.lastShift, Shift.night);
      expect(controller.activeFilterCount, 1);
    });

    test('the area filter is trimmed, and blank means unset', () async {
      final repository = _FakeGuardRepository();
      final controller = SecurityGuardsController(repository);
      addTearDown(controller.dispose);

      controller.setAreaFilter('  Main Gate  ');
      await repository.settle();
      expect(controller.areaFilter, 'Main Gate');
      expect(repository.lastArea, 'Main Gate');

      controller.setAreaFilter('   ');
      await repository.settle();
      expect(controller.areaFilter, isNull);
      expect(controller.activeFilterCount, 0);
    });

    test('areas are learned from the rows the server returned', () async {
      final repository = _FakeGuardRepository(
        guards: const [
          SecurityGuard(id: 'a', assignedArea: 'Parking'),
          SecurityGuard(id: 'b', assignedArea: 'Main Gate'),
          SecurityGuard(id: 'c', assignedArea: '  '),
        ],
      );
      final controller = SecurityGuardsController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      // Alphabetical, deduplicated, and blanks excluded.
      expect(controller.knownAreas, ['Main Gate', 'Parking']);
    });

    test('search debounces to a single request', () async {
      final repository = _FakeGuardRepository();
      final controller = SecurityGuardsController(repository);
      addTearDown(controller.dispose);

      controller.onSearchChanged('s');
      controller.onSearchChanged('sa');
      controller.onSearchChanged('san');
      expect(repository.listCalls, 0);

      await Future<void>.delayed(
        SecurityGuardsController.searchDebounce + const Duration(milliseconds: 60),
      );

      expect(repository.listCalls, 1);
      expect(repository.lastSearch, 'san');
    });

    test('clearFilters resets everything including the search', () async {
      final repository = _FakeGuardRepository();
      final controller = SecurityGuardsController(repository);
      addTearDown(controller.dispose);

      controller.setStatusFilter(AdminUserStatus.inactive);
      controller.setShiftFilter(Shift.morning);
      controller.setComplexFilter(2);
      controller.setAreaFilter('Parking');
      controller.onSearchChanged('sanjay');
      await repository.settle();

      expect(controller.hasFilters, isTrue);
      expect(controller.activeFilterCount, 4);

      controller.clearFilters();
      await repository.settle();

      expect(controller.hasFilters, isFalse);
      expect(controller.search, isEmpty);
      expect(controller.areaFilter, isNull);
    });

    test('sorting cycles ascending → descending → off', () async {
      final repository = _FakeGuardRepository();
      final controller = SecurityGuardsController(repository);
      addTearDown(controller.dispose);

      controller.toggleSort(SecurityGuardSort.area);
      await repository.settle();
      expect(controller.sort, SecurityGuardSort.area);
      expect(controller.descending, isFalse);

      controller.toggleSort(SecurityGuardSort.area);
      await repository.settle();
      expect(controller.descending, isTrue);

      controller.toggleSort(SecurityGuardSort.area);
      await repository.settle();
      expect(controller.sort, isNull);
    });

    test('rows with no salary sink in both directions', () async {
      final repository = _FakeGuardRepository(
        guards: const [
          SecurityGuard(id: '1', salary: 20000),
          SecurityGuard(id: '2'),
          SecurityGuard(id: '3', salary: 30000),
        ],
      );
      final controller = SecurityGuardsController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      controller.toggleSort(SecurityGuardSort.salary);
      await repository.settle();
      expect(controller.guards.last.id, '2');

      controller.toggleSort(SecurityGuardSort.salary);
      await repository.settle();
      expect(controller.guards.last.id, '2');
    });

    test('a stale response cannot overwrite a newer one', () async {
      final repository = _SlowFirstGuardRepository();
      final controller = SecurityGuardsController(repository);
      addTearDown(controller.dispose);

      final stale = controller.load(page: 1);
      final fresh = controller.load(page: 2);
      await Future.wait([stale, fresh]);

      expect(controller.guards.single.id, '2');
    });

    test('delete removes the row immediately', () async {
      final repository = _FakeGuardRepository(
        guards: const [
          SecurityGuard(id: 'sg-1'),
          SecurityGuard(id: 'sg-2'),
        ],
        total: 2,
      );
      final controller = SecurityGuardsController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      final pending = controller.delete('sg-1');

      expect(controller.guards.map((g) => g.id), ['sg-2']);
      await pending;
      expect(repository.deleted, ['sg-1']);
    });

    test('a failed delete puts the row back', () async {
      final repository = _FakeGuardRepository(
        guards: const [
          SecurityGuard(id: 'sg-1'),
          SecurityGuard(id: 'sg-2'),
        ],
        total: 2,
        failDelete: true,
      );
      final controller = SecurityGuardsController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      await expectLater(controller.delete('sg-1'), throwsA(isA<ApiException>()));

      expect(controller.guards.map((g) => g.id), ['sg-1', 'sg-2']);
    });

    test('deleting the last row of a page steps back a page', () async {
      final repository = _FakeGuardRepository(
        guards: const [SecurityGuard(id: 'sg-9')],
        total: 21,
        totalPages: 2,
      );
      final controller = SecurityGuardsController(repository);
      addTearDown(controller.dispose);

      await controller.load(page: 2);
      await controller.delete('sg-9');

      expect(repository.lastPage, 1);
    });

    test('the venue list is fetched once and reused', () async {
      final repository = _FakeGuardRepository();
      final controller = SecurityGuardsController(repository);
      addTearDown(controller.dispose);

      await controller.loadComplexes();
      await controller.loadComplexes();

      expect(repository.complexCalls, 1);
      expect(controller.complexes, hasLength(2));

      await controller.loadComplexes(refresh: true);
      expect(repository.complexCalls, 2);
    });

    test('credentials are returned, never held on the controller', () async {
      final repository = _FakeGuardRepository();
      final controller = SecurityGuardsController(repository);
      addTearDown(controller.dispose);

      final credentials = await controller.fetchCredentials('sg-1');
      expect(credentials.password, 'secret123');
      expect(controller.toString(), isNot(contains('secret123')));
    });

    test('a load failure surfaces the server message', () async {
      final controller = SecurityGuardsController(_FailingGuardRepository());
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.isFailed, isTrue);
      expect(controller.error, 'You do not have permission to do this.');
    });
  });
}

// -----------------------------------------------------------------------------
// Fakes
// -----------------------------------------------------------------------------

class _FakeGuardRepository implements SecurityGuardRepository {
  _FakeGuardRepository({
    this.guards = const [SecurityGuard(id: 'sg-1', fullName: 'Someone')],
    this.total = 1,
    this.totalPages = 1,
    this.failDelete = false,
  });

  final List<SecurityGuard> guards;
  final int total;
  final int totalPages;
  final bool failDelete;

  int listCalls = 0;
  int complexCalls = 0;
  int? lastPage;
  String? lastSearch;
  String? lastArea;
  Shift? lastShift;
  final List<String> deleted = [];

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  @override
  Future<Paged<SecurityGuard>> fetchGuards({
    int page = 1,
    int limit = 20,
    String? search,
    AdminUserStatus? status,
    Shift? shift,
    int? sportComplexId,
    String? assignedArea,
    String? sortBy,
    bool descending = false,
  }) async {
    listCalls++;
    lastPage = page;
    lastSearch = search;
    lastArea = assignedArea;
    lastShift = shift;
    return Paged<SecurityGuard>(
      items: guards,
      page: page,
      limit: limit,
      total: total,
      totalPages: totalPages,
    );
  }

  @override
  Future<SecurityGuard> fetchGuard(String id) async => guards.firstWhere(
    (guard) => guard.id == id,
    orElse: () => SecurityGuard(id: id),
  );

  @override
  Future<SecurityGuard> createGuard(SecurityGuardDraft draft) async =>
      const SecurityGuard(id: 'sg-new');

  @override
  Future<SecurityGuard> updateGuard(
    String id,
    SecurityGuardDraft draft,
  ) async => SecurityGuard(id: id);

  @override
  Future<void> deleteGuard(String id) async {
    if (failDelete) throw const ServerException('Delete rejected.');
    deleted.add(id);
  }

  @override
  Future<SecurityGuardCredentials> fetchCredentials(String id) async =>
      const SecurityGuardCredentials(email: 'a@b.com', password: 'secret123');

  @override
  Future<void> resetPassword(String id, String password) async {}

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async {
    complexCalls++;
    return const [
      SportsComplex(id: 1, name: 'Sinhagad Road Complex', city: 'Pune'),
      SportsComplex(id: 2, name: 'Kothrud Arena', city: 'Pune'),
    ];
  }
}

/// First call resolves slowly with stale data; later calls resolve at once.
class _SlowFirstGuardRepository extends _FakeGuardRepository {
  int _calls = 0;

  @override
  Future<Paged<SecurityGuard>> fetchGuards({
    int page = 1,
    int limit = 20,
    String? search,
    AdminUserStatus? status,
    Shift? shift,
    int? sportComplexId,
    String? assignedArea,
    String? sortBy,
    bool descending = false,
  }) async {
    final isFirst = _calls++ == 0;
    if (isFirst) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return const Paged<SecurityGuard>(
        items: [SecurityGuard(id: '1', fullName: 'stale')],
        page: 1,
      );
    }
    return const Paged<SecurityGuard>(
      items: [SecurityGuard(id: '2', fullName: 'fresh')],
      page: 2,
    );
  }
}

class _FailingGuardRepository extends _FakeGuardRepository {
  @override
  Future<Paged<SecurityGuard>> fetchGuards({
    int page = 1,
    int limit = 20,
    String? search,
    AdminUserStatus? status,
    Shift? shift,
    int? sportComplexId,
    String? assignedArea,
    String? sortBy,
    bool descending = false,
  }) async {
    throw const ForbiddenException('You do not have permission to do this.');
  }
}
