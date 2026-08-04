import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/features/admin/domain/entities/admin_role.dart';
import 'package:nahata_app/features/admin/domain/entities/admin_stats.dart';
import 'package:nahata_app/features/admin/domain/entities/admin_user.dart';
import 'package:nahata_app/features/admin/domain/entities/complex_admin.dart';
import 'package:nahata_app/features/admin/domain/entities/dashboard_stats.dart';
import 'package:nahata_app/features/admin/domain/entities/employee.dart';
import 'package:nahata_app/features/admin/domain/entities/employee_vocabulary.dart';
import 'package:nahata_app/features/admin/domain/entities/enrollment_trend.dart';
import 'package:nahata_app/features/admin/domain/entities/live_enquiry.dart';
import 'package:nahata_app/features/admin/domain/entities/paged.dart';
import 'package:nahata_app/features/admin/domain/entities/role_permissions.dart';
import 'package:nahata_app/features/admin/domain/entities/sport_distribution.dart';
import 'package:nahata_app/features/admin/domain/repositories/admin_repository.dart';
import 'package:nahata_app/features/admin/domain/repositories/complex_admin_repository.dart';
import 'package:nahata_app/features/admin/domain/repositories/dashboard_repository.dart';
import 'package:nahata_app/features/admin/domain/repositories/employee_repository.dart';
import 'package:nahata_app/features/admin/presentation/pages/admin_dashboard_page.dart';
import 'package:nahata_app/features/admin/presentation/widgets/admin_sidebar.dart';
import 'package:nahata_app/models/sports_complex_model.dart';
import 'package:nahata_app/providers/profile_provider.dart';

