import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/features/admin/data/models/event_pass_admin_model.dart';
import 'package:nahata_app/features/admin/data/repositories/event_pass_repository_impl.dart';
import 'package:nahata_app/features/admin/domain/entities/admin_role.dart';
import 'package:nahata_app/features/admin/domain/entities/event_pass.dart';
import 'package:nahata_app/features/admin/domain/repositories/event_pass_repository.dart';
import 'package:nahata_app/features/admin/presentation/state/event_passes_controller.dart';
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

EventPassSlot _slot({
  int? id,
  DateTime? date,
  String start = '10:00',
  String end = '13:00',
  num? price = 500,
  int? capacity = 100,
  String? name,
  String? status,
}) {
  return EventPassSlot(
    id: id,
    name: name,
    date: date ?? DateTime(2026, 9, 12),
    startTimeRaw: start,
    endTimeRaw: end,
    price: price,
    capacity: capacity,
    statusRaw: status,
  );
}

AdminEventPass _event({
  required int id,
  String? title,
  int? complexId,
  String? complexName,
  String status = 'Active',
  List<EventPassSlot>? slots,
}) {
  return AdminEventPass(
    id: id,
    title: title ?? 'Event $id',
    sportComplexId: complexId,
    sportComplexName: complexName,
    statusRaw: status,
    slots: slots ?? [_slot(date: DateTime(2026, 9, 12))],
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
  group('EventPassSlot', () {
    test('reads the documented HH:mm times and labels the window', () {
      final slot = _slot(start: '10:00', end: '13:00');
      expect(slot.startTime?.wire, '10:00');
      expect(slot.endTime?.wire, '13:00');
      expect(slot.windowLabel, '10:00 AM – 1:00 PM');
    });

    test('an unreadable time never fabricates a window', () {
      final slot = _slot(start: 'morning', end: 'evening');
      expect(slot.startTime, isNull);
      expect(slot.windowLabel, '—');
    });

    test('a slot with no status inherits the event rather than reading off', () {
      expect(_slot().isActive, isTrue);
      expect(_slot(status: 'Inactive').isActive, isFalse);
    });

    test('the display name falls back to the date, then to a placeholder', () {
      expect(_slot(name: ' Morning ').displayName, 'Morning');
      expect(_slot(date: DateTime(2026, 9, 12)).displayName, '12/9/2026');
      expect(
        const EventPassSlot().displayName,
        'Untitled slot',
      );
    });

    test('a dateless slot counts as upcoming rather than silently expired', () {
      final now = DateTime(2026, 9, 20);
      expect(const EventPassSlot().isUpcomingOn(now), isTrue);
      expect(_slot(date: DateTime(2026, 9, 20)).isUpcomingOn(now), isTrue);
      expect(_slot(date: DateTime(2026, 9, 19)).isUpcomingOn(now), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('AdminEventPass', () {
    test('capacity is null when not one slot declared it', () {
      // A zero here would claim a sold-out event the API never described.
      final event = _event(
        id: 1,
        slots: [_slot(capacity: null), _slot(capacity: null)],
      );
      expect(event.totalCapacity, isNull);

      final partial = _event(
        id: 2,
        slots: [_slot(capacity: 100), _slot(capacity: null)],
      );
      expect(partial.totalCapacity, 100);
    });

    test('the price range spans the slots that carry a price', () {
      final event = _event(
        id: 1,
        slots: [_slot(price: 500), _slot(price: 1500), _slot(price: null)],
      );
      expect(event.priceRange, (500, 1500));
      expect(_event(id: 2, slots: [_slot(price: null)]).priceRange, isNull);
    });

    test('the run of dates comes from the slots', () {
      final event = _event(
        id: 1,
        slots: [
          _slot(date: DateTime(2026, 9, 14)),
          _slot(date: DateTime(2026, 9, 12)),
          _slot(date: DateTime(2026, 9, 13)),
        ],
      );
      expect(event.firstDate, DateTime(2026, 9, 12));
      expect(event.lastDate, DateTime(2026, 9, 14));
    });

    test('an event whose every slot has run is finished, whatever its status',
        () {
      final now = DateTime(2026, 9, 20);
      final past = _event(
        id: 1,
        slots: [_slot(date: DateTime(2026, 9, 12))],
      );
      expect(past.isActive, isTrue);
      expect(past.hasFinished(now), isTrue);
      expect(past.upcomingSlotCount(now), 0);

      final ahead = _event(
        id: 2,
        slots: [
          _slot(date: DateTime(2026, 9, 12)),
          _slot(date: DateTime(2026, 9, 25)),
        ],
      );
      expect(ahead.hasFinished(now), isFalse);
      expect(ahead.upcomingSlotCount(now), 1);

      // No slots at all is "nothing scheduled", not "finished".
      expect(_event(id: 3, slots: const []).hasFinished(now), isFalse);
    });

    test('search matches the title and the venue', () {
      final event = _event(
        id: 1,
        title: 'Diwali Badminton Championship',
        complexName: 'Kothrud Arena',
      );
      expect(event.matches('badminton'), isTrue);
      expect(event.matches('KOTHRUD'), isTrue);
      expect(event.matches(''), isTrue);
      expect(event.matches('cricket'), isFalse);
    });

    test('a detail read fills the row in without dropping what it omits', () {
      final row = _event(id: 7, title: 'Diwali Cup', complexName: 'Kothrud');
      final detail = AdminEventPass(
        id: 7,
        description: 'A two day tournament.',
        slots: [_slot(id: 31), _slot(id: 32)],
        faqs: const [EventFaq(question: 'Parking?', answer: 'Yes.')],
      );

      final merged = row.mergedWith(detail);
      expect(merged.title, 'Diwali Cup');
      expect(merged.sportComplexName, 'Kothrud');
      expect(merged.description, 'A two day tournament.');
      expect(merged.slots.length, 2);
      expect(merged.faqs.single.question, 'Parking?');
    });

    test('initials and the title fall back for an untitled event', () {
      expect(const AdminEventPass(id: 1).displayTitle, 'Untitled event');
      expect(_event(id: 1, title: 'Diwali Cup').initials, 'DC');
      expect(_event(id: 2, title: 'Marathon').initials, 'M');
    });
  });

  // ---------------------------------------------------------------------------
  group('EventPassMapper', () {
    test('reads the shape the storefront model was written against', () {
      final event = EventPassMapper.fromJson({
        'id': 7,
        'title': 'Diwali Badminton Championship',
        'description': 'Annual tournament',
        'image': 'https://res.cloudinary.com/demo/image/upload/event.jpg',
        'sportComplexId': 2,
        'status': 'Active',
        'SportComplex': {'id': 2, 'name': 'Kothrud Arena'},
        'slots': [
          {
            'id': 31,
            'date': '2026-09-12',
            'startTime': '10:00',
            'endTime': '13:00',
            'price': '500.00',
            'capacity': 100,
          },
        ],
        'faqs': [
          {'question': 'Is parking available?', 'answer': 'Yes, free.'},
        ],
        'createdAt': '2026-08-01T10:00:00.000Z',
      });

      expect(event.id, 7);
      expect(event.title, 'Diwali Badminton Championship');
      expect(event.sportComplexId, 2);
      expect(event.sportComplexName, 'Kothrud Arena');
      expect(event.status, AdminUserStatus.active);
      expect(event.slots.single.id, 31);
      // The price is a decimal string on the way back and a number going out.
      expect(event.slots.single.price, 500);
      expect(event.slots.single.date, DateTime(2026, 9, 12));
      expect(event.faqs.single.answer, 'Yes, free.');
      expect(event.createdAt, isNotNull);
    });

    test('the snake_case and Sequelize spellings read the same', () {
      final event = EventPassMapper.fromJson({
        'data': {
          'id': 9,
          'name': 'Fun Run',
          'image_url': '/uploads/run.jpg',
          'sport_complex_id': 4,
          'EventPassSlots': [
            {
              'id': 44,
              'pass_date': '2026-10-01',
              'start_time': '06:00',
              'end_time': '09:00',
              'pass_price': 250,
              'maxCapacity': 500,
            },
          ],
        },
      });

      expect(event.id, 9);
      expect(event.title, 'Fun Run');
      expect(event.sportComplexId, 4);
      expect(event.slots.single.capacity, 500);
      expect(event.slots.single.startTime?.wire, '06:00');
    });

    test('rows without an id are dropped from the list', () {
      final events = EventPassMapper.listFrom({
        'data': [
          {'id': 1},
          {'title': 'no id'},
          {'id': 2},
        ],
      });
      expect(events.map((e) => e.id), [1, 2]);
    });

    test('the sibling pagination block this module alone uses is read', () {
      // Rows in `data`, counters in `pagination` — no other route in the
      // console splits them like this.
      final page = EventPassMapper.pageFrom(
        {
          'success': true,
          'data': [
            {'id': 1},
            {'id': 2},
          ],
          'pagination': {
            'currentPage': 2,
            'totalPages': 5,
            'totalItems': 47,
            'itemsPerPage': 10,
          },
        },
        requestedPage: 2,
        requestedLimit: 10,
      );

      expect(page.items.length, 2);
      expect(page.page, 2);
      expect(page.totalPages, 5);
      expect(page.totalItems, 47);
      expect(page.hasMore, isTrue);
    });

    test('a total with no page count still exposes the later pages', () {
      final page = EventPassMapper.pageFrom(
        {
          'data': [
            {'id': 1},
          ],
          'pagination': {'totalItems': 47, 'limit': 10},
        },
        requestedPage: 1,
        requestedLimit: 10,
      );
      expect(page.totalPages, 5);
    });

    test('a bare list degrades to one complete page', () {
      final page = EventPassMapper.pageFrom(
        [
          {'id': 1},
          {'id': 2},
        ],
        requestedPage: 1,
        requestedLimit: 20,
      );
      expect(page.totalItems, 2);
      expect(page.totalPages, 1);
      expect(page.hasMore, isFalse);
    });

    test('the upload route URL is found wherever it was put', () {
      expect(
        EventPassMapper.uploadedUrlFrom({'imageUrl': 'https://cdn/x.jpg'}),
        'https://cdn/x.jpg',
      );
      expect(
        EventPassMapper.uploadedUrlFrom({
          'data': {'secure_url': 'https://cdn/y.jpg'},
        }),
        'https://cdn/y.jpg',
      );
      expect(EventPassMapper.uploadedUrlFrom('https://cdn/z.jpg'),
          'https://cdn/z.jpg');
      expect(EventPassMapper.uploadedUrlFrom({'success': true}), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('EventBookingMapper', () {
    test('reads the booking with its event, slot and customer', () {
      final booking = EventBookingMapper.fromJson({
        'id': 12,
        'eventPassId': 7,
        'slotId': 31,
        'numberOfPasses': 2,
        'totalAmount': '1000.00',
        'couponCode': 'DIWALI10',
        'paymentStatus': 'Paid',
        'bookingStatus': 'Confirmed',
        'createdAt': '2026-08-02T08:00:00.000Z',
        'EventPass': {'id': 7, 'title': 'Diwali Cup'},
        'EventPassSlot': {'id': 31, 'name': 'Day 1', 'date': '2026-09-12'},
        'user': {
          'id': 585,
          'name': 'Rahul Sharma',
          'email': 'rahul@example.com',
          'phone_number': '9876543210',
        },
      });

      expect(booking.id, 12);
      expect(booking.eventPassId, 7);
      expect(booking.eventTitle, 'Diwali Cup');
      expect(booking.slotName, 'Day 1');
      expect(booking.userId, 585);
      expect(booking.customerName, 'Rahul Sharma');
      expect(booking.customerPhone, '9876543210');
      expect(booking.numberOfPasses, 2);
      expect(booking.totalAmount, 1000);
      expect(booking.couponCode, 'DIWALI10');
    });

    test('scanned-in is counted from the passes, and null when unreported', () {
      final counted = EventBookingMapper.fromJson({
        'id': 12,
        'individualPasses': [
          {'id': 1, 'scannedInCount': 1},
          {'id': 2, 'scannedInCount': 0},
          {'id': 3, 'scannedInCount': 2},
        ],
      });
      expect(counted.scannedInCount, 2);

      // "0 scanned" is a claim; a payload that never said must not make it.
      final silent = EventBookingMapper.fromJson({'id': 12});
      expect(silent.scannedInCount, isNull);
    });

    test('search matches the customer, the event, the contact and the id', () {
      final booking = EventBookingMapper.fromJson({
        'id': 12,
        'name': 'Rahul Sharma',
        'phone': '9876543210',
        'EventPass': {'id': 7, 'title': 'Diwali Cup'},
      });

      expect(booking.matches('rahul'), isTrue);
      expect(booking.matches('diwali'), isTrue);
      expect(booking.matches('98765'), isTrue);
      expect(booking.matches('12'), isTrue);
      expect(booking.matches('priya'), isFalse);
    });

    test('an event with no title still names itself by id', () {
      final booking = EventBookingMapper.fromJson({'id': 3, 'eventPassId': 7});
      expect(booking.displayEvent, 'Event #7');
      expect(const EventPassBookingRow(id: 3).displayEvent, '—');
      expect(booking.displayCustomer, 'Unnamed customer');
    });

    test('the list is found under the Sequelize association names too', () {
      // A list keyed `EventPassBookings` that this mapper could not read would
      // show as "No bookings found" — a different claim from an empty list.
      for (final key in const [
        'bookings',
        'eventBookings',
        'EventPassBookings',
        'rows',
      ]) {
        final rows = EventBookingMapper.listFrom({
          'success': true,
          'data': {
            key: [
              {'id': 1},
            ],
          },
        });
        expect(rows.single.id, 1, reason: 'key: $key');
      }
    });

    test('the bookings page reads the same envelope as the events page', () {
      final page = EventBookingMapper.pageFrom(
        {
          'data': [
            {'id': 1},
            {'id': 2},
          ],
          'pagination': {'currentPage': 1, 'totalPages': 3, 'totalItems': 25},
        },
        requestedPage: 1,
        requestedLimit: 10,
      );
      expect(page.items.length, 2);
      expect(page.totalPages, 3);
      expect(page.totalItems, 25);
    });
  });

  // ---------------------------------------------------------------------------
  group('EventPassDraft', () {
    test('the create payload sends the documented shape', () {
      final body = EventPassDraft(
        sportComplexId: 2,
        title: '  Diwali Badminton Championship ',
        description: 'Annual tournament',
        image: 'https://cdn/event.jpg',
        faqs: const [
          EventFaq(question: 'Parking?', answer: 'Yes.'),
          EventFaq(question: '  ', answer: '  '),
        ],
        slots: [
          EventPassSlot(
            date: DateTime(2026, 9, 12),
            startTimeRaw: '10:00',
            endTimeRaw: '13:00',
            price: 500,
            capacity: 100,
          ),
        ],
      ).toCreateJson();

      expect(body['sportComplexId'], 2);
      expect(body['title'], 'Diwali Badminton Championship');
      expect(body['status'], 'Active');
      expect(body['date'], isNull);

      final slots = body['slots'] as List;
      expect(slots.length, 1);
      final slot = slots.single as Map<String, dynamic>;
      expect(slot['date'], '2026-09-12');
      // `HH:mm` here — the bookings module stores `HH:mm:ss`.
      expect(slot['startTime'], '10:00');
      expect(slot['endTime'], '13:00');
      expect(slot['price'], 500);
      expect(slot['capacity'], 100);

      // A blank FAQ row is dropped rather than posted as two empty strings.
      expect((body['faqs'] as List).length, 1);
    });

    test('a 12-hour time still leaves as 24-hour', () {
      final body = EventPassDraft(
        slots: [
          EventPassSlot(
            date: DateTime(2026, 9, 12),
            startTimeRaw: '7:30 PM',
            endTimeRaw: '9 PM',
          ),
        ],
      ).toCreateJson();

      final slot = (body['slots'] as List).single as Map<String, dynamic>;
      expect(slot['startTime'], '19:30');
      expect(slot['endTime'], '21:00');
    });

    test('the update payload sends only what the form touched', () {
      final body = const EventPassDraft(
        title: 'Updated Event Title',
        status: AdminUserStatus.inactive,
      ).toUpdateJson();

      expect(body, {'title': 'Updated Event Title', 'status': 'Inactive'});
    });

    test('slots and FAQs are never replaced by an update', () {
      // Rewriting those arrays on an event with passes sold against its slots
      // is not something an unspecified route should be trusted with.
      final body = EventPassDraft(
        title: 'Renamed',
        slots: [_slot()],
        faqs: const [EventFaq(question: 'Q', answer: 'A')],
      ).toUpdateJson();

      expect(body.containsKey('slots'), isFalse);
      expect(body.containsKey('faqs'), isFalse);
    });

    test('an untouched draft has nothing to send', () {
      expect(const EventPassDraft().toUpdateJson(), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  group('EventBookingDraft', () {
    test('the booking payload matches the documented body', () {
      final body = const EventBookingDraft(
        eventPassId: 7,
        slotId: 31,
        name: ' Rahul Sharma ',
        email: 'rahul@example.com',
        phone: '9876543210',
        numberOfPasses: 2,
        couponCode: 'DIWALI10',
      ).toJson();

      expect(body, {
        'eventPassId': 7,
        'slotId': 31,
        'name': 'Rahul Sharma',
        'email': 'rahul@example.com',
        'phone': '9876543210',
        'numberOfPasses': 2,
        'couponCode': 'DIWALI10',
      });
    });

    test('an absent coupon is sent as null, as documented', () {
      final body = const EventBookingDraft(eventPassId: 7, slotId: 31).toJson();
      expect(body['couponCode'], isNull);
      expect(body.containsKey('couponCode'), isTrue);
      expect(body['numberOfPasses'], 1);
    });
  });

  // ---------------------------------------------------------------------------
  group('EventsSummary', () {
    test('counts the events, the active ones and those still to run', () {
      final now = DateTime(2026, 9, 20);
      final summary = EventsSummary.from(
        [
          _event(id: 1, slots: [_slot(date: DateTime(2026, 9, 25))]),
          _event(
            id: 2,
            status: 'Inactive',
            slots: [_slot(date: DateTime(2026, 9, 25))],
          ),
          _event(id: 3, slots: [_slot(date: DateTime(2026, 9, 12))]),
        ],
        now: now,
      );

      expect(summary.total, 3);
      expect(summary.active, 2);
      expect(summary.upcoming, 2);
      expect(summary.slots, 3);
      expect(summary.capacity, 300);
    });

    test('capacity stays null when no slot declared one', () {
      final summary = EventsSummary.from([
        _event(id: 1, slots: [_slot(capacity: null)]),
      ]);
      expect(summary.capacity, isNull);
    });

    test('the total can be the server figure rather than the rows in hand', () {
      final summary = EventsSummary.from([_event(id: 1)], total: 47);
      expect(summary.total, 47);
      expect(summary.slots, 1);
    });
  });

  // ---------------------------------------------------------------------------
  group('EventPassesController', () {
    test('the default read is one server page', () async {
      final repository = _FakeRepository(total: 47);
      final controller = EventPassesController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.isCatalogueMode, isFalse);
      expect(repository.pageCalls, 1);
      expect(controller.page.total, 47);
      expect(controller.summaryIsPageScoped, isTrue);
    });

    test('a filter pulls the catalogue, because one page is not enough',
        () async {
      // Filtering page one alone would make "no matches here" look like
      // "no matches at all".
      final repository = _FakeRepository();
      final controller = EventPassesController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      controller.setStatusFilter(AdminUserStatus.inactive);
      await Future<void>.delayed(Duration.zero);

      expect(controller.isCatalogueMode, isTrue);
      expect(repository.cataloguePages, isNotEmpty);
      expect(controller.summaryIsPageScoped, isFalse);
    });

    test('every filter is applied locally, whatever the route did', () async {
      final controller = EventPassesController(
        _FakeRepository(
          events: [
            _event(id: 1, complexId: 2),
            _event(id: 2, complexId: 2, status: 'Inactive'),
            _event(id: 3, complexId: 4),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.setStatusFilter(AdminUserStatus.active);
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.map((e) => e.id), [1, 3]);

      controller.setComplexFilter(2);
      expect(controller.visibleRows.single.id, 1);

      controller.setComplexFilter(9);
      expect(controller.visibleRows, isEmpty);
    });

    test('"still to run" hides the events whose slots have all passed',
        () async {
      final now = DateTime.now();
      final controller = EventPassesController(
        _FakeRepository(
          events: [
            _event(
              id: 1,
              slots: [_slot(date: now.add(const Duration(days: 10)))],
            ),
            _event(
              id: 2,
              slots: [_slot(date: now.subtract(const Duration(days: 10)))],
            ),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.setUpcomingOnly(true);
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.single.id, 1);
    });

    test('search matches the title and the venue after the debounce', () async {
      final controller = EventPassesController(
        _FakeRepository(
          events: [
            _event(id: 1, title: 'Diwali Cup', complexName: 'Kothrud Arena'),
            _event(id: 2, title: 'Fun Run', complexName: 'Baner Turf'),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.onSearchChanged('diwali');
      await Future<void>.delayed(EventPassesController.searchDebounce * 2);
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.single.id, 1);

      controller.onSearchChanged('baner');
      await Future<void>.delayed(EventPassesController.searchDebounce * 2);
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.single.id, 2);

      controller.clearSearch();
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.length, 2);
    });

    test('sorting cycles ascending, descending, then off', () async {
      final controller = EventPassesController(
        _FakeRepository(
          events: [
            _event(id: 1, title: 'Charlie'),
            _event(id: 2, title: 'alpha'),
            _event(id: 3, title: 'Bravo'),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.toggleSort(EventSort.title);
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.map((e) => e.id), [2, 3, 1]);

      controller.toggleSort(EventSort.title);
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.map((e) => e.id), [1, 3, 2]);

      controller.toggleSort(EventSort.title);
      await Future<void>.delayed(Duration.zero);
      expect(controller.sort, isNull);
    });

    test('sorting by a nullable column never dereferences a missing value',
        () async {
      final controller = EventPassesController(
        _FakeRepository(
          events: [
            _event(id: 1, slots: [_slot(date: DateTime(2026, 9, 20))]),
            _event(id: 2, slots: const []),
            _event(id: 3, slots: [_slot(date: DateTime(2026, 9, 10))]),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.toggleSort(EventSort.starts);
      await Future<void>.delayed(Duration.zero);
      // The dateless row sinks in both directions rather than floating to the
      // top when the order is reversed.
      expect(controller.visibleRows.map((e) => e.id), [3, 1, 2]);

      controller.toggleSort(EventSort.starts);
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.last.id, 2);
    });

    test('the catalogue is paged locally', () async {
      final controller = EventPassesController(
        _FakeRepository(
          events: [for (var i = 1; i <= 25; i++) _event(id: i)],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.setStatusFilter(AdminUserStatus.active);
      await Future<void>.delayed(Duration.zero);
      controller.setLimit(10);

      expect(controller.pageRows.length, 10);
      expect(controller.page.effectiveTotalPages, 3);

      controller.goToPage(3);
      expect(controller.pageRows.length, 5);
      expect(controller.pageRows.first.id, 21);
    });

    test('the catalogue walk stops at the cap rather than looping', () async {
      final repository = _FakeRepository(alwaysMore: true);
      final controller = EventPassesController(repository);
      addTearDown(controller.dispose);

      // The filter itself starts the catalogue walk; a server that always
      // claims another page must not spin this forever.
      controller.setStatusFilter(AdminUserStatus.active);
      while (controller.state.isLoading) {
        await Future<void>.delayed(Duration.zero);
      }

      expect(
        repository.cataloguePages,
        [for (var i = 1; i <= EventPassesController.catalogueMaxPages; i++) i],
      );
    });

    test('a failed load surfaces the server message', () async {
      final controller = EventPassesController(_FakeRepository(failList: true));
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.isFailed, isTrue);
      expect(controller.error, 'The events service is down');
    });

    test('the detail read merges over the row already on screen', () async {
      final controller = EventPassesController(
        _FakeRepository(
          events: [_event(id: 7, title: 'Diwali Cup')],
          detail: AdminEventPass(
            id: 7,
            description: 'Two days of badminton.',
            slots: [_slot(id: 31), _slot(id: 32)],
          ),
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      await controller.openEvent(controller.rows.single);

      expect(controller.detailState.isReady, isTrue);
      expect(controller.selected?.title, 'Diwali Cup');
      expect(controller.selected?.description, 'Two days of badminton.');
      expect(controller.selected?.slots.length, 2);

      controller.closeEvent();
      expect(controller.selected, isNull);
    });

    test('a status change is optimistic and reverts when refused', () async {
      final repository = _FakeRepository(
        events: [_event(id: 7)],
        failUpdate: true,
      );
      final controller = EventPassesController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      await expectLater(
        controller.setStatus(7, AdminUserStatus.inactive),
        throwsA(isA<ApiException>()),
      );

      // The row must not be left claiming a change the server refused.
      expect(controller.rows.single.status, AdminUserStatus.active);
      expect(controller.isRowBusy(7), isFalse);
    });

    test('a failed delete puts the row back', () async {
      final repository = _FakeRepository(
        events: [_event(id: 7), _event(id: 8)],
        failDelete: true,
      );
      final controller = EventPassesController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      await expectLater(
        controller.delete(7),
        throwsA(isA<ApiException>()),
      );
      expect(controller.rows.map((e) => e.id), [7, 8]);
    });

    test('a successful delete drops the row and reloads', () async {
      final repository = _FakeRepository(events: [_event(id: 7)]);
      final controller = EventPassesController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      await controller.delete(7);

      expect(repository.deleted, [7]);
      expect(repository.pageCalls, 2);
    });

    test('switching to the bookings view loads them once', () async {
      final repository = _FakeRepository();
      final controller = EventPassesController(repository);
      addTearDown(controller.dispose);

      controller.setView(EventsView.bookings);
      await Future<void>.delayed(Duration.zero);

      expect(controller.view, EventsView.bookings);
      expect(repository.bookingCalls, 1);

      controller.setView(EventsView.bookings);
      expect(repository.bookingCalls, 1);
    });

    test('bookings are searched locally and ordered newest first', () async {
      final controller = EventPassesController(
        _FakeRepository(
          bookings: [
            EventPassBookingRow(
              id: 1,
              customerName: 'Rahul Sharma',
              createdAt: DateTime(2026, 8, 1),
            ),
            EventPassBookingRow(
              id: 2,
              customerName: 'Priya Nair',
              createdAt: DateTime(2026, 8, 3),
            ),
            const EventPassBookingRow(id: 3, customerName: 'Amit Rao'),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.loadBookings();

      // The undated row sinks rather than posing as the newest.
      expect(controller.visibleBookings.map((b) => b.id), [2, 1, 3]);

      controller.onBookingSearchChanged('priya');
      expect(controller.visibleBookings.single.id, 2);
    });

    test('creating a booking refreshes the list only once it is on screen',
        () async {
      final repository = _FakeRepository();
      final controller = EventPassesController(repository);
      addTearDown(controller.dispose);

      await controller.createBooking(
        const EventBookingDraft(eventPassId: 7, slotId: 31),
      );
      expect(repository.bookingCalls, 0);

      await controller.loadBookings();
      await controller.createBooking(
        const EventBookingDraft(eventPassId: 7, slotId: 31),
      );
      expect(repository.bookingCalls, 2);
    });

    test('the venue list is fetched once unless a refresh is asked for',
        () async {
      final repository = _FakeRepository();
      final controller = EventPassesController(repository);
      addTearDown(controller.dispose);

      await controller.loadComplexes();
      await controller.loadComplexes();
      expect(repository.complexCalls, 1);

      await controller.loadComplexes(refresh: true);
      expect(repository.complexCalls, 2);
      expect(controller.complexById(2)?.name, 'Kothrud Arena');
    });
  });

  // ---------------------------------------------------------------------------
  group('EventPassRepositoryImpl — the wire', () {
    test('the list route sends paging', () async {
      late Uri captured;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      await EventPassRepositoryImpl().fetchEventPasses(page: 2, limit: 50);

      expect(captured.path, endsWith('/event-passes'));
      expect(captured.queryParameters['page'], '2');
      expect(captured.queryParameters['limit'], '50');
    });

    test('detail, update and delete all use the id route', () async {
      final calls = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'id': 7},
            }),
            200,
          );
        }),
      );

      final repository = EventPassRepositoryImpl();
      await repository.fetchEventPass(7);
      await repository.updateEventPass(
        7,
        const EventPassDraft(title: 'Updated Event Title'),
      );
      await repository.deleteEventPass(7);

      expect(calls[0], endsWith('GET /api/event-passes/7'));
      expect(calls[1], endsWith('PUT /api/event-passes/7'));
      expect(calls[2], endsWith('DELETE /api/event-passes/7'));
    });

    test('the booking routes are their own paths', () async {
      final paths = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': [
                {'id': 1},
              ],
            }),
            200,
          );
        }),
      );

      final repository = EventPassRepositoryImpl();
      await repository.fetchBookings(page: 1, limit: 20);
      await repository.fetchMyBookings();
      await repository.createBooking(
        const EventBookingDraft(
          eventPassId: 7,
          slotId: 31,
          name: 'Rahul',
          phone: '9876543210',
        ),
      );

      expect(paths[0], endsWith('/event-passes/bookings/all'));
      expect(paths[1], endsWith('/event-passes/bookings/my'));
      expect(paths[2], endsWith('/event-passes/bookings/create'));
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

      final repository = EventPassRepositoryImpl();
      final complete = EventPassSlot(
        date: DateTime(2026, 9, 12),
        startTimeRaw: '10:00',
        endTimeRaw: '13:00',
        price: 500,
        capacity: 100,
      );

      for (final draft in [
        const EventPassDraft(),
        const EventPassDraft(title: 'Diwali Cup'),
        // No slot at all: nothing to sell, and the storefront would render it
        // as permanently unavailable.
        const EventPassDraft(title: 'Diwali Cup', sportComplexId: 2),
        EventPassDraft(
          title: 'Diwali Cup',
          sportComplexId: 2,
          slots: [const EventPassSlot()],
        ),
        EventPassDraft(
          title: 'Diwali Cup',
          sportComplexId: 2,
          slots: [EventPassSlot(date: DateTime(2026, 9, 12))],
        ),
        EventPassDraft(
          title: 'Diwali Cup',
          sportComplexId: 2,
          slots: [
            EventPassSlot(
              date: DateTime(2026, 9, 12),
              startTimeRaw: '10:00',
              endTimeRaw: '13:00',
            ),
          ],
        ),
        EventPassDraft(
          title: 'Diwali Cup',
          sportComplexId: 2,
          slots: [
            EventPassSlot(
              date: DateTime(2026, 9, 12),
              startTimeRaw: '10:00',
              endTimeRaw: '13:00',
              price: 500,
            ),
          ],
        ),
      ]) {
        await expectLater(
          repository.createEventPass(draft),
          throwsA(isA<ValidationException>()),
        );
      }

      expect(called, isFalse);

      // The complete draft does go out.
      await repository.createEventPass(
        EventPassDraft(title: 'Diwali Cup', sportComplexId: 2, slots: [complete]),
      );
      expect(called, isTrue);
    });

    test('a booking is validated before the round trip too', () async {
      var called = false;
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          called = true;
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      final repository = EventPassRepositoryImpl();

      for (final draft in [
        const EventBookingDraft(),
        const EventBookingDraft(eventPassId: 7),
        const EventBookingDraft(eventPassId: 7, slotId: 31),
        const EventBookingDraft(eventPassId: 7, slotId: 31, name: 'Rahul'),
        const EventBookingDraft(
          eventPassId: 7,
          slotId: 31,
          name: 'Rahul',
          phone: '9876543210',
          numberOfPasses: 0,
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
        EventPassRepositoryImpl().updateEventPass(7, const EventPassDraft()),
        throwsA(isA<BadRequestException>()),
      );
      expect(called, isFalse);
    });

    test('the upload posts the documented field, and the URL comes back',
        () async {
      final file = File(
        '${Directory.systemTemp.createTempSync('event_upload').path}'
        '${Platform.pathSeparator}event.jpg',
      )..writeAsBytesSync(const [1, 2, 3]);
      addTearDown(() => file.parent.deleteSync(recursive: true));

      late String path;
      late String body;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          path = request.url.path;
          body = request.body;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'imageUrl': 'https://cdn/event.jpg'},
            }),
            200,
          );
        }),
      );

      final url = await EventPassRepositoryImpl().uploadImage(file.path);

      expect(path, endsWith('/event-passes/upload-image'));
      expect(body, contains('name="image"'));
      expect(url, 'https://cdn/event.jpg');
    });

    test('an upload that returns no URL is a failure, not a success', () async {
      final file = File(
        '${Directory.systemTemp.createTempSync('event_upload').path}'
        '${Platform.pathSeparator}event.jpg',
      )..writeAsBytesSync(const [1, 2, 3]);
      addTearDown(() => file.parent.deleteSync(recursive: true));

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          // The call succeeded, but there is nothing to put in the payload.
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      await expectLater(
        EventPassRepositoryImpl().uploadImage(file.path),
        throwsA(isA<ServerException>()),
      );
    });
  });
}

// -----------------------------------------------------------------------------
// Fakes
// -----------------------------------------------------------------------------

class _FakeRepository implements EventPassRepository {
  _FakeRepository({
    List<AdminEventPass>? events,
    List<EventPassBookingRow>? bookings,
    this.detail,
    this.total,
    this.alwaysMore = false,
    this.failList = false,
    this.failUpdate = false,
    this.failDelete = false,
  }) : events = events ?? [_event(id: 1), _event(id: 2)],
       bookings = bookings ?? const [EventPassBookingRow(id: 1)];

  final List<AdminEventPass> events;
  final List<EventPassBookingRow> bookings;
  final AdminEventPass? detail;
  final int? total;
  final bool alwaysMore;
  final bool failList;
  final bool failUpdate;
  final bool failDelete;

  int pageCalls = 0;
  int bookingCalls = 0;
  int complexCalls = 0;
  final List<int> cataloguePages = <int>[];
  final List<int> deleted = <int>[];

  @override
  Future<EventPassPageResult<AdminEventPass>> fetchEventPasses({
    int page = 1,
    int limit = 20,
  }) async {
    if (failList) throw const ServerException('The events service is down');

    if (limit == EventPassesController.cataloguePageSize) {
      cataloguePages.add(page);
      return EventPassPageResult<AdminEventPass>(
        items: page == 1 || alwaysMore ? events : const [],
        page: page,
        totalPages: alwaysMore ? 999 : 1,
        totalItems: total ?? events.length,
        perPage: limit,
      );
    }

    pageCalls++;
    return EventPassPageResult<AdminEventPass>(
      items: events,
      page: page,
      totalPages: total == null ? 1 : (total! / limit).ceil(),
      totalItems: total ?? events.length,
      perPage: limit,
    );
  }

  @override
  Future<AdminEventPass> fetchEventPass(int id) async =>
      detail ?? AdminEventPass(id: id);

  @override
  Future<AdminEventPass> createEventPass(EventPassDraft draft) async =>
      const AdminEventPass(id: 99);

  @override
  Future<AdminEventPass> updateEventPass(int id, EventPassDraft draft) async {
    if (failUpdate) throw const ServerException('Rejected');
    return AdminEventPass(id: id);
  }

  @override
  Future<void> deleteEventPass(int id) async {
    if (failDelete) throw const ServerException('Rejected');
    deleted.add(id);
  }

  @override
  Future<String> uploadImage(String filePath, {String? filename}) async =>
      'https://cdn/event.jpg';

  @override
  Future<EventPassPageResult<EventPassBookingRow>> fetchBookings({
    int page = 1,
    int limit = 20,
  }) async {
    bookingCalls++;
    return EventPassPageResult<EventPassBookingRow>(
      items: bookings,
      page: page,
      totalPages: 1,
      totalItems: bookings.length,
      perPage: limit,
    );
  }

  @override
  Future<List<EventPassBookingRow>> fetchMyBookings() async => bookings;

  @override
  Future<EventPassBookingRow> createBooking(EventBookingDraft draft) async =>
      const EventPassBookingRow(id: 99);

  @override
  Future<List<SportsComplex>> fetchSportComplexes({bool refresh = false}) async {
    complexCalls++;
    return const [
      SportsComplex(id: 2, name: 'Kothrud Arena'),
      SportsComplex(id: 4, name: 'Baner Turf'),
    ];
  }
}
