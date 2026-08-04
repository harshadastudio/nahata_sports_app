import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/features/admin/domain/entities/admin_role.dart';
import 'package:nahata_app/features/admin/domain/entities/sport.dart';
import 'package:nahata_app/features/admin/domain/repositories/sport_repository.dart';
import 'package:nahata_app/features/admin/presentation/pages/sports_page.dart';
import 'package:nahata_app/features/admin/presentation/state/sports_controller.dart';
import 'package:nahata_app/features/admin/presentation/theme/admin_theme.dart';
import 'package:nahata_app/features/admin/presentation/widgets/sports_table.dart';
import 'package:nahata_app/models/sports_complex_model.dart';

/// Paints the Sports page against a fake repository.
///
/// This is the compile-and-paint check the console's other modules already
/// have: the ten-column table, the seven-card summary row and the mobile card
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
    SportRepository? repository,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = SportsController(repository ?? _FakeRepository());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AdminTheme.build(Brightness.light),
        home: ChangeNotifierProvider<SportsController>.value(
          value: controller,
          child: const Scaffold(body: SportsPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('the desktop layout paints the table and the summary cards', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1800, 1000));

    expect(find.text('Sports'), findsWidgets);
    expect(find.byType(SportsTable), findsOneWidget);

    // The seven summary cards, counted from the returned rows.
    expect(find.text('Total sports'), findsOneWidget);
    expect(find.text('Active sports'), findsOneWidget);
    expect(find.text('Indoor sports'), findsOneWidget);
    expect(find.text('Outdoor sports'), findsOneWidget);
    expect(find.text('Visible on frontend'), findsOneWidget);
    expect(find.text('Total programs'), findsOneWidget);
    expect(find.text('Total courts'), findsOneWidget);

    // The rows themselves.
    expect(find.text('Badminton'), findsWidgets);
    expect(find.text('Football'), findsWidgets);

    // Every row carries a visibility switch.
    expect(find.byType(SportVisibilitySwitch), findsNWidgets(3));

    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow viewport swaps the table for stacked cards', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(420, 900));

    expect(find.byType(SportsTable), findsNothing);
    expect(find.byType(SportCard), findsNWidgets(3));
    expect(find.text('Add Sport'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty list explains itself instead of showing a table', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(1800, 1000),
      repository: _FakeRepository(sports: const []),
    );

    expect(find.text('No sports yet'), findsOneWidget);
    expect(find.byType(SportsTable), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a load failure offers a retry rather than an empty table', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(1800, 1000),
      repository: _FailingRepository(),
    );

    expect(find.text('Could not load sports'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeRepository implements SportRepository {
  _FakeRepository({List<Sport>? sports})
    : sports =
          sports ??
          const [
            Sport(
              id: 1,
              name: 'Badminton',
              sportComplexId: 1,
              sportComplexName: 'Kothrud Arena',
              categoryRaw: 'Indoor',
              statusRaw: 'Active',
              showOnFrontend: true,
              minAge: 6,
              maxAge: 45,
              duration: '60 mins',
              allowedMembers: 4,
              programCount: 3,
              courtCount: 5,
              availableCourts: 2,
              programNames: ['Beginners', 'Advanced'],
            ),
            Sport(
              id: 2,
              name: 'Football',
              sportComplexId: 1,
              sportComplexName: 'Kothrud Arena',
              categoryRaw: 'Outdoor',
              statusRaw: 'Inactive',
              showOnFrontend: false,
              allowedMembers: 22,
              programCount: 1,
              courtCount: 2,
            ),
            Sport(id: 3, name: 'Table Tennis', categoryRaw: 'Indoor'),
          ];

  final List<Sport> sports;

  @override
  Future<List<Sport>> fetchSports({
    AdminUserStatus? status,
    int? complexId,
  }) async => sports;

  @override
  Future<Sport> fetchSport(int id) async => Sport(id: id);

  @override
  Future<SportStats> fetchStats(int id) async => const SportStats(
    totalPrograms: 4,
    activePrograms: 3,
    totalCourts: 5,
    totalStudents: 30,
  );

  @override
  Future<Sport> createSport(SportDraft draft) async => const Sport(id: 99);

  @override
  Future<Sport> updateSport(int id, SportDraft draft) async => Sport(id: id);

  @override
  Future<void> deleteSport(int id) async {}

  @override
  Future<void> setStatus(int id, AdminUserStatus status) async {}

  @override
  Future<void> setVisibility(int id, bool showOnFrontend) async {}

  @override
  Future<void> assignComplex(int id, int sportComplexId) async {}

  @override
  Future<String> uploadImage(String filePath, {String? filename}) async =>
      'https://cdn/x.jpg';

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async => const [
    SportsComplex(id: 1, name: 'Kothrud Arena', city: 'Pune'),
    SportsComplex(id: 2, name: 'Sinhagad Road', city: 'Pune'),
  ];
}

class _FailingRepository extends _FakeRepository {
  @override
  Future<List<Sport>> fetchSports({
    AdminUserStatus? status,
    int? complexId,
  }) async {
    throw Exception('boom');
  }
}
