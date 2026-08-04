import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/features/admin/data/models/admin_sports_complex_model.dart';
import 'package:nahata_app/features/admin/data/repositories/sports_complex_admin_repository_impl.dart';
import 'package:nahata_app/features/admin/domain/entities/admin_role.dart';
import 'package:nahata_app/features/admin/domain/entities/admin_sports_complex.dart';
import 'package:nahata_app/features/admin/domain/repositories/sports_complex_admin_repository.dart';
import 'package:nahata_app/features/admin/presentation/state/sports_complexes_controller.dart';
import 'package:nahata_app/features/admin/presentation/state/view_state.dart';

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

AdminSportsComplex _complex({
  required int id,
  String? name,
  String? city,
  String? state,
  String status = 'Active',
  bool? showOnFrontend = true,
  DateTime? createdAt,
}) {
  return AdminSportsComplex(
    id: id,
    name: name ?? 'Complex $id',
    city: city,
    state: state,
    statusRaw: status,
    showOnFrontend: showOnFrontend,
    createdAt: createdAt,
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
  group('AdminSportsComplexMapper', () {
    test('parses a full record, including the nested complex envelope', () {
      final complex = AdminSportsComplexMapper.fromJson({
        'id': 4,
        'name': 'Kothrud Arena',
        'image': 'https://cdn.example.com/a.jpg',
        'address': 'Paud Road',
        'city': 'Pune',
        'state': 'Maharashtra',
        'zipCode': '411038',
        'contactPhone': '02025551234',
        'contactEmail': 'arena@example.com',
        'openingHours': '6 AM - 11 PM',
        'facilities': 'Floodlights, Parking',
        'status': 'Active',
        'showOnFrontend': true,
        'mapUrl': 'https://maps.google.com/?q=x',
        'latitude': 18.5074,
        'longitude': '73.8077',
        'totalCourts': 8,
        'activeCourts': 6,
        'externalOrgId': 'ORG-1',
        'createdAt': '2025-02-10',
      });

      expect(complex.id, 4);
      expect(complex.name, 'Kothrud Arena');
      expect(complex.city, 'Pune');
      expect(complex.status, AdminUserStatus.active);
      expect(complex.showOnFrontend, isTrue);
      expect(complex.latitude, 18.5074);
      // Sent as a string but still a coordinate.
      expect(complex.longitude, 73.8077);
      expect(complex.totalCourts, 8);
      expect(complex.externalOrgId, 'ORG-1');
      expect(complex.createdAt, DateTime.parse('2025-02-10'));
      expect(complex.facilityList, ['Floodlights', 'Parking']);
    });

    test('reads snake_case and a nested sportsComplex envelope', () {
      final complex = AdminSportsComplexMapper.fromJson({
        'sportsComplex': {
          '_id': 7,
          'complexName': 'Sinhagad Road',
          'contact_phone': '9822001100',
          'show_on_frontend': false,
          'zip_code': '411041',
          'google_map_url': 'https://maps.example.com',
        },
      });

      expect(complex.id, 7);
      expect(complex.name, 'Sinhagad Road');
      expect(complex.contactPhone, '9822001100');
      expect(complex.showOnFrontend, isFalse);
      expect(complex.zipCode, '411041');
    });

    test('an absent visibility key stays null rather than becoming false', () {
      // The table must never claim a venue is hidden on a missing key.
      final complex = AdminSportsComplexMapper.fromJson({'id': 1});
      expect(complex.showOnFrontend, isNull);
    });

    test('reads the catalogue from the key this route actually uses', () {
      final complexes = AdminSportsComplexMapper.listFrom({
        'data': {
          'sportsComplexes': [
            {'id': 1, 'name': 'A'},
            {'id': 2, 'name': 'B'},
            {'name': 'no id — dropped'},
          ],
        },
      });

      expect(complexes.map((c) => c.id), [1, 2]);
    });

    test('facilities split on commas, newlines and semicolons', () {
      const complex = AdminSportsComplex(
        id: 1,
        facilities: 'Parking\nCafeteria; Floodlights,  Lockers ',
      );
      expect(complex.facilityList, [
        'Parking',
        'Cafeteria',
        'Floodlights',
        'Lockers',
      ]);
    });

    test('mergedWith keeps a field the detail route omitted', () {
      const row = AdminSportsComplex(id: 1, city: 'Pune', name: 'Arena');
      const detail = AdminSportsComplex(id: 1, zipCode: '411038');

      final merged = row.mergedWith(detail);
      expect(merged.city, 'Pune');
      expect(merged.zipCode, '411038');
    });
  });

  // ---------------------------------------------------------------------------
  group('Upload response parsing', () {
    test('accepts every documented shape the route might answer with', () {
      expect(
        AdminSportsComplexMapper.uploadedUrlFrom('https://cdn/x.jpg'),
        'https://cdn/x.jpg',
      );
      expect(
        AdminSportsComplexMapper.uploadedUrlFrom({'imageUrl': '/uploads/x.jpg'}),
        '/uploads/x.jpg',
      );
      expect(
        AdminSportsComplexMapper.uploadedUrlFrom({
          'data': {'image': 'x.jpg'},
        }),
        'x.jpg',
      );
      expect(AdminSportsComplexMapper.uploadedUrlFrom({'ok': true}), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('Media URL resolution', () {
    test('an absolute URL is left alone', () {
      expect(
        resolveMediaUrl('https://cdn.example.com/a.jpg'),
        'https://cdn.example.com/a.jpg',
      );
    });

    test('a rooted path is hung off the API host', () {
      final resolved = resolveMediaUrl('/uploads/a.jpg');
      expect(resolved, startsWith('https://'));
      expect(resolved, endsWith('/uploads/a.jpg'));
      // The API path prefix must not leak into a media URL.
      expect(resolved, isNot(contains('/api/uploads')));
    });

    test('blank and null resolve to nothing rather than a broken URL', () {
      expect(resolveMediaUrl(null), isNull);
      expect(resolveMediaUrl('  '), isNull);
      expect(resolveMediaUrl('null'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('Maps link', () {
    test('a stored map URL wins', () {
      const complex = AdminSportsComplex(
        id: 1,
        mapUrl: 'https://maps.google.com/?q=arena',
        latitude: 1,
        longitude: 2,
      );
      expect(complex.mapsLink, 'https://maps.google.com/?q=arena');
    });

    test('coordinates are the next best thing', () {
      const complex = AdminSportsComplex(id: 1, latitude: 18.5, longitude: 73.8);
      expect(complex.mapsLink, contains('18.5,73.8'));
    });

    test('an address becomes a search, and nothing becomes null', () {
      const withAddress = AdminSportsComplex(
        id: 1,
        name: 'Arena',
        city: 'Pune',
      );
      expect(withAddress.mapsLink, contains('Arena'));
      expect(const AdminSportsComplex(id: 1).mapsLink, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  group('SportsComplexDraft', () {
    test('the create body carries every documented key', () {
      final body = const SportsComplexDraft(
        name: '  Kothrud Arena ',
        address: 'Paud Road',
        city: 'Pune',
        state: 'Maharashtra',
        zipCode: '411038',
        contactPhone: '02025551234',
        contactEmail: 'arena@example.com',
        openingHours: '6 AM - 11 PM',
        facilities: 'Parking',
        mapUrl: 'https://maps.google.com',
        image: 'https://cdn/x.jpg',
        showOnFrontend: true,
      ).toCreateJson();

      expect(body.keys, {
        'name',
        'address',
        'city',
        'state',
        'zipCode',
        'contactPhone',
        'contactEmail',
        'openingHours',
        'facilities',
        'status',
        'mapUrl',
        'image',
        'showOnFrontend',
      });
      expect(body['name'], 'Kothrud Arena');
      expect(body['showOnFrontend'], isTrue);
      // Nothing chosen on the form means the venue starts Active.
      expect(body['status'], 'Active');
    });

    test('an unset create still sends the documented empties', () {
      final body = const SportsComplexDraft(name: 'X').toCreateJson();
      expect(body['address'], '');
      expect(body['image'], '');
      expect(body['showOnFrontend'], isFalse);
    });

    test('an update sends a deliberately blanked field', () {
      // Unlike the staff modules, an address or map URL is legitimately
      // clearable, so an empty string must survive to the wire.
      final body = const SportsComplexDraft(
        name: 'Arena',
        mapUrl: '',
        image: '',
      ).toUpdateJson();

      expect(body['name'], 'Arena');
      expect(body.containsKey('mapUrl'), isTrue);
      expect(body['mapUrl'], '');
      expect(body['image'], '');
      // A field the form never touched is still omitted.
      expect(body.containsKey('city'), isFalse);
    });

    test('an update with nothing set is empty', () {
      expect(const SportsComplexDraft().toUpdateJson(), isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  group('SportsComplexAdminRepositoryImpl', () {
    tearDown(() {
      ApiClient.instance.overrideHttpClient(http.Client());
    });

    test('the city and state routes encode their segment', () async {
      final paths = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      final repository = SportsComplexAdminRepositoryImpl();
      await repository.fetchComplexesByCity('Navi Mumbai');
      await repository.fetchComplexesByState('Tamil Nadu');

      // A space in the segment would otherwise break the path.
      expect(paths[0], endsWith('/sports-complexes/city/Navi%20Mumbai'));
      expect(paths[1], endsWith('/sports-complexes/state/Tamil%20Nadu'));
    });

    test('status and visibility hit their own routes', () async {
      final calls = <String>[];
      final bodies = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          bodies.add(request.body);
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      final repository = SportsComplexAdminRepositoryImpl();
      await repository.setStatus(4, AdminUserStatus.inactive);
      await repository.setVisibility(4, true);

      expect(calls[0], endsWith('PUT /api/sports-complexes/4/status'));
      expect(calls[1], endsWith('PUT /api/sports-complexes/4/show-on-frontend'));
      expect(jsonDecode(bodies[0])['status'], 'Inactive');
      expect(jsonDecode(bodies[1])['showOnFrontend'], isTrue);
    });

    test('delete-image passes the URL as a query parameter', () async {
      late Uri captured;
      late String method;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          method = request.method;
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      await SportsComplexAdminRepositoryImpl().deleteImage(
        'https://cdn/x.jpg',
      );

      expect(method, 'DELETE');
      expect(captured.path, endsWith('/sports-complexes/delete-image'));
      expect(captured.queryParameters['imageUrl'], 'https://cdn/x.jpg');
    });

    test('create posts the documented payload', () async {
      String? body;
      String? path;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          body = request.body;
          path = request.url.path;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'id': 9},
            }),
            201,
          );
        }),
      );

      final created = await SportsComplexAdminRepositoryImpl().createComplex(
        const SportsComplexDraft(
          name: 'Arena',
          city: 'Pune',
          showOnFrontend: true,
        ),
      );

      expect(path, endsWith('/sports-complexes'));
      final decoded = jsonDecode(body!) as Map<String, dynamic>;
      expect(decoded['name'], 'Arena');
      expect(decoded['showOnFrontend'], isTrue);
      expect(created.id, 9);
    });

    test('create without a name fails before the round trip', () async {
      var called = false;
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        SportsComplexAdminRepositoryImpl().createComplex(
          const SportsComplexDraft(city: 'Pune'),
        ),
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
        SportsComplexAdminRepositoryImpl().updateComplex(
          1,
          const SportsComplexDraft(),
        ),
        throwsA(isA<BadRequestException>()),
      );
      expect(called, isFalse);
    });

    test('an upload that returns no URL is treated as a failure', () async {
      // A 200 with no URL leaves nothing to put in the complex payload.
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      await expectLater(
        SportsComplexAdminRepositoryImpl().uploadImage('/tmp/x.jpg'),
        throwsA(isA<ApiException>()),
      );
    });

    test('a rejected write throws with the server message', () async {
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          return http.Response(
            jsonEncode({
              'success': false,
              'message': 'That complex name is already taken.',
            }),
            409,
          );
        }),
      );

      await expectLater(
        SportsComplexAdminRepositoryImpl().createComplex(
          const SportsComplexDraft(name: 'Dup'),
        ),
        throwsA(
          isA<ConflictException>().having(
            (e) => e.message,
            'message',
            'That complex name is already taken.',
          ),
        ),
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('SportsComplexesController', () {
    test('summary cards are counted from the catalogue', () async {
      final repository = _FakeComplexRepository(
        complexes: [
          _complex(id: 1, city: 'Pune', status: 'Active'),
          _complex(id: 2, city: 'pune', status: 'Inactive'),
          _complex(id: 3, city: 'Mumbai', showOnFrontend: false),
          // No visibility key at all — not counted as hidden.
          _complex(id: 4, city: 'Nagpur', showOnFrontend: null),
        ],
      );
      final controller = SportsComplexesController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      final summary = controller.summary;

      expect(summary.total, 4);
      expect(summary.active, 3);
      expect(summary.hidden, 1);
      // "Pune" and "pune" are one city.
      expect(summary.cities, 3);
    });

    test('city and state options are learned, case-folded, from the API', () {
      final repository = _FakeComplexRepository(
        complexes: [
          _complex(id: 1, city: 'Pune', state: 'Maharashtra'),
          _complex(id: 2, city: 'pune', state: 'MAHARASHTRA'),
          _complex(id: 3, city: 'Chennai', state: 'Tamil Nadu'),
        ],
      );
      final controller = SportsComplexesController(repository);
      addTearDown(controller.dispose);

      return controller.load().then((_) {
        expect(controller.cities, ['Chennai', 'Pune']);
        expect(controller.states, ['Maharashtra', 'Tamil Nadu']);
      });
    });

    test('a city filter reads from the city endpoint', () async {
      final repository = _FakeComplexRepository(
        complexes: [_complex(id: 1, city: 'Pune')],
      );
      final controller = SportsComplexesController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      controller.setCityFilter('Pune');
      await repository.settle();

      expect(repository.cityCalls, ['Pune']);
      expect(controller.isScoped, isTrue);
    });

    test('a state filter reads from the state endpoint', () async {
      final repository = _FakeComplexRepository();
      final controller = SportsComplexesController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      controller.setStateFilter('Maharashtra');
      await repository.settle();

      expect(repository.stateCalls, ['Maharashtra']);
    });

    test('a scoped read never shrinks the catalogue', () async {
      final repository = _FakeComplexRepository(
        complexes: [
          _complex(id: 1, city: 'Pune'),
          _complex(id: 2, city: 'Mumbai'),
        ],
        scoped: [_complex(id: 1, city: 'Pune')],
      );
      final controller = SportsComplexesController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      controller.setCityFilter('Pune');
      await repository.settle();

      // Filtering to one city must not make every other city unpickable.
      expect(controller.cities, ['Mumbai', 'Pune']);
      expect(controller.summary.total, 2);
      expect(controller.visibleRows.map((c) => c.id), [1]);
    });

    test('status and visibility filters are applied locally', () async {
      final repository = _FakeComplexRepository(
        complexes: [
          _complex(id: 1, status: 'Active', showOnFrontend: true),
          _complex(id: 2, status: 'Inactive', showOnFrontend: true),
          _complex(id: 3, status: 'Active', showOnFrontend: false),
        ],
      );
      final controller = SportsComplexesController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      final before = repository.listCalls;

      controller.setStatusFilter(AdminUserStatus.active);
      expect(controller.visibleRows.map((c) => c.id), [1, 3]);

      controller.setVisibilityFilter(false);
      expect(controller.visibleRows.map((c) => c.id), [3]);

      // Neither of those has an endpoint, so neither refetched.
      expect(repository.listCalls, before);
    });

    test('search matches name, city and state after the debounce', () async {
      final repository = _FakeComplexRepository(
        complexes: [
          _complex(id: 1, name: 'Kothrud Arena', city: 'Pune'),
          _complex(id: 2, name: 'Marina Courts', city: 'Chennai'),
          _complex(id: 3, name: 'Baner Turf', state: 'Maharashtra'),
        ],
      );
      final controller = SportsComplexesController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      controller.onSearchChanged('chennai');
      // Not applied until the debounce fires.
      expect(controller.visibleRows, hasLength(3));

      await Future<void>.delayed(
        SportsComplexesController.searchDebounce +
            const Duration(milliseconds: 60),
      );
      expect(controller.visibleRows.map((c) => c.id), [2]);

      controller.onSearchChanged('maharashtra');
      await Future<void>.delayed(
        SportsComplexesController.searchDebounce +
            const Duration(milliseconds: 60),
      );
      expect(controller.visibleRows.map((c) => c.id), [3]);
    });

    test('paging slices the filtered rows', () async {
      final repository = _FakeComplexRepository(
        complexes: List.generate(25, (index) => _complex(id: index + 1)),
      );
      final controller = SportsComplexesController(repository);
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
      final repository = _FakeComplexRepository(
        complexes: [
          _complex(id: 1, name: 'Beta'),
          _complex(id: 2, name: 'Alpha'),
        ],
      );
      final controller = SportsComplexesController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      controller.toggleSort(SportsComplexSort.name);
      expect(controller.visibleRows.map((c) => c.id), [2, 1]);

      controller.toggleSort(SportsComplexSort.name);
      expect(controller.visibleRows.map((c) => c.id), [1, 2]);

      controller.toggleSort(SportsComplexSort.name);
      expect(controller.sort, isNull);
      expect(controller.visibleRows.map((c) => c.id), [1, 2]);
    });

    test('rows with no created date sink in both directions', () async {
      final repository = _FakeComplexRepository(
        complexes: [
          _complex(id: 1, createdAt: DateTime(2025, 1, 1)),
          _complex(id: 2),
          _complex(id: 3, createdAt: DateTime(2025, 6, 1)),
        ],
      );
      final controller = SportsComplexesController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      controller.toggleSort(SportsComplexSort.created);
      expect(controller.visibleRows.last.id, 2);

      controller.toggleSort(SportsComplexSort.created);
      expect(controller.visibleRows.last.id, 2);
    });

    test('a status change is applied before the call and kept on success',
        () async {
      final repository = _FakeComplexRepository(
        complexes: [_complex(id: 1, status: 'Active')],
      );
      final controller = SportsComplexesController(repository);
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
      final repository = _FakeComplexRepository(
        complexes: [_complex(id: 1, status: 'Active')],
        failWrites: true,
      );
      final controller = SportsComplexesController(repository);
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
      final repository = _FakeComplexRepository(
        complexes: [_complex(id: 1, showOnFrontend: true)],
        failWrites: true,
      );
      final controller = SportsComplexesController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      await expectLater(
        controller.setVisibility(1, false),
        throwsA(isA<ApiException>()),
      );

      expect(controller.visibleRows.single.showOnFrontend, isTrue);
    });

    test('delete removes the row immediately', () async {
      final repository = _FakeComplexRepository(
        complexes: [_complex(id: 1), _complex(id: 2)],
      );
      final controller = SportsComplexesController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      final pending = controller.delete(1);

      expect(controller.visibleRows.map((c) => c.id), [2]);
      await pending;
      expect(repository.deleted, [1]);
    });

    test('a failed delete puts the row back', () async {
      final repository = _FakeComplexRepository(
        complexes: [_complex(id: 1), _complex(id: 2)],
        failWrites: true,
      );
      final controller = SportsComplexesController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      await expectLater(controller.delete(1), throwsA(isA<ApiException>()));

      expect(controller.visibleRows.map((c) => c.id), [1, 2]);
    });

    test('the detail drawer loads the record and its stats together', () async {
      final repository = _FakeComplexRepository(
        complexes: [_complex(id: 1)],
      );
      final controller = SportsComplexesController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      await controller.openComplex(_complex(id: 1));

      expect(controller.detailState.isReady, isTrue);
      expect(controller.statsState.isReady, isTrue);
      expect(controller.stats?.totalCourts, 8);
      expect(repository.statsCalls, [1]);
    });

    test('a stats failure leaves the detail readable', () async {
      final repository = _FakeComplexRepository(
        complexes: [_complex(id: 1)],
        failStats: true,
      );
      final controller = SportsComplexesController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      await controller.openComplex(_complex(id: 1));

      expect(controller.detailState.isReady, isTrue);
      expect(controller.statsState.isFailed, isTrue);
      // The drawer must not report an error it already survived.
      expect(controller.detailError, isNull);
    });

    test('a stale response cannot overwrite a newer one', () async {
      final repository = _SlowFirstComplexRepository();
      final controller = SportsComplexesController(repository);
      addTearDown(controller.dispose);

      final stale = controller.load();
      final fresh = controller.load();
      await Future.wait([stale, fresh]);

      expect(controller.visibleRows.single.id, 2);
    });

    test('clearFilters refetches only when the read was scoped', () async {
      final repository = _FakeComplexRepository(
        complexes: [_complex(id: 1, city: 'Pune')],
      );
      final controller = SportsComplexesController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      // Local-only filters: clearing them needs no round trip.
      controller.setStatusFilter(AdminUserStatus.active);
      final beforeLocal = repository.listCalls;
      controller.clearFilters();
      expect(repository.listCalls, beforeLocal);

      // A scoped filter has to go back to the full catalogue.
      controller.setCityFilter('Pune');
      await repository.settle();
      final beforeScoped = repository.listCalls;
      controller.clearFilters();
      await repository.settle();
      expect(repository.listCalls, greaterThan(beforeScoped));
    });

    test('a load failure surfaces the server message', () async {
      final controller = SportsComplexesController(_FailingComplexRepository());
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

class _FakeComplexRepository implements SportsComplexAdminRepository {
  _FakeComplexRepository({
    this.complexes = const [],
    this.scoped,
    this.failWrites = false,
    this.failStats = false,
  });

  final List<AdminSportsComplex> complexes;

  /// What the city/state endpoints return; defaults to the full list.
  final List<AdminSportsComplex>? scoped;

  final bool failWrites;
  final bool failStats;

  int listCalls = 0;
  final List<String> cityCalls = [];
  final List<String> stateCalls = [];
  final List<int> statsCalls = [];
  final List<AdminUserStatus> statusCalls = [];
  final List<int> deleted = [];

  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  @override
  Future<List<AdminSportsComplex>> fetchComplexes() async {
    listCalls++;
    return complexes;
  }

  @override
  Future<List<AdminSportsComplex>> fetchComplexesByCity(String city) async {
    cityCalls.add(city);
    return scoped ?? complexes;
  }

  @override
  Future<List<AdminSportsComplex>> fetchComplexesByState(String state) async {
    stateCalls.add(state);
    return scoped ?? complexes;
  }

  @override
  Future<AdminSportsComplex> fetchComplex(int id) async => complexes.firstWhere(
    (complex) => complex.id == id,
    orElse: () => AdminSportsComplex(id: id),
  );

  @override
  Future<SportsComplexStats> fetchStats(int id) async {
    statsCalls.add(id);
    if (failStats) throw const ServerException('Stats unavailable.');
    return const SportsComplexStats(totalCourts: 8, activeCourts: 6);
  }

  @override
  Future<AdminSportsComplex> createComplex(SportsComplexDraft draft) async =>
      const AdminSportsComplex(id: 99);

  @override
  Future<AdminSportsComplex> updateComplex(
    int id,
    SportsComplexDraft draft,
  ) async => AdminSportsComplex(id: id);

  @override
  Future<void> deleteComplex(int id) async {
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
  Future<String> uploadImage(String filePath, {String? filename}) async =>
      'https://cdn/uploaded.jpg';

  @override
  Future<void> deleteImage(String imageUrl) async {}
}

/// First call resolves slowly with stale data; later calls resolve at once.
class _SlowFirstComplexRepository extends _FakeComplexRepository {
  int _calls = 0;

  @override
  Future<List<AdminSportsComplex>> fetchComplexes() async {
    final isFirst = _calls++ == 0;
    if (isFirst) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return [_complex(id: 1, name: 'stale')];
    }
    return [_complex(id: 2, name: 'fresh')];
  }
}

class _FailingComplexRepository extends _FakeComplexRepository {
  @override
  Future<List<AdminSportsComplex>> fetchComplexes() async {
    throw const ForbiddenException('You do not have permission to do this.');
  }
}
