import 'package:flutter_test/flutter_test.dart';

import 'package:nahata_app/core/api/api_role.dart';
import 'package:nahata_app/core/api/api_trace.dart';
import 'package:nahata_app/core/api/complex_scope.dart';
import 'package:nahata_app/core/api/role_api_map.dart';
import 'package:nahata_app/core/services/permission_service.dart';
import 'package:nahata_app/features/admin/presentation/navigation/admin_module.dart';
import 'package:nahata_app/models/profile_model.dart';
import 'package:nahata_app/models/sports_complex_model.dart';

/// `data.user` from `POST /auth/login`, per role.
Map<String, dynamic> _adminUser() => <String, dynamic>{
  'id': 1,
  'name': 'Admin User',
  'email': 'admin@nahatasports.com',
  'role': 'ADMIN',
  'sportComplexId': null,
  'sportComplex': null,
  'permissions': _permissions(),
};

Map<String, dynamic> _complexAdminUser({int? complexId = 1}) =>
    <String, dynamic>{
      'id': 503,
      'name': 'Sinhagad Road',
      'email': 'sinhagad.admin@nahatasports.com',
      'role': 'COMPLEX_ADMIN',
      'sportComplexId': complexId,
      'sportComplex': complexId == null
          ? null
          : {'id': complexId, 'name': 'Sinhagad Road', 'city': 'Pune'},
      'permissions': _permissions(),
    };

Map<String, dynamic> _permissions() => <String, dynamic>{
  for (final module in const [
    'dashboard',
    'users',
    'sports',
    'sportsComplex',
    'coaches',
    'batches',
    'courts',
    'bookings',
    'memberships',
    'coupons',
    'payments',
    'reports',
    'students',
  ])
    module: {'view': true, 'create': true, 'edit': true, 'delete': true},
  'settings': {'view': true, 'edit': true},
};

void _signIn(Map<String, dynamic> user) =>
    PermissionService.instance.sync(ProfileModel.fromJson(user));

