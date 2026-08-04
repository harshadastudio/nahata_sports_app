import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/features/admin/data/models/sport_model.dart';
import 'package:nahata_app/features/admin/data/repositories/sport_repository_impl.dart';
import 'package:nahata_app/features/admin/domain/entities/admin_role.dart';
import 'package:nahata_app/features/admin/domain/entities/sport.dart';
import 'package:nahata_app/features/admin/domain/repositories/sport_repository.dart';
import 'package:nahata_app/features/admin/presentation/state/sports_controller.dart';
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

Sport _sport({
  required int id,
  String? name,
  int? complexId,
  String? complexName,
  String category = 'Indoor',
  String status = 'Active',
  bool? showOnFrontend = true,
  int? programCount,
  int? courtCount,
  int? allowedMembers,
}) {
  return Sport(
    id: id,
    name: name ?? 'Sport $id',
    sportComplexId: complexId,
    sportComplexName: complexName,
    categoryRaw: category,
    statusRaw: status,
    showOnFrontend: showOnFrontend,
    programCount: programCount,
    courtCount: courtCount,
    allowedMembers: allowedMembers,
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
  group('SportCategory', () {
    test('parses case-insensitively and labels an unknown value readably', () {
      expect(SportCategory.tryParse('indoor'), SportCategory.indoor);
      expect(SportCategory.tryParse('OUTDOOR'), SportCategory.outdoor);
      expect(SportCategory.tryParse(''), isNull);
      expect(SportCategory.tryParse(null), isNull);

      expect(SportCategory.labelFor('aquatic'), 'Aquatic');
      expect(SportCategory.labelFor(null), '—');
    });

    test('slugs are the exact wire values the payload documents', () {
      expect(SportCategory.indoor.slug, 'Indoor');
      expect(SportCategory.outdoor.slug, 'Outdoor');
    });
  });

  // ---------------------------------------------------------------------------
  group('SportMapper', () {
    test('parses a full record with a nested complex', () {
      final sport = SportMapper.fromJson({
        'id': 3,
        'name': 'Badminton',
        'image': 'https://cdn.example.com/b.jpg',
        'category': 'Indoor',
        'description': 'Shuttle sport',
        'equipmentRequired': 'Racket',
        'achievements': 'State champions 2024',
        'completeInformation': 'Everything else',
        'minAge': 6,
        'maxAge': 45,
        'duration': '60 mins',
        'allowedMembers': 4,
        'status': 'Active',
        'showOnFrontend': true,
        'courtCount': 5,
        'availableCourts': 2,
        'sportComplex': {'id': 4, 'name': 'Kothrud Arena'},
        'createdAt': '2025-03-01',
      });

      expect(sport.id, 3);
      expect(sport.name, 'Badminton');
      expect(sport.category, SportCategory.indoor);
      expect(sport.minAge, 6);
      expect(sport.maxAge, 45);
      expect(sport.duration, '60 mins');
      expect(sport.allowedMembers, 4);
      expect(sport.status, AdminUserStatus.active);
      expect(sport.showOnFrontend, isTrue);
      expect(sport.courtCount, 5);
      expect(sport.availableCourts, 2);
      expect(sport.sportComplexId, 4);
      expect(sport.sportComplexName, 'Kothrud Arena');
      expect(sport.ageRangeLabel, '6–45 yrs');
    });

    test('reads snake_case and a nested sport envelope', () {
      final sport = SportMapper.fromJson({
        'sport': {
          '_id': 9,
          'sportName': 'Football',
          'sport_complex_id': 2,
          'min_age': 8,
          'allowed_members': 22,
          'show_on_frontend': false,
          'equipment_required': 'Boots',
        },
      });

      expect(sport.id, 9);
      expect(sport.name, 'Football');
      expect(sport.sportComplexId, 2);
      expect(sport.minAge, 8);
      expect(sport.allowedMembers, 22);
      expect(sport.showOnFrontend, isFalse);
      expect(sport.equipmentRequired, 'Boots');
    });

    test('programme names come from strings or from objects', () {
      final fromStrings = SportMapper.fromJson({
        'id': 1,
        'programs': ['Beginners', 'Advanced'],
      });
      expect(fromStrings.programNames, ['Beginners', 'Advanced']);

      final fromObjects = SportMapper.fromJson({
        'id': 1,
        'batches': [
          {'name': 'Morning Batch'},
          {'title': 'Evening Batch'},
        ],
      });
      expect(fromObjects.programNames, ['Morning Batch', 'Evening Batch']);
    });

    test('the programme count falls back to the number of names', () {
      // A payload that lists programmes but sends no counter still fills the
      // row badge rather than showing an em dash beside two visible names.
      final derived = SportMapper.fromJson({
        'id': 1,
        'programs': ['A', 'B', 'C'],
      });
      expect(derived.programCount, 3);

      // An explicit counter always wins.
      final explicit = SportMapper.fromJson({
        'id': 1,
        'programCount': 7,
        'programs': ['A'],
      });
      expect(explicit.programCount, 7);
    });

    test('an absent visibility key stays null rather than becoming false', () {
      final sport = SportMapper.fromJson({'id': 1});
      expect(sport.showOnFrontend, isNull);
      expect(sport.programCount, isNull);
      expect(sport.courtCount, isNull);
    });

    test('drops rows with no id', () {
      final sports = SportMapper.listFrom({
        'sports': [
          {'id': 1, 'name': 'Kept'},
          {'name': 'Dropped'},
        ],
      });
      expect(sports.map((s) => s.id), [1]);
    });

    test('one bound alone still reads as a range', () {
      expect(const Sport(id: 1, minAge: 6).ageRangeLabel, '6 yrs and up');
      expect(const Sport(id: 1, maxAge: 45).ageRangeLabel, 'Up to 45 yrs');
      expect(const Sport(id: 1).ageRangeLabel, '—');
    });

    test('mergedWith keeps a field the detail route omitted', () {
      const row = Sport(id: 1, name: 'Badminton', courtCount: 5);
      const detail = Sport(id: 1, description: 'Shuttle sport');

      final merged = row.mergedWith(detail);
      expect(merged.courtCount, 5);
      expect(merged.description, 'Shuttle sport');
    });
  });

  // ---------------------------------------------------------------------------
  group('Upload response parsing', () {
    test('accepts every shape the route might answer with', () {
      expect(SportMapper.uploadedUrlFrom('https://cdn/x.jpg'), 'https://cdn/x.jpg');
      expect(
        SportMapper.uploadedUrlFrom({'imageUrl': '/uploads/x.jpg'}),
        '/uploads/x.jpg',
      );
      expect(
        SportMapper.uploadedUrlFrom({
          'data': {'image': 'x.jpg'},
        }),
        'x.jpg',
      );
      expect(SportMapper.uploadedUrlFrom({'ok': true}), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('SportDraft', () {
    test('the create body carries every documented key', () {
      final body = const SportDraft(
        name: '  Badminton ',
        sportComplexId: 1,
        description: 'Shuttle sport',
        category: SportCategory.indoor,
        minAge: 6,
        maxAge: 45,
        duration: '60 mins',
        equipmentRequired: 'Racket',
        image: 'https://cdn/x.jpg',
        allowedMembers: 4,
        achievements: 'Champions',
        completeInformation: 'More',
        showOnFrontend: true,
      ).toCreateJson();

      expect(body.keys, {
        'name',
        'sportComplexId',
        'description',
        'category',
        'minAge',
        'maxAge',
        'duration',
        'equipmentRequired',
        'image',
        'allowedMembers',
        'achievements',
        'completeInformation',
        'status',
        'showOnFrontend',
      });
      expect(body['name'], 'Badminton');
      expect(body['category'], 'Indoor');
      // Numbers stay numbers — the documented payload sends 6, not "6".
      expect(body['minAge'], isA<int>());
      expect(body['minAge'], 6);
      expect(body['allowedMembers'], 4);
      expect(body['showOnFrontend'], isTrue);
      // Nothing chosen on the form means the sport starts Active.
      expect(body['status'], 'Active');
    });

    test('an unset number is null, not zero', () {
      // A blank age must read as "not specified" rather than as a real 0.
      final body = const SportDraft(name: 'X', sportComplexId: 1).toCreateJson();
      expect(body['minAge'], isNull);
      expect(body['maxAge'], isNull);
      expect(body['allowedMembers'], isNull);
      expect(body['description'], '');
      expect(body['showOnFrontend'], isFalse);
    });

    test('an update sends a deliberately blanked field', () {
      // A sport's achievements are legitimately clearable, so an empty string
      // must survive to the wire.
      final body = const SportDraft(
        name: 'Badminton',
        achievements: '',
        image: '',
      ).toUpdateJson();

      expect(body['name'], 'Badminton');
      expect(body.containsKey('achievements'), isTrue);
      expect(body['achievements'], '');
      expect(body['image'], '');
      // A field the form never touched is still omitted.
      expect(body.containsKey('duration'), isFalse);
    });

    test('an update with nothing set is empty', () {
      expect(const SportDraft().toUpdateJson(), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  group('SportRepositoryImpl', () {
    tearDown(() {
      ApiClient.instance.overrideHttpClient(http.Client());
    });

    test('the list forwards only the two parameters the route takes', () async {
      late Uri captured;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      await SportRepositoryImpl().fetchSports(
        status: AdminUserStatus.active,
        complexId: 4,
      );

      expect(captured.path, endsWith('/sports'));
      expect(captured.queryParameters['status'], 'Active');
      expect(captured.queryParameters['sportComplexId'], '4');
    });

    test('an unset filter is never sent as an empty parameter', () async {
      late Uri captured;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      await SportRepositoryImpl().fetchSports();

      expect(captured.queryParameters.containsKey('status'), isFalse);
      expect(captured.queryParameters.containsKey('sportComplexId'), isFalse);
    });

    test('status and visibility go out as PATCH, not PUT', () async {
      final calls = <String>[];
      final bodies = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          bodies.add(request.body);
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      final repository = SportRepositoryImpl();
      await repository.setStatus(3, AdminUserStatus.inactive);
      await repository.setVisibility(3, true);

      // The sports routes differ from the sports-complex ones here.
      expect(calls[0], endsWith('PATCH /api/sports/3/status'));
      expect(calls[1], endsWith('PATCH /api/sports/3/show-on-frontend'));
      expect(jsonDecode(bodies[0])['status'], 'Inactive');
      expect(jsonDecode(bodies[1])['showOnFrontend'], isTrue);
    });

    test('assign-ground posts the complex id', () async {
      String? path;
      String? method;
      String? body;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          path = request.url.path;
          method = request.method;
          body = request.body;
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      await SportRepositoryImpl().assignComplex(3, 7);

      expect(method, 'POST');
      expect(path, endsWith('/sports/3/assign-ground'));
      expect(jsonDecode(body!)['sportComplexId'], 7);
    });

    test('the detail and stats routes hit their documented paths', () async {
      final paths = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'id': 3, 'totalPrograms': 4, 'totalStudents': 30},
            }),
            200,
          );
        }),
      );

      final repository = SportRepositoryImpl();
      await repository.fetchSport(3);
      final stats = await repository.fetchStats(3);

      expect(paths[0], endsWith('/sports/3'));
      expect(paths[1], endsWith('/sports/3/stats'));
      expect(stats.totalPrograms, 4);
      expect(stats.totalStudents, 30);
    });

    test('create posts the documented payload', () async {
      String? body;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          body = request.body;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'id': 11},
            }),
            201,
          );
        }),
      );

      final created = await SportRepositoryImpl().createSport(
        const SportDraft(
          name: 'Badminton',
          sportComplexId: 1,
          category: SportCategory.indoor,
          minAge: 6,
        ),
      );

      final decoded = jsonDecode(body!) as Map<String, dynamic>;
      expect(decoded['name'], 'Badminton');
      expect(decoded['sportComplexId'], 1);
      expect(decoded['minAge'], 6);
      expect(created.id, 11);
    });

    test('create without a name or complex fails before the round trip',
        () async {
      var called = false;
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );

      final repository = SportRepositoryImpl();

      await expectLater(
        repository.createSport(const SportDraft(sportComplexId: 1)),
        throwsA(isA<ValidationException>()),
      );
      await expectLater(
        repository.createSport(const SportDraft(name: 'Badminton')),
        throwsA(isA<ValidationException>()),
      );
      expect(called, isFalse);
    });

    test('an update with nothing changed never reaches the network', () async {
      var called = false;
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        SportRepositoryImpl().updateSport(1, const SportDraft()),
        throwsA(isA<BadRequestException>()),
      );
      expect(called, isFalse);
    });

    test('an upload that returns no URL is treated as a failure', () async {
      // A 200 with no URL leaves nothing to put in the sport payload.
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      await expectLater(
        SportRepositoryImpl().uploadImage('/tmp/x.jpg'),
        throwsA(isA<ApiException>()),
      );
    });

    test('a rejected write throws with the server message', () async {
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'success': false,
              'message': 'That sport already exists at this complex.',
            }),
            409,
          );
        }),
      );

      await expectLater(
        SportRepositoryImpl().createSport(
          const SportDraft(name: 'Dup', sportComplexId: 1),
        ),
        throwsA(
          isA<ConflictException>().having(
            (e) => e.message,
            'message',
            'That sport already exists at this complex.',
          ),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('SportsController', () {
    test('summary cards are counted from the returned rows', () async {
      final repository = _FakeSportRepository(
        sports: [
          _sport(id: 1, category: 'Indoor', programCount: 2, courtCount: 3),
          _sport(
            id: 2,
            category: 'Outdoor',
            status: 'Inactive',
            showOnFrontend: false,
            programCount: 1,
            courtCount: 4,
          ),
          // No visibility key and no counters — neither is guessed at.
          _sport(id: 3, category: 'Outdoor', showOnFrontend: null),
        ],
      );
      final controller = SportsController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      final summary = controller.summary;

      expect(summary.total, 3);
      expect(summary.active, 2);
      expect(summary.indoor, 1);
      expect(summary.outdoor, 2);
      expect(summary.onFrontend, 1);
      expect(summary.programs, 3);
      expect(summary.courts, 7);
    });

    test('status and complex filters refetch from the server', () async {
      final repository = _FakeSportRepository();
      final controller = SportsController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      controller.setComplexFilter(4);
      await repository.settle();
      expect(repository.lastComplexId, 4);

      controller.setStatusFilter(AdminUserStatus.inactive);
      await repository.settle();
      expect(repository.lastStatus, AdminUserStatus.inactive);
      expect(controller.activeFilterCount, 2);
    });

    test('category and visibility filters are applied locally', () async {
      final repository = _FakeSportRepository(
        sports: [
          _sport(id: 1, category: 'Indoor', showOnFrontend: true),
          _sport(id: 2, category: 'Outdoor', showOnFrontend: true),
          _sport(id: 3, category: 'Indoor', showOnFrontend: false),
        ],
      );
      final controller = SportsController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      final before = repository.listCalls;

      controller.setCategoryFilter(SportCategory.indoor);
      expect(controller.visibleRows.map((s) => s.id), [1, 3]);

      controller.setVisibilityFilter(false);
      expect(controller.visibleRows.map((s) => s.id), [3]);

      // Neither has a query parameter, so neither refetched.
      expect(repository.listCalls, before);
    });

    test('search matches the sport name after the debounce', () async {
      final repository = _FakeSportRepository(
        sports: [
          _sport(id: 1, name: 'Badminton'),
          _sport(id: 2, name: 'Football'),
          _sport(id: 3, name: 'Basketball'),
        ],
      );
      final controller = SportsController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      controller.onSearchChanged('bas');
      // Not applied until the debounce fires.
      expect(controller.visibleRows, hasLength(3));

      await Future<void>.delayed(
        SportsController.searchDebounce + const Duration(milliseconds: 60),
      );
      expect(controller.visibleRows.map((s) => s.id), [3]);
    });

    test('clearFilters refetches only when a server filter was set', () async {
      final repository = _FakeSportRepository();
      final controller = SportsController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      // Local-only filters: clearing them needs no round trip.
      controller.setCategoryFilter(SportCategory.indoor);
      final beforeLocal = repository.listCalls;
      controller.clearFilters();
      expect(repository.listCalls, beforeLocal);

      // A server-side filter has to go back for the unscoped list.
      controller.setComplexFilter(4);
      await repository.settle();
      final beforeServer = repository.listCalls;
      controller.clearFilters();
      await repository.settle();
      expect(repository.listCalls, greaterThan(beforeServer));
    });

    test('paging slices the filtered rows', () async {
      final repository = _FakeSportRepository(
        sports: List.generate(25, (index) => _sport(id: index + 1)),
      );
      final controller = SportsController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      controller.setLimit(10);

      expect(controller.pageRows, hasLength(10));
      expect(controller.page.effectiveTotalPages, 3);

      controller.goToPage(3);
      expect(controller.pageRows, hasLength(5));
      expect(controller.pageRows.first.id, 21);

      // Past the end is clamped, never an empty page.
      controller.goToPage(99);
      expect(controller.page.page, 3);
    });

    test('sorting cycles ascending → descending → off', () async {
      final repository = _FakeSportRepository(
        sports: [
          _sport(id: 1, name: 'Football'),
          _sport(id: 2, name: 'Badminton'),
        ],
      );
      final controller = SportsController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      controller.toggleSort(SportSort.name);
      expect(controller.visibleRows.map((s) => s.id), [2, 1]);

      controller.toggleSort(SportSort.name);
      expect(controller.visibleRows.map((s) => s.id), [1, 2]);

      controller.toggleSort(SportSort.name);
      expect(controller.sort, isNull);
      expect(controller.visibleRows.map((s) => s.id), [1, 2]);
    });

    test('rows with no programme count sink in both directions', () async {
      final repository = _FakeSportRepository(
        sports: [
          _sport(id: 1, programCount: 2),
          _sport(id: 2),
          _sport(id: 3, programCount: 9),
        ],
      );
      final controller = SportsController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      controller.toggleSort(SportSort.programs);
      expect(controller.visibleRows.last.id, 2);

      controller.toggleSort(SportSort.programs);
      expect(controller.visibleRows.last.id, 2);
    });

    test('a status change is applied before the call and kept on success',
        () async {
      final repository = _FakeSportRepository(
        sports: [_sport(id: 1, status: 'Active')],
      );
      final controller = SportsController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      final pending = controller.setStatus(1, AdminUserStatus.inactive);

      // Flipped before the network call resolves.
      expect(controller.visibleRows.single.status, AdminUserStatus.inactive);
      expect(controller.isRowBusy(1), isTrue);

      await pending;
      expect(controller.visibleRows.single.status, AdminUserStatus.inactive);
      expect(controller.isRowBusy(1), isFalse);
      expect(repository.statusCalls, [AdminUserStatus.inactive]);
    });

    test('a rejected status change reverts the row', () async {
      final repository = _FakeSportRepository(
        sports: [_sport(id: 1, status: 'Active')],
        failWrites: true,
      );
      final controller = SportsController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      await expectLater(
        controller.setStatus(1, AdminUserStatus.inactive),
        throwsA(isA<ApiException>()),
      );

      expect(controller.visibleRows.single.status, AdminUserStatus.active);
      expect(controller.isRowBusy(1), isFalse);
    });

    test('a rejected visibility toggle reverts the row', () async {
      final repository = _FakeSportRepository(
        sports: [_sport(id: 1, showOnFrontend: true)],
        failWrites: true,
      );
      final controller = SportsController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      await expectLater(
        controller.setVisibility(1, false),
        throwsA(isA<ApiException>()),
      );

      expect(controller.visibleRows.single.showOnFrontend, isTrue);
    });

    test('assigning a complex moves the row and carries the new name',
        () async {
      final repository = _FakeSportRepository(
        sports: [_sport(id: 1, complexId: 1, complexName: 'Sinhagad Road')],
      );
      final controller = SportsController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      await controller.loadComplexes();

      final pending = controller.assignComplex(1, 2);

      // The row shows the new venue immediately, not a stale one.
      expect(controller.rows.single.sportComplexId, 2);
      expect(controller.rows.single.sportComplexName, 'Kothrud Arena');

      await pending;
      expect(repository.assigned, [(1, 2)]);
    });

    test('a rejected assignment reverts the row', () async {
      final repository = _FakeSportRepository(
        sports: [_sport(id: 1, complexId: 1, complexName: 'Sinhagad Road')],
        failWrites: true,
      );
      final controller = SportsController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      await controller.loadComplexes();

      await expectLater(
        controller.assignComplex(1, 2),
        throwsA(isA<ApiException>()),
      );

      expect(controller.rows.single.sportComplexId, 1);
      expect(controller.rows.single.sportComplexName, 'Sinhagad Road');
    });

    test('delete removes the row immediately', () async {
      final repository = _FakeSportRepository(
        sports: [_sport(id: 1), _sport(id: 2)],
      );
      final controller = SportsController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      final pending = controller.delete(1);

      expect(controller.visibleRows.map((s) => s.id), [2]);
      await pending;
      expect(repository.deleted, [1]);
    });

    test('a failed delete puts the row back', () async {
      final repository = _FakeSportRepository(
        sports: [_sport(id: 1), _sport(id: 2)],
        failWrites: true,
      );
      final controller = SportsController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      await expectLater(controller.delete(1), throwsA(isA<ApiException>()));

      expect(controller.visibleRows.map((s) => s.id), [1, 2]);
    });

    test('the drawer loads the record and its stats together', () async {
      final repository = _FakeSportRepository(sports: [_sport(id: 1)]);
      final controller = SportsController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      await controller.openSport(_sport(id: 1));

      expect(controller.detailState.isReady, isTrue);
      expect(controller.statsState.isReady, isTrue);
      expect(controller.stats?.totalPrograms, 4);
      expect(repository.statsCalls, [1]);
    });

    test('a stats failure leaves the detail readable', () async {
      final repository = _FakeSportRepository(
        sports: [_sport(id: 1)],
        failStats: true,
      );
      final controller = SportsController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      await controller.openSport(_sport(id: 1));

      expect(controller.detailState.isReady, isTrue);
      expect(controller.statsState.isFailed, isTrue);
      // The drawer must not report an error it already survived.
      expect(controller.detailError, isNull);
    });

    test('the venue list is fetched once and reused', () async {
      final repository = _FakeSportRepository();
      final controller = SportsController(repository);
      addTearDown(controller.dispose);

      await controller.loadComplexes();
      await controller.loadComplexes();

      expect(repository.complexCalls, 1);
      expect(controller.complexes, hasLength(2));

      await controller.loadComplexes(refresh: true);
      expect(repository.complexCalls, 2);
    });

    test('a stale response cannot overwrite a newer one', () async {
      final repository = _SlowFirstSportRepository();
      final controller = SportsController(repository);
      addTearDown(controller.dispose);

      final stale = controller.load();
      final fresh = controller.load();
      await Future.wait([stale, fresh]);

      expect(controller.rows.single.id, 2);
    });

    test('a load failure surfaces the server message', () async {
      final controller = SportsController(_FailingSportRepository());
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.isFailed, isTrue);
      expect(controller.error, 'You do not have permission to do this.');
    });
  });
}

