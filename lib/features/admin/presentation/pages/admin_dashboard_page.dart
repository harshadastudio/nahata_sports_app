import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../admin/notifications/admin_notification.dart';
import '../../../../core/services/session_manager.dart';
import '../../core/admin_log.dart';
import '../../data/repositories/admin_repository_impl.dart';
import '../../data/repositories/batch_repository_impl.dart';
import '../../data/repositories/booking_repository_impl.dart';
import '../../data/repositories/coach_repository_impl.dart';
import '../../data/repositories/coaching_enquiry_repository_impl.dart';
import '../../data/repositories/complex_admin_repository_impl.dart';
import '../../data/repositories/coupons_repository_impl.dart';
import '../../data/repositories/court_repository_impl.dart';
import '../../data/repositories/court_slot_repository_impl.dart';
import '../../data/repositories/dashboard_repository_impl.dart';
import '../../data/repositories/employee_repository_impl.dart';
import '../../data/repositories/event_pass_repository_impl.dart';
import '../../data/repositories/membership_repository_impl.dart';
import '../../data/repositories/report_repository_impl.dart';
import '../../data/repositories/security_guard_repository_impl.dart';
import '../../data/repositories/sport_repository_impl.dart';
import '../../data/repositories/sports_complex_admin_repository_impl.dart';
import '../../data/repositories/visitor_pass_repository_impl.dart';
import '../../domain/repositories/admin_repository.dart';
import '../../domain/repositories/batch_repository.dart';
import '../../domain/repositories/booking_repository.dart';
import '../../domain/repositories/coach_repository.dart';
import '../../domain/repositories/coaching_enquiry_repository.dart';
import '../../domain/repositories/complex_admin_repository.dart';
import '../../domain/repositories/coupons_repository.dart';
import '../../domain/repositories/court_repository.dart';
import '../../domain/repositories/court_slot_repository.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../../domain/repositories/employee_repository.dart';
import '../../domain/repositories/event_pass_repository.dart';
import '../../domain/repositories/membership_repository.dart';
import '../../domain/repositories/report_repository.dart';
import '../../domain/repositories/security_guard_repository.dart';
import '../../domain/repositories/sport_repository.dart';
import '../../domain/repositories/sports_complex_admin_repository.dart';
import '../../domain/repositories/visitor_pass_repository.dart';
import '../navigation/admin_destination.dart';
import '../state/admin_roles_controller.dart';
import '../state/admin_shell_controller.dart';
import '../state/admin_users_controller.dart';
import '../state/batches_controller.dart';
import '../state/bookings_controller.dart';
import '../state/coaches_controller.dart';
import '../state/coaching_enquiries_controller.dart';
import '../state/complex_admins_controller.dart';
import '../state/coupons_controller.dart';
import '../state/courts_controller.dart';
import '../state/dashboard_controller.dart';
import '../state/employees_controller.dart';
import '../state/event_passes_controller.dart';
import '../state/memberships_controller.dart';
import '../state/reports_controller.dart';
import '../state/security_guards_controller.dart';
import '../state/sports_complexes_controller.dart';
import '../state/sports_controller.dart';
import '../state/visitor_passes_controller.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dialogs.dart';
import '../widgets/admin_sidebar.dart';
import '../widgets/admin_top_bar.dart';
import 'batches_page.dart';
import 'bookings_page.dart';
import 'coaches_page.dart';
import 'coaching_enquiries_page.dart';
import 'complex_admins_page.dart';
import 'coupons_page.dart';
import 'courts_page.dart';
import 'dashboard_home_page.dart';
import 'employees_page.dart';
import 'event_passes_page.dart';
import 'memberships_page.dart';
import 'module_placeholder_page.dart';
import 'reports_page.dart';
import 'security_guards_page.dart';
import 'sports_complexes_page.dart';
import 'sports_page.dart';
import 'users_module_page.dart';
import 'visitor_passes_page.dart';

