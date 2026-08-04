import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/features/admin/data/models/court_model.dart';
import 'package:nahata_app/features/admin/data/models/court_slot_model.dart';
import 'package:nahata_app/features/admin/data/repositories/court_repository_impl.dart';
import 'package:nahata_app/features/admin/data/repositories/court_slot_repository_impl.dart';
import 'package:nahata_app/features/admin/domain/entities/admin_role.dart';
import 'package:nahata_app/features/admin/domain/entities/coach.dart';
import 'package:nahata_app/features/admin/domain/entities/court.dart';
import 'package:nahata_app/features/admin/domain/entities/court_slot.dart';
import 'package:nahata_app/features/admin/domain/entities/sport.dart';
import 'package:nahata_app/features/admin/domain/repositories/court_repository.dart';
import 'package:nahata_app/features/admin/domain/repositories/court_slot_repository.dart';
import 'package:nahata_app/features/admin/presentation/state/court_slots_controller.dart';
import 'package:nahata_app/features/admin/presentation/state/courts_controller.dart';
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

Court _court({
  required int id,
  String? name,
  int? sportId,
  String? sportName,
  int? complexId,
  String? complexName,
  String? surface,
  int? capacity,
  num? rate,
  bool? lighting,
  bool? showOnFrontend,
  int? slotCount,
  int? availableSlots,
  String status = 'Active',
}) {
  return Court(
    id: id,
    name: name ?? 'Court $id',
    sportId: sportId,
    sportName: sportName,
    sportComplexId: complexId,
    sportComplexName: complexName,
    surfaceType: surface,
    capacity: capacity,
    hourlyRate: rate,
    lightingAvailable: lighting,
    showOnFrontend: showOnFrontend,
    slotCount: slotCount,
    availableSlotCount: availableSlots,
    statusRaw: status,
  );
}

