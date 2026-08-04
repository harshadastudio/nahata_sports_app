import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/features/admin/domain/entities/booking.dart';
import 'package:nahata_app/features/admin/domain/entities/court.dart';
import 'package:nahata_app/features/admin/domain/entities/sport.dart';
import 'package:nahata_app/features/admin/domain/repositories/booking_repository.dart';
import 'package:nahata_app/features/admin/presentation/pages/bookings_page.dart';
import 'package:nahata_app/features/admin/presentation/state/bookings_controller.dart';
import 'package:nahata_app/features/admin/presentation/theme/admin_theme.dart';
import 'package:nahata_app/features/admin/presentation/widgets/booking_detail_panel.dart';
import 'package:nahata_app/features/admin/presentation/widgets/bookings_table.dart';
import 'package:nahata_app/models/sports_complex_model.dart';

/// Paints the Bookings page against a fake repository.
///
/// The fourteen-column table, the nine analytics cards, the mobile card list,
/// the timeline, the calendar and the charts all get laid out for real, so an
/// overflow shows up here rather than on a device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<void> pumpPage(
    WidgetTester tester, {
    required Size size,
    BookingRepository? repository,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = BookingsController(repository ?? _FakeRepository());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AdminTheme.build(Brightness.light),
        home: ChangeNotifierProvider<BookingsController>.value(
          value: controller,
          child: const Scaffold(body: BookingsPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('the desktop layout paints the table and the analytics cards', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(2200, 1100));

    expect(find.text('Bookings'), findsWidgets);
    expect(find.byType(BookingsTable), findsOneWidget);

    // The nine analytics cards.
    expect(find.text('Total bookings'), findsOneWidget);
    expect(find.text("Today's bookings"), findsOneWidget);
    expect(find.text('Confirmed'), findsWidgets);
    expect(find.text('Pending'), findsWidgets);
    expect(find.text('Cancelled'), findsWidgets);
    expect(find.text('Completed'), findsWidgets);
    expect(find.text('Total revenue'), findsOneWidget);
    expect(find.text('Paid bookings'), findsOneWidget);
    expect(find.text('Unpaid bookings'), findsOneWidget);

    expect(find.text('BOOK-2026-000071'), findsWidgets);
    expect(find.text('Rahul Sharma'), findsWidgets);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a counted card says so rather than posing as the endpoint', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(2200, 1100),
      // Stats answer with the total only, so the rest fall back to counting.
      repository: _FakeRepository(stats: const BookingStats(total: 420)),
    );

    expect(find.textContaining('Counted'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a narrow viewport swaps the table for stacked cards', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(420, 900));

    expect(find.byType(BookingsTable), findsNothing);
    expect(find.byType(BookingCard), findsNWidgets(3));
    expect(find.text('Add Booking'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the detail drawer opens beside the table on a desktop', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(2200, 1100));

    await tester.tap(find.text('Rahul Sharma').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Booking details'), findsOneWidget);
    expect(find.text('Customer'), findsWidgets);
    expect(find.text('Schedule'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Transaction ID'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(BookingDetailPanel),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text('Transaction ID'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(BookingDetailPanel),
        matching: find.text('Payment'),
      ),
      findsWidgets,
    );

    expect(tester.takeException(), isNull);
  });

  testWidgets("the today view paints the timeline and its counters", (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(2200, 1100));

    await tester.tap(find.text("Today's board"));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(BookingsTable), findsNothing);
    expect(find.text('Active today'), findsOneWidget);
    expect(find.text('Ongoing now'), findsOneWidget);
    expect(find.text('Upcoming'), findsOneWidget);
    expect(find.text('Completed today'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the calendar paints a month grid and says what it can see', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(2200, 1500));

    await tester.tap(find.text('Calendar'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.byType(BookingsTable), findsNothing);
    expect(find.text('Mon'), findsOneWidget);
    expect(find.text('Sun'), findsOneWidget);
    // The grid is drawn from loaded rows, and says so rather than implying it
    // has the whole month.
    expect(find.textContaining('fall in this month'), findsOneWidget);
    expect(find.text('Pick a day to see its bookings.'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the stats view explains itself when no series was sent', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(2200, 1100),
      repository: _FakeRepository(stats: const BookingStats(total: 420)),
    );

    await tester.tap(find.text('Statistics'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    // An axis of zeroes would read as "no bookings" — a different claim.
    expect(find.textContaining('no series'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the stats view draws the charts when a series was sent', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(2200, 1100),
      repository: _FakeRepository(
        stats: const BookingStats(
          total: 420,
          daily: [
            BookingPoint(label: '2026-08-01', value: 4),
            BookingPoint(label: '2026-08-02', value: 7),
          ],
          topSports: [BookingPoint(label: 'Badminton', value: 30)],
        ),
      ),
    );

    await tester.tap(find.text('Statistics'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Bookings over time'), findsOneWidget);
    expect(find.text('Most booked sports'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty list explains itself instead of showing a table', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(2200, 1100),
      repository: _FakeRepository(bookings: const []),
    );

    expect(find.text('No bookings found'), findsOneWidget);
    expect(find.byType(BookingsTable), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a load failure offers a retry rather than an empty table', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(2200, 1100),
      repository: _FailingRepository(),
    );

    expect(find.text('Could not load bookings'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _FakeRepository implements BookingRepository {
  _FakeRepository({List<Booking>? bookings, this.stats})
    : bookings =
          bookings ??
          [
            Booking(
              id: 71,
              reference: 'BOOK-2026-000071',
              customerName: 'Rahul Sharma',
              customerPhone: '9876543210',
              customerEmail: 'rahul@example.com',
              userId: 585,
              sportId: 8,
              sportName: 'Badminton',
              courtId: 3,
              courtName: 'Court 1',
              sportComplexId: 2,
              sportComplexName: 'Kothrud Arena',
              date: DateTime(2026, 8, 5),
              startTimeRaw: '19:00:00',
              endTimeRaw: '20:00:00',
              amount: 800,
              bookingSourceRaw: 'Mobile App',
              bookingStatusRaw: 'Confirmed',
              paymentStatusRaw: 'Paid',
              transactionId: 'pay_123',
              notes: 'Bring rackets',
              createdAt: DateTime(2026, 8, 1),
            ),
            Booking(
              id: 72,
              reference: 'BOOK-2026-000072',
              customerName: 'Priya Nair',
              customerPhone: '9000000000',
              sportId: 8,
              sportName: 'Badminton',
              courtId: 4,
              courtName: 'Court 2',
              date: DateTime(2026, 8, 6),
              startTimeRaw: '07:00:00',
              endTimeRaw: '08:00:00',
              amount: 600,
              bookingSourceRaw: 'Walk-in',
              bookingStatusRaw: 'Pending',
              paymentStatusRaw: 'Pending',
            ),
            const Booking(id: 73, customerName: 'Amit Rao'),
          ];

  final List<Booking> bookings;
  final BookingStats? stats;

  @override
  Future<BookingPageResult> fetchBookings({
    BookingStatus? status,
    PaymentStatus? payment,
    BookingSource? source,
    int? sportId,
    int? courtId,
    int? complexId,
    DateTime? date,
    int page = 1,
    int limit = 20,
  }) async => BookingPageResult(
    bookings: bookings,
    page: page,
    totalPages: 1,
    totalItems: bookings.length,
    perPage: limit,
  );

  @override
  Future<List<Booking>> fetchAllBookings({
    BookingStatus? status,
    PaymentStatus? payment,
    BookingSource? source,
    int? sportId,
    int? courtId,
    int? complexId,
    DateTime? date,
    int limit = 100,
    int maxPages = 20,
    void Function(int loaded, int total)? onCapped,
  }) async => bookings;

  @override
  Future<BookingStats> fetchStats() async =>
      stats ??
      const BookingStats(
        total: 420,
        today: 12,
        confirmed: 300,
        pending: 60,
        cancelled: 40,
        completed: 20,
        revenue: 336000,
        paid: 310,
        unpaid: 110,
        growthPercent: 12.5,
      );

  @override
  Future<List<Booking>> fetchCurrent() async {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    return [
      Booking(
        id: 81,
        reference: 'BOOK-2026-000081',
        customerName: 'Rahul Sharma',
        courtName: 'Court 1',
        sportName: 'Badminton',
        date: day,
        startTimeRaw: '07:00:00',
        endTimeRaw: '08:00:00',
        bookingStatusRaw: 'Confirmed',
        paymentStatusRaw: 'Paid',
      ),
    ];
  }

  @override
  Future<Booking> fetchBooking(int id) async =>
      Booking(id: id, notes: 'A short note.');

  @override
  Future<Booking> createBooking(BookingDraft draft) async =>
      const Booking(id: 99);

  @override
  Future<Booking> updateBooking(int id, BookingDraft draft) async =>
      Booking(id: id);

  @override
  Future<void> deleteBooking(int id) async {}

  @override
  Future<List<Court>> fetchCourts({int? complexId, int? sportId}) async =>
      const [Court(id: 3, name: 'Court 1', sportId: 8, sportComplexId: 2)];

  @override
  Future<List<Sport>> fetchSports({bool refresh = false}) async =>
      const [Sport(id: 8, name: 'Badminton', sportComplexId: 2)];

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async => const [SportsComplex(id: 2, name: 'Kothrud Arena')];
}

class _FailingRepository extends _FakeRepository {
  @override
  Future<BookingPageResult> fetchBookings({
    BookingStatus? status,
    PaymentStatus? payment,
    BookingSource? source,
    int? sportId,
    int? courtId,
    int? complexId,
    DateTime? date,
    int page = 1,
    int limit = 20,
  }) async => throw const ServerException('The bookings service is down');
}
