import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/navigation/role_router.dart';
import 'package:nahata_app/core/services/permission_service.dart';
import 'package:nahata_app/features/admin/presentation/navigation/admin_module.dart';
import 'package:nahata_app/features/admin/domain/entities/paged.dart';
import 'package:nahata_app/features/admin/domain/entities/visitor_pass.dart';
import 'package:nahata_app/features/admin/domain/repositories/visitor_pass_repository.dart';
import 'package:nahata_app/features/admin/presentation/navigation/admin_destination.dart';
import 'package:nahata_app/features/admin/presentation/navigation/admin_shell_config.dart';
import 'package:nahata_app/features/admin/presentation/state/visitor_passes_controller.dart';
import 'package:nahata_app/features/admin/presentation/theme/admin_theme.dart';
import 'package:nahata_app/features/security/presentation/pages/security_dashboard_page.dart';
import 'package:nahata_app/features/security/presentation/pages/security_console_screen.dart';
import 'package:nahata_app/features/security/presentation/state/security_dashboard_controller.dart';
import 'package:nahata_app/features/security/presentation/widgets/live_gate_status.dart';
import 'package:nahata_app/features/security/presentation/widgets/security_activity_table.dart';
import 'package:nahata_app/features/security/presentation/widgets/security_quick_actions.dart';
import 'package:nahata_app/features/security/presentation/widgets/security_stat_cards.dart';
import 'package:nahata_app/models/profile_model.dart';
import 'package:nahata_app/models/sports_complex_model.dart';

