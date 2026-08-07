import 'package:flutter/material.dart';

import '../../../../core/services/permission_service.dart';

/// One entry on the employee menu.
///
/// The list mirrors the `EMPLOYEE` block of the website's `roleMenuConfig.ts`
/// one-for-one — same order, same names, same permission slugs — so an employee
/// sees the same menu on the phone as on the web.
///
/// The six entries after Notifications are the complex-scoped operations
/// modules. Their slugs are enforced **on the API** as well by
/// `employeePermission.js`, so hiding an ungranted one is not merely cosmetic:
/// the server would answer 403 anyway.
enum EmployeeDestination {
  overview(
    label: 'Dashboard',
    description: "Today's numbers and the latest bookings",
    icon: Icons.dashboard_outlined,
    permission: EmployeePermissions.dashboard,
    group: EmployeeMenuGroup.operations,
  ),
  bookings(
    label: 'Bookings Management',
    description: 'Court bookings — edit, complete, cancel',
    icon: Icons.event_note_outlined,
    permission: EmployeePermissions.bookings,
    group: EmployeeMenuGroup.operations,
  ),
  payments(
    label: 'Payments Management',
    description: 'Every payment across courts, events and coaching',
    icon: Icons.payments_outlined,
    permission: EmployeePermissions.payments,
    group: EmployeeMenuGroup.operations,
  ),
  attendance(
    label: 'Attendance Management',
    description: 'What coaches and the gate have marked',
    icon: Icons.fact_check_outlined,
    permission: EmployeePermissions.attendance,
    group: EmployeeMenuGroup.operations,
  ),
  coaches(
    label: 'Coaches Management',
    description: 'The coaches at your complex',
    icon: Icons.sports_outlined,
    permission: EmployeePermissions.coaches,
    group: EmployeeMenuGroup.operations,
  ),
  enquiries(
    label: 'Coaching Enquiries',
    description: 'Review, then approve and enroll',
    icon: Icons.forum_outlined,
    permission: EmployeePermissions.coachingEnquiries,
    group: EmployeeMenuGroup.operations,
  ),
  feesApproval(
    label: 'Fees Approval',
    description: 'Sign off collections and unlock gate passes',
    icon: Icons.verified_outlined,
    permission: EmployeePermissions.feesApproval,
    group: EmployeeMenuGroup.operations,
  ),
  users(
    label: 'Users Management',
    description: 'App accounts — details and status',
    icon: Icons.people_alt_outlined,
    permission: EmployeePermissions.users,
    group: EmployeeMenuGroup.operations,
  ),
  notifications(
    label: 'Notifications',
    description: 'Your inbox, and broadcasting to the complex',
    icon: Icons.notifications_none_rounded,
    permission: EmployeePermissions.notifications,
    group: EmployeeMenuGroup.operations,
  ),

  // ── Complex-scoped operations modules ──────────────────────────────────────
  blockedSlots(
    label: 'Blocked Slots',
    description: 'Close a court for a date — maintenance or an event',
    icon: Icons.block_outlined,
    permission: EmployeePermissions.blockedSlots,
    group: EmployeeMenuGroup.setup,
  ),
  feesManagement(
    label: 'Fees Management',
    description: 'Record and correct student fees',
    icon: Icons.account_balance_wallet_outlined,
    permission: EmployeePermissions.feesManagement,
    group: EmployeeMenuGroup.setup,
  ),
  sports(
    label: 'Sports',
    description: 'What your complex offers',
    icon: Icons.emoji_events_outlined,
    permission: EmployeePermissions.sports,
    group: EmployeeMenuGroup.setup,
  ),
  courts(
    label: 'Court',
    description: 'Courts and grounds, and what they cost',
    icon: Icons.place_outlined,
    permission: EmployeePermissions.courts,
    group: EmployeeMenuGroup.setup,
  ),
  slots(
    label: 'Slot',
    description: 'Bookable times on each court',
    icon: Icons.schedule_outlined,
    permission: EmployeePermissions.slots,
    group: EmployeeMenuGroup.setup,
  ),
  batches(
    label: 'Batch',
    description: 'Coaching batches, schedules and fees',
    icon: Icons.groups_outlined,
    permission: EmployeePermissions.batches,
    group: EmployeeMenuGroup.setup,
  ),

  profile(
    label: 'My Profile',
    description: 'Your account details',
    icon: Icons.account_circle_outlined,
    permission: EmployeePermissions.profile,
    group: EmployeeMenuGroup.account,
    alwaysShow: true,
  );

  const EmployeeDestination({
    required this.label,
    required this.description,
    required this.icon,
    required this.permission,
    required this.group,
    this.alwaysShow = false,
  });

  final String label;
  final String description;
  final IconData icon;

  /// The slug from `/auth/profile` that grants this entry.
  final String permission;

  /// Which heading the entry sits under on the menu.
  final EmployeeMenuGroup group;

  /// Shown even when the permission is absent — the website marks the profile
  /// entry this way, and the app follows so the two menus match.
  final bool alwaysShow;

  /// The destinations this employee may see, in menu order.
  ///
  /// Falls back to **everything** when no permissions have loaded at all: an
  /// empty permission set means the profile has not arrived yet (or the backend
  /// sent none), and showing an employee a blank menu is worse than showing an
  /// entry the server will refuse anyway.
  static List<EmployeeDestination> forCurrentUser() {
    final service = PermissionService.instance;
    if (service.permissions.isEmpty) return values;

    return values
        .where((d) => d.alwaysShow || service.hasPermission(d.permission))
        .toList(growable: false);
  }

  /// The granted destinations, bucketed by heading and with empty buckets
  /// dropped — the same shape the website's sidebar renders.
  static Map<EmployeeMenuGroup, List<EmployeeDestination>> groupedForCurrentUser() {
    final grouped = <EmployeeMenuGroup, List<EmployeeDestination>>{};

    for (final destination in forCurrentUser()) {
      grouped.putIfAbsent(destination.group, () => []).add(destination);
    }

    return grouped;
  }
}

/// The headings the menu is split under.
///
/// The website puts all seventeen entries in one flat `OPERATIONS` section,
/// which is workable in a sidebar and unreadable as a phone list. The split is
/// by what the entry *does*: day-to-day desk work, then the venue setup an
/// employee changes rarely.
enum EmployeeMenuGroup {
  operations('Day to day'),
  setup('Venue setup'),
  account('Account');

  const EmployeeMenuGroup(this.label);

  final String label;
}