/// Entry point for the whole admin console.
///
/// Owns the feature's dependency graph: one repository, four controllers,
/// scoped to this subtree so nothing leaks into the customer-facing app and
/// everything is disposed when the console closes.
///
/// The panel also runs its own [Theme] and [ScaffoldMessenger] — it is a
/// desktop-style surface inside a mobile app, and it must not restyle the rest.
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    this.repository,
    this.dashboardRepository,
    this.complexAdminRepository,
    this.employeeRepository,
    this.securityGuardRepository,
    this.sportsComplexRepository,
    this.sportRepository,
    this.coachRepository,
    this.batchRepository,
    this.courtRepository,
    this.courtSlotRepository,
    this.bookingRepository,
    this.eventPassRepository,
    this.membershipRepository,
    this.reportRepository,
    this.visitorPassRepository,
    this.couponsRepository,
    this.coachingEnquiryRepository,
  });

  /// Injectable for tests; production builds use the `*Impl` classes.
  final AdminRepository? repository;
  final DashboardRepository? dashboardRepository;
  final ComplexAdminRepository? complexAdminRepository;
  final EmployeeRepository? employeeRepository;
  final SecurityGuardRepository? securityGuardRepository;
  final SportsComplexAdminRepository? sportsComplexRepository;
  final SportRepository? sportRepository;
  final CoachRepository? coachRepository;
  final BatchRepository? batchRepository;
  final CourtRepository? courtRepository;
  final CourtSlotRepository? courtSlotRepository;
  final BookingRepository? bookingRepository;
  final EventPassRepository? eventPassRepository;
  final MembershipRepository? membershipRepository;
  final ReportRepository? reportRepository;
  final VisitorPassRepository? visitorPassRepository;
  final CouponsRepository? couponsRepository;
  final CoachingEnquiryRepository? coachingEnquiryRepository;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  late final AdminRepository _repository;
  late final DashboardRepository _dashboardRepository;
  late final ComplexAdminRepository _complexAdminRepository;
  late final EmployeeRepository _employeeRepository;
  late final SecurityGuardRepository _securityGuardRepository;
  late final SportsComplexAdminRepository _sportsComplexRepository;
  late final SportRepository _sportRepository;
  late final CoachRepository _coachRepository;
  late final BatchRepository _batchRepository;
  late final CourtRepository _courtRepository;
  late final CourtSlotRepository _courtSlotRepository;
  late final BookingRepository _bookingRepository;
  late final EventPassRepository _eventPassRepository;
  late final MembershipRepository _membershipRepository;
  late final ReportRepository _reportRepository;
  late final VisitorPassRepository _visitorPassRepository;
  late final CouponsRepository _couponsRepository;
  late final CoachingEnquiryRepository _coachingEnquiryRepository;

  late final AdminShellController _shell;
  late final DashboardController _dashboard;
  late final AdminUsersController _users;
  late final AdminRolesController _roles;
  late final ComplexAdminsController _complexAdmins;
  late final EmployeesController _employees;
  late final SecurityGuardsController _securityGuards;
  late final SportsComplexesController _sportsComplexes;
  late final SportsController _sports;
  late final CoachesController _coaches;
  late final BatchesController _batches;
  late final CourtsController _courts;
  late final BookingsController _bookings;
  late final EventPassesController _events;
  late final MembershipsController _memberships;
  late final ReportsController _reports;
  late final VisitorPassesController _visitorPasses;
  late final CouponsController _coupons;
  late final CoachingEnquiriesController _coachingEnquiries;

  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _searchController = TextEditingController();

  Timer? _notificationTimer;
  int _notificationCount = 0;
  bool _fetchingNotifications = false;

  @override
  void initState() {
    super.initState();
    AdminLog.life('══════ Admin console starting ══════');

    _repository = widget.repository ?? AdminRepositoryImpl();
    _dashboardRepository =
        widget.dashboardRepository ?? DashboardRepositoryImpl();
    _complexAdminRepository =
        widget.complexAdminRepository ?? ComplexAdminRepositoryImpl();
    _employeeRepository = widget.employeeRepository ?? EmployeeRepositoryImpl();
    _securityGuardRepository =
        widget.securityGuardRepository ?? SecurityGuardRepositoryImpl();
    _sportsComplexRepository =
        widget.sportsComplexRepository ?? SportsComplexAdminRepositoryImpl();
    _sportRepository = widget.sportRepository ?? SportRepositoryImpl();
    _coachRepository = widget.coachRepository ?? CoachRepositoryImpl();
    _batchRepository = widget.batchRepository ?? BatchRepositoryImpl();
    _courtRepository = widget.courtRepository ?? CourtRepositoryImpl();
    _courtSlotRepository =
        widget.courtSlotRepository ?? CourtSlotRepositoryImpl();
    _bookingRepository = widget.bookingRepository ?? BookingRepositoryImpl();
    _eventPassRepository =
        widget.eventPassRepository ?? EventPassRepositoryImpl();
    _membershipRepository =
        widget.membershipRepository ?? MembershipRepositoryImpl();
    _reportRepository = widget.reportRepository ?? ReportRepositoryImpl();
    _visitorPassRepository =
        widget.visitorPassRepository ?? VisitorPassRepositoryImpl();
    _couponsRepository = widget.couponsRepository ?? CouponsRepositoryImpl();
    _coachingEnquiryRepository =
        widget.coachingEnquiryRepository ?? CoachingEnquiryRepositoryImpl();

    _shell = AdminShellController();
    _dashboard = DashboardController(_dashboardRepository);
    _users = AdminUsersController(_repository);
    _roles = AdminRolesController(_repository);
    _complexAdmins = ComplexAdminsController(_complexAdminRepository);
    _employees = EmployeesController(_employeeRepository);
    _securityGuards = SecurityGuardsController(_securityGuardRepository);
    _sportsComplexes = SportsComplexesController(_sportsComplexRepository);
    _sports = SportsController(_sportRepository);
    _coaches = CoachesController(_coachRepository);
    _batches = BatchesController(_batchRepository);
    _courts = CourtsController(_courtRepository);
    _bookings = BookingsController(_bookingRepository);
    _events = EventPassesController(_eventPassRepository);
    _memberships = MembershipsController(_membershipRepository);
    _reports = ReportsController(_reportRepository);
    _visitorPasses = VisitorPassesController(_visitorPassRepository);
    _coupons = CouponsController(_couponsRepository);
    _coachingEnquiries = CoachingEnquiriesController(
      _coachingEnquiryRepository,
    );

    _loadNotifications();
    _notificationTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _loadNotifications(),
    );
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    _searchController.dispose();
    _coachingEnquiries.dispose();
    _coupons.dispose();
    _visitorPasses.dispose();
    _reports.dispose();
    _memberships.dispose();
    _events.dispose();
    _bookings.dispose();
    _courts.dispose();
    _batches.dispose();
    _coaches.dispose();
    _sports.dispose();
    _sportsComplexes.dispose();
    _securityGuards.dispose();
    _employees.dispose();
    _complexAdmins.dispose();
    _roles.dispose();
    _users.dispose();
    _dashboard.dispose();
    _shell.dispose();
    AdminLog.life('══════ Admin console closed ══════');
    super.dispose();
  }

  /// Unread badge for the bell. Served by the legacy notifications endpoint the
  /// existing notifications screen already uses; a failure just leaves the
  /// badge at its last value rather than surfacing an error.
  Future<void> _loadNotifications() async {
    if (_fetchingNotifications) return;
    _fetchingNotifications = true;

    try {
      final response = await AdminNotificationService.fetchNotifications();
      final count = response['count'];
      final parsed = count is int ? count : int.tryParse('$count') ?? 0;

      if (!mounted) return;
      if (parsed != _notificationCount) {
        AdminLog.data('Unread notifications → $parsed');
        setState(() => _notificationCount = parsed);
      }
    } catch (error) {
      AdminLog.failure('Notification count unavailable', error: error);
    } finally {
      _fetchingNotifications = false;
    }
  }

  Future<void> _logout() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Log out?',
      message: 'You will need to sign in again to reach the admin console.',
      confirmLabel: 'Log out',
      destructive: true,
      icon: Icons.logout_rounded,
    );

    if (!confirmed) return;
    AdminLog.ui('Logging out');
    // SessionManager clears tokens, caches and routes back to Login itself.
    await SessionManager.instance.signOut();
  }

  void _openNotifications() {
    AdminLog.ui('Opening notifications');
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AdminNotificationsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AdminRepository>.value(value: _repository),
        Provider<DashboardRepository>.value(value: _dashboardRepository),
        Provider<ComplexAdminRepository>.value(value: _complexAdminRepository),
        Provider<EmployeeRepository>.value(value: _employeeRepository),
        Provider<SecurityGuardRepository>.value(
          value: _securityGuardRepository,
        ),
        Provider<SportsComplexAdminRepository>.value(
          value: _sportsComplexRepository,
        ),
        Provider<SportRepository>.value(value: _sportRepository),
        Provider<CoachRepository>.value(value: _coachRepository),
        Provider<BatchRepository>.value(value: _batchRepository),
        Provider<CourtRepository>.value(value: _courtRepository),
        Provider<CourtSlotRepository>.value(value: _courtSlotRepository),
        Provider<BookingRepository>.value(value: _bookingRepository),
        Provider<EventPassRepository>.value(value: _eventPassRepository),
        Provider<MembershipRepository>.value(value: _membershipRepository),
        Provider<ReportRepository>.value(value: _reportRepository),
        Provider<VisitorPassRepository>.value(value: _visitorPassRepository),
        Provider<CouponsRepository>.value(value: _couponsRepository),
        Provider<CoachingEnquiryRepository>.value(
          value: _coachingEnquiryRepository,
        ),
        ChangeNotifierProvider<AdminShellController>.value(value: _shell),
        ChangeNotifierProvider<DashboardController>.value(value: _dashboard),
        ChangeNotifierProvider<AdminUsersController>.value(value: _users),
        ChangeNotifierProvider<AdminRolesController>.value(value: _roles),
        ChangeNotifierProvider<ComplexAdminsController>.value(
          value: _complexAdmins,
        ),
        ChangeNotifierProvider<EmployeesController>.value(value: _employees),
        ChangeNotifierProvider<SecurityGuardsController>.value(
          value: _securityGuards,
        ),
        ChangeNotifierProvider<SportsComplexesController>.value(
          value: _sportsComplexes,
        ),
        ChangeNotifierProvider<SportsController>.value(value: _sports),
        ChangeNotifierProvider<CoachesController>.value(value: _coaches),
        ChangeNotifierProvider<BatchesController>.value(value: _batches),
        ChangeNotifierProvider<CourtsController>.value(value: _courts),
        ChangeNotifierProvider<BookingsController>.value(value: _bookings),
        ChangeNotifierProvider<EventPassesController>.value(value: _events),
        ChangeNotifierProvider<MembershipsController>.value(
          value: _memberships,
        ),
        ChangeNotifierProvider<ReportsController>.value(value: _reports),
        ChangeNotifierProvider<VisitorPassesController>.value(
          value: _visitorPasses,
        ),
        ChangeNotifierProvider<CouponsController>.value(value: _coupons),
        ChangeNotifierProvider<CoachingEnquiriesController>.value(
          value: _coachingEnquiries,
        ),
      ],
      child: Consumer<AdminShellController>(
        builder: (context, shell, _) {
          return Theme(
            data: AdminTheme.build(
              shell.isDark ? Brightness.dark : Brightness.light,
            ),
            child: _Shell(
              scaffoldKey: _scaffoldKey,
              searchController: _searchController,
              notificationCount: _notificationCount,
              onLogout: _logout,
              onNotifications: _openNotifications,
            ),
          );
        },
      ),
    );
  }
}