// -----------------------------------------------------------------------------
// Fakes
// -----------------------------------------------------------------------------

class _FakeSportRepository implements SportRepository {
  _FakeSportRepository({
    this.sports = const [],
    this.failWrites = false,
    this.failStats = false,
  });

  final List<Sport> sports;
  final bool failWrites;
  final bool failStats;

  int listCalls = 0;
  int complexCalls = 0;
  AdminUserStatus? lastStatus;
  int? lastComplexId;

  final List<int> statsCalls = [];
  final List<AdminUserStatus> statusCalls = [];
  final List<(int, int)> assigned = [];
  final List<int> deleted = [];

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  @override
  Future<List<Sport>> fetchSports({
    AdminUserStatus? status,
    int? complexId,
  }) async {
    listCalls++;
    lastStatus = status;
    lastComplexId = complexId;
    return sports;
  }

  @override
  Future<Sport> fetchSport(int id) async =>
      sports.firstWhere((sport) => sport.id == id, orElse: () => Sport(id: id));

  @override
  Future<SportStats> fetchStats(int id) async {
    statsCalls.add(id);
    if (failStats) throw const ServerException('Stats unavailable.');
    return const SportStats(
      totalPrograms: 4,
      activePrograms: 3,
      totalCourts: 5,
      totalStudents: 30,
    );
  }

