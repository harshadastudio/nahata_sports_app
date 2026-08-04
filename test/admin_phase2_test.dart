import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/features/admin/data/models/complex_admin_model.dart';
import 'package:nahata_app/features/admin/data/models/dashboard_charts_model.dart';
import 'package:nahata_app/features/admin/data/models/dashboard_stats_model.dart';
import 'package:nahata_app/features/admin/data/repositories/complex_admin_repository_impl.dart';
import 'package:nahata_app/features/admin/data/repositories/dashboard_repository_impl.dart';
import 'package:nahata_app/features/admin/domain/entities/admin_role.dart';
import 'package:nahata_app/features/admin/domain/entities/complex_admin.dart';
import 'package:nahata_app/features/admin/domain/entities/dashboard_stats.dart';
import 'package:nahata_app/features/admin/domain/entities/enrollment_trend.dart';
import 'package:nahata_app/features/admin/domain/entities/live_enquiry.dart';
import 'package:nahata_app/features/admin/domain/entities/paged.dart';
import 'package:nahata_app/features/admin/domain/entities/sport_distribution.dart';
import 'package:nahata_app/features/admin/domain/repositories/complex_admin_repository.dart';
import 'package:nahata_app/features/admin/domain/repositories/dashboard_repository.dart';
import 'package:nahata_app/features/admin/presentation/state/complex_admins_controller.dart';
import 'package:nahata_app/features/admin/presentation/state/dashboard_controller.dart';
import 'package:nahata_app/features/admin/presentation/state/view_state.dart';
import 'package:nahata_app/features/admin/presentation/utils/admin_format.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _secureStore.clear();
    _mockSecureStorage();
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  // ---------------------------------------------------------------------------
  group('DashboardStatsMapper', () {
    test('reads the nested per-metric shape', () {
      final stats = DashboardStatsMapper.fromJson(<String, dynamic>{
        'data': {
          'students': {
            'total': 412,
            'thisMonth': 40,
            'lastMonth': 32,
            'growth': 25,
            'isPositive': true,
          },
          'coaches': {'total': 18, 'thisMonth': 2, 'lastMonth': 2},
          'bookings': {
            'total': 1290,
            'thisMonth': 108,
            'lastMonth': 118,
            'growth': -8.47,
            'isPositive': false,
          },
          'enquiries': {'total': 264},
          'contactRequests': {'total': 77},
        },
      });

      expect(stats.students.total, 412);
      expect(stats.students.thisMonth, 40);
      expect(stats.students.growth, 25);
      expect(stats.students.trendIsPositive, isTrue);

      expect(stats.bookings.growth, -8.47);
      expect(stats.bookings.trendIsPositive, isFalse);

      expect(stats.coaches.total, 18);
      expect(stats.enquiries.total, 264);
      expect(stats.contactRequests.total, 77);
      expect(stats.isEmpty, isFalse);
    });

    test('reads the flat shape and snake_case aliases', () {
      final stats = DashboardStatsMapper.fromJson(<String, dynamic>{
        'totalStudents': 100,
        'students_this_month': 20,
        'students_last_month': 10,
        'total_coaches': 7,
        'totalBookings': '55',
        'total_contact_requests': 4,
      });

      expect(stats.students.total, 100);
      expect(stats.students.thisMonth, 20);
      expect(stats.students.lastMonth, 10);
      expect(stats.coaches.total, 7);
      expect(stats.bookings.total, 55);
      expect(stats.contactRequests.total, 4);
    });

    test('parses a percentage sent as a string', () {
      final stats = DashboardStatsMapper.fromJson(const <String, dynamic>{
        'students': {'total': 10, 'growth': '+12.5%'},
      });

      expect(stats.students.growth, 12.5);
      expect(stats.students.trendIsPositive, isTrue);
    });

    test('isPositive from the server beats the sign of the growth figure', () {
      // A fall in cancellations is good news; only the backend knows that.
      final stats = DashboardStatsMapper.fromJson(const <String, dynamic>{
        'enquiries': {'total': 5, 'growth': -10, 'isPositive': true},
      });

      expect(stats.enquiries.growth, -10);
      expect(stats.enquiries.trendIsPositive, isTrue);
    });

    test('derives growth from the two month counts when none was sent', () {
      const metric = StatMetric(total: 100, thisMonth: 40, lastMonth: 32);
      expect(metric.effectiveGrowth, closeTo(25, 0.001));
      expect(metric.hasTrend, isTrue);
    });

    test('a month that starts from zero yields no percentage', () {
      // 0 → 8 is not "+800%" and not "+100%"; it has no defined percentage.
      const metric = StatMetric(total: 8, thisMonth: 8, lastMonth: 0);
      expect(metric.effectiveGrowth, isNull);
      expect(metric.hasTrend, isTrue);
      expect(metric.trendIsPositive, isTrue);
    });

    test('an empty body stays empty rather than showing zeroes', () {
      final stats = DashboardStatsMapper.fromJson(const <String, dynamic>{});
      expect(stats.isEmpty, isTrue);
      expect(stats.students.total, isNull);
      expect(DashboardStats.empty.isEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('EnrollmentTrendMapper', () {
    test('parses a bare array', () {
      final trend = EnrollmentTrendMapper.fromBody([
        {'month': 'May', 'students': 22, 'enquiries': 30},
        {'month': 'June', 'students': 32, 'enquiries': 26},
      ]);

      expect(trend.points, hasLength(2));
      expect(trend.points.first.label, 'May');
      expect(trend.points.first.students, 22);
      expect(trend.maxValue, 32);
      expect(trend.totalStudents, 54);
      expect(trend.totalEnquiries, 56);
      expect(trend.isAllZero, isFalse);
    });

    test('parses a wrapped list and its aliases', () {
      final trend = EnrollmentTrendMapper.fromBody({
        'data': {
          'trends': [
            {'label': 'Q1', 'enrollments': 10, 'inquiries': 4},
          ],
        },
      });

      expect(trend.points.single.label, 'Q1');
      expect(trend.points.single.students, 10);
      expect(trend.points.single.enquiries, 4);
    });

    test('drops a point with no month label', () {
      final trend = EnrollmentTrendMapper.fromBody([
        {'students': 5},
        {'month': 'July', 'students': 6},
      ]);

      expect(trend.points, hasLength(1));
      expect(trend.points.single.label, 'July');
    });

    test('a series of zeroes reports itself as empty to the chart', () {
      final trend = EnrollmentTrendMapper.fromBody([
        {'month': 'May', 'students': 0, 'enquiries': 0},
      ]);

      expect(trend.isEmpty, isFalse);
      expect(trend.isAllZero, isTrue);
    });

    test('a missing series plots at zero instead of breaking the line', () {
      const point = EnrollmentPoint(label: 'May');
      expect(point.students, isNull);
      expect(point.studentsValue, 0);
    });
  });

  // ---------------------------------------------------------------------------
  group('SportDistributionMapper', () {
    test('parses slices with the API colour', () {
      final distribution = SportDistributionMapper.fromBody({
        'data': [
          {
            'sport': 'Badminton',
            'count': 180,
            'percentage': 43.7,
            'color': '#4F46E5',
          },
          {'sportName': 'Tennis', 'count': 140, 'percentage': 34},
        ],
      });

      expect(distribution.slices, hasLength(2));
      expect(distribution.totalSports, 2);
      expect(distribution.totalCount, 320);
      expect(distribution.slices.first.color, const Color(0xFF4F46E5));
      // No colour sent → null, so the chart supplies one from its palette.
      expect(distribution.slices.last.color, isNull);
    });

    test('derives a percentage when the server sent none', () {
      final distribution = SportDistributionMapper.fromBody([
        {'sport': 'A', 'count': 25},
        {'sport': 'B', 'count': 75},
      ]);

      expect(distribution.percentageOf(distribution.slices.first), 25);
      expect(distribution.percentageOf(distribution.slices.last), 75);
    });

    test('an all-zero distribution reports itself as empty', () {
      final distribution = SportDistributionMapper.fromBody([
        {'sport': 'A', 'count': 0},
      ]);

      expect(distribution.isEmpty, isFalse);
      expect(distribution.isAllZero, isTrue);
      // Guards a divide-by-zero in the share calculation.
      expect(distribution.percentageOf(distribution.slices.first), 0);
    });

    group('colour parsing', () {
      test('accepts the common hex forms', () {
        expect(
          SportDistributionMapper.parseColor('#FF5733'),
          const Color(0xFFFF5733),
        );
        expect(
          SportDistributionMapper.parseColor('FF5733'),
          const Color(0xFFFF5733),
        );
        expect(
          SportDistributionMapper.parseColor('#abc'),
          const Color(0xFFAABBCC),
        );
        expect(
          SportDistributionMapper.parseColor('#80FF5733'),
          const Color(0x80FF5733),
        );
      });

      test('accepts rgb()', () {
        expect(
          SportDistributionMapper.parseColor('rgb(255, 87, 51)'),
          const Color(0xFFFF5733),
        );
      });

      test('returns null for junk rather than a black slice', () {
        for (final value in [null, '', 'not-a-colour', '#12', 'rgb(1,2)']) {
          expect(
            SportDistributionMapper.parseColor(value),
            isNull,
            reason: '$value',
          );
        }
      });
    });
  });

  // ---------------------------------------------------------------------------
  group('LiveEnquiryMapper', () {
    test('parses rows and keeps the server phrasing of "time ago"', () {
      final enquiries = LiveEnquiryMapper.listFrom({
        'enquiries': [
          {
            'id': 12,
            'name': 'Meera Joshi',
            'email': 'meera@example.com',
            'sport': 'Badminton',
            'status': 'Pending',
            'timeAgo': '2 hours ago',
            'avatar': null,
          },
        ],
      });

      final enquiry = enquiries.single;
      expect(enquiry.id, '12');
      expect(enquiry.displayName, 'Meera Joshi');
      expect(enquiry.status, LiveEnquiryStatus.pending);
      expect(enquiry.timeAgoRaw, '2 hours ago');
      // Null avatar → initials.
      expect(enquiry.hasAvatar, isFalse);
      expect(enquiry.initials, 'MJ');
    });

    test('maps the status spellings the backend uses interchangeably', () {
      expect(LiveEnquiryStatus.tryParse('new'), LiveEnquiryStatus.pending);
      expect(
        LiveEnquiryStatus.tryParse('ACCEPTED'),
        LiveEnquiryStatus.approved,
      );
      expect(
        LiveEnquiryStatus.tryParse('declined'),
        LiveEnquiryStatus.rejected,
      );
      expect(LiveEnquiryStatus.tryParse('weird'), isNull);
      expect(LiveEnquiryStatus.labelFor('weird'), 'Weird');
    });

    test('drops rows with no id', () {
      final enquiries = LiveEnquiryMapper.listFrom([
        {'name': 'No id'},
        {'id': 'e1', 'name': 'Real'},
      ]);
      expect(enquiries, hasLength(1));
    });
  });

  // ---------------------------------------------------------------------------
  group('ComplexAdminMapper', () {
    test('an embedded user fills the person fields but never the row id', () {
      // Same shape as the security-guard row captured live on 2026-08-04.
      final admin = ComplexAdminMapper.fromJson({
        'id': 22,
        'userId': 585,
        'sportComplexId': 1,
        'status': 'Active',
        'user': {
          'id': 585,
          'name': 'Major',
          'email': 'major@gmil.com',
          'phone_number': '9856784565',
        },
      });

      expect(admin.id, '22');
      expect(admin.name, 'Major');
      expect(admin.email, 'major@gmil.com');
      expect(admin.phone, '9856784565');
      expect(admin.sportComplexId, 1);
    });

    test('reads a nested sport-complex object', () {
      final admin = ComplexAdminMapper.fromJson(<String, dynamic>{
        'id': 'ca-1',
        'name': 'Priya Deshmukh',
        'email': 'priya@example.com',
        'phone_number': '9822001100',
        'status': 'Active',
        'created_at': '2026-02-11T09:30:00Z',
        'sportComplex': {
          'id': 4,
          'name': 'Sinhagad Road Complex',
          'city': 'Pune',
        },
      });

      expect(admin.id, 'ca-1');
      expect(admin.phone, '9822001100');
      expect(admin.sportComplexId, 4);
      expect(admin.sportComplexName, 'Sinhagad Road Complex');
      expect(admin.city, 'Pune');
      expect(admin.status, AdminUserStatus.active);
      expect(admin.createdAt, isNotNull);
      expect(admin.venueLabel, 'Sinhagad Road Complex, Pune');
      expect(admin.initials, 'PD');
    });

    test('reads a flat row with only ids and names', () {
      final admin = ComplexAdminMapper.fromJson(const <String, dynamic>{
        'id': 9,
        'name': 'Solo',
        'sportComplexId': 2,
        'complexName': 'Kothrud Arena',
      });

      expect(admin.id, '9');
      expect(admin.sportComplexId, 2);
      expect(admin.sportComplexName, 'Kothrud Arena');
      expect(admin.venueLabel, 'Kothrud Arena');
    });

    test('a non-paginated body is reported as a single page', () {
      final page = ComplexAdminMapper.pageFrom(
        [
          {'id': '1', 'name': 'A'},
          {'id': '2', 'name': 'B'},
        ],
        fallbackPage: 1,
        fallbackLimit: 20,
      );

      expect(page.items, hasLength(2));
      expect(page.total, 2);
      expect(page.effectiveTotalPages, 1);
      expect(page.hasNext, isFalse);
      expect(page.hasPrevious, isFalse);
    });

    test('honours a meta block when the backend does paginate', () {
      final page = ComplexAdminMapper.pageFrom(
        {
          'data': {
            'complexAdmins': [
              {'id': '1', 'name': 'A'},
            ],
            'meta': {'page': 2, 'limit': 10, 'total': 25, 'totalPages': 3},
          },
        },
        fallbackPage: 2,
        fallbackLimit: 10,
      );

      expect(page.page, 2);
      expect(page.total, 25);
      expect(page.effectiveTotalPages, 3);
      expect(page.hasNext, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('ComplexAdminDraft', () {
    test('the create body matches the documented payload exactly', () {
      const draft = ComplexAdminDraft(
        name: 'Priya',
        email: 'priya@example.com',
        password: 'secret123',
        phone: '9822001100',
        sportComplexId: 4,
      );

      final body = draft.toCreateJson();
      expect(body.keys.toSet(), {
        'name',
        'email',
        'password',
        'phone_number',
        'sportComplexId',
      });
      expect(body['phone_number'], '9822001100');
      expect(body['sportComplexId'], 4);
    });

    test('an update omits an untouched password so it is never blanked', () {
      const draft = ComplexAdminDraft(name: 'Priya', phone: '9822001100');
      final body = draft.toUpdateJson();

      expect(body.containsKey('password'), isFalse);
      expect(body['name'], 'Priya');
      expect(body['phone_number'], '9822001100');
    });

    test('an update sends the password when one was typed', () {
      const draft = ComplexAdminDraft(password: 'newsecret');
      expect(draft.toUpdateJson()['password'], 'newsecret');
    });

    test('a whitespace-only password counts as untouched', () {
      const draft = ComplexAdminDraft(name: 'X', password: '   ');
      expect(draft.toUpdateJson().containsKey('password'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('AdminFormat', () {
    test('growth drops a pointless decimal', () {
      expect(AdminFormat.growth(12), '+12%');
      expect(AdminFormat.growth(12.5), '+12.5%');
      expect(AdminFormat.growth(-8.47), '-8.5%');
      expect(AdminFormat.growth(12, signed: false), '12%');
      expect(AdminFormat.growth(null), AdminFormat.dash);
    });

    test('share rounds to one decimal', () {
      expect(AdminFormat.share(33.333), '33.3%');
      expect(AdminFormat.share(50), '50%');
      expect(AdminFormat.share(null), AdminFormat.dash);
    });
  });

  // ---------------------------------------------------------------------------
  group('Repositories', () {
    tearDown(() {
      ApiClient.instance.overrideHttpClient(http.Client());
    });

    test('the four dashboard reads hit their documented paths', () async {
      final paths = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      final repository = DashboardRepositoryImpl();
      await repository.fetchStats();
      await repository.fetchEnrollmentTrends();
      await repository.fetchSportDistribution();
      await repository.fetchLiveEnquiries(limit: 6);

      expect(paths[0], endsWith('/dashboard/stats'));
      expect(paths[1], endsWith('/dashboard/enrollment-trends'));
      expect(paths[2], endsWith('/dashboard/sport-distribution'));
      expect(paths[3], endsWith('/dashboard/live-enquiries'));
    });

    test(
      'a failed dashboard read throws so the section can explain itself',
      () async {
        ApiClient.instance.overrideHttpClient(
          MockClient((request) async {
            return http.Response(
              jsonEncode({'success': false, 'message': 'Stats are offline.'}),
              200,
            );
          }),
        );

        await expectLater(
          DashboardRepositoryImpl().fetchStats(),
          throwsA(isA<ApiException>()),
        );
      },
    );

    test(
      'complex-admin list forwards page, limit and a trimmed search',
      () async {
        late Uri captured;

        ApiClient.instance.overrideHttpClient(
          MockClient((request) async {
            captured = request.url;
            return http.Response(
              jsonEncode({'success': true, 'data': []}),
              200,
            );
          }),
        );

        await ComplexAdminRepositoryImpl().fetchComplexAdmins(
          page: 2,
          limit: 50,
          search: '  priya  ',
        );

        expect(captured.path, endsWith('/admin/complex-admins'));
        expect(captured.queryParameters['page'], '2');
        expect(captured.queryParameters['limit'], '50');
        expect(captured.queryParameters['search'], 'priya');
      },
    );

    test('create posts the documented body', () async {
      String? body;
      String? path;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          body = request.body;
          path = request.url.path;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'id': 'ca-9'},
            }),
            201,
          );
        }),
      );

      final created = await ComplexAdminRepositoryImpl().createComplexAdmin(
        const ComplexAdminDraft(
          name: 'Priya',
          email: 'priya@example.com',
          password: 'secret123',
          phone: '9822001100',
          sportComplexId: 4,
        ),
      );

      expect(path, endsWith('/admin/complex-admins'));
      final decoded = jsonDecode(body!) as Map<String, dynamic>;
      expect(decoded['phone_number'], '9822001100');
      expect(decoded['sportComplexId'], 4);
      expect(created.id, 'ca-9');
    });

    test('create without a complex fails before the round trip', () async {
      var called = false;
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          called = true;
          return http.Response('{}', 200);
        }),
      );

      await expectLater(
        ComplexAdminRepositoryImpl().createComplexAdmin(
          const ComplexAdminDraft(name: 'No complex'),
        ),
        throwsA(isA<ValidationException>()),
      );
      expect(called, isFalse);
    });

    test('update and delete hit the id-scoped path', () async {
      final calls = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          calls.add('${request.method} ${request.url.path}');
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      final repository = ComplexAdminRepositoryImpl();
      await repository.updateComplexAdmin(
        'ca-1',
        const ComplexAdminDraft(name: 'Renamed'),
      );
      await repository.deleteComplexAdmin('ca-1');

      expect(calls[0], endsWith('PUT /api/admin/complex-admins/ca-1'));
      expect(calls[1], endsWith('DELETE /api/admin/complex-admins/ca-1'));
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
        ComplexAdminRepositoryImpl().updateComplexAdmin(
          'ca-1',
          const ComplexAdminDraft(),
        ),
        throwsA(isA<BadRequestException>()),
      );
      expect(called, isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('DashboardController', () {
    test('loads all four sections and records when it finished', () async {
      final repository = _FakeDashboardRepository();
      final controller = DashboardController(repository);
      addTearDown(controller.dispose);

      expect(controller.stats.state.isIdle, isTrue);
      // Idle counts as busy, so the first frame shimmers rather than showing
      // an empty state before the request has gone out.
      expect(controller.stats.isBusy, isTrue);

      await controller.load();

      expect(controller.stats.isReady, isTrue);
      expect(controller.trends.isReady, isTrue);
      expect(controller.distribution.isReady, isTrue);
      expect(controller.enquiries.isReady, isTrue);
      expect(controller.stats.data.students.total, 412);
      expect(controller.loadedAt, isNotNull);
      expect(repository.calls, 4);
    });

    test('one dead section does not take the others down', () async {
      final repository = _FakeDashboardRepository(failDistribution: true);
      final controller = DashboardController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.distribution.isFailed, isTrue);
      expect(controller.distribution.error, isNotNull);
      expect(controller.stats.isReady, isTrue);
      expect(controller.trends.isReady, isTrue);
      expect(controller.enquiries.isReady, isTrue);
    });

    test('a failed section keeps the server message', () async {
      final repository = _FakeDashboardRepository(statsError: 'Not permitted.');
      final controller = DashboardController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.stats.isFailed, isTrue);
      expect(controller.stats.error, 'Not permitted.');
    });

    test('one section can be retried on its own', () async {
      final repository = _FakeDashboardRepository();
      final controller = DashboardController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      expect(repository.calls, 4);

      await controller.loadDistribution();
      expect(repository.calls, 5);
      expect(controller.distribution.isReady, isTrue);
    });

    test('the enquiry card asks for a bounded preview', () async {
      final repository = _FakeDashboardRepository();
      final controller = DashboardController(repository);
      addTearDown(controller.dispose);

      await controller.loadEnquiries();
      expect(
        repository.lastEnquiryLimit,
        DashboardController.enquiryPreviewLimit,
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('ComplexAdminsController', () {
    test('search debounces to a single request', () async {
      final repository = _FakeComplexAdminRepository();
      final controller = ComplexAdminsController(repository);
      addTearDown(controller.dispose);

      await controller.load();
      final before = repository.listCalls;

      controller.onSearchChanged('p');
      controller.onSearchChanged('pr');
      controller.onSearchChanged('priya');
      expect(repository.listCalls, before);

      await Future<void>.delayed(
        ComplexAdminsController.searchDebounce +
            const Duration(milliseconds: 120),
      );

      expect(repository.listCalls, before + 1);
      expect(repository.lastSearch, 'priya');
      expect(repository.lastPage, 1);
    });

    test('a stale response cannot overwrite a newer one', () async {
      final repository = _SlowFirstComplexAdminRepository();
      final controller = ComplexAdminsController(repository);
      addTearDown(controller.dispose);

      final first = controller.load(page: 1);
      final second = controller.load(page: 2);
      await Future.wait([first, second]);

      expect(controller.page.page, 2);
      expect(controller.admins.single.name, 'fresh');
    });

    test('the venue list is fetched once and reused', () async {
      final repository = _FakeComplexAdminRepository();
      final controller = ComplexAdminsController(repository);
      addTearDown(controller.dispose);

      await controller.loadComplexes();
      await controller.loadComplexes();

      expect(repository.complexCalls, 1);
      expect(controller.complexes, hasLength(2));
      expect(controller.complexesState.isReady, isTrue);
    });

    test('a forced reload does refetch the venue list', () async {
      final repository = _FakeComplexAdminRepository();
      final controller = ComplexAdminsController(repository);
      addTearDown(controller.dispose);

      await controller.loadComplexes();
      await controller.loadComplexes(refresh: true);

      expect(repository.complexCalls, 2);
      expect(repository.lastComplexRefresh, isTrue);
    });

    test('deleting the last row of a page steps back a page', () async {
      final repository = _FakeComplexAdminRepository(
        admins: const [ComplexAdmin(id: 'ca-9', name: 'Last one')],
        totalPages: 3,
        total: 21,
      );
      final controller = ComplexAdminsController(repository);
      addTearDown(controller.dispose);

      await controller.load(page: 3);
      await controller.delete('ca-9');

      expect(repository.deleted, ['ca-9']);
      expect(repository.lastPage, 2);
    });

    test('creating reloads from page 1', () async {
      final repository = _FakeComplexAdminRepository();
      final controller = ComplexAdminsController(repository);
      addTearDown(controller.dispose);

      await controller.load(page: 2);
      await controller.create(
        const ComplexAdminDraft(name: 'New', sportComplexId: 1),
      );

      expect(repository.lastPage, 1);
    });

    test('a load failure surfaces the server message', () async {
      final repository = _FailingComplexAdminRepository();
      final controller = ComplexAdminsController(repository);
      addTearDown(controller.dispose);

      await controller.load();

      expect(controller.state.isFailed, isTrue);
      expect(controller.error, 'You do not have permission to do this.');
    });

    test('a failed venue fetch is recoverable, not fatal', () async {
      final repository = _FakeComplexAdminRepository(failComplexes: true);
      final controller = ComplexAdminsController(repository);
      addTearDown(controller.dispose);

      await controller.loadComplexes();

      expect(controller.complexesState.isFailed, isTrue);
      expect(controller.complexes, isEmpty);
    });
  });
}

// -----------------------------------------------------------------------------
// Fakes
// -----------------------------------------------------------------------------

class _FakeDashboardRepository implements DashboardRepository {
  _FakeDashboardRepository({this.failDistribution = false, this.statsError});

  final bool failDistribution;
  final String? statsError;

  int calls = 0;
  int? lastEnquiryLimit;

  @override
  Future<DashboardStats> fetchStats() async {
    calls++;
    if (statsError != null) throw ForbiddenException(statsError!);
    return const DashboardStats(students: StatMetric(total: 412));
  }

  @override
  Future<EnrollmentTrend> fetchEnrollmentTrends() async {
    calls++;
    return const EnrollmentTrend(
      points: [EnrollmentPoint(label: 'May', students: 22)],
    );
  }

  @override
  Future<SportDistribution> fetchSportDistribution() async {
    calls++;
    if (failDistribution) throw const ServerException('Distribution offline.');
    return const SportDistribution(
      slices: [SportSlice(sport: 'Badminton', count: 5)],
    );
  }

  @override
  Future<List<LiveEnquiry>> fetchLiveEnquiries({int? limit}) async {
    calls++;
    lastEnquiryLimit = limit;
    return const [LiveEnquiry(id: 'e1', name: 'Meera')];
  }
}

class _FakeComplexAdminRepository implements ComplexAdminRepository {
  _FakeComplexAdminRepository({
    this.admins = const [ComplexAdmin(id: 'ca-1', name: 'Priya')],
    this.total = 1,
    this.totalPages = 1,
    this.failComplexes = false,
  });

  final List<ComplexAdmin> admins;
  final int total;
  final int totalPages;
  final bool failComplexes;

  int listCalls = 0;
  int complexCalls = 0;
  int? lastPage;
  String? lastSearch;
  bool? lastComplexRefresh;
  final List<String> deleted = [];

  @override
  Future<Paged<ComplexAdmin>> fetchComplexAdmins({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    listCalls++;
    lastPage = page;
    lastSearch = search;
    return Paged<ComplexAdmin>(
      items: admins,
      page: page,
      limit: limit,
      total: total,
      totalPages: totalPages,
    );
  }

  @override
  Future<ComplexAdmin> createComplexAdmin(ComplexAdminDraft draft) async =>
      const ComplexAdmin(id: 'ca-new');

  @override
  Future<ComplexAdmin> updateComplexAdmin(
    String id,
    ComplexAdminDraft draft,
  ) async => ComplexAdmin(id: id);

  @override
  Future<void> deleteComplexAdmin(String id) async => deleted.add(id);

  @override
  Future<List<SportsComplex>> fetchSportComplexes({
    bool refresh = false,
  }) async {
    complexCalls++;
    lastComplexRefresh = refresh;
    if (failComplexes) throw const ServerException('Venues offline.');
    return const [
      SportsComplex(id: 1, name: 'Sinhagad Road Complex', city: 'Pune'),
      SportsComplex(id: 2, name: 'Kothrud Arena', city: 'Pune'),
    ];
  }
}

/// First call resolves slowly with stale data; later calls resolve at once.
class _SlowFirstComplexAdminRepository extends _FakeComplexAdminRepository {
  int _calls = 0;

  @override
  Future<Paged<ComplexAdmin>> fetchComplexAdmins({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    final isFirst = _calls++ == 0;
    if (isFirst) {
      await Future<void>.delayed(const Duration(milliseconds: 80));
      return const Paged<ComplexAdmin>(
        items: [ComplexAdmin(id: '1', name: 'stale')],
        page: 1,
      );
    }
    return const Paged<ComplexAdmin>(
      items: [ComplexAdmin(id: '2', name: 'fresh')],
      page: 2,
    );
  }
}

class _FailingComplexAdminRepository extends _FakeComplexAdminRepository {
  @override
  Future<Paged<ComplexAdmin>> fetchComplexAdmins({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    throw const ForbiddenException('You do not have permission to do this.');
  }
}
