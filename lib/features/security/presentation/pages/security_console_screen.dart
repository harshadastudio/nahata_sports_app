import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/navigation/security_routes.dart';
import '../../../../core/services/app_session.dart';
import '../../../../core/services/session_manager.dart';
import '../../../admin/core/admin_log.dart';
import '../../../admin/data/repositories/court_repository_impl.dart';
import '../../../admin/data/repositories/event_pass_repository_impl.dart';
import '../../../admin/data/repositories/visitor_pass_repository_impl.dart';
import '../../../admin/domain/repositories/court_repository.dart';
import '../../../admin/domain/repositories/event_pass_repository.dart';
import '../../../admin/domain/repositories/visitor_pass_repository.dart';
import '../../../admin/presentation/pages/visitor_passes_page.dart';
import '../../../admin/presentation/state/visitor_passes_controller.dart';
import '../../../admin/presentation/theme/admin_theme.dart';
import '../../../admin/presentation/widgets/admin_dialogs.dart';
import '../../data/repositories/gate_scan_repository_impl.dart';
import '../../domain/repositories/gate_scan_repository.dart';
import '../state/scan_journal.dart';
import '../state/security_guard_controller.dart';
import 'coaching_gate_page.dart';
import 'court_gate_page.dart';
import 'event_gate_page.dart';
import 'security_guard_dashboard_page.dart';

/// Which section of the security console is open.
enum SecuritySection {
  dashboard('Dashboard', Icons.dashboard_rounded, SecurityRoutes.dashboard),
  visitor('Visitor', Icons.badge_rounded, SecurityRoutes.visitorScanner),
  event(
    'Event',
    Icons.confirmation_number_rounded,
    SecurityRoutes.eventScanner,
  ),
  court(
    'Court',
    Icons.sports_tennis_rounded,
    SecurityRoutes.courtScanner,
  ),
  coaching('Coaching', Icons.school_rounded, SecurityRoutes.coachingScanner);

  const SecuritySection(this.label, this.icon, this.route);

  final String label;
  final IconData icon;

  /// The path this section corresponds to, so a deep link opens it directly.
  final String route;

  static SecuritySection fromRoute(String? route) {
    for (final section in values) {
      if (section.route == route) return section;
    }
    return SecuritySection.dashboard;
  }
}

/// The security console — everything a guard can reach, under one shell.
///
/// Owns the feature's dependency graph: four repositories and two controllers,
/// scoped to this subtree so nothing leaks into the rest of the app and
/// everything is disposed when the console closes. It runs its own [Theme] and
/// [ScaffoldMessenger], like the admin console, because it is a desktop-style
/// surface inside a mobile app and must not restyle anything else.
///
/// The visitor module is deliberately the **existing** Visitor Passes flow
/// rather than a second implementation — the guard scans through the same
/// controller an admin uses, so a pass checked in here is checked in there.
class SecurityConsoleScreen extends StatefulWidget {
  const SecurityConsoleScreen({
    super.key,
    this.initialSection = SecuritySection.dashboard,
    this.visitorPasses,
    this.gates,
    this.events,
    this.courts,
  });

  final SecuritySection initialSection;

  /// Injectable for tests; production builds use the `*Impl` classes.
  final VisitorPassRepository? visitorPasses;
  final GateScanRepository? gates;
  final EventPassRepository? events;
  final CourtRepository? courts;

  @override
  State<SecurityConsoleScreen> createState() => _SecurityConsoleScreenState();
}

class _SecurityConsoleScreenState extends State<SecurityConsoleScreen> {
  late final VisitorPassRepository _visitorPasses;
  late final GateScanRepository _gates;
  late final EventPassRepository _events;
  late final CourtRepository _courts;

  late final ScanJournal _journal;
  late final SecurityGuardController _guard;
  late final VisitorPassesController _visitorController;

  late SecuritySection _section = widget.initialSection;
  bool _dark = false;

  @override
  void initState() {
    super.initState();
    AdminLog.life('══════ Security console starting ══════');

    _visitorPasses = widget.visitorPasses ?? VisitorPassRepositoryImpl();
    _gates = widget.gates ?? GateScanRepositoryImpl();
    _events = widget.events ?? EventPassRepositoryImpl();
    _courts = widget.courts ?? CourtRepositoryImpl();

    _journal = ScanJournal();
    _guard = SecurityGuardController(
      visitorPasses: _visitorPasses,
      gates: _gates,
      journal: _journal,
    );
    _visitorController = VisitorPassesController(_visitorPasses);
  }

  @override
  void dispose() {
    _visitorController.dispose();
    _guard.dispose();
    _journal.dispose();
    AdminLog.life('══════ Security console closed ══════');
    super.dispose();
  }

