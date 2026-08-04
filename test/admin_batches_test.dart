import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/features/admin/data/models/batch_admin_model.dart';
import 'package:nahata_app/features/admin/data/repositories/batch_repository_impl.dart';
import 'package:nahata_app/features/admin/domain/entities/admin_role.dart';
import 'package:nahata_app/features/admin/domain/entities/batch.dart';
import 'package:nahata_app/features/admin/domain/entities/coach.dart';
import 'package:nahata_app/features/admin/domain/entities/sport.dart';
import 'package:nahata_app/features/admin/domain/repositories/batch_repository.dart';
import 'package:nahata_app/features/admin/presentation/state/batches_controller.dart';
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

AdminBatch _batch({
  required int id,
  String? name,
  int? sportId,
  String? sportName,
  int? coachId,
  String? coachName,
  int? complexId,
  String? complexName,
  String? days,
  String? schedule,
  DateTime? startDate,
  int? maxStudents,
  int? currentStudents,
  num? fees,
  String? ageGroup,
  String status = 'Active',
}) {
  return AdminBatch(
    id: id,
    name: name ?? 'Batch $id',
    sportId: sportId,
    sportName: sportName,
    coachId: coachId,
    coachName: coachName,
    sportComplexId: complexId,
    sportComplexName: complexName,
    daysRaw: days,
    schedule: schedule,
    startDate: startDate,
    maxStudents: maxStudents,
    currentStudents: currentStudents,
    fees: fees,
    ageGroup: ageGroup,
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
  group('AdminBatch', () {
    test('occupancy divides the two counters and clamps to 0–1', () {
      expect(_batch(id: 1, maxStudents: 20, currentStudents: 5).occupancy, 0.25);
      expect(
        _batch(id: 1, maxStudents: 20, currentStudents: 20).occupancy,
        1.0,
      );
      // A backend that oversold the batch still reads as full, not as 150%.
      expect(
        _batch(id: 1, maxStudents: 20, currentStudents: 30).occupancy,
        1.0,
      );
    });

    test('occupancy is null when there is nothing honest to divide', () {
      // No capacity, no capacity of zero, and no headcount are all unknown —
      // none of them is "0% full".
      expect(_batch(id: 1, currentStudents: 5).occupancy, isNull);
      expect(
        _batch(id: 1, maxStudents: 0, currentStudents: 5).occupancy,
        isNull,
      );
      expect(_batch(id: 1, maxStudents: 20).occupancy, isNull);
      expect(_batch(id: 1).occupancyPercent, isNull);
    });

    test('availableSeats never goes negative and stays null without capacity',
        () {
      expect(
        _batch(id: 1, maxStudents: 20, currentStudents: 8).availableSeats,
        12,
      );
      expect(
        _batch(id: 1, maxStudents: 20, currentStudents: 25).availableSeats,
        0,
      );
      // A batch that never said how many seats it has does not have zero free.
      expect(_batch(id: 1, currentStudents: 8).availableSeats, isNull);
      expect(_batch(id: 1, currentStudents: 8).isFull, isFalse);
      expect(
        _batch(id: 1, maxStudents: 8, currentStudents: 8).isFull,
        isTrue,
      );
    });

    test('the schedule label prefers the explicit times over the free text', () {
      expect(
        const AdminBatch(
          id: 1,
          startTime: '7:00 PM',
          endTime: '8:00 PM',
          schedule: 'ignored',
        ).scheduleLabel,
        '7:00 PM to 8:00 PM',
      );
      expect(
        const AdminBatch(id: 1, schedule: '6 AM to 7 AM').scheduleLabel,
        '6 AM to 7 AM',
      );
      expect(const AdminBatch(id: 1).scheduleLabel, '—');
    });

    test('days are read through the coaches module parser', () {
      final batch = _batch(id: 1, days: 'Monday, Wednesday');
      expect(batch.days.days, [Weekday.monday, Weekday.wednesday]);
      expect(batch.days.isCustom, isFalse);

      // A schedule the day list cannot express is kept verbatim.
      final custom = _batch(id: 1, days: 'Alternate weekends');
      expect(custom.days.isCustom, isTrue);
      expect(custom.daysLabel, 'Alternate weekends');
      expect(_batch(id: 1).daysLabel, '—');
    });

    test('the API name is trimmed — rows really do arrive padded', () {
      expect(_batch(id: 1, name: '3 DAYS (Morning)   ').displayName,
          '3 DAYS (Morning)');
      expect(_batch(id: 1, name: '   ').displayName, 'Unnamed batch');
    });

    test('search matches the batch, the coach and the sport', () {
      final batch = _batch(
        id: 1,
        name: 'Morning Batch',
        coachName: 'Rahul Sharma',
        sportName: 'Badminton',
      );

      expect(batch.matches('morning'), isTrue);
      expect(batch.matches('rahul'), isTrue);
      expect(batch.matches('badmin'), isTrue);
      expect(batch.matches(''), isTrue);
      expect(batch.matches('football'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('BatchMapper', () {
    test('parses a full record with nested sport and coach objects', () {
      final batch = BatchMapper.fromJson({
        'id': 3,
        'name': 'Evening Batch',
        'image': 'uploads/b.jpg',
        'schedule': '7:00 PM to 8:00 PM',
        'days': 'Monday,Tuesday',
        'startDate': '2026-07-01',
        'endDate': '2026-09-30',
        'startTime': '7:00 PM',
        'endTime': '8:00 PM',
        'maxStudents': 20,
        'currentStudents': 12,
        'fees': '2500.00',
        'ageGroup': '8-14',
        'duration': '3 months',
        'description': 'Evening coaching',
        'features': ['Equipment provided', 'Certificate'],
        'status': 'Active',
        'sport': {'id': 8, 'name': 'Badminton'},
        'coach': {'id': 5, 'name': 'Rahul Sharma'},
        'sportComplexId': 2,
        'sportComplexName': 'Kothrud Arena',
      });

      expect(batch.id, 3);
      expect(batch.name, 'Evening Batch');
      expect(batch.sportId, 8);
      expect(batch.sportName, 'Badminton');
      expect(batch.coachId, 5);
      expect(batch.coachName, 'Rahul Sharma');
      expect(batch.sportComplexId, 2);
      expect(batch.sportComplexName, 'Kothrud Arena');
      // The decimal string becomes a real number so the table can sort it.
      expect(batch.fees, 2500);
      expect(batch.maxStudents, 20);
      expect(batch.currentStudents, 12);
      expect(batch.occupancyPercent, 60);
      expect(batch.features, ['Equipment provided', 'Certificate']);
      expect(batch.startDate, DateTime.parse('2026-07-01'));
      expect(batch.days.days, [Weekday.monday, Weekday.tuesday]);
      expect(batch.status, AdminUserStatus.active);
    });

    test('reads snake_case and a nested batch envelope', () {
      final batch = BatchMapper.fromJson({
        'batch': {
          '_id': 9,
          'batchName': 'Morning',
          'sport_id': 2,
          'coach_id': 4,
          'sport_complex_id': 6,
          'max_students': 15,
          'current_students': 3,
          'age_group': '6-10',
          'start_date': '2026-01-05',
        },
      });

      expect(batch.id, 9);
      expect(batch.name, 'Morning');
      expect(batch.sportId, 2);
      expect(batch.coachId, 4);
      expect(batch.sportComplexId, 6);
      expect(batch.maxStudents, 15);
      expect(batch.currentStudents, 3);
      expect(batch.ageGroup, '6-10');
      expect(batch.startDate, DateTime.parse('2026-01-05'));
    });

    test('the venue falls back to the coach ground on the sport route', () {
      // `/batches/sport/{id}` carries the venue only as the coach's ground.
      final batch = BatchMapper.fromJson({
        'id': 1,
        'coach': {'id': 3, 'name': 'A', 'ground': 'Baner Ground'},
      });

      expect(batch.sportComplexName, 'Baner Ground');
    });

    test('days arrive as a string or as a list, normalised the same way', () {
      expect(
        BatchMapper.fromJson({'id': 1, 'days': 'Monday,Tuesday'}).daysRaw,
        'Monday, Tuesday',
      );
      expect(
        BatchMapper.fromJson({
          'id': 1,
          'weekDays': ['Monday', 'Tuesday'],
        }).daysRaw,
        'Monday, Tuesday',
      );
    });

    test('fees survive every shape the API uses, and stay null when unusable',
        () {
      expect(BatchMapper.fromJson({'id': 1, 'fees': '2500.00'}).fees, 2500);
      expect(BatchMapper.fromJson({'id': 1, 'fees': 2500}).fees, 2500);
      expect(BatchMapper.fromJson({'id': 1, 'fees': '₹2,500'}).fees, 2500);
      expect(BatchMapper.fromJson({'id': 1, 'price': '1999.50'}).fees, 1999.5);
      expect(BatchMapper.fromJson({'id': 1, 'fees': 'free'}).fees, isNull);
      expect(BatchMapper.fromJson({'id': 1}).fees, isNull);
    });

    test('rows without an id are dropped from the list', () {
      final batches = BatchMapper.listFrom({
        'batches': [
          {'id': 1},
          {'name': 'No id'},
          {'id': 2},
        ],
      });
      expect(batches.map((batch) => batch.id), [1, 2]);
    });
  });

  // ---------------------------------------------------------------------------
  group('BatchMapper.pageFrom', () {
    test('reads the documented pagination envelope', () {
      final page = BatchMapper.pageFrom(
        {
          'batches': [
            {'id': 1},
            {'id': 2},
          ],
          'currentPage': 2,
          'totalPages': 5,
          'totalItems': 47,
          'itemsPerPage': 10,
        },
        requestedPage: 2,
        requestedLimit: 10,
      );

      expect(page.batches.length, 2);
      expect(page.page, 2);
      expect(page.totalPages, 5);
      expect(page.totalItems, 47);
      expect(page.perPage, 10);
      expect(page.hasMore, isTrue);
    });

    test('derives the page count when the route sends a total but no pages',
        () {
      // Trusting a missing totalPages as 1 would hide every page after the
      // first.
      final page = BatchMapper.pageFrom(
        {
          'batches': [
            {'id': 1},
          ],
          'totalItems': 47,
          'itemsPerPage': 10,
        },
        requestedPage: 1,
        requestedLimit: 10,
      );

      expect(page.totalPages, 5);
    });

    test('a bare list is treated as one complete page', () {
      final page = BatchMapper.pageFrom(
        [
          {'id': 1},
          {'id': 2},
        ],
        requestedPage: 1,
        requestedLimit: 20,
      );

      expect(page.batches.length, 2);
      expect(page.page, 1);
      expect(page.totalItems, 2);
      expect(page.totalPages, 1);
      expect(page.hasMore, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('BatchStatsMapper', () {
    test('reads the stats envelope, including the string sport and coach', () {
      final stats = BatchStatsMapper.fromJson({
        'batchId': 3,
        'batchName': 'Evening Batch',
        'sport': 'Badminton',
        'coach': 'Rahul Sharma',
        'maxStudents': 20,
        'currentStudents': 15,
        'enrolledStudents': 16,
        'availableSlots': 5,
        'occupancyPercentage': 75,
        'fees': '2500.00',
        'status': 'Active',
      });

      expect(stats.batchName, 'Evening Batch');
      expect(stats.sportName, 'Badminton');
      expect(stats.coachName, 'Rahul Sharma');
      expect(stats.enrolledStudents, 16);
      expect(stats.availableSlots, 5);
      expect(stats.occupancy, 0.75);
      expect(stats.fees, 2500);
      expect(stats.status, AdminUserStatus.active);
    });

    test('occupancy falls back to the counters when no percentage was sent',
        () {
      final stats = BatchStatsMapper.fromJson({
        'maxStudents': 20,
        'currentStudents': 5,
      });
      expect(stats.occupancy, 0.25);

      expect(const BatchStatistics().occupancy, isNull);
      expect(const BatchStatistics().isEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('BatchDraft', () {
    test('the create payload carries every documented key', () {
      final body = BatchDraft(
        name: ' Morning Batch ',
        sportId: 8,
        coachId: 5,
        sportComplexId: 2,
        schedule: '7:00 AM to 8:00 AM',
        days: 'Monday, Tuesday',
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2026, 9, 30),
        startTime: '7:00 AM',
        endTime: '8:00 AM',
        maxStudents: 20,
        fees: 2500,
        ageGroup: '8-14',
        duration: '3 months',
        description: 'Morning coaching',
        features: const ['Equipment provided'],
        image: 'uploads/b.jpg',
        status: AdminUserStatus.inactive,
      ).toCreateJson();

      expect(body['name'], 'Morning Batch');
      expect(body['sportId'], 8);
      expect(body['coachId'], 5);
      expect(body['sportComplexId'], 2);
      // Dates go out in the shape every date the API returns is in.
      expect(body['startDate'], '2026-07-01');
      expect(body['endDate'], '2026-09-30');
      expect(body['maxStudents'], 20);
      expect(body['fees'], 2500);
      expect(body['features'], ['Equipment provided']);
      expect(body['status'], 'Inactive');
    });

    test('create defaults to Active and sends blanks, not nulls, for text', () {
      final body = const BatchDraft(name: 'A').toCreateJson();
      expect(body['status'], 'Active');
      expect(body['description'], '');
      expect(body['features'], isEmpty);
      // A date nobody picked is absent, not epoch zero.
      expect(body['startDate'], isNull);
    });

    test('formatDate pads the month and day', () {
      expect(BatchDraft.formatDate(DateTime(2026, 1, 5)), '2026-01-05');
      expect(BatchDraft.formatDate(null), isNull);
    });

    test('the update payload sends only the six editable fields', () {
      final body = BatchDraft(
        name: 'Renamed',
        fees: 3000,
        maxStudents: 25,
        description: 'Updated',
        duration: '4 months',
        status: AdminUserStatus.active,
        // None of these is documented as editable.
        sportId: 9,
        coachId: 9,
        sportComplexId: 9,
        schedule: 'ignored',
        days: 'ignored',
        startDate: DateTime(2026, 1, 1),
        image: 'ignored',
      ).toUpdateJson();

      expect(body.keys.toSet(), {
        'name',
        'fees',
        'maxStudents',
        'description',
        'duration',
        'status',
      });
    });

    test('an update omits untouched fields but keeps deliberate blanks', () {
      // A description cleared on purpose has to reach the server, or it could
      // never be erased once written.
      expect(const BatchDraft(description: '').toUpdateJson(), {
        'description': '',
      });
      expect(const BatchDraft().toUpdateJson(), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  group('BatchesSummary', () {
    test('counts statuses, students and seats', () {
      final summary = BatchesSummary.from([
        _batch(id: 1, maxStudents: 20, currentStudents: 12),
        _batch(id: 2, maxStudents: 10, currentStudents: 10),
        _batch(id: 3, status: 'Inactive', maxStudents: 5, currentStudents: 1),
      ]);

      expect(summary.total, 3);
      expect(summary.active, 2);
      expect(summary.inactive, 1);
      expect(summary.totalStudents, 23);
      expect(summary.availableSeats, 12);
    });

    test('the total is the server count when one was given', () {
      // A page of two must not claim the academy runs two batches.
      final summary = BatchesSummary.from([
        _batch(id: 1),
        _batch(id: 2),
      ], total: 47);
      expect(summary.total, 47);
    });

    test('unreported students and seats stay null rather than becoming 0', () {
      final summary = BatchesSummary.from([_batch(id: 1), _batch(id: 2)]);
      expect(summary.totalStudents, isNull);
      expect(summary.availableSeats, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('CoachBatchLoad', () {
    test('totals the batches, students and distinct schedules', () {
      final load = CoachBatchLoad(
        coachId: 5,
        coachName: 'Rahul',
        batches: [
          _batch(
            id: 1,
            schedule: '7 AM to 8 AM',
            maxStudents: 20,
            currentStudents: 10,
          ),
          _batch(
            id: 2,
            schedule: '7 AM to 8 AM',
            maxStudents: 20,
            currentStudents: 5,
            status: 'Inactive',
          ),
          _batch(
            id: 3,
            schedule: '6 PM to 7 PM',
            maxStudents: 10,
            currentStudents: 5,
          ),
        ],
      );

      expect(load.totalBatches, 3);
      expect(load.activeBatches, 2);
      expect(load.currentStudents, 20);
      expect(load.maxStudents, 50);
      expect(load.occupancy, 0.4);
      // De-duplicated, in the order first seen.
      expect(load.schedules, ['7 AM to 8 AM', '6 PM to 7 PM']);
    });

    test('a coach whose batches report nothing has unknown, not zero, load',
        () {
      final load = CoachBatchLoad(
        coachId: 5,
        batches: [_batch(id: 1), _batch(id: 2)],
      );

      expect(load.currentStudents, isNull);
      expect(load.maxStudents, isNull);
      expect(load.occupancy, isNull);
      expect(load.schedules, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  group('BatchesController — paging modes', () {
    test('the default read is one server page and the bar follows the server',
        () async {
      final repository = _FakeRepository(total: 47);
      final controller = BatchesController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.isCatalogueMode, isFalse);
      expect(repository.pageCalls, 1);
      expect(repository.catalogueCalls, 0);
      expect(controller.page.page, 1);
      expect(controller.page.total, 47);
      expect(controller.page.effectiveTotalPages, 3);
    });

    test('turning a page is a request, not a slice', () async {
      final repository = _FakeRepository(total: 47);
      final controller = BatchesController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      controller.goToPage(2);
      await Future<void>.delayed(Duration.zero);

      expect(repository.lastPage, 2);
      expect(repository.pageCalls, 2);
    });

    test('searching pulls the whole catalogue, because one page is not enough',
        () async {
      // Without this, "search" would mean "search page one", which looks
      // exactly like "no matches".
      final repository = _FakeRepository(
        catalogue: [
          _batch(id: 1, name: 'Morning Batch'),
          _batch(id: 2, name: 'Evening Batch'),
        ],
      );
      final controller = BatchesController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      controller.onSearchChanged('evening');
      await Future<void>.delayed(BatchesController.searchDebounce * 2);
      await Future<void>.delayed(Duration.zero);

      expect(controller.isCatalogueMode, isTrue);
      expect(repository.catalogueCalls, 1);
      expect(controller.visibleRows.single.id, 2);
    });

    test('sorting also needs the catalogue', () async {
      final repository = _FakeRepository();
      final controller = BatchesController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      controller.toggleSort(BatchSort.fees);
      await Future<void>.delayed(Duration.zero);

      expect(controller.isCatalogueMode, isTrue);
      expect(repository.catalogueCalls, 1);
    });

    test('clearing the last local filter goes back to server paging', () async {
      final repository = _FakeRepository();
      final controller = BatchesController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      controller.setCoachFilter(5);
      await Future<void>.delayed(Duration.zero);
      expect(controller.isCatalogueMode, isTrue);

      controller.setCoachFilter(null);
      await Future<void>.delayed(Duration.zero);
      expect(controller.isCatalogueMode, isFalse);
    });

    test('a second local filter does not re-pull the catalogue', () async {
      // It is already in memory; re-fetching would be a round trip for the
      // same rows.
      final repository = _FakeRepository();
      final controller = BatchesController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      controller.setCoachFilter(5);
      await Future<void>.delayed(Duration.zero);
      final after = repository.catalogueCalls;

      controller.setComplexFilter(2);
      await Future<void>.delayed(Duration.zero);

      expect(repository.catalogueCalls, after);
    });

    test('a page-size change refetches while paging and re-slices otherwise',
        () async {
      final repository = _FakeRepository();
      final controller = BatchesController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      controller.setLimit(50);
      await Future<void>.delayed(Duration.zero);
      expect(repository.lastLimit, 50);

      controller.setCoachFilter(5);
      await Future<void>.delayed(Duration.zero);
      final calls = repository.catalogueCalls;

      controller.setLimit(10);
      await Future<void>.delayed(Duration.zero);
      // Re-slicing a catalogue in memory costs nothing.
      expect(repository.catalogueCalls, calls);
    });

    test('a capped catalogue is reported rather than silently truncated',
        () async {
      final repository = _FakeRepository(capAt: (100, 400));
      final controller = BatchesController(repository);
      addTearDown(controller.dispose);

      controller.setCoachFilter(5);
      await Future<void>.delayed(Duration.zero);

      expect(controller.catalogueCapped, (100, 400));
    });

    test('the summary is page-scoped only while paging a multi-page list',
        () async {
      final repository = _FakeRepository(total: 47);
      final controller = BatchesController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      expect(controller.summaryIsPageScoped, isTrue);
      expect(controller.summary.total, 47);

      controller.setCoachFilter(5);
      await Future<void>.delayed(Duration.zero);
      expect(controller.summaryIsPageScoped, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('BatchesController — filters, sorting and grouped views', () {
    test('search matches the batch, the coach and the sport', () async {
      final controller = BatchesController(
        _FakeRepository(
          catalogue: [
            _batch(id: 1, name: 'Morning', coachName: 'Rahul'),
            _batch(id: 2, name: 'Evening', sportName: 'Football'),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.onSearchChanged('rahul');
      await Future<void>.delayed(BatchesController.searchDebounce * 2);
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.single.id, 1);

      controller.onSearchChanged('football');
      await Future<void>.delayed(BatchesController.searchDebounce * 2);
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.single.id, 2);
    });

    test('the age-group filter is case-insensitive and learned from the rows',
        () async {
      final controller = BatchesController(
        _FakeRepository(
          catalogue: [
            _batch(id: 1, ageGroup: '8-14'),
            _batch(id: 2, ageGroup: '8-14'),
            _batch(id: 3, ageGroup: '15+'),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      expect(controller.knownAgeGroups, ['15+', '8-14']);

      controller.setAgeGroupFilter('8-14');
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.map((b) => b.id), [1, 2]);
    });

    test('sorting by occupancy is numeric and blanks sink both ways', () async {
      final controller = BatchesController(
        _FakeRepository(
          catalogue: [
            _batch(id: 1, maxStudents: 10, currentStudents: 9),
            _batch(id: 2),
            _batch(id: 3, maxStudents: 10, currentStudents: 2),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.toggleSort(BatchSort.occupancy);
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.map((b) => b.id), [3, 1, 2]);

      controller.toggleSort(BatchSort.occupancy);
      expect(controller.visibleRows.map((b) => b.id), [1, 3, 2]);
    });

    test('sorting by a date never dereferences a missing one', () async {
      // The comparator reads startDate!, so the missing-value guard is what
      // keeps this from throwing.
      final controller = BatchesController(
        _FakeRepository(
          catalogue: [
            _batch(id: 1, startDate: DateTime(2026, 3, 1)),
            _batch(id: 2),
            _batch(id: 3, startDate: DateTime(2026, 1, 1)),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.toggleSort(BatchSort.startDate);
      await Future<void>.delayed(Duration.zero);
      expect(controller.visibleRows.map((b) => b.id), [3, 1, 2]);

      controller.toggleSort(BatchSort.startDate);
      expect(controller.visibleRows.map((b) => b.id), [1, 3, 2]);
    });

    test('the sport-wise view calls its own route', () async {
      final repository = _FakeRepository();
      final controller = BatchesController(repository);
      addTearDown(controller.dispose);

      controller.selectGroupSport(8);
      await Future<void>.delayed(Duration.zero);

      expect(repository.lastSportGroupId, 8);
      expect(controller.sportGroup.length, 2);
      expect(controller.sportGroupState.isReady, isTrue);
    });

    test('the coach-wise view calls its own route and names the coach',
        () async {
      final repository = _FakeRepository();
      final controller = BatchesController(repository);
      addTearDown(controller.dispose);
      await controller.loadCoaches();

      controller.selectGroupCoach(5);
      await Future<void>.delayed(Duration.zero);

      expect(repository.lastCoachGroupId, 5);
      expect(controller.coachGroup?.totalBatches, 2);
      expect(controller.coachGroup?.coachName, 'Rahul Sharma');
    });

    test('a grouped-view failure keeps its own error, not the list one',
        () async {
      final controller = BatchesController(_FakeRepository(failGroups: true));
      addTearDown(controller.dispose);

      controller.selectGroupSport(8);
      await Future<void>.delayed(Duration.zero);

      expect(controller.sportGroupState.isFailed, isTrue);
      expect(controller.sportGroupError, 'No batches for that sport');
      expect(controller.state.isFailed, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('BatchesController — writes', () {
    test('a delete is optimistic and restores the row when it fails', () async {
      final controller = BatchesController(_FakeRepository(failDelete: true));
      addTearDown(controller.dispose);
      await controller.load();

      final before = controller.rows.length;
      await expectLater(controller.delete(1), throwsA(isA<Exception>()));

      expect(controller.rows.length, before);
      expect(controller.rows.any((batch) => batch.id == 1), isTrue);
    });

    test('a status change is optimistic and reverts on failure', () async {
      final repository = _FakeRepository(failStatus: true);
      final controller = BatchesController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      await expectLater(
        controller.setStatus(1, AdminUserStatus.inactive),
        throwsA(isA<Exception>()),
      );

      expect(controller.rows.first.status, AdminUserStatus.active);
      expect(controller.isRowBusy(1), isFalse);
    });

    test('a status change reaches the grouped views too', () async {
      final repository = _FakeRepository();
      final controller = BatchesController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      controller.selectGroupSport(8);
      await Future<void>.delayed(Duration.zero);

      await controller.setStatus(1, AdminUserStatus.inactive);

      // The table, the summary cards and both breakdowns must never disagree.
      final grouped = controller.sportGroup.firstWhere((b) => b.id == 1);
      expect(grouped.status, AdminUserStatus.inactive);
    });

    test('a load failure surfaces the server message', () async {
      final controller = BatchesController(_FakeRepository(failList: true));
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.isFailed, isTrue);
      expect(controller.error, 'Batches are unavailable');
    });
  });

  // ---------------------------------------------------------------------------
  group('BatchRepositoryImpl — the wire', () {
    test('the list route sends status, sport, page and limit', () async {
      late Uri captured;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          return http.Response(
            jsonEncode({'success': true, 'data': {'batches': []}}),
            200,
          );
        }),
      );

      await BatchRepositoryImpl().fetchBatches(
        status: AdminUserStatus.active,
        sportId: 8,
        page: 2,
        limit: 50,
      );

      expect(captured.path, endsWith('/batches'));
      expect(captured.queryParameters['status'], 'Active');
      expect(captured.queryParameters['sportId'], '8');
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

      await BatchRepositoryImpl().fetchBatches();

      expect(captured.queryParameters.containsKey('status'), isFalse);
      expect(captured.queryParameters.containsKey('sportId'), isFalse);
    });

    test('fetchAllBatches walks the pages and stops at the cap', () async {
      final pages = <int>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          final page = int.parse(request.url.queryParameters['page']!);
          pages.add(page);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'batches': [
                  {'id': page},
                ],
                'currentPage': page,
                // Always more, so only the cap can stop the walk.
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
      final all = await BatchRepositoryImpl().fetchAllBatches(
        limit: 10,
        maxPages: 3,
        onCapped: (loaded, total) => capped = (loaded, total),
      );

      expect(pages, [1, 2, 3]);
      expect(all.length, 3);
      expect(capped, (3, 990));
    });

    test('the status route is PATCH, not PUT', () async {
      String? call;
      String? body;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          call = '${request.method} ${request.url.path}';
          body = request.body;
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      await BatchRepositoryImpl().setStatus(3, AdminUserStatus.inactive);

      expect(call, endsWith('PATCH /api/batches/3/status'));
      expect(jsonDecode(body!)['status'], 'Inactive');
    });

    test('the grouped routes are their own paths', () async {
      final paths = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      final repository = BatchRepositoryImpl();
      await repository.fetchBatchesBySport(8);
      await repository.fetchBatchesByCoach(5);

      expect(paths[0], endsWith('/batches/sport/8'));
      expect(paths[1], endsWith('/batches/coach/5'));
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

      final repository = BatchRepositoryImpl();

      // Each of these stops at a different guard.
      for (final draft in [
        const BatchDraft(),
        const BatchDraft(name: 'A'),
        const BatchDraft(name: 'A', sportId: 1),
        const BatchDraft(name: 'A', sportId: 1, coachId: 1),
        const BatchDraft(name: 'A', sportId: 1, coachId: 1, sportComplexId: 1),
      ]) {
        await expectLater(
          repository.createBatch(draft),
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
        BatchRepositoryImpl().updateBatch(3, const BatchDraft()),
        throwsA(isA<BadRequestException>()),
      );
      expect(called, isFalse);
    });

    test('an upload that returns no URL is a failure, not a silent success',
        () async {
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      await expectLater(
        BatchRepositoryImpl().uploadImage('does-not-matter.jpg'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}

// -----------------------------------------------------------------------------
// Fakes
// -----------------------------------------------------------------------------

class _FakeRepository implements BatchRepository {
  _FakeRepository({
    List<AdminBatch>? catalogue,
    this.total,
    this.capAt,
    this.failList = false,
    this.failDelete = false,
    this.failStatus = false,
    this.failGroups = false,
  }) : catalogue =
           catalogue ??
           [
             _batch(id: 1, sportId: 8, coachId: 5, fees: 2500),
             _batch(id: 2, sportId: 8, coachId: 5, fees: 1500),
           ];

  final List<AdminBatch> catalogue;

  /// What the server claims the whole collection holds.
  final int? total;

  /// `(loaded, total)` to report through `onCapped`.
  final (int, int)? capAt;

  final bool failList;
  final bool failDelete;
  final bool failStatus;
  final bool failGroups;

  int pageCalls = 0;
  int catalogueCalls = 0;
  int? lastPage;
  int? lastLimit;
  int? lastSportGroupId;
  int? lastCoachGroupId;

  @override
  Future<BatchPageResult> fetchBatches({
    AdminUserStatus? status,
    int? sportId,
    int page = 1,
    int limit = 20,
  }) async {
    pageCalls++;
    lastPage = page;
    lastLimit = limit;
    if (failList) throw const ServerException('Batches are unavailable');

    final totalItems = total ?? catalogue.length;
    return BatchPageResult(
      batches: catalogue,
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
  }) async {
    catalogueCalls++;
    if (failList) throw const ServerException('Batches are unavailable');
    final cap = capAt;
    if (cap != null) onCapped?.call(cap.$1, cap.$2);
    return catalogue;
  }

  @override
  Future<AdminBatch> fetchBatch(int id) async =>
      AdminBatch(id: id, description: 'Detail');

  @override
  Future<BatchStatistics> fetchStats(int id) async =>
      const BatchStatistics(maxStudents: 20, currentStudents: 12);

  @override
  Future<List<AdminBatch>> fetchBatchesBySport(int sportId) async {
    lastSportGroupId = sportId;
    if (failGroups) throw const ServerException('No batches for that sport');
    return catalogue;
  }

  @override
  Future<CoachBatchLoad> fetchBatchesByCoach(
    int coachId, {
    String? coachName,
  }) async {
    lastCoachGroupId = coachId;
    if (failGroups) throw const ServerException('No batches for that coach');
    return CoachBatchLoad(
      coachId: coachId,
      coachName: coachName,
      batches: catalogue,
    );
  }

  @override
  Future<AdminBatch> createBatch(BatchDraft draft) async =>
      const AdminBatch(id: 99);

  @override
  Future<AdminBatch> updateBatch(int id, BatchDraft draft) async =>
      AdminBatch(id: id);

  @override
  Future<void> setStatus(int id, AdminUserStatus status) async {
    if (failStatus) throw const ServerException('Rejected');
  }

  @override
  Future<void> deleteBatch(int id) async {
    if (failDelete) throw const ServerException('Rejected');
  }

  @override
  Future<String> uploadImage(String filePath, {String? filename}) async =>
      'https://cdn/x.jpg';

  @override
  Future<List<Sport>> fetchSports({bool refresh = false}) async =>
      const [Sport(id: 8, name: 'Badminton')];

  @override
  Future<List<Coach>> fetchCoaches({bool refresh = false}) async =>
      const [Coach(id: 5, name: 'Rahul Sharma')];

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async => const [SportsComplex(id: 2, name: 'Kothrud Arena')];
}
