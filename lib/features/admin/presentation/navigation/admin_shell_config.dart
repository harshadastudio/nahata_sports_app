import '../../../../core/services/app_session.dart';
import 'admin_destination.dart';
import 'admin_module.dart';

/// One labelled group of sidebar entries.
class AdminNavSection {
  const AdminNavSection({required this.title, required this.destinations});

  /// Shown above the group when the rail is expanded.
  final String title;

  final List<AdminDestination> destinations;

  /// The same section with anything the signed-in user may not view removed.
  AdminNavSection filtered() => AdminNavSection(
        title: title,
        destinations:
            destinations.where(AdminAccess.allows).toList(growable: false),
      );

  bool get isEmpty => destinations.isEmpty;
}

/// What the console shell shows: its branding, its sidebar, and which modules
/// may be opened.
///
/// One shell serves both consoles. [admin] is the full estate-wide layout and
/// is deliberately *not* permission-filtered — the ADMIN console keeps working
/// exactly as it did. [complexAdmin] is the venue-scoped layout, built from
/// `data.user.permissions` alone.
class AdminShellConfig {
  const AdminShellConfig({
    required this.title,
    required this.subtitle,
    required this.sections,
    this.home = AdminDestination.dashboard,
    this.enforcePermissions = false,
  });

  /// Sidebar brand line 1.
  final String title;

  /// Sidebar brand line 2 — the complex name for a venue-scoped console.
  final String subtitle;

  final List<AdminNavSection> sections;

  /// The module opened first, and the one a blocked navigation falls back to.
  final AdminDestination home;

  /// When true the sidebar hides, and the shell refuses to open, anything the
  /// permission payload does not grant.
  final bool enforcePermissions;

  /// The existing ADMIN console: every module, grouped as it always has been.
  static const AdminShellConfig admin = AdminShellConfig(
    title: 'Nahata Sports',
    subtitle: 'Admin Console',
    sections: [
      AdminNavSection(
        title: 'Overview',
        destinations: [AdminDestination.dashboard],
      ),
      AdminNavSection(
        title: 'Access control',
        destinations: [
          AdminDestination.users,
          AdminDestination.complexAdmins,
          AdminDestination.employees,
          AdminDestination.securityGuards,
          AdminDestination.sportsComplexes,
        ],
      ),
      AdminNavSection(
        title: 'Operations',
        destinations: [
          AdminDestination.sports,
          AdminDestination.coaches,
          AdminDestination.batches,
          AdminDestination.coachingEnquiries,
          AdminDestination.courts,
          AdminDestination.bookings,
          AdminDestination.events,
          AdminDestination.visitorPasses,
        ],
      ),
      AdminNavSection(
        title: 'Business',
        destinations: [
          AdminDestination.memberships,
          AdminDestination.coupons,
          AdminDestination.payments,
          AdminDestination.reports,
          AdminDestination.settings,
        ],
      ),
    ],
  );

  /// The COMPLEX_ADMIN console for the venue in the current session.
  ///
  /// The entries listed here are the candidates; which of them actually appear
  /// is decided by `permissions.<module>.view` at render time, so a backend
  /// that revokes a module removes the menu with no app release.
  factory AdminShellConfig.complexAdmin() {
    final complex = AppSession.instance.sportComplexName;

    return AdminShellConfig(
      title: complex.isEmpty ? 'Nahata Sports' : complex,
      subtitle: complex.isEmpty
          ? 'Complex Admin'
          : 'Complex Admin'
              '${AppSession.instance.sportComplexCity == null ? '' : ' · ${AppSession.instance.sportComplexCity}'}',
      enforcePermissions: true,
      sections: const [
        AdminNavSection(
          title: 'Overview',
          destinations: [AdminDestination.dashboard],
        ),
        AdminNavSection(
          title: 'Access control',
          destinations: [
            AdminDestination.users,
            AdminDestination.sportsComplexes,
          ],
        ),
        AdminNavSection(
          title: 'Operations',
          destinations: [
            AdminDestination.sports,
            AdminDestination.coaches,
            AdminDestination.batches,
            AdminDestination.courts,
            AdminDestination.bookings,
          ],
        ),
        AdminNavSection(
          title: 'Business',
          destinations: [
            AdminDestination.memberships,
            AdminDestination.coupons,
            AdminDestination.payments,
            AdminDestination.reports,
            AdminDestination.settings,
          ],
        ),
      ],
    );
  }

  /// Sections as they should be drawn: permission-filtered when the config asks
  /// for it, and with any group left empty dropped.
  List<AdminNavSection> get visibleSections {
    if (!enforcePermissions) return sections;
    return sections
        .map((section) => section.filtered())
        .where((section) => !section.isEmpty)
        .toList(growable: false);
  }

  /// Every destination this shell may open.
  Set<AdminDestination> get allowedDestinations => visibleSections
      .expand((section) => section.destinations)
      .toSet();

  bool allows(AdminDestination destination) =>
      !enforcePermissions || allowedDestinations.contains(destination);

  /// The module to open on launch — [home] when it is permitted, otherwise the
  /// first entry the user does have, so the console never starts on a blocked
  /// screen.
  AdminDestination get initialDestination {
    if (allows(home)) return home;
    for (final section in visibleSections) {
      if (section.destinations.isNotEmpty) return section.destinations.first;
    }
    return home;
  }
}