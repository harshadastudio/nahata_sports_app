import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/core/storage/token_storage.dart';
import 'package:nahata_app/features/admin/data/models/admin_stats_model.dart';
import 'package:nahata_app/features/admin/data/models/admin_user_model.dart';
import 'package:nahata_app/features/admin/data/models/role_permissions_model.dart';
import 'package:nahata_app/features/admin/data/repositories/admin_repository_impl.dart';
import 'package:nahata_app/features/admin/domain/entities/admin_role.dart';
import 'package:nahata_app/features/admin/domain/entities/admin_stats.dart';
import 'package:nahata_app/features/admin/domain/entities/admin_user.dart';
import 'package:nahata_app/features/admin/domain/entities/paged.dart';
import 'package:nahata_app/features/admin/domain/entities/role_permissions.dart';
import 'package:nahata_app/features/admin/domain/repositories/admin_repository.dart';
import 'package:nahata_app/features/admin/presentation/state/admin_roles_controller.dart';
import 'package:nahata_app/features/admin/presentation/state/admin_users_controller.dart';
import 'package:nahata_app/features/admin/presentation/state/view_state.dart';

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
  group('AdminStatsMapper', () {
    test('reads camelCase counters straight out of a data envelope', () {
      final stats = AdminStatsMapper.fromJson(<String, dynamic>{
        'data': {
          'totalUsers': 1280,
          'verifiedUsers': 900,
          'unverifiedUsers': 380,
          'totalCoaches': 14,
          'employees': 22,
          'securityGuards': 6,
          'admins': 3,
        },
      });

      expect(stats.totalUsers, 1280);
      expect(stats.verifiedUsers, 900);
      expect(stats.unverifiedUsers, 380);
      expect(stats.totalCoaches, 14);
      expect(stats.employees, 22);
      expect(stats.securityGuards, 6);
      expect(stats.admins, 3);
      expect(stats.verifiedRatio, closeTo(900 / 1280, 0.0001));
    });

    test('accepts snake_case and string numbers', () {
      final stats = AdminStatsMapper.fromJson(<String, dynamic>{
        'total_users': '500',
        'verified_users': 320,
        'total_coaches': '9',
      });

      expect(stats.totalUsers, 500);
      expect(stats.verifiedUsers, 320);
      expect(stats.totalCoaches, 9);
      // Derived, because two of the three were known.
      expect(stats.unverifiedUsers, 180);
    });

    test('leaves a counter null rather than inventing a zero', () {
      final stats = AdminStatsMapper.fromJson(const <String, dynamic>{
        'totalUsers': 10,
      });

      expect(stats.totalUsers, 10);
      expect(stats.admins, isNull);
      expect(stats.securityGuards, isNull);
      // Only one of total/verified is known, so nothing is derived.
      expect(stats.unverifiedUsers, isNull);
      expect(stats.isEmpty, isFalse);
    });

    test('an empty body yields an empty entity, not a zeroed one', () {
      final stats = AdminStatsMapper.fromJson(const <String, dynamic>{});
      expect(stats.isEmpty, isTrue);
      expect(stats.verifiedRatio, isNull);
      expect(AdminStats.empty.isEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('AdminUserMapper', () {
    test('parses a page with a meta block', () {
      final page = AdminUserMapper.pageFrom(
        <String, dynamic>{
          'success': true,
          'data': {
            'users': [
              {
                'id': 7,
                'name': 'Riya Sharma',
                'email': 'riya@example.com',
                'phoneNumber': '9876543210',
                'role': 'COACH',
                'status': 'Active',
                'membershipType': 'Premium',
                'totalBookings': 12,
                'joinDate': '2025-03-04T10:00:00Z',
                'lastActive': '2026-07-30T08:15:00Z',
                'assignedSports': ['Badminton', 'Tennis'],
                'assignedLocation': 'Nahata Sports Complex',
              },
            ],
            'meta': {'page': 2, 'limit': 20, 'total': 41, 'totalPages': 3},
          },
        },
        fallbackPage: 2,
        fallbackLimit: 20,
      );

      expect(page.items, hasLength(1));
      expect(page.page, 2);
      expect(page.total, 41);
      expect(page.totalPages, 3);
      expect(page.hasNext, isTrue);
      expect(page.hasPrevious, isTrue);
      expect(page.firstIndex, 21);
      expect(page.lastIndex, 21);

      final user = page.items.single;
      expect(user.id, '7');
      expect(user.displayName, 'Riya Sharma');
      expect(user.role, AdminRole.coach);
      expect(user.status, AdminUserStatus.active);
      expect(user.membership, 'Premium');
      expect(user.totalBookings, 12);
      expect(user.joinedAt, isNotNull);
      expect(user.assignedSports, ['Badminton', 'Tennis']);
      expect(user.isCoach, isTrue);
      expect(user.initials, 'RS');
    });

    test('derives totalPages when the server omits it', () {
      final page = AdminUserMapper.pageFrom(
        <String, dynamic>{
          'users': [
            {'id': 1, 'name': 'A'},
            {'id': 2, 'name': 'B'},
          ],
          'total': 25,
          'limit': 10,
          'page': 1,
        },
        fallbackPage: 1,
        fallbackLimit: 10,
      );

      expect(page.totalPages, 0);
      expect(page.effectiveTotalPages, 3);
      expect(page.hasNext, isTrue);
    });

    test('handles a bare list body', () {
      final page = AdminUserMapper.pageFrom(
        [
          {'id': 'a1', 'name': 'Solo User'},
        ],
        fallbackPage: 1,
        fallbackLimit: 20,
      );

      expect(page.items, hasLength(1));
      expect(page.page, 1);
      expect(page.total, 1);
    });

    test('drops records with no id rather than rendering a ghost row', () {
      final users = AdminUserMapper.listFrom(<String, dynamic>{
        'users': [
          {'name': 'No id here'},
          {'id': '9', 'name': 'Real'},
        ],
      });

      expect(users, hasLength(1));
      expect(users.single.id, '9');
    });

    test('unwraps a nested user envelope on the detail route', () {
      final user = AdminUserMapper.fromJson(<String, dynamic>{
        'data': {
          'user': {
            'id': '42',
            'full_name': 'Arjun Nahata',
            'email_verified': true,
            'phone_verified': 0,
            'blood_group': 'O+',
            'dob': '12-05-1998',
            'employee_id': 'NS-1042',
            'department': 'Operations',
            'role': 'security_guard',
            'permissions': 'gate.scan, gate.view',
          },
        },
      });

      expect(user.id, '42');
      expect(user.name, 'Arjun Nahata');
      expect(user.emailVerified, isTrue);
      expect(user.phoneVerified, isFalse);
      expect(user.bloodGroup, 'O+');
      expect(user.dateOfBirth, DateTime(1998, 5, 12));
      expect(user.employeeId, 'NS-1042');
      expect(user.role, AdminRole.securityGuard);
      expect(user.roleLabel, 'Security Guard');
      expect(user.permissions, ['gate.scan', 'gate.view']);
      expect(user.isEmployeeLike, isTrue);
    });

    test('an unknown role still renders a readable label', () {
      final user = AdminUserMapper.fromJson(const <String, dynamic>{
        'id': '1',
        'role': 'REGIONAL_MANAGER',
      });

      expect(user.role, isNull);
      expect(user.roleLabel, 'Regional Manager');
    });

    test('mergedWith keeps a list field the detail route omitted', () {
      const row = AdminUser(
        id: '5',
        name: 'Row Name',
        membership: 'Gold',
        totalBookings: 4,
      );
      const detail = AdminUser(id: '5', name: 'Detail Name', bloodGroup: 'B+');

      final merged = row.mergedWith(detail);
      expect(merged.name, 'Detail Name');
      expect(merged.bloodGroup, 'B+');
      expect(merged.membership, 'Gold');
      expect(merged.totalBookings, 4);
    });
  });

  // ---------------------------------------------------------------------------
  group('AdminUserDraft', () {
    test('sends the employee block only for an employee-shaped role', () {
      const draft = AdminUserDraft(
        name: 'Staff Member',
        email: 'staff@example.com',
        phone: '9876543210',
        role: AdminRole.employee,
        status: AdminUserStatus.active,
        employeeId: 'NS-9',
        department: 'Front Desk',
        assignedSports: ['Tennis'],
        assignedLocation: 'Complex A',
      );

      final body = draft.toJson();
      expect(body['role'], 'EMPLOYEE');
      expect(body['status'], 'Active');
      expect(body['employeeId'], 'NS-9');
      expect(body['department'], 'Front Desk');
      // Coach-only fields must not ride along.
      expect(body.containsKey('assignedSports'), isFalse);
      expect(body.containsKey('assignedLocation'), isFalse);
    });

    test('sends the coach block only for a coach', () {
      const draft = AdminUserDraft(
        name: 'Coach',
        role: AdminRole.coach,
        employeeId: 'NS-1',
        assignedSports: ['Badminton'],
        assignedLocation: 'Complex B',
      );

      final body = draft.toJson();
      expect(body['assignedSports'], ['Badminton']);
      expect(body['assignedLocation'], 'Complex B');
      expect(body.containsKey('employeeId'), isFalse);
    });

    test('omits blank fields so an edit never blanks a column', () {
      const draft = AdminUserDraft(name: 'Only Name', phone: '   ');
      final body = draft.toJson();

      expect(body.keys, ['name']);
      expect(body['name'], 'Only Name');
    });
  });

  // ---------------------------------------------------------------------------
  group('RolePermissionsMapper', () {
    test('reads a plain granted list', () {
      final permissions = RolePermissionsMapper.fromJson(
        AdminRole.coach,
        const <String, dynamic>{
          'permissions': ['batches.view', 'attendance.mark'],
        },
      );

      expect(permissions.granted, {'batches.view', 'attendance.mark'});
      expect(permissions.catalogue, hasLength(2));
      expect(permissions.isGranted('batches.view'), isTrue);
    });

    test('reads objects carrying their own granted flag', () {
      final permissions = RolePermissionsMapper.fromJson(
        AdminRole.admin,
        const <String, dynamic>{
          'data': {
            'permissions': [
              {'slug': 'users.read', 'granted': true},
              {'slug': 'users.write', 'granted': false},
              {'slug': 'payments.refund', 'granted': true},
            ],
          },
        },
      );

      expect(permissions.granted, {'users.read', 'payments.refund'});
      expect(permissions.catalogue, [
        'users.read',
        'users.write',
        'payments.refund',
      ]);
    });

    test('reads explicit granted + available lists and keeps the catalogue a '
        'superset', () {
      final permissions = RolePermissionsMapper.fromJson(
        AdminRole.employee,
        const <String, dynamic>{
          'available': ['bookings.view', 'bookings.create'],
          'granted': ['bookings.view', 'reports.read'],
        },
      );

      expect(permissions.granted, {'bookings.view', 'reports.read'});
      expect(permissions.catalogue, contains('reports.read'));
      expect(permissions.catalogue, hasLength(3));
    });

    test('groups by module prefix and labels slugs readably', () {
      final permissions = RolePermissionsMapper.fromJson(
        AdminRole.admin,
        const <String, dynamic>{
          'permissions': [
            'users.read',
            'users.write',
            'payments.refund',
            'ping',
          ],
        },
      );

      final grouped = permissions.grouped;
      expect(grouped['Users'], ['users.read', 'users.write']);
      expect(grouped['Payments'], ['payments.refund']);
      expect(grouped['General'], ['ping']);
      expect(RolePermissions.labelFor('users.read'), 'Users Read');
      expect(
        RolePermissions.labelFor('manage_all_bookings'),
        'Manage All Bookings',
      );
    });

    test('toUpdateBody sends a sorted slug list', () {
      final body = RolePermissionsMapper.toUpdateBody({'b.two', 'a.one'});
      expect(body['permissions'], ['a.one', 'b.two']);
    });

    test('sameGrantsAs is what keeps Save disabled', () {
      const a = RolePermissions(role: AdminRole.user, granted: {'x', 'y'});
      const b = RolePermissions(role: AdminRole.user, granted: {'y', 'x'});
      expect(a.sameGrantsAs(b), isTrue);
      expect(a.toggled('z', true).sameGrantsAs(b), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('AdminRole', () {
    test('the permissions route accepts four roles, and says which', () {
      expect(AdminRole.permissionManaged, [
        AdminRole.employee,
        AdminRole.coach,
        AdminRole.securityGuard,
        AdminRole.user,
      ]);
      expect(AdminRole.admin.supportsPermissions, isFalse);
      expect(AdminRole.complexAdmin.supportsPermissions, isFalse);
      expect(AdminRole.securityGuard.permissionsSlug, 'SECURITY');
      // Every other role uses the one slug for both.
      expect(AdminRole.employee.permissionsSlug, AdminRole.employee.slug);
    });

    test('a response echoing SECURITY still lands on the guard role', () {
      expect(AdminRole.tryParse('SECURITY'), AdminRole.securityGuard);
      expect(AdminRole.tryParse('security'), AdminRole.securityGuard);
    });

    test('parses casing and separator variants onto one role', () {
      for (final value in [
        'SECURITY_GUARD',
        'security_guard',
        'Security Guard',
        'securityGuard',
        'security-guard',
      ]) {
        expect(
          AdminRole.tryParse(value),
          AdminRole.securityGuard,
          reason: value,
        );
      }
      expect(AdminRole.tryParse(''), isNull);
      expect(AdminRole.tryParse(null), isNull);
    });

    test('slugs are the wire values the endpoints expect', () {
      expect(AdminRole.complexAdmin.slug, 'COMPLEX_ADMIN');
      expect(AdminUserStatus.active.slug, 'Active');
    });
  });

  // ---------------------------------------------------------------------------
  group('AdminRepositoryImpl', () {
    test(
      'GET /admin/users forwards every filter as a query parameter',
      () async {
        late Uri captured;

        ApiClient.instance.overrideHttpClient(
          MockClient((request) async {
            captured = request.url;
            return http.Response(
              jsonEncode({
                'success': true,
                'data': {
                  'users': [],
                  'meta': {'page': 1, 'total': 0},
                },
              }),
              200,
            );
          }),
        );

        await AdminRepositoryImpl().fetchUsers(
          page: 3,
          limit: 50,
          role: AdminRole.user,
          status: AdminUserStatus.active,
          search: '  riya  ',
          sortBy: 'name',
          descending: true,
        );

        expect(captured.path, endsWith('/admin/users'));
        expect(captured.queryParameters['page'], '3');
        expect(captured.queryParameters['limit'], '50');
        expect(captured.queryParameters['role'], 'USER');
        expect(captured.queryParameters['status'], 'Active');
        expect(captured.queryParameters['search'], 'riya');
        expect(captured.queryParameters['sortBy'], 'name');
        expect(captured.queryParameters['sortOrder'], 'desc');
      },
    );

    test('an unset filter is never sent as an empty parameter', () async {
      late Uri captured;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      await AdminRepositoryImpl().fetchUsers(page: 1, limit: 20);

      expect(captured.queryParameters.containsKey('role'), isFalse);
      expect(captured.queryParameters.containsKey('status'), isFalse);
      expect(captured.queryParameters.containsKey('search'), isFalse);
      expect(captured.queryParameters.containsKey('sortBy'), isFalse);
    });

    test('the permissions route gets its own role vocabulary', () async {
      // Captured live on 2026-08-04: `/admin/roles/ADMIN/permissions` answered
      // 400 `Invalid role. Must be one of: EMPLOYEE, COACH, SECURITY, USER`.
      // So this route calls the guard role SECURITY, even though
      // `/admin/users?role=` and create-user use SECURITY_GUARD.
      late Uri captured;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          return http.Response(jsonEncode({'permissions': <String>[]}), 200);
        }),
      );

      await AdminRepositoryImpl().fetchRolePermissions(AdminRole.securityGuard);

      expect(captured.path, endsWith('/admin/roles/SECURITY/permissions'));
      expect(AdminRole.securityGuard.slug, 'SECURITY_GUARD');
    });

    test('a role the route rejects never leaves the app', () async {
      var called = false;
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          called = true;
          return http.Response(jsonEncode({'permissions': <String>[]}), 200);
        }),
      );

      final repository = AdminRepositoryImpl();
      for (final role in [AdminRole.admin, AdminRole.complexAdmin]) {
        await expectLater(
          repository.fetchRolePermissions(role),
          throwsA(isA<ValidationException>()),
        );
        await expectLater(
          repository.updateRolePermissions(role, const {'users.read'}),
          throwsA(isA<ValidationException>()),
        );
      }

      // A guaranteed 400 is not worth a round trip, and reads to an admin as
      // if the server were broken.
      expect(called, isFalse);
    });

    test('PUT permissions posts the granted slugs', () async {
      String? body;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          body = request.body;
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      final result = await AdminRepositoryImpl().updateRolePermissions(
        AdminRole.coach,
        {'b', 'a'},
      );

      expect(jsonDecode(body!)['permissions'], ['a', 'b']);
      // No echo from the server — the repository falls back to what was sent.
      expect(result.granted, {'a', 'b'});
    });

    test('a failed write throws so the dialog can show the reason', () async {
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'success': false,
              'message': 'A user with this email already exists.',
            }),
            409,
          );
        }),
      );

      await expectLater(
        AdminRepositoryImpl().createUser(
          const AdminUserDraft(name: 'Dup', email: 'dup@example.com'),
        ),
        throwsA(
          isA<ConflictException>().having(
            (e) => e.message,
            'message',
            'A user with this email already exists.',
          ),
        ),
      );
    });

    test(
      'a failed stats read degrades to an empty entity, never throws',
      () async {
        ApiClient.instance.overrideHttpClient(
          MockClient((request) async {
            return http.Response('gateway down', 502);
          }),
        );

        final stats = await AdminRepositoryImpl().fetchStats();
        expect(stats.isEmpty, isTrue);
      },
    );

    test(
      'a 2xx carrying success:false is still treated as a failure',
      () async {
        ApiClient.instance.overrideHttpClient(
          MockClient((request) async {
            return http.Response(
              jsonEncode({'success': false, 'message': 'Not permitted.'}),
              200,
            );
          }),
        );

        await expectLater(
          AdminRepositoryImpl().fetchUsers(page: 1, limit: 20),
          throwsA(isA<ApiException>()),
        );
      },
    );

    tearDown(() {
      ApiClient.instance.overrideHttpClient(http.Client());
      TokenStorage.instance.clear();
    });
  });

  // ---------------------------------------------------------------------------
  group('AdminUsersController', () {
    test('changing a filter reloads from page 1', () async {
      final repository = _FakeAdminRepository();
      final controller = AdminUsersController(repository);
      addTearDown(controller.dispose);

      await controller.load(page: 3);
      expect(repository.lastPage, 3);

      controller.setRoleFilter(AdminRole.coach);
      await repository.settle();

      expect(repository.lastPage, 1);
      expect(repository.lastRole, AdminRole.coach);
    });

    test('search debounces to a single request', () async {
      final repository = _FakeAdminRepository();
      final controller = AdminUsersController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      final before = repository.callCount;

      controller.onSearchChanged('r');
      controller.onSearchChanged('ri');
      controller.onSearchChanged('riy');
      controller.onSearchChanged('riya');

      // Nothing has gone out yet.
      expect(repository.callCount, before);

      await Future<void>.delayed(
        AdminUsersController.searchDebounce + const Duration(milliseconds: 120),
      );

      expect(repository.callCount, before + 1);
      expect(repository.lastSearch, 'riya');
    });

    test('sorting cycles ascending → descending → off', () async {
      final repository = _FakeAdminRepository();
      final controller = AdminUsersController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      controller.toggleSort(UserSort.name);
      await repository.settle();
      expect(controller.sort, UserSort.name);
      expect(controller.descending, isFalse);

      controller.toggleSort(UserSort.name);
      await repository.settle();
      expect(controller.descending, isTrue);

      controller.toggleSort(UserSort.name);
      await repository.settle();
      expect(controller.sort, isNull);
    });

    test(
      'rows are ordered locally even when the server ignores sortBy',
      () async {
        final repository = _FakeAdminRepository(
          users: const [
            AdminUser(id: '1', name: 'Zara'),
            AdminUser(id: '2', name: 'Aman'),
            AdminUser(id: '3', name: 'Meera'),
          ],
        );
        final controller = AdminUsersController(repository);
        addTearDown(controller.dispose);

        await controller.load();
        controller.toggleSort(UserSort.name);
        await repository.settle();

        expect(controller.users.map((u) => u.name), ['Aman', 'Meera', 'Zara']);
      },
    );

    test('rows with no date sort last in both directions', () async {
      final repository = _FakeAdminRepository(
        users: [
          AdminUser(id: '1', name: 'Has date', joinedAt: DateTime(2025, 1, 1)),
          const AdminUser(id: '2', name: 'No date'),
        ],
      );
      final controller = AdminUsersController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      controller.toggleSort(UserSort.joined);
      await repository.settle();
      expect(controller.users.last.name, 'No date');

      controller.toggleSort(UserSort.joined); // descending
      await repository.settle();
      expect(controller.users.last.name, 'No date');
    });

    test(
      'membership vocabulary is learned from the rows, not hardcoded',
      () async {
        final repository = _FakeAdminRepository(
          users: const [
            AdminUser(id: '1', membership: 'Gold', department: 'Ops'),
            AdminUser(id: '2', membership: 'Silver'),
            AdminUser(id: '3', membership: 'Gold'),
          ],
        );
        final controller = AdminUsersController(repository);
        addTearDown(controller.dispose);

        await controller.load();

        expect(controller.knownMemberships, ['Gold', 'Silver']);
        expect(controller.knownDepartments, ['Ops']);
      },
    );

    test('a stale response cannot overwrite a newer one', () async {
      final repository = _SlowFirstRepository();
      final controller = AdminUsersController(repository);
      addTearDown(controller.dispose);

      // First request is slow and returns 'stale'; the second is immediate.
      final first = controller.load(page: 1);
      final second = controller.load(page: 2);
      await Future.wait([first, second]);

      expect(controller.page.page, 2);
      expect(controller.users.single.name, 'fresh');
    });

    test('deleting the last row of a page steps back a page', () async {
      final repository = _FakeAdminRepository(
        users: const [AdminUser(id: '9', name: 'Last one')],
        total: 21,
        totalPages: 3,
      );
      final controller = AdminUsersController(repository);
      addTearDown(controller.dispose);

      await controller.load(page: 3);
      await controller.deleteUser('9');

      expect(repository.deleted, ['9']);
      expect(repository.lastPage, 2);
    });

    test('a load failure surfaces the server message', () async {
      final repository = _FailingRepository();
      final controller = AdminUsersController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.isFailed, isTrue);
      expect(controller.error, 'You do not have permission to do this.');
    });
  });

  // ---------------------------------------------------------------------------
  group('AdminRolesController', () {
    test(
      'Save stays disabled until a toggle actually changes something',
      () async {
        final repository = _FakeAdminRepository(
          permissions: const RolePermissions(
            role: AdminRole.coach,
            granted: {'batches.view'},
            available: ['batches.view', 'attendance.mark'],
          ),
        );
        final controller = AdminRolesController(repository);
        addTearDown(controller.dispose);

        await controller.selectRole(AdminRole.coach);
        expect(controller.isDirty, isFalse);

        controller.toggle('attendance.mark', true);
        expect(controller.isDirty, isTrue);
        expect(controller.grantedCount, 2);

        // Toggling back to the saved set clears the dirty flag.
        controller.toggle('attendance.mark', false);
        expect(controller.isDirty, isFalse);
      },
    );

    test('discard returns to the last confirmed state', () async {
      final repository = _FakeAdminRepository(
        permissions: const RolePermissions(
          role: AdminRole.employee,
          granted: {'users.read'},
          available: ['users.read', 'users.write'],
        ),
      );
      final controller = AdminRolesController(repository);
      addTearDown(controller.dispose);

      await controller.selectRole(AdminRole.employee);
      controller.toggle('users.write', true);
      controller.discard();

      expect(controller.isDirty, isFalse);
      expect(controller.permissions!.granted, {'users.read'});
    });

    test('toggleGroup flips every slug in one module', () async {
      final repository = _FakeAdminRepository(
        permissions: const RolePermissions(
          role: AdminRole.employee,
          granted: {},
          available: ['users.read', 'users.write', 'payments.refund'],
        ),
      );
      final controller = AdminRolesController(repository);
      addTearDown(controller.dispose);

      await controller.selectRole(AdminRole.employee);
      controller.toggleGroup('Users', true);

      expect(controller.permissions!.granted, {'users.read', 'users.write'});
      expect(controller.isDirty, isTrue);
    });

    test('a successful save becomes the new clean baseline', () async {
      final repository = _FakeAdminRepository(
        permissions: const RolePermissions(
          role: AdminRole.user,
          granted: {},
          available: ['bookings.create'],
        ),
      );
      final controller = AdminRolesController(repository);
      addTearDown(controller.dispose);

      await controller.selectRole(AdminRole.user);
      controller.toggle('bookings.create', true);

      final saved = await controller.save();

      expect(saved, isTrue);
      expect(controller.isDirty, isFalse);
      expect(repository.savedPermissions, {'bookings.create'});
    });

    test(
      'a rejected save keeps the edits so nothing is silently lost',
      () async {
        final repository = _FakeAdminRepository(
          permissions: const RolePermissions(
            role: AdminRole.user,
            granted: {},
            available: ['bookings.create'],
          ),
          failSave: true,
        );
        final controller = AdminRolesController(repository);
        addTearDown(controller.dispose);

        await controller.selectRole(AdminRole.user);
        controller.toggle('bookings.create', true);

        final saved = await controller.save();

        expect(saved, isFalse);
        expect(controller.saveError, isNotNull);
        expect(controller.isDirty, isTrue);
        expect(controller.permissions!.granted, {'bookings.create'});
      },
    );
  });
}