  @override
  Future<Sport> createSport(SportDraft draft) async => const Sport(id: 99);

  @override
  Future<Sport> updateSport(int id, SportDraft draft) async => Sport(id: id);

  @override
  Future<void> deleteSport(int id) async {
    if (failWrites) throw const ServerException('Delete rejected.');
    deleted.add(id);
  }

  @override
  Future<void> setStatus(int id, AdminUserStatus status) async {
    if (failWrites) throw const ServerException('Status change rejected.');
    statusCalls.add(status);
  }

  @override
  Future<void> setVisibility(int id, bool showOnFrontend) async {
    if (failWrites) throw const ServerException('Visibility change rejected.');
  }

  @override
  Future<void> assignComplex(int id, int sportComplexId) async {
    if (failWrites) throw const ServerException('Assignment rejected.');
    assigned.add((id, sportComplexId));
  }

  @override
  Future<String> uploadImage(String filePath, {String? filename}) async =>
      'https://cdn/uploaded.jpg';

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async {
    complexCalls++;
    return const [
      SportsComplex(id: 1, name: 'Sinhagad Road', city: 'Pune'),
      SportsComplex(id: 2, name: 'Kothrud Arena', city: 'Pune'),
    ];
  }
}

/// First call resolves slowly with stale data; later calls resolve at once.
class _SlowFirstSportRepository extends _FakeSportRepository {
  int _calls = 0;

  @override
  Future<List<Sport>> fetchSports({
    AdminUserStatus? status,
    int? complexId,
  }) async {
    final isFirst = _calls++ == 0;
    if (isFirst) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return [_sport(id: 1, name: 'stale')];
    }
    return [_sport(id: 2, name: 'fresh')];
  }
}

class _FailingSportRepository extends _FakeSportRepository {
  @override
  Future<List<Sport>> fetchSports({
    AdminUserStatus? status,
    int? complexId,
  }) async {
    throw const ForbiddenException('You do not have permission to do this.');
  }
}
