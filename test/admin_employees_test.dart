import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/core/utils/app_logger.dart';
import 'package:nahata_app/features/admin/data/models/employee_model.dart';
import 'package:nahata_app/features/admin/data/repositories/employee_repository_impl.dart';
import 'package:nahata_app/features/admin/domain/entities/admin_role.dart';
import 'package:nahata_app/features/admin/domain/entities/employee.dart';
import 'package:nahata_app/features/admin/domain/entities/employee_vocabulary.dart';
import 'package:nahata_app/features/admin/domain/entities/paged.dart';
import 'package:nahata_app/features/admin/domain/repositories/employee_repository.dart';
import 'package:nahata_app/features/admin/presentation/state/employees_controller.dart';
import 'package:nahata_app/features/admin/presentation/state/view_state.dart';
import 'package:nahata_app/features/admin/presentation/utils/admin_format.dart';
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
  group('Employee vocabularies', () {
    test('parse case- and separator-insensitively', () {
      for (final value in [
        'Front Desk',
        'front_desk',
        'FRONT-DESK',
        'frontDesk',
      ]) {
        expect(Department.tryParse(value), Department.frontDesk, reason: value);
      }
      expect(Designation.tryParse('receptionist'), Designation.receptionist);
      expect(Shift.tryParse('ROTATIONAL'), Shift.rotational);
      expect(Shift.tryParse(''), isNull);
      expect(Shift.tryParse(null), isNull);
    });

    test('a value outside the list still renders readably', () {
      expect(Department.tryParse('Logistics'), isNull);
      expect(Department.labelFor('logistics_team'), 'Logistics Team');
      expect(Designation.labelFor(null), '—');
    });

    test('slugs are the exact wire values the payload documents', () {
      expect(Department.customerService.slug, 'Customer Service');
      expect(Designation.manager.slug, 'Manager');
      expect(Shift.night.slug, 'Night');
    });
  });

  // ---------------------------------------------------------------------------
  group('EmployeeMapper', () {
    test('an embedded user fills the person fields but never the row id', () {
      // Shaped like the security-guard row captured live on 2026-08-04, where
      // unwrapping into `user` swapped the staff record for the person and
      // took the user id with it.
      final employee = EmployeeMapper.fromJson({
        'id': 22,
        'userId': 585,
        'employeeId': 'NS-1042',
        'department': 'Operations',
        'status': 'Active',
        'user': {
          'id': 585,
          'name': 'Major',
          'email': 'major@gmil.com',
          'phone_number': '9856784565',
        },
      });

      expect(employee.id, '22');
      expect(employee.employeeCode, 'NS-1042');
      expect(employee.fullName, 'Major');
      expect(employee.email, 'major@gmil.com');
      expect(employee.phone, '9856784565');
      // The staff-record fields survive.
      expect(employee.departmentRaw, 'Operations');
    });

    test('parses a full row, keeping id and employee code distinct', () {
      final employee = EmployeeMapper.fromJson(<String, dynamic>{
        'id': 'emp-1',
        'employeeId': 'NS-1042',
        'fullName': 'Rahul Kale',
        'email': 'rahul@example.com',
        'phone': '9822001100',
        'department': 'Front Desk',
        'designation': 'Supervisor',
        'shift': 'Morning',
        'salary': 35000,
        'status': 'Active',
        'joiningDate': '2025-06-01T00:00:00Z',
        'address': '12 MG Road, Pune',
        'sportComplex': {'id': 4, 'name': 'Sinhagad Road Complex'},
      });

      // The two identifiers must never be swapped.
      expect(employee.id, 'emp-1');
      expect(employee.employeeCode, 'NS-1042');

      expect(employee.department, Department.frontDesk);
      expect(employee.designation, Designation.supervisor);
      expect(employee.shift, Shift.morning);
      expect(employee.status, AdminUserStatus.active);
      expect(employee.salary, 35000);
      expect(employee.sportComplexId, 4);
      expect(employee.sportComplexName, 'Sinhagad Road Complex');
      expect(employee.joiningDate, isNotNull);
      expect(employee.initials, 'RK');
    });

    test('parses snake_case and a salary sent as a formatted string', () {
      final employee = EmployeeMapper.fromJson(const <String, dynamic>{
        '_id': 'emp-2',
        'employee_id': 'NS-7',
        'full_name': 'Sana Shah',
        'phone_number': '9000000000',
        'salary': '₹42,500',
        'joining_date': '01-07-2025',
        'sport_complex_id': 9,
      });

      expect(employee.employeeCode, 'NS-7');
      expect(employee.fullName, 'Sana Shah');
      expect(employee.phone, '9000000000');
      expect(employee.salary, 42500);
      expect(employee.joiningDate, DateTime(2025, 7, 1));
      expect(employee.sportComplexId, 9);
    });

    test('drops rows with no id', () {
      final employees = EmployeeMapper.listFrom(<String, dynamic>{
        'employees': [
          {'fullName': 'No id'},
          {'id': 'e1', 'fullName': 'Real'},
        ],
      });

      expect(employees, hasLength(1));
      expect(employees.single.id, 'e1');
    });

    test('unwraps a nested detail envelope', () {
      final employee = EmployeeMapper.fromJson(const <String, dynamic>{
        'data': {
          'employee': {'id': 'emp-9', 'fullName': 'Nested'},
        },
      });

      expect(employee.id, 'emp-9');
      expect(employee.fullName, 'Nested');
    });

    test('reads pagination meta, and derives pages when it is absent', () {
      final withMeta = EmployeeMapper.pageFrom(
        {
          'data': {
            'employees': [
              {'id': '1'},
            ],
            'meta': {'page': 2, 'limit': 20, 'total': 45, 'totalPages': 3},
          },
        },
        fallbackPage: 2,
        fallbackLimit: 20,
      );
      expect(withMeta.page, 2);
      expect(withMeta.effectiveTotalPages, 3);
      expect(withMeta.hasNext, isTrue);

      final withoutMeta = EmployeeMapper.pageFrom(
        [
          {'id': '1'},
          {'id': '2'},
        ],
        fallbackPage: 1,
        fallbackLimit: 20,
      );
      expect(withoutMeta.total, 2);
      expect(withoutMeta.effectiveTotalPages, 1);
    });

    test('mergedWith keeps a field the detail route omitted', () {
      const row = Employee(id: '1', employeeCode: 'NS-1', salary: 100);
      const detail = Employee(id: '1', address: 'Somewhere');

      final merged = row.mergedWith(detail);
      expect(merged.employeeCode, 'NS-1');
      expect(merged.salary, 100);
      expect(merged.address, 'Somewhere');
    });
  });

  // ---------------------------------------------------------------------------
  group('EmployeeCredentialsMapper', () {
    test('reads the temporary-password shapes', () {
      for (final key in [
        'temporaryPassword',
        'temporary_password',
        'tempPassword',
        'password',
      ]) {
        final credentials = EmployeeCredentialsMapper.fromJson(
          <String, dynamic>{'email': 'a@b.com', key: 'secret123'},
        );
        expect(credentials.password, 'secret123', reason: key);
        expect(credentials.email, 'a@b.com');
        expect(credentials.hasPassword, isTrue);
      }
    });

    test('reports a missing password rather than an empty string', () {
      final credentials = EmployeeCredentialsMapper.fromJson(
        const <String, dynamic>{
          'data': {'email': 'a@b.com'},
        },
      );
      expect(credentials.email, 'a@b.com');
      expect(credentials.password, isNull);
      expect(credentials.hasPassword, isFalse);
    });

    test('toString never leaks the password', () {
      const credentials = EmployeeCredentials(
        email: 'a@b.com',
        password: 'hunter2',
      );
      expect(credentials.toString(), isNot(contains('hunter2')));
      expect(credentials.toString(), contains('***'));
    });
  });

  // ---------------------------------------------------------------------------
  group('AppLogger redaction', () {
    test('masks every password-shaped key, prefixed or suffixed', () {
      for (final key in [
        'password',
        'temporaryPassword',
        'temporary_password',
        'newPassword',
        'tempPassword',
      ]) {
        final line = AppLogger.redact('{"$key":"hunter2"}');
        expect(line, isNot(contains('hunter2')), reason: key);
        expect(line, contains('***'), reason: key);
      }
    });

    test('still masks tokens and bearer headers', () {
      expect(AppLogger.redact('{"accessToken":"abc"}'), isNot(contains('abc')));
      expect(
        AppLogger.redact('Authorization: Bearer abc.def.ghi'),
        isNot(contains('abc.def.ghi')),
      );
    });

    test('leaves ordinary fields alone', () {
      expect(AppLogger.redact('{"email":"a@b.com"}'), contains('a@b.com'));
    });
  });

  // ---------------------------------------------------------------------------
  group('EmployeeDraft', () {
    test('the create body carries every documented key', () {
      final draft = EmployeeDraft(
        fullName: 'Rahul Kale',
        email: 'rahul@example.com',
        phone: '9822001100',
        password: 'secret123',
        employeeCode: 'NS-1042',
        department: Department.frontDesk,
        designation: Designation.supervisor,
        joiningDate: DateTime(2025, 6, 1),
        salary: '35000',
        shift: Shift.morning,
        sportComplexId: 4,
        address: '12 MG Road',
      );

      final body = draft.toCreateJson();
      expect(body.keys.toSet(), {
        'fullName',
        'email',
        'phone',
        'password',
        'employeeId',
        'department',
        'designation',
        'joiningDate',
        'salary',
        'shift',
        'status',
        'sportComplexId',
        'address',
      });
      expect(body['employeeId'], 'NS-1042');
      expect(body['department'], 'Front Desk');
      expect(body['joiningDate'], '2025-06-01');
      // The payload pins new employees to Active.
      expect(body['status'], 'Active');
    });

    test('dates are formatted as yyyy-MM-dd with padding', () {
      expect(EmployeeDraft.formatDate(DateTime(2026, 1, 5)), '2026-01-05');
      expect(EmployeeDraft.formatDate(null), '');
    });

    test('an update sends only what changed', () {
      const draft = EmployeeDraft(fullName: 'Renamed', phone: '9000000000');
      final body = draft.toUpdateJson();

      expect(body.keys.toSet(), {'fullName', 'phone'});
      expect(body.containsKey('password'), isFalse);
      expect(body.containsKey('email'), isFalse);
    });

    test('an emptied address is cleared explicitly, not dropped', () {
      const draft = EmployeeDraft(fullName: 'X');

      expect(draft.toUpdateJson().containsKey('address'), isFalse);
      expect(draft.toUpdateJson(clearAddress: true)['address'], '');
    });
  });

  // ---------------------------------------------------------------------------
  group('AdminFormat.currency', () {
    test('groups in the Indian convention and drops empty decimals', () {
      expect(AdminFormat.currency(120000), '₹1,20,000');
      expect(AdminFormat.currency(35000), '₹35,000');
      expect(AdminFormat.currency(null), AdminFormat.dash);
    });

    test('keeps paise when there are any', () {
      expect(AdminFormat.currency(1234.5), contains('.50'));
    });
  });

  // ---------------------------------------------------------------------------
  group('EmployeeRepositoryImpl', () {
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

      await EmployeeRepositoryImpl().fetchEmployees(
        page: 2,
        limit: 50,
        search: '  rahul  ',
        status: AdminUserStatus.active,
        department: Department.frontDesk,
        shift: Shift.morning,
        sportComplexId: 4,
        sortBy: 'fullName',
        descending: true,
      );

      expect(captured.path, endsWith('/admin/employees'));
      expect(captured.queryParameters['page'], '2');
      expect(captured.queryParameters['limit'], '50');
      expect(captured.queryParameters['search'], 'rahul');
      expect(captured.queryParameters['status'], 'Active');
      expect(captured.queryParameters['department'], 'Front Desk');
      expect(captured.queryParameters['shift'], 'Morning');
      expect(captured.queryParameters['sportComplexId'], '4');
      expect(captured.queryParameters['sortOrder'], 'desc');
    });

    test('the confirmed URL shape is sent even with no filters set', () async {
      late Uri captured;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      await EmployeeRepositoryImpl().fetchEmployees(page: 1, limit: 20);

      expect(captured.path, endsWith('/admin/employees'));

      // `search`, `department` and `status` ride along empty rather than being
      // omitted — that is the captured ADMIN Employees URL,
      // `?page=1&limit=10&search=&department=&status=`, and it is the shape
      // proven against the live backend.
      for (final key in ['search', 'department', 'status']) {
        expect(captured.queryParameters[key], '', reason: key);
      }

      // `shift` and the sort keys are ours, not the captured URL's, so they
      // stay absent until something sets them.
      for (final key in ['shift', 'sortBy', 'sortOrder', 'sportComplexId']) {
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
              'data': {'id': 'emp-9'},
            }),
            201,
          );
        }),
      );

      final created = await EmployeeRepositoryImpl().createEmployee(
        EmployeeDraft(
          fullName: 'Rahul',
          email: 'rahul@example.com',
          phone: '9822001100',
          password: 'secret123',
          employeeCode: 'NS-1',
          department: Department.operations,
          designation: Designation.staff,
          joiningDate: DateTime(2025, 6, 1),
          shift: Shift.night,
          sportComplexId: 4,
        ),
      );

      expect(path, endsWith('/admin/employees'));
      final decoded = jsonDecode(body!) as Map<String, dynamic>;
      expect(decoded['employeeId'], 'NS-1');
      expect(decoded['shift'], 'Night');
      expect(decoded['sportComplexId'], 4);
      expect(created.id, 'emp-9');
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
        EmployeeRepositoryImpl().createEmployee(
          const EmployeeDraft(fullName: 'No complex'),
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
        EmployeeRepositoryImpl().updateEmployee('emp-1', const EmployeeDraft()),
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

      final repository = EmployeeRepositoryImpl();
      final credentials = await repository.fetchCredentials('emp-1');
      await repository.resetPassword('emp-1', 'newSecret123');

      expect(calls[0], endsWith('GET /api/admin/employees/emp-1/password'));
      expect(
        calls[1],
        endsWith('POST /api/admin/employees/emp-1/reset-password'),
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

      await EmployeeRepositoryImpl().deleteEmployee('emp-1');
      expect(calls.single, endsWith('DELETE /api/admin/employees/emp-1'));
    });

    test('a rejected write throws with the server message', () async {
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'success': false,
              'message': 'That employee ID is already taken.',
            }),
            409,
          );
        }),
      );

      await expectLater(
        EmployeeRepositoryImpl().createEmployee(
          const EmployeeDraft(fullName: 'Dup', sportComplexId: 1),
        ),
        throwsA(
          isA<ConflictException>().having(
            (e) => e.message,
            'message',
            'That employee ID is already taken.',
          ),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('EmployeesController', () {
    test('changing a filter reloads from page 1', () async {
      final repository = _FakeEmployeeRepository();
      final controller = EmployeesController(repository);
      addTearDown(controller.dispose);

      await controller.load(page: 3);
      expect(repository.lastPage, 3);

      controller.setDepartmentFilter(Department.maintenance);
      await repository.settle();

      expect(repository.lastPage, 1);
      expect(repository.lastDepartment, Department.maintenance);
    });

    test(
      'activeFilterCount counts the dropdowns, not the search box',
      () async {
        final repository = _FakeEmployeeRepository();
        final controller = EmployeesController(repository);
        addTearDown(controller.dispose);

        expect(controller.activeFilterCount, 0);

        controller.setStatusFilter(AdminUserStatus.active);
        controller.setShiftFilter(Shift.night);
        await repository.settle();
        expect(controller.activeFilterCount, 2);

        controller.onSearchChanged('rahul');
        expect(controller.activeFilterCount, 2);
        expect(controller.hasFilters, isTrue);
      },
    );

    test('search debounces to a single request', () async {
      final repository = _FakeEmployeeRepository();
      final controller = EmployeesController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      final before = repository.listCalls;

      controller.onSearchChanged('r');
      controller.onSearchChanged('ra');
      controller.onSearchChanged('rahul');
      expect(repository.listCalls, before);

      await Future<void>.delayed(
        EmployeesController.searchDebounce + const Duration(milliseconds: 120),
      );

      expect(repository.listCalls, before + 1);
      expect(repository.lastSearch, 'rahul');
    });

    test('clearFilters resets everything including the search', () async {
      final repository = _FakeEmployeeRepository();
      final controller = EmployeesController(repository);
      addTearDown(controller.dispose);

      controller.setStatusFilter(AdminUserStatus.inactive);
      controller.setComplexFilter(4);
      await repository.settle();

      controller.clearFilters();
      await repository.settle();

      expect(controller.activeFilterCount, 0);
      expect(controller.search, isEmpty);
      expect(controller.hasFilters, isFalse);
    });

    test('sorting cycles ascending → descending → off', () async {
      final repository = _FakeEmployeeRepository();
      final controller = EmployeesController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      controller.toggleSort(EmployeeSort.salary);
      await repository.settle();
      expect(controller.sort, EmployeeSort.salary);
      expect(controller.descending, isFalse);

      controller.toggleSort(EmployeeSort.salary);
      await repository.settle();
      expect(controller.descending, isTrue);

      controller.toggleSort(EmployeeSort.salary);
      await repository.settle();
      expect(controller.sort, isNull);
    });

    test(
      'rows are ordered locally even if the server ignores sortBy',
      () async {
        final repository = _FakeEmployeeRepository(
          employees: const [
            Employee(id: '1', fullName: 'Zara', salary: 50000),
            Employee(id: '2', fullName: 'Aman', salary: 20000),
            Employee(id: '3', fullName: 'Meera', salary: 35000),
          ],
        );
        final controller = EmployeesController(repository);
        addTearDown(controller.dispose);

        await controller.load();
        controller.toggleSort(EmployeeSort.salary);
        await repository.settle();

        expect(controller.employees.map((e) => e.salary), [
          20000,
          35000,
          50000,
        ]);
      },
    );

    test('rows with no salary sink in both directions', () async {
      final repository = _FakeEmployeeRepository(
        employees: const [
          Employee(id: '1', fullName: 'Paid', salary: 100),
          Employee(id: '2', fullName: 'Unknown'),
        ],
      );
      final controller = EmployeesController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      controller.toggleSort(EmployeeSort.salary);
      await repository.settle();
      expect(controller.employees.last.fullName, 'Unknown');

      controller.toggleSort(EmployeeSort.salary); // descending
      await repository.settle();
      expect(controller.employees.last.fullName, 'Unknown');
    });

    test('a stale response cannot overwrite a newer one', () async {
      final repository = _SlowFirstEmployeeRepository();
      final controller = EmployeesController(repository);
      addTearDown(controller.dispose);

      final first = controller.load(page: 1);
      final second = controller.load(page: 2);
      await Future.wait([first, second]);

      expect(controller.page.page, 2);
      expect(controller.employees.single.fullName, 'fresh');
    });

    test('delete removes the row immediately', () async {
      final repository = _FakeEmployeeRepository(
        employees: const [
          Employee(id: 'a', fullName: 'First'),
          Employee(id: 'b', fullName: 'Second'),
        ],
        total: 2,
      );
      final controller = EmployeesController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      final future = controller.delete('a');

      // Optimistic: gone before the call has resolved.
      expect(controller.employees.map((e) => e.id), ['b']);

      await future;
      expect(repository.deleted, ['a']);
    });

    test('a failed delete puts the row back', () async {
      final repository = _FakeEmployeeRepository(
        employees: const [
          Employee(id: 'a', fullName: 'First'),
          Employee(id: 'b', fullName: 'Second'),
        ],
        total: 2,
        failDelete: true,
      );
      final controller = EmployeesController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      await expectLater(controller.delete('a'), throwsA(isA<ApiException>()));

      // Restored, so a failed delete never silently loses a row.
      expect(controller.employees.map((e) => e.id), ['a', 'b']);
      expect(controller.page.total, 2);
    });

    test('deleting the last row of a page steps back a page', () async {
      final repository = _FakeEmployeeRepository(
        employees: const [Employee(id: 'z', fullName: 'Only one')],
        total: 21,
        totalPages: 3,
      );
      final controller = EmployeesController(repository);
      addTearDown(controller.dispose);

      await controller.load(page: 3);
      await controller.delete('z');

      expect(repository.lastPage, 2);
    });

    test('the venue list is fetched once and reused', () async {
      final repository = _FakeEmployeeRepository();
      final controller = EmployeesController(repository);
      addTearDown(controller.dispose);

      await controller.loadComplexes();
      await controller.loadComplexes();

      expect(repository.complexCalls, 1);
      expect(controller.complexes, hasLength(2));
    });

    test(
      'filteredComplex resolves the chip label from the loaded venues',
      () async {
        final repository = _FakeEmployeeRepository();
        final controller = EmployeesController(repository);
        addTearDown(controller.dispose);

        await controller.loadComplexes();
        controller.setComplexFilter(2);
        await repository.settle();

        expect(controller.filteredComplex?.name, 'Kothrud Arena');
      },
    );

    test('credentials are returned, never held on the controller', () async {
      final repository = _FakeEmployeeRepository();
      final controller = EmployeesController(repository);
      addTearDown(controller.dispose);

      final credentials = await controller.fetchCredentials('emp-1');
      expect(credentials.password, 'secret123');

      // Nothing on the controller exposes them afterwards.
      expect(controller.toString(), isNot(contains('secret123')));
    });

    test('a load failure surfaces the server message', () async {
      final repository = _FailingEmployeeRepository();
      final controller = EmployeesController(repository);
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

class _FakeEmployeeRepository implements EmployeeRepository {
  _FakeEmployeeRepository({
    this.employees = const [Employee(id: 'emp-1', fullName: 'Someone')],
    this.total = 1,
    this.totalPages = 1,
    this.failDelete = false,
  });

  final List<Employee> employees;
  final int total;
  final int totalPages;
  final bool failDelete;

  int listCalls = 0;
  int complexCalls = 0;
  int? lastPage;
  String? lastSearch;
  Department? lastDepartment;
  final List<String> deleted = [];

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  @override
  Future<Paged<Employee>> fetchEmployees({
    int page = 1,
    int limit = 20,
    String? search,
    AdminUserStatus? status,
    Department? department,
    Shift? shift,
    int? sportComplexId,
    String? sortBy,
    bool descending = false,
  }) async {
    listCalls++;
    lastPage = page;
    lastSearch = search;
    lastDepartment = department;
    return Paged<Employee>(
      items: employees,
      page: page,
      limit: limit,
      total: total,
      totalPages: totalPages,
    );
  }

  @override
  Future<Employee> fetchEmployee(String id) async =>
      employees.firstWhere((e) => e.id == id, orElse: () => Employee(id: id));

  @override
  Future<Employee> createEmployee(EmployeeDraft draft) async =>
      const Employee(id: 'emp-new');

  @override
  Future<Employee> updateEmployee(
    String id,
    EmployeeDraft draft, {
    bool clearAddress = false,
  }) async => Employee(id: id);

  @override
  Future<void> deleteEmployee(String id) async {
    if (failDelete) throw const ServerException('Delete rejected.');
    deleted.add(id);
  }

  @override
  Future<EmployeeCredentials> fetchCredentials(String id) async =>
      const EmployeeCredentials(email: 'a@b.com', password: 'secret123');

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
class _SlowFirstEmployeeRepository extends _FakeEmployeeRepository {
  int _calls = 0;

  @override
  Future<Paged<Employee>> fetchEmployees({
    int page = 1,
    int limit = 20,
    String? search,
    AdminUserStatus? status,
    Department? department,
    Shift? shift,
    int? sportComplexId,
    String? sortBy,
    bool descending = false,
  }) async {
    final isFirst = _calls++ == 0;
    if (isFirst) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return const Paged<Employee>(
        items: [Employee(id: '1', fullName: 'stale')],
        page: 1,
      );
    }
    return const Paged<Employee>(
      items: [Employee(id: '2', fullName: 'fresh')],
      page: 2,
    );
  }
}

class _FailingEmployeeRepository extends _FakeEmployeeRepository {
  @override
  Future<Paged<Employee>> fetchEmployees({
    int page = 1,
    int limit = 20,
    String? search,
    AdminUserStatus? status,
    Department? department,
    Shift? shift,
    int? sportComplexId,
    String? sortBy,
    bool descending = false,
  }) async {
    throw const ForbiddenException('You do not have permission to do this.');
  }
}