// -----------------------------------------------------------------------------
// Fakes
// -----------------------------------------------------------------------------

class _FakeAdminRepository implements AdminRepository {
  _FakeAdminRepository({
    this.users = const [AdminUser(id: '1', name: 'Someone')],
    this.total = 1,
    this.totalPages = 1,
    this.permissions,
    this.failSave = false,
  });

  final List<AdminUser> users;
  final int total;
  final int totalPages;
  final RolePermissions? permissions;
  final bool failSave;

  int callCount = 0;
  int? lastPage;
  AdminRole? lastRole;
  String? lastSearch;
  final List<String> deleted = [];
  Set<String>? savedPermissions;

  /// Lets a test wait for a fire-and-forget reload kicked off by a setter.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  @override
  Future<Paged<AdminUser>> fetchUsers({
    int page = 1,
    int limit = 20,
    AdminRole? role,
    AdminUserStatus? status,
    String? search,
    String? sortBy,
    bool descending = false,
  }) async {
    callCount++;
    lastPage = page;
    lastRole = role;
    lastSearch = search;
    return Paged<AdminUser>(
      items: users,
      page: page,
      limit: limit,
      total: total,
      totalPages: totalPages,
    );
  }

  @override
  Future<AdminStats> fetchStats() async => AdminStats.empty;