void main() {
  tearDown(PermissionService.instance.clear);

  group('ApiRole', () {
    test('normalises every spelling of the role string', () {
      for (final spelling in const [
        'COMPLEX_ADMIN',
        'complex-admin',
        'Complex Admin',
        ' complex_admin ',
      ]) {
        expect(
          ApiRole.fromRole(spelling),
          ApiRole.complexAdmin,
          reason: '"$spelling" must resolve to COMPLEX_ADMIN',
        );
      }
    });

    test('an unknown, empty or null role is never administrative', () {
      for (final spelling in <String?>[null, '', 'student', 'nonsense']) {
        expect(ApiRole.fromRole(spelling), ApiRole.user);
        expect(ApiRole.fromRole(spelling).isAdministrative, isFalse);
      }
    });

    test('reads the signed-in account', () {
      _signIn(_complexAdminUser());
      expect(ApiRole.current, ApiRole.complexAdmin);

      _signIn(_adminUser());
      expect(ApiRole.current, ApiRole.admin);

      PermissionService.instance.clear();
      expect(ApiRole.current, ApiRole.user);
    });
  });

  group('The confirmed URLs', () {
    test('ADMIN + EMPLOYEES → /admin/employees, with the captured query', () {
      final route = RoleApiMap.require(
        ApiModule.employees,
        role: ApiRole.admin,
      );

      expect(route.method, 'GET');
      expect(route.path, '/admin/employees');
      expect(route.query['page'], 1);
      expect(route.query['limit'], 10);
      // Sent present-but-empty, exactly as the captured URL has them.
      expect(route.query['search'], '');
      expect(route.query['department'], '');
      expect(route.query['status'], '');
    });

    test('COMPLEX_ADMIN + COACHES → /coaches?page=1&limit=100', () {
      final route = RoleApiMap.require(
        ApiModule.coaches,
        role: ApiRole.complexAdmin,
      );

      expect(route.method, 'GET');
      expect(route.path, '/coaches');
      expect(route.query['page'], 1);
      expect(route.query['limit'], 100);
      // The backend reads the venue from the JWT, so the URL must not carry it.
      expect(route.scopeFromJwt, isTrue);
      expect(route.query.containsKey('sportComplexId'), isFalse);
    });

    test('SPORTS is /sports?page=1&limit=100&status=Active for both', () {
      for (final role in const [ApiRole.admin, ApiRole.complexAdmin]) {
        final route = RoleApiMap.require(ApiModule.sports, role: role);
        expect(route.path, '/sports');
        expect(route.query['page'], 1);
        expect(route.query['limit'], 100);
        expect(route.query['status'], 'Active');
      }
    });

    test('SPORTS_COMPLEXES is /sports-complexes?page=1&limit=100', () {
      for (final role in const [ApiRole.admin, ApiRole.complexAdmin]) {
        final route = RoleApiMap.require(
          ApiModule.sportsComplexes,
          role: role,
        );
        expect(route.path, '/sports-complexes');
        expect(route.query['page'], 1);
        expect(route.query['limit'], 100);
      }

      // ADMIN works with the global catalogue; a venue admin is restricted to
      // its own — and that restriction is ours, not a second endpoint.
      expect(
        RoleApiMap.require(
          ApiModule.sportsComplexes,
          role: ApiRole.admin,
        ).complexScoped,
        isFalse,
      );
      expect(
        RoleApiMap.require(
          ApiModule.sportsComplexes,
          role: ApiRole.complexAdmin,
        ).complexScoped,
        isTrue,
      );
    });
  });

  group('Employees and Coaches are never merged', () {
    test('the two modules resolve to different endpoints', () {
      final employees = RoleApiMap.require(
        ApiModule.employees,
        role: ApiRole.admin,
      );
      final coaches = RoleApiMap.require(
        ApiModule.coaches,
        role: ApiRole.complexAdmin,
      );

      expect(employees.path, isNot(coaches.path));
      expect(employees.path, '/admin/employees');
      expect(coaches.path, '/coaches');
    });

    test('ADMIN Employees never becomes /coaches', () {
      expect(
        RoleApiMap.require(ApiModule.employees, role: ApiRole.admin).path,
        isNot(contains('coaches')),
      );
    });

    test('COMPLEX_ADMIN has no Employees route at all', () {
      expect(
        RoleApiMap.list(ApiModule.employees, role: ApiRole.complexAdmin),
        isNull,
      );
      expect(
        RoleApiMap.supports(ApiModule.employees, role: ApiRole.complexAdmin),
        isFalse,
      );
    });

    test('asking for it refuses rather than borrowing the other role\'s URL',
        () {
      expect(
        () => RoleApiMap.require(
          ApiModule.employees,
          role: ApiRole.complexAdmin,
        ),
        throwsA(
          isA<UnmappedModuleException>()
              // Surfaces as a 403 so screens show the permission message they
              // already show for a real one — and route nobody anywhere.
              .having((e) => e.statusCode, 'statusCode', 403),
        ),
      );
    });

    test('the other estate-wide registries are ADMIN-only too', () {
      for (final module in const [
        ApiModule.complexAdmins,
        ApiModule.securityGuards,
        ApiModule.roles,
      ]) {
        expect(
          RoleApiMap.supports(module, role: ApiRole.admin),
          isTrue,
          reason: '${module.traceName} must stay available to ADMIN',
        );
        expect(
          RoleApiMap.supports(module, role: ApiRole.complexAdmin),
          isFalse,
          reason: '${module.traceName} has no confirmed venue-scoped route',
        );
      }
    });
  });

  group('The map covers every module', () {
    test('ADMIN reaches all of them', () {
      for (final module in ApiModule.values) {
        expect(
          RoleApiMap.supports(module, role: ApiRole.admin),
          isTrue,
          reason: '${module.traceName} has no ADMIN mapping',
        );
      }
    });

    test('every path is a real endpoint, not an invented one', () {
      for (final module in ApiModule.values) {
        final route = RoleApiMap.require(module, role: ApiRole.admin);
        expect(route.path, startsWith('/'));
        expect(route.path, isNot(endsWith('/')));
        expect(route.method, 'GET');
      }
    });

    test('permission keys match the console\'s module keys', () {
      // One vocabulary for `data.user.permissions`: if these two ever drift,
      // a sidebar entry silently stops matching its own permission.
      expect(ApiModule.dashboard.permissionKey, AdminModules.dashboard);
      expect(ApiModule.users.permissionKey, AdminModules.users);
      expect(ApiModule.roles.permissionKey, AdminModules.roles);
      expect(ApiModule.employees.permissionKey, AdminModules.users);
      expect(
        ApiModule.sportsComplexes.permissionKey,
        AdminModules.sportsComplex,
      );
      expect(ApiModule.sports.permissionKey, AdminModules.sports);
      expect(ApiModule.coaches.permissionKey, AdminModules.coaches);
      expect(ApiModule.batches.permissionKey, AdminModules.batches);
      expect(ApiModule.courts.permissionKey, AdminModules.courts);
      expect(ApiModule.bookings.permissionKey, AdminModules.bookings);
      expect(ApiModule.memberships.permissionKey, AdminModules.memberships);
      expect(ApiModule.coupons.permissionKey, AdminModules.coupons);
      expect(ApiModule.payments.permissionKey, AdminModules.payments);
      expect(ApiModule.reports.permissionKey, AdminModules.reports);
      expect(ApiModule.settings.permissionKey, AdminModules.settings);
      expect(
        ApiModule.coachingEnquiries.permissionKey,
        AdminModules.students,
      );
    });
  });

  group('ComplexScope', () {
    const venues = <SportsComplex>[
      SportsComplex(id: 1, name: 'Sinhagad Road', city: 'Pune'),
      SportsComplex(id: 2, name: 'Gangadham Chowk', city: 'Pune'),
      SportsComplex(id: 3, name: 'Kondhwa', city: 'Pune'),
    ];

    test('is inactive for an ADMIN', () {
      _signIn(_adminUser());

      expect(ComplexScope.isActive, isFalse);
      expect(ComplexScope.id, isNull);
      expect(ComplexScope.pin(2), 2);
      expect(ComplexScope.restrict(venues, (v) => v.id), hasLength(3));
    });

    test('narrows a COMPLEX_ADMIN to its assigned venue', () {
      _signIn(_complexAdminUser());

      expect(ComplexScope.isActive, isTrue);
      expect(ComplexScope.id, 1);
      expect(ComplexScope.name, 'Sinhagad Road');

      final scoped = ComplexScope.restrict(venues, (v) => v.id);
      expect(scoped, hasLength(1));
      expect(scoped.single.name, 'Sinhagad Road');
    });

    test('the venue comes from the session, never a constant', () {
      _signIn(_complexAdminUser(complexId: 7));

      expect(ComplexScope.id, 7);
      // The brief's example value must not be baked in anywhere.
      expect(ComplexScope.id, isNot(1));
      expect(RoleApiMap.scopedComplexId, 7);
    });

    test('a complex admin cannot select another complex', () {
      _signIn(_complexAdminUser());

      expect(ComplexScope.pin(2), 1);
      expect(ComplexScope.pin(null), 1);
    });

    test('a row that reports no venue is kept, not dropped', () {
      _signIn(_complexAdminUser());

      final rows = ['own', 'other', 'unknown'];
      final kept = ComplexScope.restrict(
        rows,
        (row) => switch (row) {
          'own' => 1,
          'other' => 2,
          _ => null,
        },
      );

      expect(kept, ['own', 'unknown']);
    });

    test('fails open when the account carries no complex', () {
      // A COMPLEX_ADMIN with no venue on the session is a server-side
      // misconfiguration. Scoping it to "no venue" would render an empty
      // console the user cannot fix; the backend still refuses what it should.
      _signIn(_complexAdminUser(complexId: null));

      expect(ComplexScope.isActive, isFalse);
      expect(ComplexScope.restrict(venues, (v) => v.id), hasLength(3));
    });
  });

  group('API trace', () {
    test('builds the absolute URL the log line prints', () {
      final url = ApiTrace.url('/coaches', {'page': 1, 'limit': 100});

      expect(url, endsWith('/coaches?page=1&limit=100'));
      expect(url, startsWith('http'));
    });

    test('drops null parameters and needs no query at all', () {
      expect(
        ApiTrace.url('/sports', {'page': 1, 'status': null}),
        endsWith('/sports?page=1'),
      );
      expect(ApiTrace.url('/sports'), endsWith('/sports'));
    });

    test('names the module behind a URL, so every call is tagged', () {
      const cases = <String, ApiModule>{
        '/coaches': ApiModule.coaches,
        '/coaches/12/reset-password': ApiModule.coaches,
        '/admin/employees': ApiModule.employees,
        '/admin/employees/emp-1/password': ApiModule.employees,
        '/admin/security-guards': ApiModule.securityGuards,
        '/admin/users?role=COACH': ApiModule.users,
        '/sports/8/stats': ApiModule.sports,
        '/memberships/check-expired': ApiModule.memberships,
        '/reports/booking-trends': ApiModule.reports,
      };

      cases.forEach((path, module) {
        expect(RoleApiMap.moduleForPath(path), module, reason: path);
      });
    });

    test('/sports never claims /sports-complexes', () {
      expect(
        RoleApiMap.moduleForPath('/sports-complexes'),
        ApiModule.sportsComplexes,
      );
      expect(
        RoleApiMap.moduleForPath('/sports-complexes/3/stats'),
        ApiModule.sportsComplexes,
      );
      expect(RoleApiMap.moduleForPath('/sports'), ApiModule.sports);
    });

    test('a court\'s slots are the Slots module, not Courts', () {
      expect(RoleApiMap.moduleForPath('/courts'), ApiModule.courts);
      expect(RoleApiMap.moduleForPath('/courts/5'), ApiModule.courts);
      expect(
        RoleApiMap.moduleForPath('/courts/5/slots'),
        ApiModule.courtSlots,
      );
      expect(
        RoleApiMap.moduleForPath('/courts/5/slots/9/toggle'),
        ApiModule.courtSlots,
      );
    });

    test('accepts the absolute path the HTTP client ends up with', () {
      expect(RoleApiMap.moduleForPath('/api/coaches'), ApiModule.coaches);
      expect(
        RoleApiMap.moduleForPath('/api/admin/employees'),
        ApiModule.employees,
      );
    });

    test('a path outside the console has no module rather than a guess', () {
      for (final path in const [
        '/auth/login',
        '/auth/profile',
        '/coach/dashboard/stats',
        '/api',
      ]) {
        expect(RoleApiMap.moduleForPath(path), isNull, reason: path);
      }
    });

    test('the endpoints confirmed alongside Contact Enquiries are mapped', () {
      const cases = <String, ApiModule>{
        '/contact-us/admin': ApiModule.contactEnquiries,
        '/students': ApiModule.students,
        // The customer's own record sits under the same prefix. Naming it
        // STUDENTS in a log line is accurate; it is a trace label, not an
        // authorisation decision.
        '/students/me': ApiModule.students,
        '/fees': ApiModule.fees,
        '/fees/retention-stats': ApiModule.fees,
        '/courts': ApiModule.courts,
      };

      cases.forEach((path, module) {
        expect(RoleApiMap.moduleForPath(path), module, reason: path);
      });
    });
  });

  group('Permission helpers read the login payload', () {
    test('a granted module is viewable, an absent one is not', () {
      _signIn(_complexAdminUser());

      final permissions = PermissionService.instance;
      expect(permissions.canView(AdminModules.coaches), isTrue);
      expect(permissions.canCreate(AdminModules.coaches), isTrue);
      expect(permissions.canEdit(AdminModules.coaches), isTrue);
      expect(permissions.canDelete(AdminModules.coaches), isTrue);

      // Never granted in the payload above — and never assumed from the role.
      expect(permissions.canView('somethingElse'), isFalse);
      expect(permissions.canDelete(AdminModules.settings), isFalse);
    });

    test('COMPLEX_ADMIN is not hard-coded to everything', () {
      _signIn(<String, dynamic>{
        ..._complexAdminUser(),
        'permissions': {
          'dashboard': {'view': true},
          'coaches': {'view': true, 'create': false},
        },
      });

      final permissions = PermissionService.instance;
      expect(permissions.canView(AdminModules.coaches), isTrue);
      expect(permissions.canCreate(AdminModules.coaches), isFalse);
      expect(permissions.canView(AdminModules.memberships), isFalse);
    });
  });
}