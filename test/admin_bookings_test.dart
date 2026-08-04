import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/features/admin/data/models/booking_model.dart';
import 'package:nahata_app/features/admin/data/repositories/booking_repository_impl.dart';
import 'package:nahata_app/features/admin/domain/entities/booking.dart';
import 'package:nahata_app/features/admin/domain/entities/court.dart';
import 'package:nahata_app/features/admin/domain/entities/court_slot.dart';
import 'package:nahata_app/features/admin/domain/entities/sport.dart';
import 'package:nahata_app/features/admin/domain/repositories/booking_repository.dart';
import 'package:nahata_app/features/admin/presentation/state/bookings_controller.dart';
import 'package:nahata_app/features/admin/presentation/state/view_state.dart';
import 'package:nahata_app/models/sports_complex_model.dart';

final Map<String, String> _secureStore = <String, String>{};

void _mockSecureStorage() {
  const channel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall call) async {
        final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
        final key = args['key'] as String?;
        switch (call.method) {
          case 'read':
            return _secureStore[key];
          case 'write':
            _secureStore[key!] = args['value'] as String;
            return null;
          case 'delete':
            _secureStore.remove(key);
            return null;
          case 'readAll':
            return Map<String, String>.from(_secureStore);
          default:
            return null;
        }
      });
}