/// The chrome: sidebar (or drawer), top bar, and the current module.
class _Shell extends StatelessWidget {
  const _Shell({
    required this.scaffoldKey,
    required this.searchController,
    required this.notificationCount,
    required this.onLogout,
    required this.onNotifications,
  });

  final GlobalKey<ScaffoldState> scaffoldKey;
  final TextEditingController searchController;
  final int notificationCount;
  final VoidCallback onLogout;
  final VoidCallback onNotifications;

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<AdminShellController>();
    final users = context.watch<AdminUsersController>();
    final tokens = AdminTheme.of(context);

    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < AdminTokens.mobileMax;
    final isTablet = width < AdminTokens.tabletMax;

    // Keep the top-bar field aligned with the controller — a "clear filters"
    // elsewhere has to empty it too. Deferred to after the frame: assigning to
    // a TextEditingController notifies its TextField, and doing that mid-build
    // would mark a descendant dirty while it is already building.
    if (searchController.text != users.search) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (searchController.text == users.search) return;
        searchController.value = TextEditingValue(
          text: users.search,
          selection: TextSelection.collapsed(offset: users.search.length),
        );
      });
    }

    return Scaffold(
      key: scaffoldKey,
      backgroundColor: tokens.canvas,
      drawer: isTablet
          ? Drawer(
              width: AdminTokens.sidebarWidth,
              child: AdminSidebar(
                current: shell.destination,
                collapsed: false,
                showToggle: false,
                onSelect: (destination) {
                  shell.go(destination);
                  Navigator.of(context).pop();
                },
              ),
            )
          : null,
      body: SafeArea(
        child: Row(
          children: [
            if (!isTablet)
              AdminSidebar(
                current: shell.destination,
                collapsed: shell.sidebarCollapsed,
                onToggleCollapse: shell.toggleSidebar,
                onSelect: shell.go,
              ),
            Expanded(
              child: Column(
                children: [
                  AdminTopBar(
                    destination: shell.destination,
                    isDark: shell.isDark,
                    compact: isMobile,
                    onToggleTheme: shell.toggleTheme,
                    onLogout: onLogout,
                    onNotifications: onNotifications,
                    notificationCount: notificationCount,
                    onMenu: isTablet
                        ? () => scaffoldKey.currentState?.openDrawer()
                        : null,
                    searchController: searchController,
                    searchEnabled: shell.isSearchable,
                    searchHint: 'Search users by name, email or phone',
                    onSearchChanged: users.onSearchChanged,
                    onClearSearch: users.clearSearch,
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: AdminTokens.normal,
                      switchInCurve: AdminTokens.curve,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.015),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      ),
                      child: KeyedSubtree(
                        key: ValueKey<AdminDestination>(shell.destination),
                        child: _pageFor(shell.destination, isMobile),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The one place a destination is turned into a page — adding a module means
  /// adding a case here and nothing else.
  Widget _pageFor(AdminDestination destination, bool isMobile) {
    switch (destination) {
      case AdminDestination.dashboard:
        return const DashboardHomePage();
      case AdminDestination.users:
        // On a compact bar the search box is not in the chrome, so the module
        // renders its own.
        return UsersModulePage(showInlineSearch: isMobile);
      case AdminDestination.complexAdmins:
        return const ComplexAdminsPage();
      case AdminDestination.employees:
        return const EmployeesPage();
      case AdminDestination.securityGuards:
        return const SecurityGuardsPage();
      case AdminDestination.sportsComplexes:
        return const SportsComplexesPage();
      case AdminDestination.sports:
        return const SportsPage();
      case AdminDestination.coaches:
        return const CoachesPage();
      case AdminDestination.batches:
        return const BatchesPage();
      case AdminDestination.coachingEnquiries:
        return const CoachingEnquiriesPage();
      case AdminDestination.courts:
        return const CourtsPage();
      case AdminDestination.events:
        return const EventPassesPage();
      case AdminDestination.visitorPasses:
        return const VisitorPassesPage();
      case AdminDestination.memberships:
        return const MembershipsPage();
      case AdminDestination.bookings:
        return const BookingsPage();
      case AdminDestination.reports:
        return const ReportsPage();
      case AdminDestination.coupons:
        return const CouponsPage();
      case AdminDestination.payments:
      case AdminDestination.settings:
        return ModulePlaceholderPage(destination: destination);
    }
  }
}
