import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/features/admin/data/models/coach_model.dart';
import 'package:nahata_app/features/admin/data/repositories/coach_repository_impl.dart';
import 'package:nahata_app/features/admin/domain/entities/admin_role.dart';
import 'package:nahata_app/features/admin/domain/entities/coach.dart';
import 'package:nahata_app/features/admin/domain/entities/sport.dart';
import 'package:nahata_app/features/admin/domain/repositories/coach_repository.dart';
import 'package:nahata_app/features/admin/presentation/state/coaches_controller.dart';
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

Coach _coach({
  required int id,
  String? name,
  String? email,
  String? phone,
  int? sportId,
  String? sportName,
  int? complexId,
  String? complexName,
  String? ground,
  String? category,
  String? experience,
  num? price,
  String? availability,
  String status = 'Active',
}) {
  return Coach(
    id: id,
    name: name ?? 'Coach $id',
    email: email,
    phone: phone,
    sportId: sportId,
    sportName: sportName,
    sportComplexId: complexId,
    sportComplexName: complexName,
    ground: ground,
    categoryRaw: category,
    experience: experience,
    price: price,
    availabilityRaw: availability,
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
  group('CoachAvailability', () {
    test('reads a comma-separated day list in week order', () {
      final availability = CoachAvailability.parse('Friday, Monday, Wednesday');

      expect(availability.isCustom, isFalse);
      expect(availability.days, [
        Weekday.monday,
        Weekday.wednesday,
        Weekday.friday,
      ]);
      expect(availability.raw, 'Friday, Monday, Wednesday');
    });

    test('accepts short day names and other separators', () {
      expect(
        CoachAvailability.parse('Mon/Tue|Wed').days,
        [Weekday.monday, Weekday.tuesday, Weekday.wednesday],
      );
      expect(CoachAvailability.parse('SAT\nSUN').days, [
        Weekday.saturday,
        Weekday.sunday,
      ]);
    });

    test('one unreadable token makes the whole schedule custom', () {
      // A partial reading would silently drop what the admin actually wrote.
      final availability = CoachAvailability.parse('Monday, 6am-9am');

      expect(availability.isCustom, isTrue);
      expect(availability.days, isEmpty);
      expect(availability.raw, 'Monday, 6am-9am');
    });

    test('an empty or null value is neither custom nor a day list', () {
      for (final value in [null, '', '   ', 'null']) {
        final availability = CoachAvailability.parse(value);
        expect(availability.isEmpty, isTrue);
        expect(availability.isCustom, isFalse);
        expect(availability.days, isEmpty);
      }
    });

    test('availableOn answers only when the schedule can be read', () {
      // 2026-08-03 is a Monday.
      final monday = DateTime(2026, 8, 3);
      final tuesday = DateTime(2026, 8, 4);

      final readable = CoachAvailability.parse('Monday, Friday');
      expect(readable.availableOn(monday), isTrue);
      expect(readable.availableOn(tuesday), isFalse);

      // Unknown, not "unavailable" — nothing here can say either way.
      expect(CoachAvailability.parse('Weekdays only').availableOn(monday),
          isNull);
      expect(CoachAvailability.parse(null).availableOn(monday), isNull);
    });

    test('compose writes the canonical week-ordered string', () {
      expect(
        CoachAvailability.compose({Weekday.sunday, Weekday.tuesday}),
        'Tuesday, Sunday',
      );
      expect(CoachAvailability.compose(const <Weekday>[]), '');
    });

    test('the summary label describes the schedule without inventing days', () {
      expect(CoachAvailability.parse(null).summaryLabel, '—');
      expect(CoachAvailability.parse('Monday').summaryLabel, 'Monday');
      expect(CoachAvailability.parse('Monday, Friday').summaryLabel, '2 days');
      expect(
        CoachAvailability.compose(Weekday.values),
        'Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday',
      );
      expect(
        CoachAvailability.parse(
          CoachAvailability.compose(Weekday.values),
        ).summaryLabel,
        'Every day',
      );
      expect(CoachAvailability.parse('Weekends').summaryLabel, 'Weekends');
    });

    test('Weekday.of maps DateTime weekdays across without an offset bug', () {
      expect(Weekday.of(DateTime(2026, 8, 3)), Weekday.monday);
      expect(Weekday.of(DateTime(2026, 8, 9)), Weekday.sunday);
      expect(Weekday.monday.dateTimeWeekday, DateTime.monday);
      expect(Weekday.sunday.dateTimeWeekday, DateTime.sunday);
    });
  });

  // ---------------------------------------------------------------------------
  group('CoachMapper', () {
    test('parses a full record with nested sport and complex objects', () {
      final coach = CoachMapper.fromJson({
        'id': 3,
        'name': 'Rahul Sharma',
        'email': 'rahul@nahatasports.com',
        'phone': '9876543210',
        'image': 'https://cdn.example.com/r.jpg',
        'ground': 'Court 3',
        'experience': '5 years',
        'price': 1200,
        'certification': 'NIS Level 2',
        'qualifications': 'BPEd',
        'specialization': 'Junior coaching',
        'bio': 'Ten years on the circuit.',
        'availability': 'Monday, Wednesday',
        'status': 'Active',
        'sport': {'id': 7, 'name': 'Badminton', 'category': 'Indoor'},
        'sportComplex': {'id': 4, 'name': 'Kothrud Arena'},
        'createdAt': '2025-03-01',
      });

      expect(coach.id, 3);
      expect(coach.name, 'Rahul Sharma');
      expect(coach.email, 'rahul@nahatasports.com');
      expect(coach.phone, '9876543210');
      expect(coach.ground, 'Court 3');
      expect(coach.experience, '5 years');
      expect(coach.price, 1200);
      expect(coach.certification, 'NIS Level 2');
      expect(coach.qualifications, 'BPEd');
      expect(coach.specialization, 'Junior coaching');
      expect(coach.sportId, 7);
      expect(coach.sportName, 'Badminton');
      // The category rides on the sport, not on the coach.
      expect(coach.category, SportCategory.indoor);
      expect(coach.sportComplexId, 4);
      expect(coach.sportComplexName, 'Kothrud Arena');
      expect(coach.status, AdminUserStatus.active);
      expect(coach.availability.days, [Weekday.monday, Weekday.wednesday]);
    });

    test('reads snake_case and a nested coach envelope', () {
      final coach = CoachMapper.fromJson({
        'coach': {
          '_id': 9,
          'coachName': 'Priya Nair',
          'phoneNumber': '9000000000',
          'sport_id': 2,
          'sport_name': 'Football',
          'sport_complex_id': 5,
          'complexName': 'Baner Ground',
          'profileImage': 'uploads/p.jpg',
          'specialisation': 'Goalkeeping',
          'sport_category': 'Outdoor',
        },
      });

      expect(coach.id, 9);
      expect(coach.name, 'Priya Nair');
      expect(coach.phone, '9000000000');
      expect(coach.sportId, 2);
      expect(coach.sportName, 'Football');
      expect(coach.sportComplexId, 5);
      expect(coach.sportComplexName, 'Baner Ground');
      expect(coach.specialization, 'Goalkeeping');
      expect(coach.category, SportCategory.outdoor);
    });

    test('availability arrives as a string or as a list of days', () {
      final asList = CoachMapper.fromJson({
        'id': 1,
        'availableDays': ['Monday', 'Friday'],
      });
      expect(asList.availabilityRaw, 'Monday, Friday');
      expect(asList.availability.days, [Weekday.monday, Weekday.friday]);

      final asString = CoachMapper.fromJson({
        'id': 1,
        'availability': 'Tuesday',
      });
      expect(asString.availability.days, [Weekday.tuesday]);
    });

    test('a price sent as a formatted string still reads as a number', () {
      expect(CoachMapper.fromJson({'id': 1, 'price': '1200'}).price, 1200);
      expect(CoachMapper.fromJson({'id': 1, 'price': '₹1,200'}).price, 1200);
      expect(CoachMapper.fromJson({'id': 1, 'price': 1499.5}).price, 1499.5);
      // Unparseable is null, never a zero fee the API never sent.
      expect(CoachMapper.fromJson({'id': 1, 'price': 'on request'}).price,
          isNull);
      expect(CoachMapper.fromJson({'id': 1}).price, isNull);
    });

    test('assigned sports come from strings or from objects', () {
      final fromStrings = CoachMapper.fromJson({
        'id': 1,
        'sports': ['Badminton', 'Squash'],
      });
      expect(fromStrings.sportNames, ['Badminton', 'Squash']);

      final fromObjects = CoachMapper.fromJson({
        'id': 1,
        'assignedSports': [
          {'name': 'Tennis'},
          {'sportName': 'Padel'},
        ],
      });
      expect(fromObjects.sportNames, ['Tennis', 'Padel']);
    });

    test('allSportNames leads with the primary and never repeats it', () {
      final coach = CoachMapper.fromJson({
        'id': 1,
        'sportName': 'Badminton',
        'sports': ['badminton', 'Squash'],
      });

      expect(coach.allSportNames, ['Badminton', 'Squash']);
    });

    test('rows without an id are dropped from the list', () {
      final coaches = CoachMapper.listFrom({
        'coaches': [
          {'id': 1, 'name': 'A'},
          {'name': 'No id'},
          {'id': 2, 'name': 'B'},
        ],
      });

      expect(coaches.map((coach) => coach.id), [1, 2]);
    });

    test('a bare list body is read as the list', () {
      final coaches = CoachMapper.listFrom([
        {'id': 4, 'name': 'Solo'},
      ]);
      expect(coaches.single.name, 'Solo');
    });

    test('the upload route answers in several shapes, all accepted', () {
      expect(
        CoachMapper.uploadedUrlFrom('https://cdn/a.jpg'),
        'https://cdn/a.jpg',
      );
      expect(
        CoachMapper.uploadedUrlFrom({'imageUrl': 'https://cdn/b.jpg'}),
        'https://cdn/b.jpg',
      );
      expect(
        CoachMapper.uploadedUrlFrom({
          'data': {'image': 'uploads/c.jpg'},
        }),
        'uploads/c.jpg',
      );
      expect(CoachMapper.uploadedUrlFrom({'ok': true}), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('CoachStatsMapper', () {
    test('reads a nested stats envelope', () {
      final stats = CoachStatsMapper.fromJson({
        'stats': {
          'totalPrograms': 6,
          'activePrograms': 4,
          'totalStudents': 48,
          'status': 'Active',
        },
      });

      expect(stats.totalPrograms, 6);
      expect(stats.activePrograms, 4);
      expect(stats.totalStudents, 48);
      expect(stats.status, AdminUserStatus.active);
    });

    test('a counter the route omitted stays null rather than becoming 0', () {
      final stats = CoachStatsMapper.fromJson({'totalStudents': 3});

      expect(stats.totalStudents, 3);
      expect(stats.totalPrograms, isNull);
      expect(stats.activePrograms, isNull);
      expect(stats.isEmpty, isFalse);
      expect(const CoachStats().isEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('CoachCredentialsMapper', () {
    test('accepts every spelling the credentials route might use', () {
      expect(
        CoachCredentialsMapper.fromJson({
          'email': 'a@b.com',
          'temporaryPassword': 'secret1',
        }).password,
        'secret1',
      );
      expect(
        CoachCredentialsMapper.fromJson({
          'credentials': {'email': 'a@b.com', 'password': 'secret2'},
        }).email,
        'a@b.com',
      );
    });

    test('toString never leaks the password', () {
      const credentials = CoachCredentials(
        email: 'a@b.com',
        password: 'hunter2',
      );

      expect(credentials.hasPassword, isTrue);
      expect(credentials.toString(), contains('***'));
      expect(credentials.toString(), isNot(contains('hunter2')));
    });
  });

  // ---------------------------------------------------------------------------
  group('CoachDraft', () {
    test('the create payload carries every documented key', () {
      final body = const CoachDraft(
        name: ' Rahul ',
        email: 'rahul@nahatasports.com',
        phone: '9876543210',
        password: 'secret123',
        sportId: 7,
        sportComplexId: 4,
        ground: 'Court 3',
        price: 1200,
        availability: 'Monday, Friday',
        certification: 'NIS',
        bio: 'Bio',
        image: 'https://cdn/x.jpg',
        experience: '5 years',
        specialization: 'Juniors',
        qualifications: 'BPEd',
        status: AdminUserStatus.inactive,
      ).toCreateJson();

      expect(body.keys, containsAll(const [
        'name',
        'email',
        'phone',
        'password',
        'sportId',
        'sportComplexId',
        'ground',
        'price',
        'availability',
        'certification',
        'bio',
        'image',
        'experience',
        'specialization',
        'qualifications',
        'status',
      ]));

      expect(body['name'], 'Rahul');
      expect(body['sportId'], 7);
      expect(body['price'], 1200);
      expect(body['status'], 'Inactive');
    });

    test('create defaults to Active and sends blanks, not nulls, for text', () {
      final body = const CoachDraft(name: 'A', email: 'a@b.com').toCreateJson();

      expect(body['status'], 'Active');
      expect(body['bio'], '');
      expect(body['ground'], '');
      // A fee nobody typed is "not specified", not a free session.
      expect(body['price'], isNull);
    });

    test('the update payload sends only the eleven editable fields', () {
      final body = const CoachDraft(
        name: 'Rahul',
        email: 'ignored@example.com',
        password: 'ignored',
        sportId: 9,
        sportComplexId: 9,
        ground: 'ignored',
        phone: '9876543210',
        experience: '6 years',
        price: 1500,
        certification: 'NIS',
        qualifications: 'BPEd',
        specialization: 'Juniors',
        bio: 'Updated',
        availability: 'Monday',
        image: '',
        status: AdminUserStatus.active,
      ).toUpdateJson();

      expect(body.keys.toSet(), {
        'name',
        'phone',
        'experience',
        'price',
        'certification',
        'qualifications',
        'specialization',
        'bio',
        'availability',
        'image',
        'status',
      });
      // The route documents none of these as editable.
      expect(body.containsKey('email'), isFalse);
      expect(body.containsKey('password'), isFalse);
      expect(body.containsKey('sportId'), isFalse);
      expect(body.containsKey('sportComplexId'), isFalse);
      expect(body.containsKey('ground'), isFalse);
    });

    test('an update omits untouched fields but keeps deliberate blanks', () {
      final body = const CoachDraft(bio: '', status: null).toUpdateJson();

      // A bio cleared on purpose has to reach the server, or it could never be
      // erased once written.
      expect(body, {'bio': ''});
    });
  });

  // ---------------------------------------------------------------------------
  group('CoachesSummary', () {
    test('counts statuses, distinct sports and distinct complexes', () {
      final summary = CoachesSummary.from([
        _coach(id: 1, sportName: 'Badminton', complexId: 1),
        _coach(id: 2, sportName: 'badminton', complexId: 1),
        _coach(id: 3, sportName: 'Football', complexId: 2, status: 'Inactive'),
      ]);

      expect(summary.total, 3);
      expect(summary.active, 2);
      expect(summary.inactive, 1);
      // Case-insensitive, so one sport is not counted twice.
      expect(summary.sportsCovered, 2);
      expect(summary.complexesCovered, 2);
    });

    test('availableToday counts only the schedules it can read', () {
      final monday = DateTime(2026, 8, 3);

      final summary = CoachesSummary.from([
        _coach(id: 1, availability: 'Monday, Friday'),
        _coach(id: 2, availability: 'Tuesday'),
        _coach(id: 3, availability: 'Alternate weekends'),
        _coach(id: 4),
      ], now: monday);

      expect(summary.availableToday, 1);
    });

    test('availableToday is null when no schedule can be read at all', () {
      // An em dash, not a zero — the rows say nothing about today.
      final summary = CoachesSummary.from([
        _coach(id: 1),
        _coach(id: 2, availability: 'By appointment'),
      ], now: DateTime(2026, 8, 3));

      expect(summary.availableToday, isNull);
    });

    test('a complex with no id falls back to its name', () {
      final summary = CoachesSummary.from([
        _coach(id: 1, complexName: 'Kothrud Arena'),
        _coach(id: 2, complexName: 'kothrud arena'),
      ]);

      expect(summary.complexesCovered, 1);
    });
  });

  // ---------------------------------------------------------------------------
  group('CoachesController — filters and sorting', () {
    test('search matches the name, the email and the phone', () async {
      final controller = CoachesController(
        _FakeRepository(
          coaches: [
            _coach(id: 1, name: 'Rahul', email: 'rahul@x.com', phone: '9111'),
            _coach(id: 2, name: 'Priya', email: 'priya@x.com', phone: '9222'),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.onSearchChanged('priya@');
      await Future<void>.delayed(CoachesController.searchDebounce * 2);
      expect(controller.visibleRows.single.id, 2);

      controller.onSearchChanged('9111');
      await Future<void>.delayed(CoachesController.searchDebounce * 2);
      expect(controller.visibleRows.single.id, 1);

      controller.clearSearch();
      expect(controller.visibleRows.length, 2);
    });

    test('the complex and category filters are applied locally', () async {
      final repository = _FakeRepository(
        coaches: [
          _coach(id: 1, complexId: 1, category: 'Indoor'),
          _coach(id: 2, complexId: 2, category: 'Outdoor'),
          _coach(id: 3, complexId: 1, category: 'Outdoor'),
        ],
      );
      final controller = CoachesController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      final before = repository.listCalls;

      controller.setComplexFilter(1);
      expect(controller.visibleRows.map((c) => c.id), [1, 3]);

      controller.setCategoryFilter(SportCategory.outdoor);
      expect(controller.visibleRows.single.id, 3);

      // Neither filter is a route parameter, so neither costs a round trip.
      expect(repository.listCalls, before);
    });

    test('the sport filter switches the read to the sport route', () async {
      final repository = _FakeRepository();
      final controller = CoachesController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      expect(repository.lastSportId, isNull);

      controller.setSportFilter(7);
      await Future<void>.delayed(Duration.zero);
      expect(repository.lastSportId, 7);
    });

    test('status is re-applied locally, because the sport route ignores it',
        () async {
      // The fake answers the sport route with rows of both statuses, exactly
      // as a backend that does not filter them would.
      final repository = _FakeRepository(
        coaches: [
          _coach(id: 1, status: 'Active'),
          _coach(id: 2, status: 'Inactive'),
        ],
        ignoreStatus: true,
      );
      final controller = CoachesController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      controller.setSportFilter(7);
      await Future<void>.delayed(Duration.zero);
      controller.setStatusFilter(AdminUserStatus.active);
      await Future<void>.delayed(Duration.zero);

      expect(controller.rows.length, 2);
      expect(controller.visibleRows.single.id, 1);
    });

    test('sorting by price is numeric and blanks sink in both directions',
        () async {
      final controller = CoachesController(
        _FakeRepository(
          coaches: [
            _coach(id: 1, price: 900),
            _coach(id: 2),
            _coach(id: 3, price: 1500),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.toggleSort(CoachSort.price);
      expect(controller.visibleRows.map((c) => c.id), [1, 3, 2]);

      controller.toggleSort(CoachSort.price);
      expect(controller.visibleRows.map((c) => c.id), [3, 1, 2]);

      // A third tap restores the API's own order.
      controller.toggleSort(CoachSort.price);
      expect(controller.sort, isNull);
      expect(controller.visibleRows.map((c) => c.id), [1, 2, 3]);
    });

    test('experience sorts on its leading number, not alphabetically',
        () async {
      final controller = CoachesController(
        _FakeRepository(
          coaches: [
            _coach(id: 1, experience: '10 years'),
            _coach(id: 2, experience: '2 years'),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.toggleSort(CoachSort.experience);
      expect(controller.visibleRows.map((c) => c.id), [2, 1]);
    });

    test('paging slices the filtered rows and clamps out-of-range pages',
        () async {
      final controller = CoachesController(
        _FakeRepository(
          coaches: List.generate(25, (index) => _coach(id: index + 1)),
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      controller.setLimit(10);
      expect(controller.pageRows.length, 10);
      expect(controller.page.effectiveTotalPages, 3);

      controller.goToPage(3);
      expect(controller.pageRows.length, 5);

      controller.goToPage(99);
      expect(controller.page.page, 3);
    });

    test('clearFilters refetches only when a server-side filter was set',
        () async {
      final repository = _FakeRepository();
      final controller = CoachesController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      controller.setComplexFilter(1);
      final afterLocal = repository.listCalls;
      controller.clearFilters();
      expect(repository.listCalls, afterLocal);

      controller.setStatusFilter(AdminUserStatus.active);
      await Future<void>.delayed(Duration.zero);
      final afterServer = repository.listCalls;
      controller.clearFilters();
      await Future<void>.delayed(Duration.zero);
      expect(repository.listCalls, afterServer + 1);
    });

    test('knownGrounds is learned from the rows, de-duplicated and sorted',
        () async {
      final controller = CoachesController(
        _FakeRepository(
          coaches: [
            _coach(id: 1, ground: 'Court 3'),
            _coach(id: 2, ground: 'court 3'),
            _coach(id: 3, ground: 'Arena A'),
            _coach(id: 4),
          ],
        ),
      );
      addTearDown(controller.dispose);
      await controller.load();

      expect(controller.knownGrounds, ['Arena A', 'Court 3']);
    });
  });

  // ---------------------------------------------------------------------------
  group('CoachesController — detail, writes and failures', () {
    test('a detail failure notes itself instead of blanking the drawer',
        () async {
      final controller = CoachesController(_FakeRepository(failDetail: true));
      addTearDown(controller.dispose);
      await controller.load();

      await controller.openCoach(controller.rows.first);

      // `/coaches/{id}` is not part of the documented module, so its failure
      // must leave the row on screen rather than replacing it with an error.
      expect(controller.selected, isNotNull);
      expect(controller.detailState.isFailed, isFalse);
      expect(controller.detailError, isNotNull);
      expect(controller.stats, isNotNull);
    });

    test('a stats failure leaves the rest of the drawer intact', () async {
      final controller = CoachesController(_FakeRepository(failStats: true));
      addTearDown(controller.dispose);
      await controller.load();

      await controller.openCoach(controller.rows.first);

      expect(controller.statsState.isFailed, isTrue);
      expect(controller.detailError, isNull);
      expect(controller.selected, isNotNull);
    });

    test('a delete is optimistic and restores the row when it fails', () async {
      final repository = _FakeRepository(failDelete: true);
      final controller = CoachesController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      final before = controller.rows.length;
      await expectLater(controller.delete(1), throwsA(isA<Exception>()));

      expect(controller.rows.length, before);
      expect(controller.rows.any((coach) => coach.id == 1), isTrue);
    });

    test('a status change is a PUT of that one field, and reverts on failure',
        () async {
      final repository = _FakeRepository(failUpdate: true);
      final controller = CoachesController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      await expectLater(
        controller.setStatus(1, AdminUserStatus.inactive),
        throwsA(isA<Exception>()),
      );

      expect(controller.rows.first.status, AdminUserStatus.active);
      // There is no /status route, so the write went through updateCoach.
      expect(repository.lastUpdateDraft?.status, AdminUserStatus.inactive);
      expect(controller.isRowBusy(1), isFalse);
    });

    test('a status change that is already in force does nothing', () async {
      final repository = _FakeRepository();
      final controller = CoachesController(repository);
      addTearDown(controller.dispose);
      await controller.load();

      await controller.setStatus(1, AdminUserStatus.active);
      expect(repository.lastUpdateDraft, isNull);
    });

    test('a load failure surfaces the server message', () async {
      final controller = CoachesController(_FakeRepository(failList: true));
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.isFailed, isTrue);
      expect(controller.error, 'Coaches are unavailable');
    });

    test('a superseded response is dropped rather than overwriting a newer one',
        () async {
      final repository = _SlowRepository();
      final controller = CoachesController(repository);
      addTearDown(controller.dispose);

      final first = controller.load();
      final second = controller.load();
      await Future.wait([first, second]);

      // Both requests answered; only the newer one is allowed to land.
      expect(repository.listCalls, 2);
      expect(controller.rows.single.id, 2);
    });
  });

  // ---------------------------------------------------------------------------
  group('CoachRepositoryImpl — the wire', () {
    test('the list route sends the status and nothing it was not given',
        () async {
      late Uri captured;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      await CoachRepositoryImpl().fetchCoaches(status: AdminUserStatus.active);

      expect(captured.path, endsWith('/coaches'));
      expect(captured.queryParameters['status'], 'Active');

      await CoachRepositoryImpl().fetchCoaches();
      expect(captured.queryParameters.containsKey('status'), isFalse);
    });

    test('a sport filter takes the sport route instead of a query parameter',
        () async {
      late Uri captured;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      await CoachRepositoryImpl().fetchCoaches(
        status: AdminUserStatus.active,
        sportId: 7,
      );

      expect(captured.path, endsWith('/coaches/sport/7'));
      // The route takes no status; the controller re-applies it locally.
      expect(captured.queryParameters.containsKey('status'), isFalse);
    });

    test('the credential and reset routes use the documented verbs', () async {
      final calls = <String>[];
      final bodies = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          bodies.add(request.body);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'email': 'a@b.com', 'password': 'secret1'},
            }),
            200,
          );
        }),
      );

      final repository = CoachRepositoryImpl();
      final credentials = await repository.fetchCredentials(3);
      await repository.resetPassword(3, 'newSecret123');

      expect(calls[0], endsWith('GET /api/coaches/3/password'));
      expect(calls[1], endsWith('POST /api/coaches/3/reset-password'));
      expect(jsonDecode(bodies[1])['password'], 'newSecret123');
      expect(credentials.password, 'secret1');
    });

    test('update is a PUT and delete is a DELETE on the id route', () async {
      final calls = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      final repository = CoachRepositoryImpl();
      await repository.updateCoach(3, const CoachDraft(name: 'A'));
      await repository.deleteCoach(3);

      expect(calls[0], endsWith('PUT /api/coaches/3'));
      expect(calls[1], endsWith('DELETE /api/coaches/3'));
    });

    test('create validates before spending a round trip', () async {
      var called = false;
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          called = true;
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      final repository = CoachRepositoryImpl();

      await expectLater(
        repository.createCoach(const CoachDraft()),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        repository.createCoach(const CoachDraft(name: 'A')),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        repository.createCoach(
          const CoachDraft(name: 'A', email: 'a@b.com', password: 'secret1'),
        ),
        throwsA(isA<ValidationException>()),
      );

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
        CoachRepositoryImpl().updateCoach(3, const CoachDraft()),
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
        CoachRepositoryImpl().uploadImage('does-not-matter.jpg'),
        throwsA(isA<ApiException>()),
      );
    });
  });
}

// -----------------------------------------------------------------------------
// Fakes
// -----------------------------------------------------------------------------

class _FakeRepository implements CoachRepository {
  _FakeRepository({
    List<Coach>? coaches,
    this.failList = false,
    this.failDetail = false,
    this.failStats = false,
    this.failDelete = false,
    this.failUpdate = false,
    this.ignoreStatus = false,
  }) : coaches =
           coaches ??
           [
             _coach(id: 1, sportName: 'Badminton', complexId: 1),
             _coach(id: 2, sportName: 'Football', complexId: 1),
           ];

  final List<Coach> coaches;
  final bool failList;
  final bool failDetail;
  final bool failStats;
  final bool failDelete;
  final bool failUpdate;

  /// Mimics a backend that answers the sport route without honouring status.
  final bool ignoreStatus;

  int listCalls = 0;
  int? lastSportId;
  CoachDraft? lastUpdateDraft;

  @override
  Future<List<Coach>> fetchCoaches({
    AdminUserStatus? status,
    int? sportId,
  }) async {
    listCalls++;
    lastSportId = sportId;
    if (failList) throw const ServerException('Coaches are unavailable');
    if (status == null || ignoreStatus || sportId != null) return coaches;
    return coaches.where((coach) => coach.status == status).toList();
  }

  @override
  Future<Coach> fetchCoach(int id) async {
    if (failDetail) throw const ServerException('No such coach');
    return Coach(id: id, bio: 'Detail bio');
  }

  @override
  Future<CoachStats> fetchStats(int id) async {
    if (failStats) throw const ServerException('No stats');
    return const CoachStats(
      totalPrograms: 4,
      activePrograms: 3,
      totalStudents: 30,
    );
  }

  @override
  Future<Coach> createCoach(CoachDraft draft) async => const Coach(id: 99);

  @override
  Future<Coach> updateCoach(int id, CoachDraft draft) async {
    lastUpdateDraft = draft;
    if (failUpdate) throw const ServerException('Rejected');
    return Coach(id: id);
  }

  @override
  Future<void> deleteCoach(int id) async {
    if (failDelete) throw const ServerException('Rejected');
  }

  @override
  Future<CoachCredentials> fetchCredentials(int id) async =>
      const CoachCredentials(email: 'a@b.com', password: 'secret1');

  @override
  Future<void> resetPassword(int id, String password) async {}

  @override
  Future<String> uploadImage(String filePath, {String? filename}) async =>
      'https://cdn/x.jpg';

  @override
  Future<List<Sport>> fetchSports({bool refresh = false}) async =>
      const [Sport(id: 7, name: 'Badminton')];

  @override
  Future<List<SportsComplex>> fetchSportComplexes({bool refresh = false}) async
  => const [SportsComplex(id: 1, name: 'Kothrud Arena')];
}

/// Answers the second call first, so the controller's request-id guard has
/// something to drop.
class _SlowRepository extends _FakeRepository {
  @override
  Future<List<Coach>> fetchCoaches({
    AdminUserStatus? status,
    int? sportId,
  }) async {
    listCalls++;
    final id = listCalls;
    await Future<void>.delayed(Duration(milliseconds: id == 1 ? 40 : 5));
    return [_coach(id: id)];
  }
}
