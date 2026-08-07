import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nahata_app/bottombar/Custombottombar.dart';
import 'package:nahata_app/core/navigation/role_router.dart';
import 'package:nahata_app/core/services/app_session.dart';
import 'package:nahata_app/core/services/permission_service.dart';
import 'package:nahata_app/features/admin/presentation/navigation/admin_destination.dart';
import 'package:nahata_app/features/admin/presentation/navigation/admin_module.dart';
import 'package:nahata_app/features/admin/presentation/navigation/admin_shell_config.dart';
import 'package:nahata_app/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:nahata_app/features/complex_admin/presentation/pages/complex_admin_dashboard_page.dart';
import 'package:nahata_app/models/profile_model.dart';

/// `data.user` from `POST /auth/login` for an ADMIN, verbatim.
Map<String, dynamic> _adminUser() => <String, dynamic>{
      'id': 1,
      'name': 'Admin User',
      'email': 'admin@nahatasports.com',
      'role': 'ADMIN',
      'phone_number': '+1234567890',
      'sportComplexId': null,
      'sportComplex': null,
      'permissions': _fullPermissions(),
    };

/// The same call for a COMPLEX_ADMIN — note the venue fields.
Map<String, dynamic> _complexAdminUser({
  Map<String, dynamic>? permissions,
}) =>
    <String, dynamic>{
      'id': 503,
      'name': 'Sinhagad Road',
      'email': 'sinhagad.admin@nahatasports.com',
      'role': 'COMPLEX_ADMIN',
      'phone_number': null,
      'sportComplexId': 1,
      'sportComplex': {'id': 1, 'name': 'Sinhagad Road', 'city': 'Pune'},
      'permissions': permissions ?? _fullPermissions(),
    };

Map<String, dynamic> _fullPermissions() => <String, dynamic>{
      for (final module in const [
        'dashboard',
        'users',
        'roles',
        'memberships',
        'payments',
        'coupons',
        'reports',
        'sports',
        'courts',
        'sportsComplex',
        'programs',
        'batches',
        'coaches',
        'students',
        'bookings',
      ])
        module: {'view': true, 'create': true, 'edit': true, 'delete': true},
      'settings': {'view': true, 'edit': true},
    };

