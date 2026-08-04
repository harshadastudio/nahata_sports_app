import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/features/admin/domain/entities/event_pass.dart';
import 'package:nahata_app/features/admin/domain/repositories/event_pass_repository.dart';
import 'package:nahata_app/features/admin/presentation/pages/event_passes_page.dart';
import 'package:nahata_app/features/admin/presentation/state/event_passes_controller.dart';
import 'package:nahata_app/features/admin/presentation/theme/admin_theme.dart';
import 'package:nahata_app/features/admin/presentation/widgets/event_pass_detail_panel.dart';
import 'package:nahata_app/features/admin/presentation/widgets/event_pass_form_dialog.dart';
import 'package:nahata_app/features/admin/presentation/widgets/event_passes_table.dart';
import 'package:nahata_app/models/sports_complex_model.dart';

/// Paints the Event Passes page against a fake repository.
///
/// The events table, the summary cards, the bookings board, the mobile card
/// list, the detail drawer and both dialogs get laid out for real, so an
/// overflow shows up here rather than on a device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required Size size,
    EventPassRepository? repository,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = EventPassesController(repository ?? _FakeRepository());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AdminTheme.build(Brightness.light),
        home: ChangeNotifierProvider<EventPassesController>.value(
          value: controller,
          child: const Scaffold(body: EventPassesPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('the desktop layout paints the table and the summary cards', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1800, 1100));

    expect(find.text('Event Passes'), findsWidgets);
    expect(find.byType(EventPassesTable), findsOneWidget);

    // The five summary cards.
    expect(find.text('Total events'), findsOneWidget);
    expect(find.text('Active events'), findsOneWidget);
    expect(find.text('Still to run'), findsOneWidget);
    expect(find.text('Total slots'), findsOneWidget);
    expect(find.text('Total capacity'), findsOneWidget);

    expect(find.text('Diwali Badminton Championship'), findsWidgets);
    expect(find.text('Kothrud Arena'), findsWidgets);

    expect(tester.takeException(), isNull);
  });

  testWidgets('an unreported capacity says so rather than claiming no seats', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(1800, 1100),
      repository: _FakeRepository(
        events: [
          AdminEventPass(
            id: 7,
            title: 'Diwali Badminton Championship',
            statusRaw: 'Active',
            slots: [
              EventPassSlot(
                date: DateTime(2026, 9, 12),
                startTimeRaw: '10:00',
                endTimeRaw: '13:00',
              ),
            ],
          ),
        ],
      ),
    );

    // A zero would read as "sold out", which the payload never said.
    expect(find.text('Not reported'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow viewport swaps the table for stacked cards', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(420, 900));

    expect(find.byType(EventPassesTable), findsNothing);
    expect(find.byType(EventPassCard), findsNWidgets(2));
    expect(find.text('Add Event'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the detail drawer opens beside the table on a desktop', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1800, 1100));

    await tester.tap(find.text('Diwali Badminton Championship').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(EventPassDetailPanel), findsOneWidget);
    expect(find.text('Event details'), findsOneWidget);
    // The slots and FAQs arrive with the detail read.
    expect(
      find.descendant(
        of: find.byType(EventPassDetailPanel),
        matching: find.text('Slots'),
      ),
      findsWidgets,
    );
    expect(find.text('Is parking available?'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the bookings view paints its own table', (tester) async {
    await pumpPage(tester, size: const Size(1800, 1100));

    await tester.tap(find.text('Event bookings'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(EventPassesTable), findsNothing);
    expect(find.byType(EventBookingsTable), findsOneWidget);
    expect(find.text('Rahul Sharma'), findsWidgets);
    expect(find.text('Scanned in'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the add dialog opens with an editable slot row', (tester) async {
    await pumpPage(tester, size: const Size(1800, 1100));

    await tester.tap(find.text('Add Event'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(EventPassFormDialog), findsOneWidget);
    expect(find.text('Add event'), findsWidgets);
    // The field labels are rich text, so the hints stand in for them.
    expect(find.text('e.g. Independence Day Cricket Cup'), findsOneWidget);
    expect(find.text('Add slot'), findsOneWidget);
    expect(find.text('Add FAQ'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the edit dialog shows the slots read-only and says why', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1800, 1100));

    await tester.tap(find.byIcon(Icons.more_horiz_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    await tester.tap(find.text('Edit event').last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(EventPassFormDialog), findsOneWidget);
    expect(find.text('Edit event'), findsWidgets);
    // Replacing the slot array on an event with passes sold is not something
    // an undocumented route should be trusted with, and the form says so.
    expect(find.textContaining('read-only'), findsOneWidget);
    expect(find.text('Add slot'), findsNothing);

    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty list explains itself instead of showing a table', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(1800, 1100),
      repository: _FakeRepository(events: const []),
    );

    expect(find.text('No events found'), findsOneWidget);
    expect(find.byType(EventPassesTable), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a load failure offers a retry rather than an empty table', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(1800, 1100),
      repository: _FailingRepository(),
    );

    expect(find.text('Could not load the events'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeRepository implements EventPassRepository {
  _FakeRepository({List<AdminEventPass>? events})
    : events =
          events ??
          [
            AdminEventPass(
              id: 7,
              title: 'Diwali Badminton Championship',
              description: 'Annual badminton tournament with prizes.',
              sportComplexId: 2,
              sportComplexName: 'Kothrud Arena',
              statusRaw: 'Active',
              slots: [
                EventPassSlot(
                  id: 31,
                  date: DateTime(2026, 9, 12),
                  startTimeRaw: '10:00',
                  endTimeRaw: '13:00',
                  price: 500,
                  capacity: 100,
                ),
                EventPassSlot(
                  id: 32,
                  date: DateTime(2026, 9, 13),
                  startTimeRaw: '10:00',
                  endTimeRaw: '13:00',
                  price: 750,
                  capacity: 80,
                ),
              ],
            ),
            AdminEventPass(
              id: 8,
              title: 'Monsoon Fun Run',
              sportComplexId: 4,
              sportComplexName: 'Baner Turf',
              statusRaw: 'Inactive',
              slots: [
                EventPassSlot(
                  id: 41,
                  date: DateTime(2026, 10, 1),
                  startTimeRaw: '06:00',
                  endTimeRaw: '09:00',
                  price: 250,
                  capacity: 500,
                ),
              ],
            ),
          ];

  final List<AdminEventPass> events;

  @override
  Future<EventPassPageResult<AdminEventPass>> fetchEventPasses({
    int page = 1,
    int limit = 20,
  }) async => EventPassPageResult<AdminEventPass>(
    items: events,
    page: page,
    totalPages: 1,
    totalItems: events.length,
    perPage: limit,
  );

  @override
  Future<AdminEventPass> fetchEventPass(int id) async => AdminEventPass(
    id: id,
    faqs: const [
      EventFaq(question: 'Is parking available?', answer: 'Yes, and free.'),
    ],
  );

  @override
  Future<AdminEventPass> createEventPass(EventPassDraft draft) async =>
      const AdminEventPass(id: 99);

  @override
  Future<AdminEventPass> updateEventPass(int id, EventPassDraft draft) async =>
      AdminEventPass(id: id);

  @override
  Future<void> deleteEventPass(int id) async {}

  @override
  Future<String> uploadImage(String filePath, {String? filename}) async =>
      'https://cdn/event.jpg';

  @override
  Future<EventPassPageResult<EventPassBookingRow>> fetchBookings({
    int page = 1,
    int limit = 20,
  }) async {
    final bookings = [
      EventPassBookingRow(
        id: 12,
        eventPassId: 7,
        eventTitle: 'Diwali Badminton Championship',
        slotId: 31,
        slotName: 'Day 1',
        slotDate: DateTime(2026, 9, 12),
        customerName: 'Rahul Sharma',
        customerEmail: 'rahul@example.com',
        customerPhone: '9876543210',
        numberOfPasses: 2,
        totalAmount: 1000,
        couponCode: 'DIWALI10',
        paymentStatusRaw: 'Paid',
        bookingStatusRaw: 'Confirmed',
        scannedInCount: 1,
        createdAt: DateTime(2026, 8, 2),
      ),
      const EventPassBookingRow(id: 13, customerName: 'Priya Nair'),
    ];

    return EventPassPageResult<EventPassBookingRow>(
      items: bookings,
      page: page,
      totalPages: 1,
      totalItems: bookings.length,
      perPage: limit,
    );
  }

  @override
  Future<List<EventPassBookingRow>> fetchMyBookings() async => const [];

  @override
  Future<EventPassBookingRow> createBooking(EventBookingDraft draft) async =>
      const EventPassBookingRow(id: 99);

  @override
  Future<List<SportsComplex>> fetchSportComplexes({bool refresh = false}) async
  => const [
    SportsComplex(id: 2, name: 'Kothrud Arena'),
    SportsComplex(id: 4, name: 'Baner Turf'),
  ];
}

class _FailingRepository extends _FakeRepository {
  @override
  Future<EventPassPageResult<AdminEventPass>> fetchEventPasses({
    int page = 1,
    int limit = 20,
  }) async => throw const ServerException('The events service is down');
}