  @override
  Future<AdminUser> fetchUser(String userId) async => users.firstWhere(
    (u) => u.id == userId,
    orElse: () => AdminUser(id: userId),
  );

  @override
  Future<AdminUser> createUser(AdminUserDraft draft) async =>
      const AdminUser(id: 'new');

  @override
  Future<AdminUser> updateUser(String userId, AdminUserDraft draft) async =>
      AdminUser(id: userId);

  @override
  Future<void> deleteUser(String userId) async => deleted.add(userId);

  @override
  Future<RolePermissions> fetchRolePermissions(AdminRole role) async =>
      permissions ?? RolePermissions(role: role);

  @override
  Future<RolePermissions> updateRolePermissions(
    AdminRole role,
    Set<String> granted,
  ) async {
    if (failSave) throw const ServerException('Save rejected.');
    savedPermissions = granted;
    return RolePermissions(
      role: role,
      granted: granted,
      available: permissions?.available ?? granted.toList(),
    );
  }
}

/// First call resolves slowly with stale data, later calls resolve at once.
class _SlowFirstRepository extends _FakeAdminRepository {
  int _calls = 0;

  @override
  Future<Paged<AdminUser>> fetchUsers({
    int page = 1,
    int limit = 20,
    AdminRole? role,
    AdminUserStatus? status,
    String? search,
    String? sortBy,
    bool descending = false,
  }) async {
    final isFirst = _calls++ == 0;
    if (isFirst) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return const Paged<AdminUser>(
        items: [AdminUser(id: '1', name: 'stale')],
        page: 1,
      );
    }
    return const Paged<AdminUser>(
      items: [AdminUser(id: '2', name: 'fresh')],
      page: 2,
    );
  }
}

class _FailingRepository extends _FakeAdminRepository {
  @override
  Future<Paged<AdminUser>> fetchUsers({
    int page = 1,
    int limit = 20,
    AdminRole? role,
    AdminUserStatus? status,
    String? search,
    String? sortBy,
    bool descending = false,
  }) async {
    throw const ForbiddenException('You do not have permission to do this.');
  }
}