void main() {
  tearDown(PermissionService.instance.clear);

  group('ProfileModel — login payload', () {
    test('reads the complex admin venue', () {
      final profile = ProfileModel.fromJson(_complexAdminUser());

      expect(profile.isComplexAdmin, isTrue);
      expect(profile.isAdmin, isFalse);
      expect(profile.sportComplexId, 1);
      expect(profile.sportComplex?.name, 'Sinhagad Road');
      expect(profile.sportComplex?.city, 'Pune');
      expect(profile.sportComplex?.label, 'Sinhagad Road, Pune');
    });

    test('an admin has no venue', () {
      final profile = ProfileModel.fromJson(_adminUser());

      expect(profile.isAdmin, isTrue);
      expect(profile.sportComplexId, isNull);
      expect(profile.sportComplex, isNull);
    });

    test('reads the object-form permissions', () {
      final profile = ProfileModel.fromJson(
        _complexAdminUser(
          permissions: {
            'dashboard': {'view': true},
            'students': {'view': false, 'create': true},
          },
        ),
      );

      expect(profile.can('dashboard', 'view'), isTrue);
      expect(profile.can('students', 'view'), isFalse);
      expect(profile.can('students', 'create'), isTrue);
      // Unknown module / action, never a crash.
      expect(profile.can('students', 'delete'), isFalse);
      expect(profile.can('nonsense', 'view'), isFalse);
      // Granted actions are also exposed as flat slugs.
      expect(profile.permissions, contains('dashboard.view'));
      expect(profile.permissions, isNot(contains('students.view')));
    });

    test('the legacy slug list still parses', () {
      final profile = ProfileModel.fromJson({
        'id': 7,
        'role': 'COACH',
        'permissions': ['coach_dashboard', 'coach_students'],
      });

      expect(profile.permissionMatrix, isEmpty);
      expect(profile.hasPermission('coach_dashboard'), isTrue);
      expect(profile.can('students', 'view'), isFalse);
    });

    test('survives a cache round-trip in both shapes', () {
      for (final source in [_complexAdminUser(), _adminUser()]) {
        final original = ProfileModel.fromJson(source);
        final restored = ProfileModel.decode(original.encode());

        expect(restored, isNotNull);
        expect(restored!.roleKey, original.roleKey);
        expect(restored.sportComplex, original.sportComplex);
        expect(restored.can('bookings', 'edit'), original.can('bookings', 'edit'));
      }
    });
  });

  group('AppSession', () {
    test('exposes the venue globally after a complex admin signs in', () {
      PermissionService.instance.sync(
        ProfileModel.fromJson(_complexAdminUser()),
      );

      final session = AppSession.instance;
      expect(session.isComplexAdmin, isTrue);
      expect(session.hasComplexScope, isTrue);
      expect(session.sportComplexId, 1);
      expect(session.sportComplexName, 'Sinhagad Road');
      expect(session.sportComplexCity, 'Pune');
      expect(session.canCreate('bookings'), isTrue);
    });

    test('keeps the venue and matrix when /auth/profile omits them', () {
      PermissionService.instance.sync(
        ProfileModel.fromJson(_complexAdminUser()),
      );

      // What `GET /auth/profile` returns for the same account: no permission
      // object, no complex.
      PermissionService.instance.sync(
        ProfileModel.fromJson({
          'id': 503,
          'name': 'Sinhagad Road',
          'role': 'COMPLEX_ADMIN',
          'permissions': <String>[],
        }),
      );

      expect(AppSession.instance.sportComplexId, 1);
      expect(AppSession.instance.sportComplexName, 'Sinhagad Road');
      expect(AppSession.instance.canView('bookings'), isTrue);
      expect(PermissionService.instance.matrix, isNotEmpty);
    });

    test('a payload that does carry permissions replaces them', () {
      PermissionService.instance.sync(
        ProfileModel.fromJson(_complexAdminUser()),
      );
      PermissionService.instance.sync(
        ProfileModel.fromJson(
          _complexAdminUser(
            permissions: {
              'bookings': {'view': false},
            },
          ),
        ),
      );

      expect(AppSession.instance.canView('bookings'), isFalse);
    });

    test('a different user does not inherit the previous session', () {
      PermissionService.instance.sync(
        ProfileModel.fromJson(_complexAdminUser()),
      );
      PermissionService.instance.sync(ProfileModel.fromJson(_adminUser()));

      expect(AppSession.instance.sportComplexId, isNull);
      expect(AppSession.instance.isComplexAdmin, isFalse);
    });

    test('is cleared on sign-out', () {
      PermissionService.instance.sync(
        ProfileModel.fromJson(_complexAdminUser()),
      );
      PermissionService.instance.clear();

      expect(AppSession.instance.isSignedIn, isFalse);
      expect(AppSession.instance.sportComplexId, isNull);
      expect(AppSession.instance.canView('bookings'), isFalse);
    });
  });

  group('RoleRouter', () {
    test('sends each role to its own dashboard', () {
      expect(RoleRouter.screenFor('ADMIN'), isA<AdminDashboardScreen>());
      expect(
        RoleRouter.screenFor('COMPLEX_ADMIN'),
        isA<ComplexAdminDashboardScreen>(),
      );
      expect(RoleRouter.screenFor('USER'), isA<CustomBottomNav>());
      expect(RoleRouter.screenFor(null), isA<CustomBottomNav>());
    });

    test('a complex admin never lands on the student dashboard', () {
      for (final spelling in const [
        'COMPLEX_ADMIN',
        'complex_admin',
        'Complex-Admin',
        'complex admin',
      ]) {
        expect(
          RoleRouter.screenFor(spelling),
          isA<ComplexAdminDashboardScreen>(),
          reason: '"$spelling" must reach the complex admin console',
        );
      }
    });

    test('the admin console is not the complex admin one', () {
      expect(RoleRouter.screenFor('ADMIN'), isNot(isA<ComplexAdminDashboardScreen>()));
    });
  });

  group('Permission-driven sidebar', () {
    test('lists only what the payload grants', () {
      PermissionService.instance.sync(
        ProfileModel.fromJson(
          _complexAdminUser(
            permissions: {
              'dashboard': {'view': true},
              'bookings': {'view': true, 'create': false},
              'sports': {'view': false},
              'coupons': {'view': false},
            },
          ),
        ),
      );

      final config = AdminShellConfig.complexAdmin();
      final visible = config.allowedDestinations;

      expect(visible, contains(AdminDestination.dashboard));
      expect(visible, contains(AdminDestination.bookings));
      expect(visible, isNot(contains(AdminDestination.sports)));
      expect(visible, isNot(contains(AdminDestination.coupons)));
      // Estate-wide modules are not part of this console at all.
      expect(visible, isNot(contains(AdminDestination.employees)));

      expect(config.allows(AdminDestination.sports), isFalse);
      expect(AdminAccess.canCreate(AdminModules.bookings), isFalse);
      expect(AdminAccess.canView(AdminModules.bookings), isTrue);
    });

    test('is branded with the complex', () {
      PermissionService.instance.sync(
        ProfileModel.fromJson(_complexAdminUser()),
      );

      final config = AdminShellConfig.complexAdmin();
      expect(config.title, 'Sinhagad Road');
      expect(config.subtitle, contains('Complex Admin'));
      expect(config.enforcePermissions, isTrue);
    });

    test('opens on a module the user actually has', () {
      PermissionService.instance.sync(
        ProfileModel.fromJson(
          _complexAdminUser(
            permissions: {
              'dashboard': {'view': false},
              'bookings': {'view': true},
            },
          ),
        ),
      );

      expect(
        AdminShellConfig.complexAdmin().initialDestination,
        AdminDestination.bookings,
      );
    });

    test('the ADMIN console keeps every module and no filtering', () {
      PermissionService.instance.sync(ProfileModel.fromJson(_adminUser()));

      const config = AdminShellConfig.admin;
      expect(config.enforcePermissions, isFalse);
      expect(config.title, 'Nahata Sports');
      expect(config.subtitle, 'Admin Console');
      expect(config.initialDestination, AdminDestination.dashboard);
      for (final destination in AdminDestination.values) {
        expect(config.allows(destination), isTrue, reason: destination.name);
      }
    });
  });

  group('AdminAccess', () {
    test('permits everything when the backend sent no matrix', () {
      PermissionService.instance.sync(
        ProfileModel.fromJson({
          'id': 7,
          'role': 'ADMIN',
          'permissions': ['legacy_slug'],
        }),
      );

      expect(AdminAccess.canCreate(AdminModules.sports), isTrue);
      expect(AdminAccess.allows(AdminDestination.reports), isTrue);
    });

    test('filters a row menu down to the granted actions', () {
      PermissionService.instance.sync(
        ProfileModel.fromJson(
          _complexAdminUser(
            permissions: {
              'sports': {'view': true, 'edit': false, 'delete': false},
            },
          ),
        ),
      );

      final menu = <PopupMenuEntry<String>>[
        const PopupMenuItem<String>(value: 'view', child: Text('View')),
        const PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
        const PopupMenuDivider(),
        const PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
      ].gatedBy(
        AdminModules.sports,
        isDestructive: (a) => a == 'delete',
        isReadOnly: (a) => a == 'view',
      );

      expect(menu, hasLength(1));
      expect((menu.single as PopupMenuItem<String>).value, 'view');
    });
  });
}