Booking _booking({
  required int id,
  String? reference,
  String? customer,
  String? phone,
  int? courtId,
  String? courtName,
  int? sportId,
  String? sportName,
  int? complexId,
  DateTime? date,
  String start = '07:00:00',
  String end = '08:00:00',
  num? amount,
  String status = 'Confirmed',
  String payment = 'Paid',
  String? source,
}) {
  return Booking(
    id: id,
    reference: reference,
    customerName: customer,
    customerPhone: phone,
    courtId: courtId,
    courtName: courtName,
    sportId: sportId,
    sportName: sportName,
    sportComplexId: complexId,
    date: date ?? DateTime(2026, 8, 5),
    startTimeRaw: start,
    endTimeRaw: end,
    amount: amount,
    bookingStatusRaw: status,
    paymentStatusRaw: payment,
    bookingSourceRaw: source,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _secureStore.clear();
    _mockSecureStorage();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // ---------------------------------------------------------------------------
  group('Booking vocabularies', () {
    test('the slugs are the exact wire values', () {
      expect(BookingStatus.values.map((s) => s.slug), [
        'Confirmed',
        'Pending',
        'Cancelled',
        'Completed',
      ]);
      expect(PaymentStatus.values.map((p) => p.slug), [
        'Paid',
        'Pending',
        'Failed',
        'Refunded',
      ]);
      // The hyphen matters on the wire, even though reads ignore it.
      expect(BookingSource.walkIn.slug, 'Walk-in');
      expect(BookingSource.mobileApp.slug, 'Mobile App');
    });

    test('reads are case- and separator-insensitive', () {
      expect(BookingStatus.tryParse('confirmed'), BookingStatus.confirmed);
      expect(PaymentStatus.tryParse('REFUNDED'), PaymentStatus.refunded);
      expect(BookingSource.tryParse('walkin'), BookingSource.walkIn);
      expect(BookingSource.tryParse('WALK_IN'), BookingSource.walkIn);
      expect(BookingSource.tryParse('mobile app'), BookingSource.mobileApp);
      expect(BookingSource.tryParse(''), isNull);
    });

    test('a value outside a vocabulary still renders', () {
      expect(BookingStatus.labelFor('no_show'), 'No Show');
      expect(PaymentStatus.labelFor(null), '—');
    });
  });

  // ---------------------------------------------------------------------------
  group('Booking', () {
    test('parses the HH:mm:ss times live payloads use', () {
      final booking = _booking(id: 1, start: '07:00:00', end: '08:30:00');
      expect(booking.startTime?.wire, '07:00');
      expect(booking.windowLabel, '7:00 AM – 8:30 AM');
      expect(booking.durationMinutes, 90);
      expect(booking.durationLabel, '1 hr 30 min');
    });

    test('an unreadable time never fabricates a window', () {
      final booking = _booking(id: 1, start: 'soon', end: 'later');
      expect(booking.startTime, isNull);
      expect(booking.windowLabel, '—');
      expect(booking.durationLabel, '—');
    });

    test('the reference falls back to the id, which URLs use', () {
      expect(_booking(id: 7).displayReference, '#7');
      expect(
        _booking(id: 7, reference: 'BOOK-2026-000071').displayReference,
        'BOOK-2026-000071',
      );
    });

    test('search matches the reference, the id, the name and the phone', () {
      final booking = _booking(
        id: 71,
        reference: 'BOOK-2026-000071',
        customer: 'Rahul Sharma',
        phone: '9876543210',
      );

      expect(booking.matches('000071'), isTrue);
      expect(booking.matches('71'), isTrue);
      expect(booking.matches('rahul'), isTrue);
      expect(booking.matches('98765'), isTrue);
      expect(booking.matches('amit'), isFalse);
    });

    test('phaseAt separates upcoming, ongoing and finished', () {
      final today = DateTime(2026, 8, 5);
      final booking = _booking(
        id: 1,
        date: today,
        start: '10:00:00',
        end: '11:00:00',
      );

      expect(
        booking.phaseAt(DateTime(2026, 8, 5, 9)),
        BookingPhase.upcoming,
      );
      expect(
        booking.phaseAt(DateTime(2026, 8, 5, 10, 30)),
        BookingPhase.ongoing,
      );
      expect(
        booking.phaseAt(DateTime(2026, 8, 5, 12)),
        BookingPhase.finished,
      );
      // A different day is judged by the date, not the clock.
      expect(
        booking.phaseAt(DateTime(2026, 8, 4, 23)),
        BookingPhase.upcoming,
      );
      expect(
        booking.phaseAt(DateTime(2026, 8, 6, 1)),
        BookingPhase.finished,
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('Booking.clashesWith', () {
    test('the same court at an overlapping time clashes', () {
      final first = _booking(id: 1, courtId: 3, start: '08:00:00', end: '09:00:00');
      final second = _booking(id: 2, courtId: 3, start: '08:30:00', end: '09:30:00');
      expect(first.clashesWith(second), isTrue);
    });

    test('back-to-back bookings do not clash', () {
      // 08–09 and 09–10 is exactly how an hourly schedule is built.
      final first = _booking(id: 1, courtId: 3, start: '08:00:00', end: '09:00:00');
      final second = _booking(id: 2, courtId: 3, start: '09:00:00', end: '10:00:00');
      expect(first.clashesWith(second), isFalse);
    });

    test('a different court or a different day never clashes', () {
      final base = _booking(id: 1, courtId: 3);
      expect(base.clashesWith(_booking(id: 2, courtId: 4)), isFalse);
      expect(
        base.clashesWith(
          _booking(id: 3, courtId: 3, date: DateTime(2026, 8, 6)),
        ),
        isFalse,
      );
    });

    test('a cancelled booking frees the court', () {
      final live = _booking(id: 1, courtId: 3);
      final cancelled = _booking(id: 2, courtId: 3, status: 'Cancelled');
      expect(live.clashesWith(cancelled), isFalse);
      expect(cancelled.clashesWith(live), isFalse);
    });

    test('a booking with no court cannot be judged', () {
      expect(_booking(id: 1).clashesWith(_booking(id: 2, courtId: 3)), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('BookingMapper', () {
    test('parses a record shaped like the live payload', () {
      final booking = BookingMapper.fromJson({
        'id': 71,
        'passCode': 'BOOK-2026-000071',
        'date': '2026-08-05',
        'startTime': '19:00:00',
        'endTime': '20:00:00',
        'bookingStatus': 'Confirmed',
        'paymentStatus': 'Paid',
        'totalAmount': '800.00',
        'bookingSource': 'Mobile App',
        'transactionId': 'pay_123',
        'notes': 'Bring rackets',
        'createdAt': '2026-08-01T10:00:00.000Z',
        'User': {
          'id': 585,
          'name': 'Rahul Sharma',
          'email': 'rahul@example.com',
          'phone_number': '9876543210',
        },
        'Court': {
          'id': 3,
          'name': 'Court 1',
          'sportComplexId': 2,
          'SportComplex': {'id': 2, 'name': 'Kothrud Arena'},
        },
        'Sport': {'id': 8, 'name': 'Badminton'},
      });

      expect(booking.id, 71);
      expect(booking.reference, 'BOOK-2026-000071');
      expect(booking.customerName, 'Rahul Sharma');
      expect(booking.customerPhone, '9876543210');
      expect(booking.customerEmail, 'rahul@example.com');
      expect(booking.userId, 585);
      expect(booking.courtId, 3);
      expect(booking.courtName, 'Court 1');
      expect(booking.sportId, 8);
      expect(booking.sportName, 'Badminton');
      // The complex is nested inside the court on this shape.
      expect(booking.sportComplexId, 2);
      expect(booking.sportComplexName, 'Kothrud Arena');
      expect(booking.date, DateTime.parse('2026-08-05'));
      expect(booking.startTime?.wire, '19:00');
      expect(booking.amount, 800);
      expect(booking.status, BookingStatus.confirmed);
      expect(booking.payment, PaymentStatus.paid);
      expect(booking.source, BookingSource.mobileApp);
    });

    test('reads snake_case and flat customer keys', () {
      final booking = BookingMapper.fromJson({
        'booking': {
          '_id': 9,
          'customerName': 'Amit',
          'phone': '9000000000',
          'court_id': 4,
          'sport_id': 2,
          'booking_status': 'Pending',
          'payment_status': 'Failed',
          'start_time': '06:00',
          'total_amount': 500,
        },
      });

      expect(booking.id, 9);
      expect(booking.customerName, 'Amit');
      expect(booking.customerPhone, '9000000000');
      expect(booking.courtId, 4);
      expect(booking.status, BookingStatus.pending);
      expect(booking.payment, PaymentStatus.failed);
      expect(booking.startTime?.wire, '06:00');
      expect(booking.amount, 500);
    });

    test('rows without an id are dropped from the list', () {
      final bookings = BookingMapper.listFrom({
        'bookings': [
          {'id': 1},
          {'passCode': 'no id'},
          {'id': 2},
        ],
      });
      expect(bookings.map((b) => b.id), [1, 2]);
    });

    test('the pagination envelope is read, and derived when partial', () {
      final full = BookingMapper.pageFrom(
        {
          'bookings': [
            {'id': 1},
          ],
          'currentPage': 2,
          'totalPages': 5,
          'totalItems': 47,
          'itemsPerPage': 10,
        },
        requestedPage: 2,
        requestedLimit: 10,
      );
      expect(full.page, 2);
      expect(full.totalPages, 5);
      expect(full.hasMore, isTrue);

      // A total with no page count must not hide every page after the first.
      final derived = BookingMapper.pageFrom(
        {
          'bookings': [
            {'id': 1},
          ],
          'totalItems': 47,
          'itemsPerPage': 10,
        },
        requestedPage: 1,
        requestedLimit: 10,
      );
      expect(derived.totalPages, 5);

      final bare = BookingMapper.pageFrom(
        [
          {'id': 1},
          {'id': 2},
        ],
        requestedPage: 1,
        requestedLimit: 20,
      );
      expect(bare.totalItems, 2);
      expect(bare.totalPages, 1);
    });
  });

  // ---------------------------------------------------------------------------
  group('BookingStatsMapper', () {
    test('reads the counters and the growth figure', () {
      final stats = BookingStatsMapper.fromJson({
        'data': {
          'totalBookings': 420,
          'todayBookings': 12,
          'confirmedBookings': 300,
          'pendingBookings': 60,
          'cancelledBookings': 40,
          'completedBookings': 20,
          'totalRevenue': '336000.00',
          'paidBookings': 310,
          'unpaidBookings': 110,
          'growth': 12.5,
        },
      });

      expect(stats.total, 420);
      expect(stats.today, 12);
      expect(stats.revenue, 336000);
      expect(stats.growthPercent, 12.5);
      expect(stats.isEmpty, isFalse);
    });

    test('a series is read from a list of objects or from a map', () {
      final fromList = BookingStatsMapper.fromJson({
        'daily': [
          {'date': '2026-08-01', 'count': 4},
          {'date': '2026-08-02', 'count': 7},
        ],
      });
      expect(fromList.daily.map((p) => p.label), ['2026-08-01', '2026-08-02']);
      expect(fromList.daily.map((p) => p.value), [4, 7]);

      final fromMap = BookingStatsMapper.fromJson({
        'peakHours': {'07': 3, '18': 9},
      });
      expect(fromMap.peakHours.length, 2);
    });

    test('a missing series is empty, so the chart is simply not drawn', () {
      // An axis of zeroes reads as "no bookings", which is a different claim
      // from "the endpoint did not send this".
      final stats = BookingStatsMapper.fromJson({'totalBookings': 5});
      expect(stats.daily, isEmpty);
      expect(stats.topSports, isEmpty);
      expect(stats.hasCharts, isFalse);
    });

    test('an empty payload yields an empty stats object', () {
      expect(BookingStatsMapper.fromJson(const {}).isEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('BookingDraft', () {
    test('the create payload sends the API date and time formats', () {
      final body = BookingDraft(
        userId: 585,
        sportId: 8,
        courtId: 3,
        date: DateTime(2026, 8, 5),
        startTime: SlotTime.parse('7:00 PM'),
        endTime: SlotTime.parse('8:00 PM'),
        amount: 800,
        source: BookingSource.walkIn,
        status: BookingStatus.confirmed,
        payment: PaymentStatus.paid,
      ).toCreateJson();

      expect(body['userId'], 585);
      expect(body['date'], '2026-08-05');
      // Bookings store HH:mm:ss, unlike the slots module's HH:mm.
      expect(body['startTime'], '19:00:00');
      expect(body['endTime'], '20:00:00');
      expect(body['bookingSource'], 'Walk-in');
      expect(body['bookingStatus'], 'Confirmed');
      expect(body['paymentStatus'], 'Paid');
    });

    test('create defaults to Admin / Confirmed / Pending', () {
      final body = const BookingDraft(userId: 1).toCreateJson();
      expect(body['bookingSource'], 'Admin');
      expect(body['bookingStatus'], 'Confirmed');
      expect(body['paymentStatus'], 'Pending');
    });

    test('the update payload sends only the editable fields', () {
      final body = BookingDraft(
        date: DateTime(2026, 8, 6),
        startTime: SlotTime.parse('09:00'),
        endTime: SlotTime.parse('10:00'),
        status: BookingStatus.completed,
        payment: PaymentStatus.paid,
        notes: 'Done',
        // None of these is documented as editable.
        userId: 9,
        sportId: 9,
        courtId: 9,
        amount: 999,
        source: BookingSource.website,
      ).toUpdateJson();

      expect(body.keys.toSet(), {
        'date',
        'startTime',
        'endTime',
        'bookingStatus',
        'paymentStatus',
        'notes',
      });
      expect(body.containsKey('userId'), isFalse);
      expect(body.containsKey('courtId'), isFalse);
      expect(body.containsKey('totalAmount'), isFalse);
    });

    test('an update omits what was not touched but keeps a cleared note', () {
      expect(
        const BookingDraft(status: BookingStatus.cancelled).toUpdateJson(),
        {'bookingStatus': 'Cancelled'},
      );
      // A note cleared on purpose has to reach the server.
      expect(const BookingDraft(notes: '').toUpdateJson(), {'notes': ''});
      expect(const BookingDraft().toUpdateJson(), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  group('BookingsSummary', () {
    test('counts each status and payment bucket', () {
      final summary = BookingsSummary.from([
        _booking(id: 1, amount: 800),
        _booking(id: 2, status: 'Pending', payment: 'Pending', amount: 600),
        _booking(id: 3, status: 'Cancelled', payment: 'Refunded', amount: 500),
        _booking(id: 4, status: 'Completed', amount: 400),
      ]);

      expect(summary.total, 4);
      expect(summary.confirmed, 1);
      expect(summary.pending, 1);
      expect(summary.cancelled, 1);
      expect(summary.completed, 1);
      expect(summary.paid, 2);
      expect(summary.unpaid, 2);
      // The cancelled booking's amount is excluded — counting refunded money
      // as revenue would overstate the take.
      expect(summary.revenue, 1800);
    });

    test('revenue stays null when no row carried an amount', () {
      final summary = BookingsSummary.from([_booking(id: 1), _booking(id: 2)]);
      expect(summary.revenue, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('BookingsController', () {
    test('the default read is one server page', () async {
      final repository = _FakeRepository(total: 47);
      final controller = BookingsController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.isCatalogueMode, isFalse);
      expect(repository.pageCalls, 1);
      expect(controller.page.total, 47);
      expect(controller.page.effectiveTotalPages, 3);
    });

    test('any filter pulls the catalogue, because one page is not enough',
        () async {
      // Filtering one page at a time would make "no matches on page one"
      // indistinguishable from "no matches".
      final repository = _FakeRepository();
      final controller = BookingsController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      controller.setStatusFilter(BookingStatus.pending);
      await Future<void>.delayed(Duration.zero);

      expect(controller.isCatalogueMode, isTrue);
      expect(repository.catalogueCalls, 1);
    });

    test('every filter is re-applied locally, whatever the server did',
        () async {
      // The fake ignores the parameters entirely, as an undocumented route may.
      final controller = BookingsController(
        _FakeRepository(
          bookings: [
            _booking(id: 1, status: 'Confirmed', payment: 'Paid', courtId: 3),
            _booking(id: 2, status: 'Pending', payment: 'Paid', courtId: 3),
            _booking(id: 3, status: 'Confirmed', payment: 'Pending', courtId: 4),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.setStatusFilter(BookingStatus.confirmed);
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.map((b) => b.id), [1, 3]);

      controller.setPaymentFilter(PaymentStatus.paid);
      expect(controller.visibleRows.map((b) => b.id), [1]);

      controller.setCourtFilter(4);
      expect(controller.visibleRows, isEmpty);
    });

    test('the date filter matches the calendar day', () async {
      final controller = BookingsController(
        _FakeRepository(
          bookings: [
            _booking(id: 1, date: DateTime(2026, 8, 5)),
            _booking(id: 2, date: DateTime(2026, 8, 6)),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.setDateFilter(DateTime(2026, 8, 6, 13, 45));
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.single.id, 2);
    });

    test('search matches across the three documented fields', () async {
      final controller = BookingsController(
        _FakeRepository(
          bookings: [
            _booking(id: 1, customer: 'Rahul', phone: '9111'),
            _booking(id: 2, reference: 'BOOK-2026-000002'),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.onSearchChanged('rahul');
      await Future<void>.delayed(BookingsController.searchDebounce * 2);
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.single.id, 1);

      controller.onSearchChanged('000002');
      await Future<void>.delayed(BookingsController.searchDebounce * 2);
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.single.id, 2);
    });

    test('sorting by date orders the day then the slot', () async {
      final controller = BookingsController(
        _FakeRepository(
          bookings: [
            _booking(id: 1, date: DateTime(2026, 8, 5), start: '18:00:00'),
            _booking(id: 2, date: DateTime(2026, 8, 5), start: '07:00:00'),
            _booking(id: 3, date: DateTime(2026, 8, 4), start: '12:00:00'),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.toggleSort(BookingSort.date);
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.map((b) => b.id), [3, 2, 1]);
    });

    test('sorting by a nullable column never dereferences a missing value',
        () async {
      final controller = BookingsController(
        _FakeRepository(
          bookings: [
            _booking(id: 1, amount: 800),
            const Booking(id: 2),
            _booking(id: 3, amount: 400),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.toggleSort(BookingSort.amount);
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.map((b) => b.id), [3, 1, 2]);

      controller.toggleSort(BookingSort.date);
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.last.id, 2);
    });

    test("today's board splits into the three phases", () async {
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);

      final controller = BookingsController(
        _FakeRepository(
          current: [
            _booking(id: 1, date: day, start: '00:00:00', end: '00:30:00'),
            _booking(id: 2, date: day, start: '23:00:00', end: '23:59:00'),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.loadCurrent();

      final noon = DateTime(day.year, day.month, day.day, 12);
      expect(
        controller.currentIn(BookingPhase.finished, now: noon).single.id,
        1,
      );
      expect(
        controller.currentIn(BookingPhase.upcoming, now: noon).single.id,
        2,
      );
      expect(controller.currentIn(BookingPhase.ongoing, now: noon), isEmpty);
      expect(controller.orderedCurrent().map((b) => b.id), [1, 2]);
    });

    test('the calendar reads from the rows in hand', () async {
      final controller = BookingsController(
        _FakeRepository(
          bookings: [
            _booking(id: 1, date: DateTime(2026, 8, 5)),
            _booking(id: 2, date: DateTime(2026, 8, 5)),
            _booking(id: 3, date: DateTime(2026, 8, 6)),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      expect(controller.bookingsOn(DateTime(2026, 8, 5)).length, 2);
      expect(controller.bookingsOn(DateTime(2026, 8, 7)), isEmpty);

      controller.goToMonth(DateTime(2026, 9));
      expect(controller.calendarMonth, DateTime(2026, 9));
      controller.previousMonth();
      expect(controller.calendarMonth, DateTime(2026, 8));
    });

    test('clashesWith finds a double booking and ignores the edited row',
        () async {
      final controller = BookingsController(
        _FakeRepository(
          bookings: [
            _booking(
              id: 1,
              courtId: 3,
              date: DateTime(2026, 8, 5),
              start: '08:00:00',
              end: '09:00:00',
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      final draft = BookingDraft(
        courtId: 3,
        date: DateTime(2026, 8, 5),
        startTime: SlotTime.parse('08:30'),
        endTime: SlotTime.parse('09:30'),
      );

      expect(controller.clashesWith(draft).single.id, 1);
      expect(controller.clashesWith(draft, ignoreId: 1), isEmpty);
    });

    test('a status change is optimistic and reverts on failure', () async {
      final controller = BookingsController(
        _FakeRepository(failUpdate: true),
      );
      addTearDown(controller.dispose);
      await controller.load();

      await expectLater(
        controller.setStatus(1, BookingStatus.cancelled),
        throwsA(isA<Exception>()),
      );

      expect(controller.rows.first.status, BookingStatus.confirmed);
      expect(controller.isRowBusy(1), isFalse);
    });

    test('a delete is optimistic and restores the row when it fails', () async {
      final controller = BookingsController(
        _FakeRepository(failDelete: true),
      );
      addTearDown(controller.dispose);
      await controller.load();

      final before = controller.rows.length;
      await expectLater(controller.delete(1), throwsA(isA<Exception>()));
      expect(controller.rows.length, before);
    });

    test('a load failure surfaces the server message', () async {
      final controller = BookingsController(_FakeRepository(failList: true));
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.isFailed, isTrue);
      expect(controller.error, 'Bookings are unavailable');
    });

    test('a stats failure does not fail the list', () async {
      final controller = BookingsController(_FakeRepository(failStats: true));
      addTearDown(controller.dispose);

      await controller.load();
      await controller.loadStats();

      expect(controller.state.isReady, isTrue);
      expect(controller.statsState.isFailed, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('BookingRepositoryImpl — the wire', () {
    test('the list route sends the filters it has, and paging', () async {
      late Uri captured;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      await BookingRepositoryImpl().fetchBookings(
        status: BookingStatus.confirmed,
        payment: PaymentStatus.paid,
        source: BookingSource.walkIn,
        sportId: 8,
        courtId: 3,
        complexId: 2,
        date: DateTime(2026, 8, 5),
        page: 2,
        limit: 50,
      );

      expect(captured.path, endsWith('/bookings'));
      expect(captured.queryParameters['bookingStatus'], 'Confirmed');
      expect(captured.queryParameters['paymentStatus'], 'Paid');
      expect(captured.queryParameters['bookingSource'], 'Walk-in');
      expect(captured.queryParameters['date'], '2026-08-05');
      expect(captured.queryParameters['page'], '2');
      expect(captured.queryParameters['limit'], '50');
    });

    test('an unset filter is never sent as an empty parameter', () async {
      late Uri captured;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      await BookingRepositoryImpl().fetchBookings();

      expect(captured.queryParameters.containsKey('bookingStatus'), isFalse);
      expect(captured.queryParameters.containsKey('date'), isFalse);
    });

    test('the stats and current routes are their own paths', () async {
      final paths = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      final repository = BookingRepositoryImpl();
      await repository.fetchStats();
      await repository.fetchCurrent();

      expect(paths[0], endsWith('/bookings/stats'));
      expect(paths[1], endsWith('/bookings/current'));
    });

    test('fetchAllBookings walks the pages and stops at the cap', () async {
      final pages = <int>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          final page = int.parse(request.url.queryParameters['page']!);
          pages.add(page);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'bookings': [
                  {'id': page},
                ],
                'currentPage': page,
                'totalPages': 99,
                'totalItems': 990,
                'itemsPerPage': 10,
              },
            }),
            200,
          );
        }),
      );

      (int, int)? capped;
      final all = await BookingRepositoryImpl().fetchAllBookings(
        limit: 10,
        maxPages: 3,
        onCapped: (loaded, total) => capped = (loaded, total),
      );

      expect(pages, [1, 2, 3]);
      expect(all.length, 3);
      expect(capped, (3, 990));
    });

    test('update and delete use the id route', () async {
      final calls = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      final repository = BookingRepositoryImpl();
      await repository.updateBooking(
        71,
        const BookingDraft(status: BookingStatus.completed),
      );
      await repository.deleteBooking(71);

      expect(calls[0], endsWith('PUT /api/bookings/71'));
      expect(calls[1], endsWith('DELETE /api/bookings/71'));
    });

    test('create validates every required field before the round trip',
        () async {
      var called = false;
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          called = true;
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      final repository = BookingRepositoryImpl();

      for (final draft in [
        const BookingDraft(),
        const BookingDraft(userId: 1),
        const BookingDraft(userId: 1, sportId: 1),
        const BookingDraft(userId: 1, sportId: 1, courtId: 1),
        BookingDraft(
          userId: 1,
          sportId: 1,
          courtId: 1,
          date: DateTime(2026, 8, 5),
        ),
      ]) {
        await expectLater(
          repository.createBooking(draft),
          throwsA(isA<ValidationException>()),
        );
      }

      expect(called, isFalse);
    });

    test('an update with nothing in it is refused rather than sent', () async {
      var called = false;
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          called = true;
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      await expectLater(
        BookingRepositoryImpl().updateBooking(1, const BookingDraft()),
        throwsA(isA<BadRequestException>()),
      );
      expect(called, isFalse);
    });
  });
}

// -----------------------------------------------------------------------------
// Fakes
// -----------------------------------------------------------------------------

class _FakeRepository implements BookingRepository {
  _FakeRepository({
    List<Booking>? bookings,
    List<Booking>? current,
    this.total,
    this.failList = false,
    this.failStats = false,
    this.failUpdate = false,
    this.failDelete = false,
  }) : bookings = bookings ?? [_booking(id: 1), _booking(id: 2)],
       current = current ?? const [];

  final List<Booking> bookings;
  final List<Booking> current;
  final int? total;
  final bool failList;
  final bool failStats;
  final bool failUpdate;
  final bool failDelete;

  int pageCalls = 0;
  int catalogueCalls = 0;

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
  }) async {
    pageCalls++;
    if (failList) throw const ServerException('Bookings are unavailable');

    final totalItems = total ?? bookings.length;
    return BookingPageResult(
      bookings: bookings,
      page: page,
      totalPages: (totalItems / limit).ceil().clamp(1, 999),
      totalItems: totalItems,
      perPage: limit,
    );
  }

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
  }) async {
    catalogueCalls++;
    if (failList) throw const ServerException('Bookings are unavailable');
    // Deliberately ignores every parameter, as an undocumented route may.
    return bookings;
  }

  @override
  Future<BookingStats> fetchStats() async {
    if (failStats) throw const ServerException('No stats');
    return const BookingStats(total: 420, today: 12, revenue: 336000);
  }

  @override
  Future<List<Booking>> fetchCurrent() async => current;

  @override
  Future<Booking> fetchBooking(int id) async => Booking(id: id, notes: 'Detail');

  @override
  Future<Booking> createBooking(BookingDraft draft) async =>
      const Booking(id: 99);

  @override
  Future<Booking> updateBooking(int id, BookingDraft draft) async {
    if (failUpdate) throw const ServerException('Rejected');
    return Booking(id: id);
  }

  @override
  Future<void> deleteBooking(int id) async {
    if (failDelete) throw const ServerException('Rejected');
  }

  @override
  Future<List<Court>> fetchCourts({int? complexId, int? sportId}) async =>
      const [Court(id: 3, name: 'Court 1', sportId: 8)];

  @override
  Future<List<Sport>> fetchSports({bool refresh = false}) async =>
      const [Sport(id: 8, name: 'Badminton')];

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async => const [SportsComplex(id: 2, name: 'Kothrud Arena')];
}