  Future<void> _logout() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Log out?',
      message: 'You will need to sign in again to reach the gate console.',
      confirmLabel: 'Log out',
      destructive: true,
      icon: Icons.logout_rounded,
    );

    if (!confirmed) return;
    AdminLog.ui('Security console logging out');
    // SessionManager clears tokens, caches and routes back to Login itself.
    await SessionManager.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<VisitorPassRepository>.value(value: _visitorPasses),
        Provider<GateScanRepository>.value(value: _gates),
        Provider<EventPassRepository>.value(value: _events),
        Provider<CourtRepository>.value(value: _courts),
        ChangeNotifierProvider<ScanJournal>.value(value: _journal),
        ChangeNotifierProvider<SecurityGuardController>.value(value: _guard),
        ChangeNotifierProvider<VisitorPassesController>.value(
          value: _visitorController,
        ),
      ],
      child: Theme(
        data: AdminTheme.build(_dark ? Brightness.dark : Brightness.light),
        child: Builder(
          builder: (context) {
            final tokens = AdminTheme.of(context);
            final complex = AppSession.instance.sportComplexName;
            final wide =
                MediaQuery.sizeOf(context).width >= AdminTokens.tabletMax;

            return Scaffold(
              backgroundColor: tokens.canvas,
              appBar: AppBar(
                backgroundColor: tokens.surface,
                surfaceTintColor: Colors.transparent,
                elevation: 0,
                shape: Border(bottom: BorderSide(color: tokens.border)),
                titleSpacing: AdminTokens.space4,
                title: _Brand(complex: complex),
                actions: [
                  IconButton(
                    onPressed: () => setState(() => _dark = !_dark),
                    tooltip: _dark ? 'Switch to light' : 'Switch to dark',
                    color: tokens.textSecondary,
                    icon: Icon(
                      _dark
                          ? Icons.light_mode_rounded
                          : Icons.dark_mode_outlined,
                      size: 20,
                    ),
                  ),
                  IconButton(
                    onPressed: _logout,
                    tooltip: 'Log out',
                    color: tokens.danger,
                    icon: const Icon(Icons.logout_rounded, size: 20),
                  ),
                  const SizedBox(width: AdminTokens.space2),
                ],
                bottom: wide
                    ? PreferredSize(
                        preferredSize: const Size.fromHeight(48),
                        child: _SectionTabs(
                          current: _section,
                          onSelect: (section) =>
                              setState(() => _section = section),
                        ),
                      )
                    : null,
              ),
              bottomNavigationBar: wide
                  ? null
                  : NavigationBar(
                      selectedIndex: _section.index,
                      onDestinationSelected: (index) => setState(
                        () => _section = SecuritySection.values[index],
                      ),
                      destinations: [
                        for (final section in SecuritySection.values)
                          NavigationDestination(
                            icon: Icon(section.icon),
                            label: section.label,
                          ),
                      ],
                    ),
              body: SafeArea(
                child: AnimatedSwitcher(
                  duration: AdminTokens.normal,
                  switchInCurve: AdminTokens.curve,
                  child: KeyedSubtree(
                    key: ValueKey<SecuritySection>(_section),
                    child: _pageFor(_section),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _pageFor(SecuritySection section) {
    switch (section) {
      case SecuritySection.dashboard:
        return SecurityGuardDashboardPage(
          onOpenVisitorPasses: () =>
              setState(() => _section = SecuritySection.visitor),
        );
      case SecuritySection.visitor:
        // The existing Visitor Passes module: list, search, filters, details,
        // the scanner and — for an admin only — delete. One implementation,
        // two consoles, so a pass scanned here is scanned there.
        return const VisitorPassesPage();
      case SecuritySection.event:
        return const EventGatePage();
      case SecuritySection.court:
        return const CourtGatePage();
      case SecuritySection.coaching:
        return const CoachingGatePage();
    }
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.complex});

  final String complex;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
            gradient: LinearGradient(
              colors: [tokens.accent, tokens.success],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Icon(
            Icons.shield_rounded,
            size: 18,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: AdminTokens.space3),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Gate Security',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
              Text(
                complex.isEmpty ? 'Nahata Sports' : complex,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.textMuted,
                  fontSize: 11,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTabs extends StatelessWidget {
  const _SectionTabs({required this.current, required this.onSelect});

  final SecuritySection current;
  final ValueChanged<SecuritySection> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      height: 48,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: AdminTokens.space4),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (final section in SecuritySection.values)
              Padding(
                padding: const EdgeInsets.only(right: AdminTokens.space2),
                child: GestureDetector(
                  onTap: () => onSelect(section),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: AdminTokens.fast,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AdminTokens.space4,
                      vertical: AdminTokens.space2 + 2,
                    ),
                    decoration: BoxDecoration(
                      color: current == section
                          ? tokens.accentSoft
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(
                        AdminTokens.radiusPill,
                      ),
                      border: Border.all(
                        color: current == section
                            ? tokens.accent
                            : tokens.border,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          section.icon,
                          size: 16,
                          color: current == section
                              ? tokens.accent
                              : tokens.textMuted,
                        ),
                        const SizedBox(width: AdminTokens.space2),
                        Text(
                          section.label,
                          style: TextStyle(
                            color: current == section
                                ? tokens.accent
                                : tokens.textSecondary,
                            fontSize: 13,
                            fontWeight: current == section
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}