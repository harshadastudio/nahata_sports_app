import 'package:flutter/material.dart';

import '../../../../core/services/permission_service.dart';
import 'admin_destination.dart';

/// The module keys used by `data.user.permissions`.
///
/// Spelled exactly as the backend sends them — `sportsComplex` is camel case
/// there while everything else is lower case, so it stays that way here rather
/// than being "tidied" into something that would silently never match.
class AdminModules {
  const AdminModules._();

  static const String dashboard = 'dashboard';
  static const String users = 'users';
  static const String roles = 'roles';
  static const String memberships = 'memberships';
  static const String payments = 'payments';
  static const String coupons = 'coupons';
  static const String reports = 'reports';
  static const String sports = 'sports';
  static const String courts = 'courts';
  static const String sportsComplex = 'sportsComplex';
  static const String programs = 'programs';
  static const String batches = 'batches';
  static const String coaches = 'coaches';
  static const String students = 'students';
  static const String bookings = 'bookings';
  static const String settings = 'settings';
}

/// Which permission module gates which sidebar entry.
extension AdminDestinationPermission on AdminDestination {
  /// Null for destinations the permission payload has no key for — those are
  /// never permission-filtered, only included or excluded by the shell config.
  String? get permissionModule {
    switch (this) {
      case AdminDestination.dashboard:
        return AdminModules.dashboard;
      case AdminDestination.users:
      case AdminDestination.complexAdmins:
      case AdminDestination.employees:
      case AdminDestination.securityGuards:
        return AdminModules.users;
      case AdminDestination.sportsComplexes:
        return AdminModules.sportsComplex;
      case AdminDestination.sports:
        return AdminModules.sports;
      case AdminDestination.coaches:
        return AdminModules.coaches;
      case AdminDestination.batches:
        return AdminModules.batches;
      case AdminDestination.coachingEnquiries:
        return AdminModules.students;
      case AdminDestination.courts:
        return AdminModules.courts;
      case AdminDestination.events:
      case AdminDestination.visitorPasses:
      case AdminDestination.securityDashboard:
      case AdminDestination.bookings:
        return AdminModules.bookings;
      case AdminDestination.memberships:
        return AdminModules.memberships;
      case AdminDestination.coupons:
        return AdminModules.coupons;
      case AdminDestination.payments:
        return AdminModules.payments;
      case AdminDestination.reports:
        return AdminModules.reports;
      case AdminDestination.settings:
        return AdminModules.settings;
    }
  }
}

/// "May the signed-in user do X?", for the console's UI.
///
/// A thin, readable front for [PermissionService] so pages read
/// `AdminAccess.canCreate(AdminModules.sports)` instead of reaching into the
/// service and spelling the action out. Everything comes from
/// `data.user.permissions` — nothing here is hard-coded per role.
///
/// When the backend sends no permission matrix at all (the legacy slug list, or
/// an offline start-up before the profile lands) every check answers **true**:
/// an absent payload must not lock an admin out of a console they could use
/// yesterday. Only an explicit `false` hides anything.
class AdminAccess {
  const AdminAccess._();

  static PermissionService get _service => PermissionService.instance;

  /// True while the console has no matrix to judge by — see the class note.
  static bool get _unrestricted => _service.matrix.isEmpty;

  static bool can(String? module, String action) {
    if (module == null || _unrestricted) return true;
    return _service.can(module, action);
  }

  static bool canView(String? module) => can(module, 'view');
  static bool canCreate(String? module) => can(module, 'create');
  static bool canEdit(String? module) => can(module, 'edit');
  static bool canDelete(String? module) => can(module, 'delete');

  /// Whether a sidebar entry / page may be opened at all.
  static bool allows(AdminDestination destination) =>
      canView(destination.permissionModule);
}

/// Permission filtering for a row's "more actions" menu.
///
/// Written as an extension so a table gates its menu by appending one call to
/// the list it already builds — the entries themselves stay where they are:
///
/// ```dart
/// itemBuilder: (context) => <PopupMenuEntry<SportAction>>[
///   _item(SportAction.edit, …),
///   _item(SportAction.delete, …),
/// ].gatedBy(
///   AdminModules.sports,
///   isDestructive: (a) => a == SportAction.delete,
///   isReadOnly: (a) => a == SportAction.view,
/// ),
/// ```
///
/// Read-only entries always survive; destructive ones need
/// `permissions.<module>.delete` and everything else `…edit`.
extension AdminMenuGate<T> on List<PopupMenuEntry<T>> {
  List<PopupMenuEntry<T>> gatedBy(
    String module, {
    bool Function(T value)? isDestructive,
    bool Function(T value)? isReadOnly,
  }) {
    final mayEdit = AdminAccess.canEdit(module);
    final mayDelete = AdminAccess.canDelete(module);
    if (mayEdit && mayDelete) return this;

    final kept = <PopupMenuEntry<T>>[];
    for (final entry in this) {
      if (entry is PopupMenuItem<T>) {
        final value = entry.value;
        if (value != null && !(isReadOnly?.call(value) ?? false)) {
          final allowed =
              (isDestructive?.call(value) ?? false) ? mayDelete : mayEdit;
          if (!allowed) continue;
        }
      }
      kept.add(entry);
    }

    return _withoutStrandedDividers(kept);
  }

  /// Removes the separators left hanging when the entries around them were
  /// filtered out — leading, trailing and doubled-up.
  static List<PopupMenuEntry<T>> _withoutStrandedDividers<T>(
    List<PopupMenuEntry<T>> entries,
  ) {
    final tidy = <PopupMenuEntry<T>>[];
    for (final entry in entries) {
      final isDivider = entry is PopupMenuDivider;
      if (isDivider && (tidy.isEmpty || tidy.last is PopupMenuDivider)) {
        continue;
      }
      tidy.add(entry);
    }
    while (tidy.isNotEmpty && tidy.last is PopupMenuDivider) {
      tidy.removeLast();
    }
    return tidy;
  }
}