import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/features/admin/domain/entities/admin_role.dart';
import 'package:nahata_app/features/admin/domain/entities/coach.dart';
import 'package:nahata_app/features/admin/domain/entities/sport.dart';
import 'package:nahata_app/features/admin/domain/repositories/coach_repository.dart';
import 'package:nahata_app/features/admin/presentation/pages/coaches_page.dart';
import 'package:nahata_app/features/admin/presentation/state/coaches_controller.dart';
import 'package:nahata_app/features/admin/presentation/theme/admin_theme.dart';
import 'package:nahata_app/features/admin/presentation/widgets/coach_detail_panel.dart';
import 'package:nahata_app/features/admin/presentation/widgets/coaches_table.dart';
import 'package:nahata_app/models/sports_complex_model.dart';

/// Paints the Coaches page against a fake repository.
///
/// This is the compile-and-paint check the console's other modules already
/// have: the twelve-column table, the six-card summary row and the mobile card
/// list all get laid out for real, so an overflow shows up here rather than on
/// a device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required Size size,
    CoachRepository? repository,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = CoachesController(repository ?? _FakeRepository());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AdminTheme.build(Brightness.light),
        home: ChangeNotifierProvider<CoachesController>.value(
          value: controller,
          child: const Scaffold(body: CoachesPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('the desktop layout paints the table and the summary cards', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1900, 1000));

    expect(find.text('Coaches'), findsWidgets);
    expect(find.byType(CoachesTable), findsOneWidget);

    // The six summary cards, counted from the returned rows.
    expect(find.text('Total coaches'), findsOneWidget);
    expect(find.text('Active coaches'), findsOneWidget);
    expect(find.text('Inactive coaches'), findsOneWidget);
    expect(find.text('Sports covered'), findsOneWidget);
    expect(find.text('Sports complexes'), findsOneWidget);
    expect(find.text('Available today'), findsOneWidget);

    // The rows themselves.
    expect(find.text('Rahul Sharma'), findsWidgets);
    expect(find.text('Priya Nair'), findsWidgets);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow viewport swaps the table for stacked cards', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(420, 900));

    expect(find.byType(CoachesTable), findsNothing);
    expect(find.byType(CoachCard), findsNWidgets(3));
    expect(find.text('Add Coach'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the detail drawer opens beside the table on a desktop', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1900, 1000));

    await tester.tap(find.text('Rahul Sharma').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Coach details'), findsOneWidget);
    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('Sports information'), findsOneWidget);
    expect(find.text('Availability'), findsWidgets);

    // The credential actions sit below the fold in the drawer's own scroll
    // view, so they are only built once scrolled to.
    await tester.scrollUntilVisible(
      find.text('View password'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(CoachDetailPanel),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('View password'), findsOneWidget);
    expect(find.text('Reset password'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a coach with no readable schedule shows a dash, not a zero', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(1900, 1000),
      repository: _FakeRepository(
        coaches: const [
          Coach(id: 1, name: 'No Schedule', statusRaw: 'Active'),
        ],
      ),
    );

    // The card renders; the figure itself is an em dash with a caption saying
    // why, rather than a zero the rows cannot support.
    expect(find.text('Available today'), findsOneWidget);
    expect(find.text('No readable schedules'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty list explains itself instead of showing a table', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(1900, 1000),
      repository: _FakeRepository(coaches: const []),
    );

    expect(find.text('No coaches yet'), findsOneWidget);
    expect(find.byType(CoachesTable), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a load failure offers a retry rather than an empty table', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(1900, 1000),
      repository: _FailingRepository(),
    );

    expect(find.text('Could not load coaches'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeRepository implements CoachRepository {
  _FakeRepository({List<Coach>? coaches})
    : coaches =
          coaches ??
          const [
            Coach(
              id: 1,
              name: 'Rahul Sharma',
              email: 'rahul@nahatasports.com',
              phone: '9876543210',
              sportId: 7,
              sportName: 'Badminton',
              sportComplexId: 1,
              sportComplexName: 'Kothrud Arena',
              ground: 'Court 3',
              categoryRaw: 'Indoor',
              experience: '5 years',
              price: 1200,
              availabilityRaw: 'Monday, Wednesday, Friday',
              statusRaw: 'Active',
              specialization: 'Junior coaching',
            ),
            Coach(
              id: 2,
              name: 'Priya Nair',
              email: 'priya@nahatasports.com',
              phone: '9000000000',
              sportId: 8,
              sportName: 'Football',
              sportComplexId: 2,
              sportComplexName: 'Baner Ground',
              categoryRaw: 'Outdoor',
              experience: '2 years',
              availabilityRaw: 'Weekends only',
              statusRaw: 'Inactive',
            ),
            Coach(id: 3, name: 'Amit Rao', statusRaw: 'Active'),
          ];

  final List<Coach> coaches;

  @override
  Future<List<Coach>> fetchCoaches({
    AdminUserStatus? status,
    int? sportId,
  }) async => coaches;

  @override
  Future<Coach> fetchCoach(int id) async => Coach(id: id, bio: 'A short bio.');

  @override
  Future<CoachStats> fetchStats(int id) async => const CoachStats(
    totalPrograms: 4,
    activePrograms: 3,
    totalStudents: 30,
  );

  @override
  Future<Coach> createCoach(CoachDraft draft) async => const Coach(id: 99);

  @override
  Future<Coach> updateCoach(int id, CoachDraft draft) async => Coach(id: id);

  @override
  Future<void> deleteCoach(int id) async {}

  @override
  Future<CoachCredentials> fetchCredentials(int id) async =>
      const CoachCredentials(email: 'a@b.com', password: 'secret1');

  @override
  Future<void> resetPassword(int id, String password) async {}

  @override
  Future<String> uploadImage(String filePath, {String? filename}) async =>
      'https://cdn/x.jpg';

  @override
  Future<List<Sport>> fetchSports({bool refresh = false}) async => const [
    Sport(id: 7, name: 'Badminton', sportComplexId: 1),
    Sport(id: 8, name: 'Football', sportComplexId: 2),
  ];

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async => const [
    SportsComplex(id: 1, name: 'Kothrud Arena'),
    SportsComplex(id: 2, name: 'Baner Ground'),
  ];
}

class _FailingRepository extends _FakeRepository {
  @override
  Future<List<Coach>> fetchCoaches({
    AdminUserStatus? status,
    int? sportId,
  }) async => throw const ServerException('The coaches service is down');
}
