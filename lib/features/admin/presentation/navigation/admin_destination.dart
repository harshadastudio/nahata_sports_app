import 'package:flutter/material.dart';

/// One entry in the left sidebar.
///
/// Adding a module later is a matter of appending a value here and returning a
/// page for it in `AdminDashboardPage._pageFor` — nothing else moves.
enum AdminDestination {
  dashboard(
    label: 'Dashboard',
    icon: Icons.space_dashboard_outlined,
    activeIcon: Icons.space_dashboard_rounded,
    subtitle: 'Overview and key numbers',
    ready: true,
  ),
  users(
    label: 'Users, Roles & Permissions',
    shortLabel: 'Users & Roles',
    icon: Icons.manage_accounts_outlined,
    activeIcon: Icons.manage_accounts_rounded,
    subtitle: 'Accounts, access and permissions',
    ready: true,
    primary: true,
  ),
  complexAdmins(
    label: 'Complex Admin',
    icon: Icons.admin_panel_settings_outlined,
    activeIcon: Icons.admin_panel_settings_rounded,
    subtitle: 'Admins scoped to a single sports complex',
    ready: true,
  ),
  employees(
    label: 'Employees',
    icon: Icons.badge_outlined,
    activeIcon: Icons.badge_rounded,
    subtitle: 'Staff accounts, departments and shifts',
    ready: true,
  ),
  securityGuards(
    label: 'Security Guards',
    icon: Icons.shield_outlined,
    activeIcon: Icons.shield_rounded,
    subtitle: 'Guard accounts, postings and shifts',
    ready: true,
  ),
  sportsComplexes(
    label: 'Sports Complexes',
    icon: Icons.stadium_outlined,
    activeIcon: Icons.stadium_rounded,
    subtitle: 'Venues, contact details and storefront visibility',
    ready: true,
  ),
  sports(
    label: 'Sports',
    icon: Icons.sports_tennis_outlined,
    activeIcon: Icons.sports_tennis_rounded,
    subtitle: 'Sports offered across complexes',
    ready: true,
  ),
  coaches(
    label: 'Coaches',
    icon: Icons.sports_outlined,
    activeIcon: Icons.sports_rounded,
    subtitle: 'Coaching staff and assignments',
    ready: true,
  ),
  batches(
    label: 'Batches',
    icon: Icons.groups_2_outlined,
    activeIcon: Icons.groups_2_rounded,
    subtitle: 'Programmes, schedules and enrolment',
    ready: true,
  ),
  courts(
    label: 'Courts',
    icon: Icons.grid_view_outlined,
    activeIcon: Icons.grid_view_rounded,
    subtitle: 'Courts, surfaces and availability',
    ready: true,
  ),
  events(
    label: 'Event Passes',
    shortLabel: 'Events',
    icon: Icons.confirmation_number_outlined,
    activeIcon: Icons.confirmation_number_rounded,
    subtitle: 'Events, their slots and their passes',
    ready: true,
  ),
  memberships(
    label: 'Memberships',
    icon: Icons.card_membership_outlined,
    activeIcon: Icons.card_membership_rounded,
    subtitle: 'Plans, tiers and renewals',
    ready: true,
  ),
  bookings(
    label: 'Bookings',
    icon: Icons.event_available_outlined,
    activeIcon: Icons.event_available_rounded,
    subtitle: 'Court and event reservations',
    ready: true,
  ),
  payments(
    label: 'Payments',
    icon: Icons.payments_outlined,
    activeIcon: Icons.payments_rounded,
    subtitle: 'Orders, refunds and settlements',
  ),
  reports(
    label: 'Reports',
    icon: Icons.insights_outlined,
    activeIcon: Icons.insights_rounded,
    subtitle: 'Revenue, usage and attendance',
    ready: true,
  ),
  settings(
    label: 'Settings',
    icon: Icons.settings_outlined,
    activeIcon: Icons.settings_rounded,
    subtitle: 'Complex, branding and preferences',
  );

  const AdminDestination({
    required this.label,
    required this.icon,
    required this.activeIcon,
    required this.subtitle,
    this.shortLabel,
    this.ready = false,
    this.primary = false,
  });

  /// Full name, used in the sidebar and as the page title.
  final String label;

  /// Shorter form for tight rails and mobile headers.
  final String? shortLabel;

  final IconData icon;
  final IconData activeIcon;

  /// One line under the page title.
  final String subtitle;

  /// False until the module is implemented — the sidebar marks it "Soon" and
  /// the page explains what will live there.
  final bool ready;

  /// Highlighted in the sidebar as the primary module.
  final bool primary;

  String get compactLabel => shortLabel ?? label;
}

/// The two screens inside the Users module.
enum UsersTab {
  users('Users', 'Users', Icons.people_alt_outlined),
  roles('Roles & Permissions', 'Roles', Icons.key_outlined);

  const UsersTab(this.label, this.shortLabel, this.icon);

  final String label;

  /// Used on phone widths, where the full pair does not fit side by side.
  final String shortLabel;

  final IconData icon;
}
