import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/features/admin/domain/entities/admin_role.dart';
import 'package:nahata_app/features/admin/domain/entities/batch.dart';
import 'package:nahata_app/features/admin/domain/entities/coach.dart';
import 'package:nahata_app/features/admin/domain/entities/sport.dart';
import 'package:nahata_app/features/admin/domain/repositories/batch_repository.dart';
import 'package:nahata_app/features/admin/presentation/pages/batches_page.dart';
import 'package:nahata_app/features/admin/presentation/state/batches_controller.dart';
import 'package:nahata_app/features/admin/presentation/theme/admin_theme.dart';
import 'package:nahata_app/features/admin/presentation/widgets/batch_detail_panel.dart';
import 'package:nahata_app/features/admin/presentation/widgets/batches_table.dart';
import 'package:nahata_app/features/admin/presentation/widgets/occupancy_ring.dart';
import 'package:nahata_app/models/sports_complex_model.dart';

/// Paints the Batches page against a fake repository.
///
/// This is the compile-and-paint check the console's other modules already
/// have: the fourteen-column table, the five-card summary row, the view
/// switcher and the mobile card list all get laid out for real, so an overflow
/// shows up here rather than on a device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required Size size,
    BatchRepository? repository,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = BatchesController(repository ?? _FakeRepository());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AdminTheme.build(Brightness.light),
        home: ChangeNotifierProvider<BatchesController>.value(
          value: controller,
          child: const Scaffold(body: BatchesPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('the desktop layout paints the table and the summary cards', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(2100, 1000));

    expect(find.text('Batches'), findsWidgets);
    expect(find.byType(BatchesTable), findsOneWidget);

    // The five summary cards.
    expect(find.text('Total batches'), findsOneWidget);
    expect(find.text('Active batches'), findsOneWidget);
    expect(find.text('Inactive batches'), findsOneWidget);
    expect(find.text('Total students'), findsOneWidget);
    expect(find.text('Available seats'), findsOneWidget);

    // The rows themselves.
    expect(find.text('Morning Batch'), findsWidgets);
    expect(find.text('Evening Batch'), findsWidgets);

    // Every row carries an occupancy indicator.
    expect(find.byType(OccupancyBar), findsNWidgets(3));

    expect(tester.takeException(), isNull);
  });

  testWidgets('the summary captions say when a figure is only this page', (
    tester,
  ) async {
    // Three rows out of forty-seven: the counted cards describe the page, and
    // must say so rather than implying they describe the academy.
    await pumpPage(
      tester,
      size: const Size(2100, 1000),
      repository: _FakeRepository(total: 47),
    );

    expect(find.text('On this page'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow viewport swaps the table for stacked cards', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(420, 900));

    expect(find.byType(BatchesTable), findsNothing);
    expect(find.byType(BatchCard), findsNWidgets(3));
    expect(find.text('Add Batch'), findsOneWidget);
    // Pull-to-refresh only exists on the layout that owns its scroll.
    expect(find.byType(RefreshIndicator), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the detail drawer opens beside the table on a desktop', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(2100, 1000));

    await tester.tap(find.text('Morning Batch').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Batch details'), findsOneWidget);
    expect(find.text('Statistics'), findsOneWidget);
    expect(find.text('Occupancy'), findsWidgets);

    // The ring the spec asks for, in the hero and in the statistics card.
    expect(find.byType(OccupancyRing), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('General information'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(BatchDetailPanel),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('General information'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the view switcher moves to the sport-wise breakdown', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(2100, 1000));

    await tester.tap(find.text('Sport-wise'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Nothing is picked yet, so the view asks rather than guessing.
    expect(find.text('Pick a sport'), findsOneWidget);
    expect(find.byType(BatchesTable), findsNothing);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Badminton'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Badminton'), findsWidgets);
    expect(find.text('Kothrud Arena'), findsWidgets);

    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty list explains itself instead of showing a table', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(2100, 1000),
      repository: _FakeRepository(batches: const []),
    );

    expect(find.text('No batches found'), findsOneWidget);
    expect(find.byType(BatchesTable), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a load failure offers a retry rather than an empty table', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(2100, 1000),
      repository: _FailingRepository(),
    );

    expect(find.text('Could not load batches'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeRepository implements BatchRepository {
  _FakeRepository({List<AdminBatch>? batches, this.total})
    : batches =
          batches ??
          [
            AdminBatch(
              id: 1,
              name: 'Morning Batch',
              sportId: 8,
              sportName: 'Badminton',
              coachId: 5,
              coachName: 'Rahul Sharma',
              sportComplexId: 2,
              sportComplexName: 'Kothrud Arena',
              schedule: '7:00 AM to 8:00 AM',
              daysRaw: 'Monday, Wednesday, Friday',
              startDate: DateTime(2026, 7, 1),
              endDate: DateTime(2026, 9, 30),
              maxStudents: 20,
              currentStudents: 12,
              fees: 2500,
              ageGroup: '8-14',
              duration: '3 months',
              statusRaw: 'Active',
            ),
            AdminBatch(
              id: 2,
              name: 'Evening Batch',
              sportId: 8,
              sportName: 'Badminton',
              coachId: 5,
              coachName: 'Rahul Sharma',
              sportComplexId: 2,
              sportComplexName: 'Kothrud Arena',
              schedule: '6:00 PM to 7:00 PM',
              daysRaw: 'Tuesday, Thursday',
              maxStudents: 10,
              currentStudents: 10,
              fees: 1800,
              statusRaw: 'Inactive',
            ),
            const AdminBatch(id: 3, name: 'Weekend Camp', statusRaw: 'Active'),
          ];

  final List<AdminBatch> batches;
  final int? total;

  @override
  Future<BatchPageResult> fetchBatches({
    AdminUserStatus? status,
    int? sportId,
    int page = 1,
    int limit = 20,
  }) async {
    final totalItems = total ?? batches.length;
    return BatchPageResult(
      batches: batches,
      page: page,
      totalPages: (totalItems / limit).ceil().clamp(1, 999),
      totalItems: totalItems,
      perPage: limit,
    );
  }

  @override
  Future<List<AdminBatch>> fetchAllBatches({
    AdminUserStatus? status,
    int? sportId,
    int limit = 100,
    int maxPages = 20,
    void Function(int loaded, int total)? onCapped,
  }) async => batches;

  @override
  Future<AdminBatch> fetchBatch(int id) async =>
      AdminBatch(id: id, description: 'A short description.');

  @override
  Future<BatchStatistics> fetchStats(int id) async => const BatchStatistics(
    maxStudents: 20,
    currentStudents: 12,
    enrolledStudents: 13,
    availableSlots: 8,
    occupancyPercentage: 60,
    fees: 2500,
    statusRaw: 'Active',
  );

  @override
  Future<List<AdminBatch>> fetchBatchesBySport(int sportId) async => batches;

  @override
  Future<CoachBatchLoad> fetchBatchesByCoach(
    int coachId, {
    String? coachName,
  }) async => CoachBatchLoad(
    coachId: coachId,
    coachName: coachName,
    batches: batches,
  );

  @override
  Future<AdminBatch> createBatch(BatchDraft draft) async =>
      const AdminBatch(id: 99);

  @override
  Future<AdminBatch> updateBatch(int id, BatchDraft draft) async =>
      AdminBatch(id: id);

  @override
  Future<void> setStatus(int id, AdminUserStatus status) async {}

  @override
  Future<void> deleteBatch(int id) async {}

  @override
  Future<String> uploadImage(String filePath, {String? filename}) async =>
      'https://cdn/x.jpg';

  @override
  Future<List<Sport>> fetchSports({bool refresh = false}) async =>
      const [Sport(id: 8, name: 'Badminton', sportComplexId: 2)];

  @override
  Future<List<Coach>> fetchCoaches({bool refresh = false}) async => const [
    Coach(id: 5, name: 'Rahul Sharma', sportId: 8, sportComplexId: 2),
  ];

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async => const [SportsComplex(id: 2, name: 'Kothrud Arena')];
}

class _FailingRepository extends _FakeRepository {
  @override
  Future<BatchPageResult> fetchBatches({
    AdminUserStatus? status,
    int? sportId,
    int page = 1,
    int limit = 20,
  }) async => throw const ServerException('The batches service is down');
}