CourtSlot _slot({
  required int id,
  String start = '07:00',
  String end = '08:00',
  String? days = 'Monday, Wednesday',
  String type = 'Regular',
  num? price,
  String status = 'Active',
}) {
  return CourtSlot(
    id: id,
    courtId: 1,
    startTimeRaw: start,
    endTimeRaw: end,
    availableDaysRaw: days,
    slotTypeRaw: type,
    priceOverride: price,
    statusRaw: status,
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
  group('SlotTime', () {
    test('parses every shape the API has been seen using', () {
      expect(SlotTime.parse('07:00')?.wire, '07:00');
      expect(SlotTime.parse('07:00:00')?.wire, '07:00');
      expect(SlotTime.parse('7:30 PM')?.wire, '19:30');
      expect(SlotTime.parse('7 AM')?.wire, '07:00');
      expect(SlotTime.parse('12:00 AM')?.wire, '00:00');
      expect(SlotTime.parse('12:00 PM')?.wire, '12:00');
    });

    test('refuses nonsense rather than guessing a time', () {
      for (final value in const [null, '', 'soon', '25:00', '07:99', 'abc']) {
        expect(SlotTime.parse(value), isNull, reason: '$value');
      }
    });

    test('labels in 12-hour form', () {
      expect(SlotTime.parse('00:00')!.label, '12:00 AM');
      expect(SlotTime.parse('12:00')!.label, '12:00 PM');
      expect(SlotTime.parse('19:05')!.label, '7:05 PM');
    });

    test('adding an hour wraps past midnight', () {
      expect(SlotTime.parse('23:30')!.plusMinutes(60).wire, '00:30');
    });

    test('minutesUntil counts a wrap as forward, not negative', () {
      expect(SlotTime.parse('07:00')!.minutesUntil(SlotTime.parse('08:00')!),
          60);
      // 23:30 → 00:30 is an hour later, not 23 hours earlier.
      expect(SlotTime.parse('23:30')!.minutesUntil(SlotTime.parse('00:30')!),
          60);
    });
  });

  // ---------------------------------------------------------------------------
  group('CourtSlotDraft.validateWindow', () {
    test('accepts exactly one hour and nothing else', () {
      expect(
        CourtSlotDraft.validateWindow(
          SlotTime.parse('07:00'),
          SlotTime.parse('08:00'),
        ),
        isNull,
      );

      // The spec's rule, enforced before a round trip is spent.
      expect(
        CourtSlotDraft.validateWindow(
          SlotTime.parse('07:00'),
          SlotTime.parse('09:00'),
        ),
        contains('exactly one hour'),
      );
      expect(
        CourtSlotDraft.validateWindow(
          SlotTime.parse('07:00'),
          SlotTime.parse('07:30'),
        ),
        contains('30 min'),
      );
      expect(
        CourtSlotDraft.validateWindow(
          SlotTime.parse('07:00'),
          SlotTime.parse('07:00'),
        ),
        contains('cannot equal'),
      );
    });

    test('names the missing end of the pair', () {
      expect(
        CourtSlotDraft.validateWindow(null, SlotTime.parse('08:00')),
        'Pick a start time',
      );
      expect(
        CourtSlotDraft.validateWindow(SlotTime.parse('07:00'), null),
        'Pick an end time',
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('CourtSlot.overlaps', () {
    test('windows that merely touch do not overlap', () {
      // 08:00–09:00 and 09:00–10:00 is how an hourly schedule is built.
      final first = _slot(id: 1, start: '08:00', end: '09:00');
      final second = _slot(id: 2, start: '09:00', end: '10:00');
      expect(first.overlaps(second), isFalse);
      expect(second.overlaps(first), isFalse);
    });

    test('windows that share clock time on a shared day do overlap', () {
      final first = _slot(id: 1, start: '08:00', end: '09:00');
      final second = _slot(id: 2, start: '08:30', end: '09:30');
      expect(first.overlaps(second), isTrue);
    });

    test('the same hour on different days does not clash', () {
      final monday = _slot(id: 1, days: 'Monday');
      final tuesday = _slot(id: 2, days: 'Tuesday');
      expect(monday.overlaps(tuesday), isFalse);
    });

    test('an unreadable day list is treated as possibly clashing', () {
      // The safer answer is "possibly", so the form warns rather than waving a
      // real clash through.
      final custom = _slot(id: 1, days: 'Alternate weekends');
      final monday = _slot(id: 2, days: 'Monday');
      expect(custom.overlaps(monday), isTrue);
    });

    test('a slot with unreadable times never claims a clash', () {
      final broken = _slot(id: 1, start: 'soon', end: 'later');
      expect(broken.overlaps(_slot(id: 2)), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('CourtMapper', () {
    test('parses a full record with Sequelize-cased associations', () {
      // The storefront's BookedCourt already reads `SportComplex` with a
      // capital S from a live payload.
      final court = CourtMapper.fromJson({
        'id': 3,
        'name': 'Court 1',
        'description': 'Indoor synthetic',
        'capacity': 4,
        'surfaceType': 'Synthetic',
        'lightingAvailable': true,
        'equipmentAvailable': 'Rackets, balls',
        'hourlyRate': '800.00',
        'status': 'Active',
        'showOnFrontend': true,
        'image': 'uploads/c.jpg',
        'Sport': {'id': 8, 'name': 'Badminton'},
        'SportComplex': {'id': 2, 'name': 'Kothrud Arena'},
      });

      expect(court.id, 3);
      expect(court.name, 'Court 1');
      expect(court.sportId, 8);
      expect(court.sportName, 'Badminton');
      expect(court.sportComplexId, 2);
      expect(court.sportComplexName, 'Kothrud Arena');
      expect(court.capacity, 4);
      expect(court.surfaceType, 'Synthetic');
      expect(court.lightingAvailable, isTrue);
      expect(court.equipmentAvailable, 'Rackets, balls');
      // The decimal string becomes a real number so the table can sort it.
      expect(court.hourlyRate, 800);
      expect(court.status, AdminUserStatus.active);
      expect(court.showOnFrontend, isTrue);
    });

    test('reads snake_case and a nested court envelope', () {
      final court = CourtMapper.fromJson({
        'court': {
          '_id': 9,
          'courtName': 'Court 9',
          'sport_id': 2,
          'sport_complex_id': 6,
          'surface_type': 'Clay',
          'hourly_rate': 650,
          'lighting_available': false,
          'show_on_frontend': false,
        },
      });

      expect(court.id, 9);
      expect(court.name, 'Court 9');
      expect(court.sportId, 2);
      expect(court.sportComplexId, 6);
      expect(court.surfaceType, 'Clay');
      expect(court.hourlyRate, 650);
      expect(court.lightingAvailable, isFalse);
      expect(court.showOnFrontend, isFalse);
    });

    test('an absent boolean stays null rather than becoming false', () {
      final court = CourtMapper.fromJson({'id': 1});
      expect(court.lightingAvailable, isNull);
      expect(court.showOnFrontend, isNull);
      expect(court.hourlyRate, isNull);
      expect(court.capacity, isNull);
    });

    test('equipment sent as a list is joined rather than dropped', () {
      final court = CourtMapper.fromJson({
        'id': 1,
        'equipment': ['Rackets', 'Balls'],
      });
      expect(court.equipmentAvailable, 'Rackets, Balls');
    });

    test('rows without an id are dropped from the list', () {
      final courts = CourtMapper.listFrom({
        'courts': [
          {'id': 1},
          {'name': 'No id'},
          {'id': 2},
        ],
      });
      expect(courts.map((court) => court.id), [1, 2]);
    });
  });

  // ---------------------------------------------------------------------------
  group('CourtSlotMapper', () {
    test('parses a slot and normalises its days', () {
      final slot = CourtSlotMapper.fromJson({
        'id': 4,
        'courtId': 3,
        'startTime': '07:00:00',
        'endTime': '08:00:00',
        'availableDays': 'Monday,Wednesday',
        'slotType': 'Premium',
        'priceOverride': '1200.00',
        'status': 'Active',
      });

      expect(slot.id, 4);
      expect(slot.courtId, 3);
      expect(slot.startTime?.wire, '07:00');
      expect(slot.days.days, [Weekday.monday, Weekday.wednesday]);
      expect(slot.slotType, SlotType.premium);
      expect(slot.priceOverride, 1200);
      expect(slot.isBookable, isTrue);
      expect(slot.durationMinutes, 60);
    });

    test('the toggle response is read from a status or from a boolean', () {
      expect(
        CourtSlotMapper.statusFrom({'status': 'Inactive'}),
        AdminUserStatus.inactive,
      );
      expect(
        CourtSlotMapper.statusFrom({'data': {'isBlocked': true}}),
        AdminUserStatus.inactive,
      );
      expect(
        CourtSlotMapper.statusFrom({'data': {'isActive': true}}),
        AdminUserStatus.active,
      );
      // Null means "the route did not say" — the caller must not assume.
      expect(CourtSlotMapper.statusFrom({'success': true}), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('AvailableSlot', () {
    test('resolves the three states the spec colours', () {
      expect(
        AvailableSlotMapper.fromJson({'isBlocked': true}).availability,
        SlotAvailability.blocked,
      );
      expect(
        AvailableSlotMapper.fromJson({'status': 'Booked'}).availability,
        SlotAvailability.booked,
      );
      expect(
        AvailableSlotMapper.fromJson({'isAvailable': true}).availability,
        SlotAvailability.available,
      );
      expect(
        AvailableSlotMapper.fromJson({'isAvailable': false}).availability,
        SlotAvailability.booked,
      );
    });

    test('a payload that says nothing is unknown, never available', () {
      // Telling an admin a court is free when it is not is the expensive
      // mistake, so silence is never read as green.
      expect(
        AvailableSlotMapper.fromJson({'startTime': '07:00'}).availability,
        SlotAvailability.unknown,
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('AvailabilityWindow', () {
    test('never exposes a court name, even when the payload carries one', () {
      final window = AvailabilityMapper.fromJson({
        'startTime': '07:00',
        'endTime': '08:00',
        'availableCourts': 2,
        'totalCourts': 5,
        'courtName': 'Court 1',
      });

      expect(window.windowLabel, '7:00 AM – 8:00 AM');
      expect(window.availableCourts, 2);
      expect(window.totalCourts, 5);
      expect(window.hasAvailability, isTrue);
      // The model has nowhere to put it — that is the point.
      expect(window.toString(), isNot(contains('Court 1')));
    });

    test('a window with no counter is not treated as bookable', () {
      final window = AvailabilityMapper.fromJson({'startTime': '07:00'});
      expect(window.hasAvailability, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('CourtDraft', () {
    test('the create payload carries every documented key', () {
      final body = const CourtDraft(
        name: ' Court 1 ',
        sportId: 8,
        sportComplexId: 2,
        description: 'Indoor',
        capacity: 4,
        surfaceType: 'Synthetic',
        lightingAvailable: true,
        equipmentAvailable: 'Rackets',
        hourlyRate: 800,
        image: 'uploads/c.jpg',
        status: AdminUserStatus.inactive,
        showOnFrontend: true,
      ).toCreateJson();

      expect(body['name'], 'Court 1');
      expect(body['sportId'], 8);
      expect(body['sportComplexId'], 2);
      expect(body['capacity'], 4);
      expect(body['hourlyRate'], 800);
      expect(body['lightingAvailable'], isTrue);
      expect(body['status'], 'Inactive');
      expect(body['showOnFrontend'], isTrue);
    });

    test('create defaults to Active and hidden', () {
      final body = const CourtDraft(name: 'A').toCreateJson();
      expect(body['status'], 'Active');
      expect(body['showOnFrontend'], isFalse);
      expect(body['lightingAvailable'], isFalse);
      expect(body['capacity'], isNull);
    });

    test('the update payload sends only the eight editable fields', () {
      final body = const CourtDraft(
        name: 'Renamed',
        description: 'Updated',
        capacity: 6,
        hourlyRate: 900,
        surfaceType: 'Clay',
        lightingAvailable: false,
        equipmentAvailable: 'Balls',
        status: AdminUserStatus.active,
        // Neither is documented as editable.
        sportId: 9,
        sportComplexId: 9,
        showOnFrontend: true,
      ).toUpdateJson();

      expect(body.keys.toSet(), {
        'name',
        'description',
        'capacity',
        'hourlyRate',
        'surfaceType',
        'lightingAvailable',
        'equipmentAvailable',
        'status',
      });
      expect(body.containsKey('sportId'), isFalse);
      expect(body.containsKey('sportComplexId'), isFalse);
      // Visibility has a PATCH route of its own.
      expect(body.containsKey('showOnFrontend'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('CourtSlotDraft payloads', () {
    test('times go out in 24-hour form whatever was typed', () {
      final body = CourtSlotDraft(
        startTime: SlotTime.parse('7:00 PM'),
        endTime: SlotTime.parse('8:00 PM'),
        availableDays: 'Monday',
        slotType: SlotType.coaching,
        priceOverride: 1200,
      ).toCreateJson();

      expect(body['startTime'], '19:00');
      expect(body['endTime'], '20:00');
      expect(body['slotType'], 'Coaching');
      expect(body['priceOverride'], 1200);
      expect(body['status'], 'Active');
    });

    test('an update omits what was not touched', () {
      final body = const CourtSlotDraft(
        status: AdminUserStatus.inactive,
      ).toUpdateJson();
      expect(body, {'status': 'Inactive'});
    });

    test('clearing the override sends an explicit null', () {
      // Otherwise an override could never be removed, only changed.
      final body = const CourtSlotDraft(
        clearPriceOverride: true,
      ).toUpdateJson();
      expect(body.containsKey('priceOverride'), isTrue);
      expect(body['priceOverride'], isNull);

      final untouched = const CourtSlotDraft().toUpdateJson();
      expect(untouched.containsKey('priceOverride'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('CourtsSummary', () {
    test('counts statuses and visibility, and never guesses at silence', () {
      final summary = CourtsSummary.from([
        _court(id: 1, showOnFrontend: true, slotCount: 5, availableSlots: 2),
        _court(id: 2, showOnFrontend: false, slotCount: 3, availableSlots: 1),
        _court(id: 3, status: 'Inactive'),
      ]);

      expect(summary.total, 3);
      expect(summary.active, 2);
      expect(summary.onFrontend, 1);
      expect(summary.hidden, 1);
      // Court 3 said nothing about visibility, so it is in neither bucket.
      expect(summary.onFrontend + summary.hidden, 2);
      expect(summary.slots, 8);
      expect(summary.availableSlots, 3);
    });

    test('slot counters stay null when the list did not report them', () {
      final summary = CourtsSummary.from([_court(id: 1), _court(id: 2)]);
      expect(summary.slots, isNull);
      expect(summary.availableSlots, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('SlotsSummary', () {
    test('counts bookable, blocked, regular and custom-price slots', () {
      final summary = SlotsSummary.from([
        _slot(id: 1),
        _slot(id: 2, status: 'Inactive'),
        _slot(id: 3, type: 'Premium', price: 1200),
      ]);

      expect(summary.total, 3);
      expect(summary.active, 2);
      expect(summary.blocked, 1);
      expect(summary.regular, 2);
      expect(summary.customPrice, 1);
    });
  });

  // ---------------------------------------------------------------------------
  group('CourtsController', () {
    test('the complex and sport filters refetch; the rest do not', () async {
      final repository = _FakeCourtRepository();
      final controller = CourtsController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      controller.setComplexFilter(2);
      await Future<void>.delayed(Duration.zero);
      expect(repository.lastComplexId, 2);
      expect(repository.listCalls, 2);

      final before = repository.listCalls;
      controller.setStatusFilter(AdminUserStatus.active);
      controller.setSurfaceFilter('Clay');
      controller.setVisibilityFilter(true);
      expect(repository.listCalls, before);
    });

    test('search and the local filters narrow the rows', () async {
      final controller = CourtsController(
        _FakeCourtRepository(
          courts: [
            _court(id: 1, name: 'Court A', surface: 'Clay'),
            _court(id: 2, name: 'Court B', surface: 'Synthetic'),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.onSearchChanged('court b');
      await Future<void>.delayed(CourtsController.searchDebounce * 2);
      expect(controller.visibleRows.single.id, 2);

      controller.clearSearch();
      controller.setSurfaceFilter('clay');
      expect(controller.visibleRows.single.id, 1);
    });

    test('knownSurfaces is learned from the rows, de-duplicated and sorted',
        () async {
      final controller = CourtsController(
        _FakeCourtRepository(
          courts: [
            _court(id: 1, surface: 'Synthetic'),
            _court(id: 2, surface: 'synthetic'),
            _court(id: 3, surface: 'Clay'),
            _court(id: 4),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      expect(controller.knownSurfaces, ['Clay', 'Synthetic']);
    });

    test('sorting by rate is numeric and blanks sink both ways', () async {
      final controller = CourtsController(
        _FakeCourtRepository(
          courts: [
            _court(id: 1, rate: 900),
            _court(id: 2),
            _court(id: 3, rate: 400),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.toggleSort(CourtSort.rate);
      expect(controller.visibleRows.map((c) => c.id), [3, 1, 2]);

      controller.toggleSort(CourtSort.rate);
      expect(controller.visibleRows.map((c) => c.id), [1, 3, 2]);
    });

    test('a visibility toggle is optimistic and reverts on failure', () async {
      final controller = CourtsController(
        _FakeCourtRepository(failVisibility: true),
      );
      addTearDown(controller.dispose);
      await controller.load();

      await expectLater(
        controller.setVisibility(1, true),
        throwsA(isA<Exception>()),
      );

      expect(controller.rows.first.showOnFrontend, isFalse);
      expect(controller.isRowBusy(1), isFalse);
    });

    test('a delete is optimistic and restores the row when it fails', () async {
      final controller = CourtsController(
        _FakeCourtRepository(failDelete: true),
      );
      addTearDown(controller.dispose);
      await controller.load();

      final before = controller.rows.length;
      await expectLater(controller.delete(1), throwsA(isA<Exception>()));

      expect(controller.rows.length, before);
    });

    test('a load failure surfaces the server message', () async {
      final controller = CourtsController(
        _FakeCourtRepository(failList: true),
      );
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.isFailed, isTrue);
      expect(controller.error, 'Courts are unavailable');
    });
  });

  // ---------------------------------------------------------------------------
  group('CourtSlotsController', () {
    test('clashesWith ignores the slot being edited', () async {
      final repository = _FakeSlotRepository(
        slots: [_slot(id: 1, start: '08:00', end: '09:00')],
      );
      final controller = CourtSlotsController(repository, _court(id: 1));
      addTearDown(controller.dispose);
      await controller.load();

      final draft = CourtSlotDraft(
        startTime: SlotTime.parse('08:00'),
        endTime: SlotTime.parse('09:00'),
        availableDays: 'Monday, Wednesday',
      );

      // Editing slot 1 into its own window is not a clash.
      expect(controller.clashesWith(draft, ignoreId: 1), isEmpty);
      // Creating a second slot in it is.
      expect(controller.clashesWith(draft).single.id, 1);
    });

    test('a toggle assumes the opposite, and defers to the server', () async {
      // The route flips whatever the slot is, so the optimistic value is a
      // guess — and the response wins when it names a status.
      final repository = _FakeSlotRepository(
        slots: [_slot(id: 1, status: 'Active')],
        toggleAnswer: AdminUserStatus.active,
      );
      final controller = CourtSlotsController(repository, _court(id: 1));
      addTearDown(controller.dispose);
      await controller.load();

      await controller.toggle(1);

      // The guess was Inactive; the server said Active, so Active is what shows.
      expect(controller.slots.single.status, AdminUserStatus.active);
    });

    test('a failed toggle reverts the row', () async {
      final controller = CourtSlotsController(
        _FakeSlotRepository(
          slots: [_slot(id: 1, status: 'Active')],
          failToggle: true,
        ),
        _court(id: 1),
      );
      addTearDown(controller.dispose);
      await controller.load();

      await expectLater(controller.toggle(1), throwsA(isA<Exception>()));

      expect(controller.slots.single.status, AdminUserStatus.active);
      expect(controller.isRowBusy(1), isFalse);
    });

    test('the week grid asks for seven days and keeps a partial week',
        () async {
      final repository = _FakeSlotRepository(failDayAfter: 3);
      final controller = CourtSlotsController(repository, _court(id: 1));
      addTearDown(controller.dispose);

      await controller.loadWeek();

      expect(repository.availableSlotCalls, 7);
      expect(controller.week.length, 7);
      // A day that failed leaves its column empty rather than failing the grid.
      expect(controller.weekState.isReady, isTrue);
      expect(controller.week[1], isNotEmpty);
      expect(controller.week[7], isEmpty);
    });

    test('the grid falls back to a working day when nothing is scheduled',
        () async {
      final controller = CourtSlotsController(
        _FakeSlotRepository(slots: const []),
        _court(id: 1),
      );
      addTearDown(controller.dispose);
      await controller.load();

      // Visibly a default rather than data.
      expect(controller.gridHours.first, 6);
      expect(controller.gridHours.last, 22);
    });

    test('ordered slots put unreadable times last, never dropping them',
        () async {
      final controller = CourtSlotsController(
        _FakeSlotRepository(
          slots: [
            _slot(id: 1, start: '18:00', end: '19:00'),
            _slot(id: 2, start: 'soon', end: 'later'),
            _slot(id: 3, start: '07:00', end: '08:00'),
          ],
        ),
        _court(id: 1),
      );
      addTearDown(controller.dispose);
      await controller.load();

      expect(controller.orderedSlots.map((s) => s.id), [3, 1, 2]);
    });
  });

  // ---------------------------------------------------------------------------
  group('CourtRepositoryImpl — the wire', () {
    test('the list route sends the complex and the sport', () async {
      late Uri captured;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      await CourtRepositoryImpl().fetchCourts(complexId: 2, sportId: 8);

      expect(captured.path, endsWith('/courts'));
      expect(captured.queryParameters['sportComplexId'], '2');
      expect(captured.queryParameters['sportId'], '8');

      await CourtRepositoryImpl().fetchCourts();
      expect(captured.queryParameters.containsKey('sportComplexId'), isFalse);
    });

    test('visibility is PATCH; status is a PUT of that one field', () async {
      final calls = <String>[];
      final bodies = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          bodies.add(request.body);
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      final repository = CourtRepositoryImpl();
      await repository.setVisibility(3, true);
      await repository.setStatus(3, AdminUserStatus.inactive);

      expect(calls[0], endsWith('PATCH /api/courts/3/show-on-frontend'));
      expect(jsonDecode(bodies[0])['showOnFrontend'], isTrue);
      // There is no /courts/{id}/status route.
      expect(calls[1], endsWith('PUT /api/courts/3'));
      expect(jsonDecode(bodies[1])['status'], 'Inactive');
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

      final repository = CourtRepositoryImpl();

      for (final draft in const [
        CourtDraft(),
        CourtDraft(name: 'A'),
        CourtDraft(name: 'A', sportComplexId: 1),
        CourtDraft(name: 'A', sportComplexId: 1, sportId: 1),
        CourtDraft(name: 'A', sportComplexId: 1, sportId: 1, capacity: 4),
      ]) {
        await expectLater(
          repository.createCourt(draft),
          throwsA(isA<ValidationException>()),
        );
      }

      expect(called, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('CourtSlotRepositoryImpl — the wire', () {
    test('every slot route is scoped to its court', () async {
      final calls = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      final repository = CourtSlotRepositoryImpl();
      await repository.fetchSlots(3);
      await repository.toggleSlot(3, 4);
      await repository.deleteSlot(3, 4);

      expect(calls[0], endsWith('GET /api/courts/3/slots'));
      expect(calls[1], endsWith('PATCH /api/courts/3/slots/4/toggle'));
      expect(calls[2], endsWith('DELETE /api/courts/3/slots/4'));
    });

    test('the availability routes send the date as yyyy-MM-dd', () async {
      final urls = <Uri>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          urls.add(request.url);
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      final repository = CourtSlotRepositoryImpl();
      await repository.fetchAvailableSlots(3, DateTime(2026, 8, 5));
      await repository.fetchAvailability(
        complexId: 2,
        sportId: 8,
        date: DateTime(2026, 12, 25),
      );

      expect(urls[0].path, endsWith('/courts/3/available-slots'));
      expect(urls[0].queryParameters['date'], '2026-08-05');
      expect(urls[1].path, endsWith('/courts/availability'));
      expect(urls[1].queryParameters['date'], '2026-12-25');
      expect(urls[1].queryParameters['sportComplexId'], '2');
    });

    test('a create with a bad window never reaches the network', () async {
      var called = false;
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          called = true;
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      await expectLater(
        CourtSlotRepositoryImpl().createSlot(
          3,
          CourtSlotDraft(
            startTime: SlotTime.parse('07:00'),
            endTime: SlotTime.parse('09:00'),
          ),
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(called, isFalse);
    });

    test('an update that changes only one end is not window-checked',
        () async {
      // The other end stays as the server has it, and this app cannot judge
      // the pair — so it is sent and the backend decides.
      var called = false;
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          called = true;
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      await CourtSlotRepositoryImpl().updateSlot(
        3,
        4,
        CourtSlotDraft(startTime: SlotTime.parse('09:00')),
      );

      expect(called, isTrue);
    });
  });
}

// -----------------------------------------------------------------------------
// Fakes
// -----------------------------------------------------------------------------

class _FakeCourtRepository implements CourtRepository {
  _FakeCourtRepository({
    List<Court>? courts,
    this.failList = false,
    this.failDelete = false,
    this.failVisibility = false,
  }) : courts =
           courts ??
           [
             _court(id: 1, showOnFrontend: false, rate: 800, capacity: 4),
             _court(id: 2, showOnFrontend: true, rate: 600, capacity: 2),
           ];

  final List<Court> courts;
  final bool failList;
  final bool failDelete;
  final bool failVisibility;

  int listCalls = 0;
  int? lastComplexId;
  int? lastSportId;

  @override
  Future<List<Court>> fetchCourts({int? complexId, int? sportId}) async {
    listCalls++;
    lastComplexId = complexId;
    lastSportId = sportId;
    if (failList) throw const ServerException('Courts are unavailable');
    return courts;
  }

  @override
  Future<Court> fetchCourt(int id) async => Court(id: id, description: 'D');

  @override
  Future<Court> createCourt(CourtDraft draft) async => const Court(id: 99);

  @override
  Future<Court> updateCourt(int id, CourtDraft draft) async => Court(id: id);

  @override
  Future<void> setVisibility(int id, bool showOnFrontend) async {
    if (failVisibility) throw const ServerException('Rejected');
  }

  @override
  Future<void> setStatus(int id, AdminUserStatus status) async {}

  @override
  Future<void> deleteCourt(int id) async {
    if (failDelete) throw const ServerException('Rejected');
  }

  @override
  Future<String> uploadImage(String filePath, {String? filename}) async =>
      'https://cdn/x.jpg';

  @override
  Future<List<Sport>> fetchSports({bool refresh = false}) async =>
      const [Sport(id: 8, name: 'Badminton')];

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async => const [SportsComplex(id: 2, name: 'Kothrud Arena')];
}

class _FakeSlotRepository implements CourtSlotRepository {
  _FakeSlotRepository({
    List<CourtSlot>? slots,
    this.toggleAnswer,
    this.failToggle = false,
    this.failDayAfter,
  }) : slots = slots ?? [_slot(id: 1)];

  final List<CourtSlot> slots;
  final AdminUserStatus? toggleAnswer;
  final bool failToggle;

  /// Days at or after this index (0-based) answer with nothing.
  final int? failDayAfter;

  int availableSlotCalls = 0;

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
  Future<AdminUserStatus?> toggleSlot(int courtId, int slotId) async {
    if (failToggle) throw const ServerException('Rejected');
    return toggleAnswer;
  }

  @override
  Future<void> deleteSlot(int courtId, int slotId) async {}

  @override
  Future<List<AvailableSlot>> fetchAvailableSlots(
    int courtId,
    DateTime date,
  ) async {
    final index = availableSlotCalls++;
    final cap = failDayAfter;
    if (cap != null && index >= cap) return const [];
    return const [
      AvailableSlot(
        startTimeRaw: '07:00',
        endTimeRaw: '08:00',
        isAvailable: true,
      ),
    ];
  }

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
    ),
  ];
}