/// Renders the console end to end against a fake repository. This is the
/// compile-and-paint check for the widget tree — every page, the sidebar, the
/// table, the drawer and the dialogs are reachable from here.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpConsole(
    WidgetTester tester,
    AdminRepository repository, {
    DashboardRepository? dashboard,
    ComplexAdminRepository? complexAdmins,
    EmployeeRepository? employees,
  }) async {
    // Desktop-sized surface: the console's widest layout, sidebar included.
    // Wide enough that the employee table's twelve columns fit without
    // horizontal scrolling, so its row actions are reachable by a tap.
    tester.view.physicalSize = const Size(1800, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<ProfileProvider>(
        create: (_) => ProfileProvider(),
        child: MaterialApp(
          home: AdminDashboardScreen(
            repository: repository,
            dashboardRepository: dashboard ?? _FakeDashboardRepository(),
            complexAdminRepository:
                complexAdmins ?? _FakeComplexAdminRepository(),
            employeeRepository: employees ?? _FakeEmployeeRepository(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('dashboard home renders every stat card from the API', (
    tester,
  ) async {
    await pumpConsole(tester, _FakeRepository());

    expect(find.text('Nahata Sports'), findsOneWidget);
    // The five /dashboard/stats cards.
    expect(find.text('Students'), findsWidgets);
    expect(find.text('Coaches'), findsWidgets);
    expect(find.text('Bookings'), findsWidgets);
    expect(find.text('Enquiries'), findsWidgets);
    expect(find.text('Contact Requests'), findsOneWidget);

    // Every sidebar destination is present, including the new module.
    expect(find.text('Dashboard'), findsWidgets);
    expect(find.text('Users & Roles'), findsOneWidget);
    expect(find.text('Complex Admin'), findsOneWidget);
    expect(find.text('Bookings'), findsWidgets);

    // The rail scrolls: with every module in place, the later groups sit below
    // the fold on a 1000px-tall surface.
    final rail = find
        .descendant(
          of: find.byType(AdminSidebar),
          matching: find.byType(Scrollable),
        )
        .first;

    // The rail labels each destination by its compact name.
    await tester.scrollUntilVisible(find.text('Events'), 200, scrollable: rail);
    expect(find.text('Events'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Settings'), 200,
        scrollable: rail);
    expect(find.text('Settings'), findsOneWidget);
  });

  testWidgets('opening the Users module lists rows from the repository', (
    tester,
  ) async {
    await pumpConsole(tester, _FakeRepository());

    await tester.tap(find.text('Users & Roles'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.text('Riya Sharma'), findsOneWidget);
    expect(find.text('riya@example.com'), findsOneWidget);
    expect(find.text('Arjun Nahata'), findsOneWidget);
    // Table chrome.
    expect(find.text('Membership'), findsWidgets);
    expect(find.text('Add user'), findsOneWidget);
    expect(find.textContaining('Showing 1'), findsOneWidget);
  });

  testWidgets('the Roles tab renders the permission catalogue and keeps Save '
      'disabled until something changes', (tester) async {
    final repository = _FakeRepository();
    await pumpConsole(tester, repository);

    await tester.tap(find.text('Users & Roles'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    await tester.tap(find.text('Roles & Permissions'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.text('Users Read'), findsOneWidget);
    expect(find.text('Users Write'), findsOneWidget);
    expect(find.text('All changes saved'), findsOneWidget);

    expect(
      _saveButton(tester).onPressed,
      isNull,
      reason: 'nothing has changed yet',
    );

    // Flip one permission — Save must come alive.
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();

    expect(find.text('Unsaved changes'), findsOneWidget);
    expect(_saveButton(tester).onPressed, isNotNull);
  });

  testWidgets('an empty user list shows the empty state, not a blank table', (
    tester,
  ) async {
    await pumpConsole(tester, _FakeRepository(users: const []));

    await tester.tap(find.text('Users & Roles'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.text('No users yet'), findsOneWidget);
  });

  testWidgets('a failed load shows the error state with the server message', (
    tester,
  ) async {
    await pumpConsole(tester, _FakeRepository(failUsers: true));

    await tester.tap(find.text('Users & Roles'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.text('Could not load users'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('the theme switch flips the console to dark', (tester) async {
    await pumpConsole(tester, _FakeRepository());

    final before = Theme.of(
      tester.element(find.text('Contact Requests')),
    ).brightness;
    expect(before, Brightness.light);

    await tester.tap(find.byTooltip('Switch to dark'));
    await tester.pumpAndSettle();

    final after = Theme.of(
      tester.element(find.text('Contact Requests')),
    ).brightness;
    expect(after, Brightness.dark);
  });

  testWidgets('the Add user dialog opens and reveals the coach block for a '
      'coach role', (tester) async {
    await pumpConsole(tester, _FakeRepository());

    await tester.tap(find.text('Users & Roles'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    await tester.tap(find.text('Add user'));
    await tester.pumpAndSettle();

    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Membership'), findsWidgets);
    // Conditional blocks are hidden until a role selects them.
    expect(find.text('Coach information'), findsNothing);
    expect(find.text('Employee information'), findsNothing);

    await tester.tap(find.byType(DropdownButtonFormField<AdminRole>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coach').last);
    await tester.pumpAndSettle();

    expect(find.text('Coach information'), findsOneWidget);
    expect(find.text('Assigned sports'), findsOneWidget);
    expect(find.text('Employee information'), findsNothing);
  });

  testWidgets('the mobile layout renders as cards behind a drawer', (
    tester,
  ) async {
    // `MyApp` locks the app to portrait, so a phone-sized console is the real
    // worst case for the table: it has to degrade to cards without overflowing.
    tester.view.physicalSize = const Size(1080, 2280);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider<ProfileProvider>(
        create: (_) => ProfileProvider(),
        child: MaterialApp(
          home: AdminDashboardScreen(
            repository: _FakeRepository(),
            dashboardRepository: _FakeDashboardRepository(),
            complexAdminRepository: _FakeComplexAdminRepository(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    // No permanent sidebar at this width — navigation lives in the drawer.
    expect(find.byTooltip('Menu'), findsOneWidget);
    expect(find.text('Contact Requests'), findsOneWidget);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Users & Roles'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.text('Riya Sharma'), findsOneWidget);
    // The compact bar has no search box, so the module renders its own.
    expect(find.text('Search name, email or phone'), findsOneWidget);
  });

  testWidgets('the dashboard renders both charts and the enquiries card', (
    tester,
  ) async {
    await pumpConsole(tester, _FakeRepository());

    expect(find.text('Enrollment trends'), findsOneWidget);
    expect(find.text('Sport distribution'), findsOneWidget);
    expect(find.text('Recent enquiries'), findsOneWidget);

    // Doughnut centre: the sport count from the API, not a hardcoded number.
    // ("Sports" also names a sidebar entry, hence findsWidgets.)
    expect(find.text('Sports'), findsWidgets);
    expect(find.text('3'), findsOneWidget);
    // Each sport appears twice: once in the doughnut legend, once as an
    // enquiry's sport.
    expect(find.text('Badminton'), findsWidgets);
    expect(find.text('Tennis'), findsWidgets);
    expect(find.text('Swimming'), findsOneWidget);

    // Enquiry rows.
    expect(find.text('Meera Joshi'), findsOneWidget);
    expect(find.text('Pending'), findsOneWidget);
    expect(find.text('Approved'), findsOneWidget);
  });

  testWidgets('a growth card shows the trend direction from the API', (
    tester,
  ) async {
    await pumpConsole(tester, _FakeRepository());

    // Students is up 25% (40 vs 32) → green, up arrow.
    expect(find.text('+25%'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_upward_rounded), findsWidgets);
    // Bookings is explicitly negative in the fake.
    expect(find.text('-8.5%'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_downward_rounded), findsWidgets);
  });

  testWidgets('a failed chart shows its own retry card, not a dead page', (
    tester,
  ) async {
    await pumpConsole(
      tester,
      _FakeRepository(),
      dashboard: _FakeDashboardRepository(failDistribution: true),
    );

    // The distribution failed…
    expect(find.text('Could not load this chart'), findsOneWidget);
    // …while the rest of the page carried on.
    expect(find.text('Enrollment trends'), findsOneWidget);
    expect(find.text('Recent enquiries'), findsOneWidget);
    expect(find.text('Contact Requests'), findsOneWidget);
  });

  testWidgets('an empty chart shows an empty state rather than flat lines', (
    tester,
  ) async {
    await pumpConsole(
      tester,
      _FakeRepository(),
      dashboard: _FakeDashboardRepository(emptyCharts: true),
    );

    expect(find.text('No enrollment data yet'), findsOneWidget);
    expect(find.text('No sports to show'), findsOneWidget);
    expect(find.text('No recent enquiries'), findsOneWidget);
  });

  testWidgets('the Complex Admin module lists rows from the repository', (
    tester,
  ) async {
    await pumpConsole(tester, _FakeRepository());

    await tester.tap(find.text('Complex Admin'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.text('Priya Deshmukh'), findsOneWidget);
    expect(find.text('priya@example.com'), findsOneWidget);
    expect(find.text('Sinhagad Road Complex'), findsWidgets);
    expect(find.text('Add Complex Admin'), findsWidgets);
    expect(find.text('Sport complex'), findsWidgets);
  });

  testWidgets('the Add Complex Admin dialog opens with a venue picker fed by '
      'the API', (tester) async {
    await pumpConsole(tester, _FakeRepository());

    await tester.tap(find.text('Complex Admin'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    // Tapped by text: `FilledButton.icon` builds a private subclass, which
    // `find.widgetWithText` (an exact-runtime-type match) would not see.
    await tester.tap(find.text('Add Complex Admin').first);
    await tester.pumpAndSettle();

    expect(find.text('Add complex admin'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Select a sports complex'), findsOneWidget);

    // Opening the picker lists the venues the repository returned.
    await tester.tap(find.text('Select a sports complex'));
    await tester.pumpAndSettle();

    expect(find.text('Select sports complex'), findsOneWidget);
    expect(find.text('Sinhagad Road Complex'), findsWidgets);
    expect(find.text('Kothrud Arena'), findsOneWidget);
  });

  testWidgets('deleting a complex admin asks first and then calls the API', (
    tester,
  ) async {
    final complexAdmins = _FakeComplexAdminRepository();
    await pumpConsole(tester, _FakeRepository(), complexAdmins: complexAdmins);

    await tester.tap(find.text('Complex Admin'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    await tester.tap(find.byTooltip('Actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete admin'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this complex admin?'), findsOneWidget);
    expect(complexAdmins.deleted, isEmpty, reason: 'not confirmed yet');

    await tester.tap(find.widgetWithText(FilledButton, 'Delete admin'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(complexAdmins.deleted, ['ca-1']);
  });

  testWidgets('an empty complex-admin list shows the empty state', (
    tester,
  ) async {
    await pumpConsole(
      tester,
      _FakeRepository(),
      complexAdmins: _FakeComplexAdminRepository(admins: const []),
    );

    await tester.tap(find.text('Complex Admin'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.text('No complex admins yet'), findsOneWidget);
  });

  testWidgets('the Employees module lists rows with all twelve columns', (
    tester,
  ) async {
    await pumpConsole(tester, _FakeRepository());

    await tester.tap(find.text('Employees'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    // Header.
    expect(find.text('Add Employee'), findsWidgets);
    expect(find.text('Filter'), findsOneWidget);

    // Row content, straight from the repository.
    expect(find.text('Rahul Kale'), findsOneWidget);
    expect(find.text('NS-1042'), findsOneWidget);
    expect(find.text('rahul@example.com'), findsOneWidget);
    expect(find.text('Front Desk'), findsWidgets);
    expect(find.text('Supervisor'), findsWidgets);
    expect(find.text('Morning'), findsWidgets);
    // Salary, formatted rather than raw.
    expect(find.text('₹35,000'), findsOneWidget);
  });

  testWidgets('the employee filter sheet offers every documented option', (
    tester,
  ) async {
    await pumpConsole(tester, _FakeRepository());

    await tester.tap(find.text('Employees'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    await tester.tap(find.text('Filter'));
    await tester.pumpAndSettle();

    expect(find.text('Filter employees'), findsOneWidget);
    for (final department in Department.values) {
      expect(
        find.text(department.label),
        findsWidgets,
        reason: department.slug,
      );
    }
    for (final shift in Shift.values) {
      expect(find.text(shift.label), findsWidgets, reason: shift.slug);
    }
    // The venue list comes from the API, not a hardcoded list.
    expect(find.text('Kothrud Arena'), findsOneWidget);
  });

  testWidgets('the Add Employee form shows its three sections and validates', (
    tester,
  ) async {
    await pumpConsole(tester, _FakeRepository());

    await tester.tap(find.text('Employees'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    await tester.tap(find.text('Add Employee').first);
    await tester.pumpAndSettle();

    expect(find.text('Basic Information'), findsOneWidget);
    expect(find.text('Employment Details'), findsOneWidget);
    expect(find.text('Address'), findsWidgets);
    expect(find.text('Save Employee'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Submitting an empty form reports the required fields rather than posting.
    await tester.tap(find.text('Save Employee'));
    await tester.pumpAndSettle();

    expect(find.text('Full name is required'), findsOneWidget);
    expect(find.text('Email is required'), findsOneWidget);
    expect(find.text('Phone is required'), findsOneWidget);
    expect(find.text('Password is required'), findsOneWidget);
    expect(find.text('Employee ID is required'), findsOneWidget);
    expect(find.text('Sport complex is required'), findsOneWidget);
    expect(find.text('Joining date is required'), findsOneWidget);
  });

  testWidgets('the form rejects a short phone and a mismatched confirmation', (
    tester,
  ) async {
    await pumpConsole(tester, _FakeRepository());

    await tester.tap(find.text('Employees'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));
    await tester.tap(find.text('Add Employee').first);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, '10-digit mobile number'),
      '98220',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'At least 6 characters'),
      'secret123',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Re-enter the password'),
      'different',
    );
    await tester.pumpAndSettle();

    expect(find.text('Enter exactly 10 digits'), findsOneWidget);
    expect(find.text('Passwords do not match'), findsOneWidget);
  });

  testWidgets('the password dialog masks the value until it is revealed', (
    tester,
  ) async {
    await pumpConsole(tester, _FakeRepository());

    await tester.tap(find.text('Employees'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    await tester.tap(find.byTooltip('More actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('View password'));
    await tester.pumpAndSettle();

    expect(find.text('Sign-in credentials'), findsOneWidget);
    expect(find.text('rahul@example.com'), findsWidgets);
    // Masked by default — the plaintext is not on screen.
    expect(find.text('secret123'), findsNothing);

    await tester.tap(find.byTooltip('Reveal'));
    await tester.pumpAndSettle();

    expect(find.text('secret123'), findsOneWidget);
  });

  testWidgets('resetting a password confirms what the backend did', (
    tester,
  ) async {
    final employees = _FakeEmployeeRepository();
    await pumpConsole(tester, _FakeRepository(), employees: employees);

    await tester.tap(find.text('Employees'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    await tester.tap(find.byTooltip('More actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset password'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'At least 6 characters'),
      'newSecret123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Reset password'));
    await tester.pumpAndSettle();

    expect(employees.resetTo, 'newSecret123');
    expect(
      find.textContaining('has been emailed to the employee'),
      findsOneWidget,
    );
  });

  testWidgets('deleting an employee asks first and removes the row', (
    tester,
  ) async {
    final employees = _FakeEmployeeRepository();
    await pumpConsole(tester, _FakeRepository(), employees: employees);

    await tester.tap(find.text('Employees'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    await tester.tap(find.byTooltip('More actions').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete employee'));
    await tester.pumpAndSettle();

    expect(find.text('Delete this employee?'), findsOneWidget);
    expect(employees.deleted, isEmpty, reason: 'not confirmed yet');

    await tester.tap(find.widgetWithText(FilledButton, 'Delete employee'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(employees.deleted, ['emp-1']);
  });

  testWidgets('an empty employee list shows the empty state', (tester) async {
    await pumpConsole(
      tester,
      _FakeRepository(),
      employees: _FakeEmployeeRepository(employees: const []),
    );

    await tester.tap(find.text('Employees'));
    await tester.pumpAndSettle(const Duration(milliseconds: 600));

    expect(find.text('No employees yet'), findsOneWidget);
  });

  testWidgets('a placeholder module explains itself instead of faking data', (
    tester,
  ) async {
    await pumpConsole(tester, _FakeRepository());

    await tester.tap(find.text('Payments'));
    await tester.pumpAndSettle();

    expect(find.textContaining('has not been built yet'), findsOneWidget);
  });
}

/// `find.byType` matches the exact runtime type, and `FilledButton.icon` builds
/// a private subclass — so the Save button has to be found by predicate.
FilledButton _saveButton(WidgetTester tester) {
  return tester.widget<FilledButton>(
    find.ancestor(
      of: find.text('Save changes'),
      matching: find.byWidgetPredicate((widget) => widget is FilledButton),
    ),
  );
}

class _FakeDashboardRepository implements DashboardRepository {
  _FakeDashboardRepository({
    this.failDistribution = false,
    this.emptyCharts = false,
  });

  final bool failDistribution;
  final bool emptyCharts;

  @override
  Future<DashboardStats> fetchStats() async => const DashboardStats(
    students: StatMetric(total: 412, thisMonth: 40, lastMonth: 32),
    coaches: StatMetric(total: 18, thisMonth: 2, lastMonth: 2),
    bookings: StatMetric(
      total: 1290,
      thisMonth: 108,
      lastMonth: 118,
      growth: -8.5,
      isPositive: false,
    ),
    enquiries: StatMetric(total: 264, thisMonth: 31, lastMonth: 24),
    contactRequests: StatMetric(total: 77, thisMonth: 9, lastMonth: 11),
  );

  @override
  Future<EnrollmentTrend> fetchEnrollmentTrends() async {
    if (emptyCharts) return EnrollmentTrend.empty;
    return const EnrollmentTrend(
      points: [
        EnrollmentPoint(label: 'May', students: 22, enquiries: 30),
        EnrollmentPoint(label: 'June', students: 32, enquiries: 26),
        EnrollmentPoint(label: 'July', students: 40, enquiries: 31),
      ],
    );
  }

  @override
  Future<SportDistribution> fetchSportDistribution() async {
    if (failDistribution) throw Exception('distribution down');
    if (emptyCharts) return SportDistribution.empty;
    return const SportDistribution(
      slices: [
        SportSlice(sport: 'Badminton', count: 180, percentage: 43.7),
        SportSlice(sport: 'Tennis', count: 140, percentage: 34),
        SportSlice(sport: 'Swimming', count: 92, percentage: 22.3),
      ],
    );
  }

  @override
  Future<List<LiveEnquiry>> fetchLiveEnquiries({int? limit}) async {
    if (emptyCharts) return const [];
    return const [
      LiveEnquiry(
        id: 'e-1',
        name: 'Meera Joshi',
        email: 'meera@example.com',
        sport: 'Badminton',
        statusRaw: 'Pending',
        timeAgoRaw: '2 hours ago',
      ),
      LiveEnquiry(
        id: 'e-2',
        name: 'Rahul Kale',
        email: 'rahul@example.com',
        sport: 'Tennis',
        statusRaw: 'Approved',
        timeAgoRaw: 'Yesterday',
      ),
    ];
  }
}

class _FakeEmployeeRepository implements EmployeeRepository {
  _FakeEmployeeRepository({
    this.employees = const [
      Employee(
        id: 'emp-1',
        employeeCode: 'NS-1042',
        fullName: 'Rahul Kale',
        email: 'rahul@example.com',
        phone: '9822001100',
        sportComplexId: 1,
        sportComplexName: 'Sinhagad Road Complex',
        departmentRaw: 'Front Desk',
        designationRaw: 'Supervisor',
        shiftRaw: 'Morning',
        salary: 35000,
        statusRaw: 'Active',
      ),
    ],
  });

  final List<Employee> employees;
  final List<String> deleted = [];
  String? resetTo;

  @override
  Future<Paged<Employee>> fetchEmployees({
    int page = 1,
    int limit = 20,
    String? search,
    AdminUserStatus? status,
    Department? department,
    Shift? shift,
    int? sportComplexId,
    String? sortBy,
    bool descending = false,
  }) async => Paged<Employee>(
    items: employees,
    page: page,
    limit: limit,
    total: employees.length,
    totalPages: 1,
  );

  @override
  Future<Employee> fetchEmployee(String id) async =>
      employees.firstWhere((e) => e.id == id, orElse: () => Employee(id: id));

  @override
  Future<Employee> createEmployee(EmployeeDraft draft) async =>
      const Employee(id: 'emp-new');

  @override
  Future<Employee> updateEmployee(
    String id,
    EmployeeDraft draft, {
    bool clearAddress = false,
  }) async => Employee(id: id);

  @override
  Future<void> deleteEmployee(String id) async => deleted.add(id);

  @override
  Future<EmployeeCredentials> fetchCredentials(String id) async =>
      const EmployeeCredentials(
        email: 'rahul@example.com',
        password: 'secret123',
      );

  @override
  Future<void> resetPassword(String id, String password) async {
    resetTo = password;
  }

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async => const [
    SportsComplex(id: 1, name: 'Sinhagad Road Complex', city: 'Pune'),
    SportsComplex(id: 2, name: 'Kothrud Arena', city: 'Pune'),
  ];
}

class _FakeComplexAdminRepository implements ComplexAdminRepository {
  _FakeComplexAdminRepository({
    this.admins = const [
      ComplexAdmin(
        id: 'ca-1',
        name: 'Priya Deshmukh',
        email: 'priya@example.com',
        phone: '9822001100',
        sportComplexId: 1,
        sportComplexName: 'Sinhagad Road Complex',
        city: 'Pune',
        statusRaw: 'Active',
      ),
    ],
  });

  final List<ComplexAdmin> admins;
  final List<String> deleted = [];
  ComplexAdminDraft? created;

  @override
  Future<Paged<ComplexAdmin>> fetchComplexAdmins({
    int page = 1,
    int limit = 20,
    String? search,
  }) async => Paged<ComplexAdmin>(
    items: admins,
    page: page,
    limit: limit,
    total: admins.length,
    totalPages: 1,
  );

  @override
  Future<ComplexAdmin> createComplexAdmin(ComplexAdminDraft draft) async {
    created = draft;
    return const ComplexAdmin(id: 'ca-new');
  }

  @override
  Future<ComplexAdmin> updateComplexAdmin(
    String id,
    ComplexAdminDraft draft,
  ) async => ComplexAdmin(id: id);

  @override
  Future<void> deleteComplexAdmin(String id) async => deleted.add(id);

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async {
    return const [
      SportsComplex(id: 1, name: 'Sinhagad Road Complex', city: 'Pune'),
      SportsComplex(id: 2, name: 'Kothrud Arena', city: 'Pune'),
    ];
  }
}

class _FakeRepository implements AdminRepository {
  _FakeRepository({
    this.users = const [
      AdminUser(
        id: '1',
        name: 'Riya Sharma',
        email: 'riya@example.com',
        phone: '9876543210',
        roleRaw: 'COACH',
        statusRaw: 'Active',
        membership: 'Premium',
        totalBookings: 12,
      ),
      AdminUser(
        id: '2',
        name: 'Arjun Nahata',
        email: 'arjun@example.com',
        roleRaw: 'ADMIN',
        statusRaw: 'Active',
      ),
    ],
    this.failUsers = false,
  });

  final List<AdminUser> users;
  final bool failUsers;

  @override
  Future<AdminStats> fetchStats() async => const AdminStats(
    totalUsers: 1280,
    verifiedUsers: 900,
    unverifiedUsers: 380,
    totalCoaches: 14,
    employees: 22,
    securityGuards: 6,
    admins: 3,
  );

  @override
  Future<Paged<AdminUser>> fetchUsers({
    int page = 1,
    int limit = 20,
    AdminRole? role,
    AdminUserStatus? status,
    String? search,
    String? sortBy,
    bool descending = false,
  }) async {
    if (failUsers) throw Exception('boom');
    return Paged<AdminUser>(
      items: users,
      page: page,
      limit: limit,
      total: users.length,
      totalPages: 1,
    );
  }

  @override
  Future<AdminUser> fetchUser(String userId) async =>
      users.firstWhere((u) => u.id == userId);

  @override
  Future<AdminUser> createUser(AdminUserDraft draft) async =>
      const AdminUser(id: 'new');

  @override
  Future<AdminUser> updateUser(String userId, AdminUserDraft draft) async =>
      AdminUser(id: userId);

  @override
  Future<void> deleteUser(String userId) async {}

  @override
  Future<RolePermissions> fetchRolePermissions(AdminRole role) async =>
      RolePermissions(
        role: role,
        granted: const {'users.read'},
        available: const ['users.read', 'users.write'],
      );

  @override
  Future<RolePermissions> updateRolePermissions(
    AdminRole role,
    Set<String> granted,
  ) async => RolePermissions(role: role, granted: granted);
}
