import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/features/admin/domain/entities/admin_role.dart';
import 'package:nahata_app/features/admin/domain/entities/court.dart';
import 'package:nahata_app/features/admin/domain/entities/court_slot.dart';
import 'package:nahata_app/features/admin/domain/entities/sport.dart';
import 'package:nahata_app/features/admin/domain/repositories/court_repository.dart';
import 'package:nahata_app/features/admin/domain/repositories/court_slot_repository.dart';
import 'package:nahata_app/features/admin/presentation/pages/court_slots_page.dart';
import 'package:nahata_app/features/admin/presentation/pages/courts_page.dart';
import 'package:nahata_app/features/admin/presentation/state/courts_controller.dart';
import 'package:nahata_app/features/admin/presentation/theme/admin_theme.dart';
import 'package:nahata_app/features/admin/presentation/widgets/courts_table.dart';
import 'package:nahata_app/features/admin/presentation/widgets/slots_table.dart';
import 'package:nahata_app/models/sports_complex_model.dart';

/// Paints the Courts page and the Manage Slots screen against fake
/// repositories.
///
/// This is the compile-and-paint check the console's other modules already
/// have: the twelve-column table, the six-card summary row, the mobile card
/// list, the slot schedule and the week calendar all get laid out for real, so
/// an overflow shows up here rather than on a device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpCourts(
    WidgetTester tester, {
    required Size size,
    CourtRepository? repository,
    CourtSlotRepository? slots,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = CourtsController(repository ?? _FakeCourtRepository());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AdminTheme.build(Brightness.light),
        home: MultiProvider(
          providers: [
            ChangeNotifierProvider<CourtsController>.value(value: controller),
            Provider<CourtSlotRepository>.value(
              value: slots ?? _FakeSlotRepository(),
            ),
          ],
          child: const Scaffold(body: CourtsPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('the desktop layout paints the table and the summary cards', (
    tester,
  ) async {
    await pumpCourts(tester, size: const Size(2000, 1000));

    expect(find.text('Courts'), findsWidgets);
    expect(find.byType(CourtsTable), findsOneWidget);

    // The six summary cards.
    expect(find.text('Total courts'), findsOneWidget);
    expect(find.text('Active courts'), findsOneWidget);
    expect(find.text('Visible on frontend'), findsOneWidget);
    expect(find.text('Hidden courts'), findsOneWidget);
    expect(find.text('Total slots'), findsOneWidget);
    expect(find.text('Available slots'), findsOneWidget);

    expect(find.text('Court 1'), findsWidgets);
    expect(find.text('Court 2'), findsWidgets);

    // Every row carries a visibility switch.
    expect(find.byType(CourtVisibilitySwitch), findsNWidgets(3));

    expect(tester.takeException(), isNull);
  });

  testWidgets('a court with no slot counters says so rather than showing 0', (
    tester,
  ) async {
    await pumpCourts(
      tester,
      size: const Size(2000, 1000),
      repository: _FakeCourtRepository(
        courts: const [Court(id: 1, name: 'Court 1', statusRaw: 'Active')],
      ),
    );

    expect(find.text('Not reported by the list'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow viewport swaps the table for stacked cards', (
    tester,
  ) async {
    await pumpCourts(tester, size: const Size(420, 900));

    expect(find.byType(CourtsTable), findsNothing);
    expect(find.byType(CourtCard), findsNWidgets(3));
    expect(find.text('Add Court'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the availability view hides the table and the court names', (
    tester,
  ) async {
    await pumpCourts(tester, size: const Size(2000, 1000));

    await tester.tap(find.text('Availability'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(CourtsTable), findsNothing);
    // The whole point of the view: free time, no court names.
    expect(find.textContaining('court names are not shown'), findsOneWidget);
    expect(find.text('Court 1'), findsNothing);
    expect(find.textContaining('courts free'), findsWidgets);

    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty list explains itself instead of showing a table', (
    tester,
  ) async {
    await pumpCourts(
      tester,
      size: const Size(2000, 1000),
      repository: _FakeCourtRepository(courts: const []),
    );

    expect(find.text('No courts found'), findsOneWidget);
    expect(find.byType(CourtsTable), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a load failure offers a retry rather than an empty table', (
    tester,
  ) async {
    await pumpCourts(
      tester,
      size: const Size(2000, 1000),
      repository: _FailingCourtRepository(),
    );

    expect(find.text('Could not load courts'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // ---------------------------------------------------------------------------

  Future<void> pumpSlots(
    WidgetTester tester, {
    required Size size,
    CourtSlotRepository? repository,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AdminTheme.build(Brightness.light),
        home: CourtSlotsPage(
          court: const Court(
            id: 1,
            name: 'Court 1',
            sportName: 'Badminton',
            sportComplexName: 'Kothrud Arena',
            hourlyRate: 800,
          ),
          repository: repository ?? _FakeSlotRepository(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('the slots screen paints the schedule and its summary cards', (
    tester,
  ) async {
    await pumpSlots(tester, size: const Size(1400, 1000));

    expect(find.text('Court 1'), findsWidgets);
    expect(find.byType(SlotsTable), findsOneWidget);

    expect(find.text('Total slots'), findsOneWidget);
    expect(find.text('Regular slots'), findsOneWidget);
    expect(find.text('Custom price'), findsOneWidget);
    // "Bookable" and "Blocked" label both a summary card and the row switches,
    // so they are expected more than once.
    expect(find.text('Bookable'), findsWidgets);
    expect(find.text('Blocked'), findsWidgets);

    expect(find.text('7:00 AM – 8:00 AM'), findsWidgets);
    expect(find.byType(SlotBookableSwitch), findsNWidgets(2));

    expect(tester.takeException(), isNull);
  });

  testWidgets('the week calendar paints its grid and legend', (tester) async {
    await pumpSlots(tester, size: const Size(1400, 1000));

    await tester.tap(find.text('Week calendar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(SlotsTable), findsNothing);
    // The legend names all four states, including the honest fourth.
    expect(find.text('Available'), findsWidgets);
    expect(find.text('Booked'), findsWidgets);
    expect(find.text('Blocked'), findsWidgets);
    expect(find.text('Not reported'), findsOneWidget);
    expect(find.text('Mon'), findsWidgets);
    expect(find.text('Sun'), findsWidgets);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a court with no slots explains itself', (tester) async {
    await pumpSlots(
      tester,
      size: const Size(1400, 1000),
      repository: _FakeSlotRepository(slots: const []),
    );

    expect(find.text('No slots available'), findsOneWidget);
    expect(find.byType(SlotsTable), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _FakeCourtRepository implements CourtRepository {
  _FakeCourtRepository({List<Court>? courts})
    : courts =
          courts ??
          const [
            Court(
              id: 1,
              name: 'Court 1',
              sportId: 8,
              sportName: 'Badminton',
              sportComplexId: 2,
              sportComplexName: 'Kothrud Arena',
              surfaceType: 'Synthetic',
              capacity: 4,
              hourlyRate: 800,
              lightingAvailable: true,
              equipmentAvailable: 'Rackets',
              statusRaw: 'Active',
              showOnFrontend: true,
              slotCount: 12,
              availableSlotCount: 5,
            ),
            Court(
              id: 2,
              name: 'Court 2',
              sportId: 8,
              sportName: 'Badminton',
              sportComplexId: 2,
              sportComplexName: 'Kothrud Arena',
              surfaceType: 'Clay',
              capacity: 2,
              hourlyRate: 600,
              lightingAvailable: false,
              statusRaw: 'Inactive',
              showOnFrontend: false,
              slotCount: 8,
              availableSlotCount: 2,
            ),
            Court(id: 3, name: 'Court 3', statusRaw: 'Active'),
          ];

  final List<Court> courts;

  @override
  Future<List<Court>> fetchCourts({int? complexId, int? sportId}) async =>
      courts;

  @override
  Future<Court> fetchCourt(int id) async =>
      Court(id: id, description: 'A short description.');

  @override
  Future<Court> createCourt(CourtDraft draft) async => const Court(id: 99);

  @override
  Future<Court> updateCourt(int id, CourtDraft draft) async => Court(id: id);

  @override
  Future<void> setVisibility(int id, bool showOnFrontend) async {}

  @override
  Future<void> setStatus(int id, AdminUserStatus status) async {}

  @override
  Future<void> deleteCourt(int id) async {}

  @override
  Future<String> uploadImage(String filePath, {String? filename}) async =>
      'https://cdn/x.jpg';

  @override
  Future<List<Sport>> fetchSports({bool refresh = false}) async =>
      const [Sport(id: 8, name: 'Badminton', sportComplexId: 2)];

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async => const [SportsComplex(id: 2, name: 'Kothrud Arena')];
}

class _FailingCourtRepository extends _FakeCourtRepository {
  @override
  Future<List<Court>> fetchCourts({int? complexId, int? sportId}) async =>
      throw const ServerException('The courts service is down');
}

class _FakeSlotRepository implements CourtSlotRepository {
  _FakeSlotRepository({List<CourtSlot>? slots})
    : slots =
          slots ??
          const [
            CourtSlot(
              id: 1,
              courtId: 1,
              startTimeRaw: '07:00',
              endTimeRaw: '08:00',
              availableDaysRaw: 'Monday, Wednesday, Friday',
              slotTypeRaw: 'Regular',
              statusRaw: 'Active',
            ),
            CourtSlot(
              id: 2,
              courtId: 1,
              startTimeRaw: '18:00',
              endTimeRaw: '19:00',
              availableDaysRaw: 'Tuesday, Thursday',
              slotTypeRaw: 'Premium',
              priceOverride: 1200,
              statusRaw: 'Inactive',
            ),
          ];

  final List<CourtSlot> slots;

  @override
  Future<List<CourtSlot>> fetchSlots(int courtId) async => slots;

  @override
  Future<CourtSlot> createSlot(int courtId, CourtSlotDraft draft) async =>
      CourtSlot(id: 99, courtId: courtId);

  @override
  Future<CourtSlot> updateSlot(
    int courtId,
    int slotId,
    CourtSlotDraft draft,
  ) async => CourtSlot(id: slotId, courtId: courtId);

  @override
  Future<AdminUserStatus?> toggleSlot(int courtId, int slotId) async => null;

  @override
  Future<void> deleteSlot(int courtId, int slotId) async {}

  @override
  Future<List<AvailableSlot>> fetchAvailableSlots(
    int courtId,
    DateTime date,
  ) async => const [
    AvailableSlot(
      startTimeRaw: '07:00',
      endTimeRaw: '08:00',
      isAvailable: true,
    ),
    AvailableSlot(
      startTimeRaw: '18:00',
      endTimeRaw: '19:00',
      isBlocked: true,
    ),
  ];

  @override
  Future<List<AvailabilityWindow>> fetchAvailability({
    int? complexId,
    int? sportId,
    required DateTime date,
  }) async => const [
    AvailabilityWindow(
      startTimeRaw: '07:00',
      endTimeRaw: '08:00',
      availableCourts: 2,
      totalCourts: 3,
    ),
  ];
}
