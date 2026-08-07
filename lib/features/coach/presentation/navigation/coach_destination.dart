import 'package:flutter/material.dart';

import '../../../../core/services/permission_service.dart';

/// Which build phase a destination's app screen has landed in.
///
/// The coach module is being brought over from the website one phase at a
/// time. A destination that is not built yet is still listed — hiding it would
/// make the app look like it has fewer features than the coach's own web
/// dashboard — but it says so plainly instead of opening a screen wired to the
/// retired API.
enum CoachDestinationStatus {
  /// Built and wired to the JWT backend.
  ready,

  /// Listed, not built yet.
  planned,
}

/// One entry on the coach menu.
///
/// The list mirrors the `COACH` block of the website's `roleMenuConfig.ts`
/// one-for-one — same order, same names, same permission slugs — so a coach
/// sees the same menu on the phone as on the web.
enum CoachDestination {
  overview(
    label: 'Dashboard',
    description: 'Your numbers, schedule and enquiries',
    icon: Icons.dashboard_outlined,
    permission: CoachPermissions.dashboard,
    status: CoachDestinationStatus.ready,
  ),
  students(
    label: 'My Students',
    description: 'Everyone on your roster',
    icon: Icons.people_alt_outlined,
    permission: CoachPermissions.students,
    status: CoachDestinationStatus.ready,
  ),
  enrollments(
    label: 'Student Enrollments',
    description: 'Month-wise joiners, batch by batch',
    icon: Icons.calendar_month_outlined,
    permission: CoachPermissions.students,
    status: CoachDestinationStatus.ready,
  ),
  attendance(
    label: 'Attendance Sheet',
    description: 'Mark and review attendance',
    icon: Icons.fact_check_outlined,
    permission: CoachPermissions.attendance,
    status: CoachDestinationStatus.ready,
  ),
  scanner(
    label: 'Pass Scanner',
    description: 'Scan a gate pass to mark entry',
    icon: Icons.qr_code_scanner_rounded,
    permission: CoachPermissions.attendance,
    status: CoachDestinationStatus.ready,
  ),
  enquiries(
    label: 'Coaching Enquiries',
    description: 'Your enquiry queue',
    icon: Icons.forum_outlined,
    permission: CoachPermissions.coachingEnquiries,
    status: CoachDestinationStatus.ready,
  ),
  schedule(
    label: 'My Schedule',
    description: 'Your batches and timings',
    icon: Icons.event_note_outlined,
    permission: CoachPermissions.schedule,
    status: CoachDestinationStatus.ready,
  ),
  progress(
    label: 'Student Progress',
    description: 'Record and track assessments',
    icon: Icons.trending_up_rounded,
    permission: CoachPermissions.performance,
    status: CoachDestinationStatus.ready,
  ),
  feesManagement(
    label: 'Fees Management',
    description: 'Collect and track student fees',
    icon: Icons.account_balance_wallet_outlined,
    permission: CoachPermissions.feesManagement,
    status: CoachDestinationStatus.ready,
  ),
  feesApproval(
    label: 'Fees Approval',
    description: 'Payments waiting on an admin',
    icon: Icons.verified_outlined,
    permission: CoachPermissions.feesApproval,
    status: CoachDestinationStatus.ready,
  ),
  notifications(
    label: 'Notifications',
    description: 'Your inbox, and sending one',
    icon: Icons.notifications_none_rounded,
    permission: CoachPermissions.notifications,
    status: CoachDestinationStatus.ready,
  ),
  profile(
    label: 'My Profile',
    description: 'Your account details',
    icon: Icons.account_circle_outlined,
    permission: CoachPermissions.profile,
    status: CoachDestinationStatus.ready,
    alwaysShow: true,
  );

  const CoachDestination({
    required this.label,
    required this.description,
    required this.icon,
    required this.permission,
    required this.status,
    this.alwaysShow = false,
  });

  final String label;
  final String description;
  final IconData icon;

  /// The slug from `/auth/profile` that grants this entry.
  final String permission;

  final CoachDestinationStatus status;

  /// Shown even when the permission is absent — the website marks the profile
  /// entry this way, and the app follows so the two menus match.
  final bool alwaysShow;

  bool get isReady => status == CoachDestinationStatus.ready;

  /// The destinations this coach may see, in menu order.
  ///
  /// Falls back to **everything** when no permissions have loaded at all: an
  /// empty permission set means the profile has not arrived yet (or the
  /// backend sent none), and showing a coach a blank menu is worse than
  /// showing an entry the server will refuse anyway.
  static List<CoachDestination> forCurrentUser() {
    final service = PermissionService.instance;
    if (service.permissions.isEmpty) return values;

    return values
        .where((d) => d.alwaysShow || service.hasPermission(d.permission))
        .toList(growable: false);
  }
}