/// Paints the dashboard end to end against a fake repository — the
/// compile-and-render check for every panel on the screen.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  final now = DateTime(2026, 8, 7, 14, 30);
  final today = DateTime(2026, 8, 7);

  VisitorPass pass({
    required int id,
    String? status,
    DateTime? entry,
    DateTime? exit,
  }) =>
      VisitorPass(
        id: id,
        passCode: 'NS-$id',
        visitorName: 'Visitor $id',
        phoneNumber: '90000000$id',
        visitPurpose: 'Meeting',
        statusRaw: status,
        entryTime: entry,
        exitTime: exit,
        createdByName: 'Ravi Gate',
        createdAt: today.add(Duration(hours: 8 + id)),
      );

  final rows = [
    pass(id: 1, status: 'Pending'),
    pass(
      id: 2,
      status: 'Checked In',
      entry: today.add(const Duration(hours: 10)),
    ),
    pass(
      id: 3,
      status: 'Checked Out',
      entry: today.add(const Duration(hours: 11)),
      exit: today.add(const Duration(hours: 12)),
    ),
  ];

  Future<void> pumpDashboard(
    WidgetTester tester, {
    Size size = const Size(1600, 2400),
    VoidCallback? onOpenReports,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repository = _FakeRepository(rows);
    final dashboard = SecurityDashboardController(repository, clock: () => now);
    final passes = VisitorPassesController(repository);
    addTearDown(dashboard.dispose);
    addTearDown(passes.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SecurityDashboardController>.value(
            value: dashboard,
          ),
          ChangeNotifierProvider<VisitorPassesController>.value(value: passes),
        ],
        child: MaterialApp(
          theme: AdminTheme.build(Brightness.light),
          home: Scaffold(
            body: SecurityDashboardPage(onOpenReports: onOpenReports),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  testWidgets('renders every panel with data', (tester) async {
    await pumpDashboard(tester);

    // Cards
    expect(find.byType(SecurityStatCards), findsOneWidget);
    expect(find.text('Currently Inside'), findsOneWidget);
    expect(find.text('Pending Visitors'), findsOneWidget);
    expect(find.text('Total Visitor Passes'), findsOneWidget);
    expect(find.text('Active Passes'), findsOneWidget);
    expect(find.text('Expired Passes'), findsOneWidget);

    // The panels, in the order the layout calls for.
    expect(find.text('Recent Visitor Activity'), findsOneWidget);
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(find.text('Recent Generated Passes'), findsOneWidget);
    expect(find.text('Today’s Timeline'), findsOneWidget);
    expect(find.text('Live Gate Status'), findsOneWidget);
    expect(find.text('Visitor Status'), findsOneWidget);
    expect(find.text('Hourly Visitor Trend'), findsOneWidget);
    expect(find.text('Daily Visitors'), findsOneWidget);

    // Contents
    expect(find.byType(SecurityActivityTable), findsOneWidget);
    expect(find.byType(SecurityQuickActions), findsOneWidget);
    expect(find.byType(LiveGateStatus), findsOneWidget);
    expect(find.text('Visitor 1'), findsWidgets);
  });

  testWidgets('the activity table shows the nine documented columns',
      (tester) async {
    await pumpDashboard(tester);

    for (final column in const [
      'Visitor',
      'Phone',
      'Purpose',
      'Pass Code',
      'Status',
      'Entry Time',
      'Exit Time',
      'Security',
      'Action',
    ]) {
      // Scoped to the table: "Purpose" and "Security" are also filter labels.
      expect(
        find.descendant(
          of: find.byType(SecurityActivityTable),
          matching: find.text(column),
        ),
        findsOneWidget,
        reason: column,
      );
    }
  });

  testWidgets('offers only the leg each pass is waiting for', (tester) async {
    await pumpDashboard(tester);

    // Pending → "In", checked in → "Out", checked out → neither: the pass is
    // spent for good and can never be scanned again.
    expect(find.text('In'), findsOneWidget);
    expect(find.text('Out'), findsOneWidget);

    // The spent row falls back to a plain View button.
    expect(
      find.descendant(
        of: find.byType(SecurityActivityTable),
        matching: find.byTooltip('View details'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('hides the Reports action when there is nowhere to go',
      (tester) async {
    await pumpDashboard(tester);
    expect(find.text('Reports'), findsNothing);

    await pumpDashboard(tester, onOpenReports: () {});
    expect(find.text('Reports'), findsOneWidget);
  });

  testWidgets('renders on a phone without overflowing', (tester) async {
    await pumpDashboard(tester, size: const Size(420, 3600));

    expect(find.byType(SecurityActivityTable), findsOneWidget);
    expect(find.text('Quick Actions'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows an empty state when nobody has visited', (tester) async {
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repository = _FakeRepository(const []);
    final dashboard = SecurityDashboardController(repository, clock: () => now);
    final passes = VisitorPassesController(repository);
    addTearDown(dashboard.dispose);
    addTearDown(passes.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SecurityDashboardController>.value(
            value: dashboard,
          ),
          ChangeNotifierProvider<VisitorPassesController>.value(value: passes),
        ],
        child: MaterialApp(
          theme: AdminTheme.build(Brightness.light),
          home: const Scaffold(body: SecurityDashboardPage()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No visitors in this period'), findsOneWidget);
    expect(find.text('The building is empty'), findsOneWidget);
    expect(find.text('No movements yet'), findsOneWidget);
    expect(find.text('Nothing to chart yet'), findsWidgets);
  });

  testWidgets('a guard keeps Generate even with no admin permissions',
      (tester) async {
    // A SECURITY payload need not carry the admin `bookings` module; gating
    // the guard's own job on it would leave them a read-only dashboard.
    tester.view.physicalSize = const Size(1600, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repository = _FakeRepository(rows);
    final dashboard = SecurityDashboardController(repository, clock: () => now);
    final passes = VisitorPassesController(repository);
    addTearDown(dashboard.dispose);
    addTearDown(passes.dispose);

    PermissionService.instance.sync(
      ProfileModel.fromJson({
        'id': 88,
        'role': 'SECURITY',
        'permissions': {
          'dashboard': {'view': true},
        },
      }),
    );
    addTearDown(PermissionService.instance.clear);

    expect(AdminAccess.canCreate(AdminModules.bookings), isFalse);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<SecurityDashboardController>.value(
            value: dashboard,
          ),
          ChangeNotifierProvider<VisitorPassesController>.value(value: passes),
        ],
        child: MaterialApp(
          theme: AdminTheme.build(Brightness.light),
          home: const Scaffold(
            body: SecurityDashboardPage(enforceModulePermissions: false),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Generate Pass'), findsOneWidget);
    expect(find.text('Scan QR'), findsOneWidget);
  });

  group('access', () {
    test('SECURITY lands on the guard console', () {
      expect(
        RoleRouter.screenFor('SECURITY'),
        isA<SecurityConsoleScreen>(),
      );
    });

    test('the module is in both consoles', () {
      expect(
        AdminShellConfig.admin.sections
            .expand((section) => section.destinations),
        contains(AdminDestination.securityDashboard),
      );
      // The complex admin's own console lists it too, subject to permissions.
      expect(
        AdminShellConfig.complexAdmin()
            .sections
            .expand((section) => section.destinations),
        contains(AdminDestination.securityDashboard),
      );
    });
  });
}

class _FakeRepository implements VisitorPassRepository {
  _FakeRepository(this.rows);

  final List<VisitorPass> rows;

  @override
  Future<Paged<VisitorPass>> fetchVisitorPasses({
    int page = 1,
    int limit = 20,
    String? search,
  }) async =>
      Paged<VisitorPass>(
        items: page == 1 ? rows : const [],
        page: page,
        limit: limit,
        total: rows.length,
        totalPages: 1,
      );

  @override
  Future<VisitorPass> fetchVisitorPass(String idOrCode) async => rows.first;

  @override
  Future<VisitorPass> createVisitorPass(VisitorPassDraft draft) async =>
      rows.first;

  @override
  Future<VisitorPassCheck> verifyPass({
    required String passCode,
    required VisitorScanType scanType,
  }) async =>
      const VisitorPassCheck(success: true, readOnly: false);

  @override
  Future<VisitorPassCheck> lookupPass(String passCode) async =>
      const VisitorPassCheck(success: true, readOnly: true);

  @override
  Future<String> sendPassEmail({
    required String idOrCode,
    required String recipientEmail,
    required String recipientName,
  }) async =>
      'Sent';

  @override
  Future<void> deleteVisitorPass(String idOrCode) async {}

  @override
  Future<List<SportsComplex>> fetchSportComplexes({bool refresh = false}) async =>
      const [SportsComplex(id: 1, name: 'Sinhagad Road', city: 'Pune')];
}