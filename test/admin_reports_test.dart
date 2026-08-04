import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_client.dart';
import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/features/admin/data/datasources/report_remote_data_source.dart';
import 'package:nahata_app/features/admin/data/models/report_model.dart';
import 'package:nahata_app/features/admin/data/repositories/report_repository_impl.dart';
import 'package:nahata_app/features/admin/domain/entities/paged.dart';
import 'package:nahata_app/features/admin/domain/entities/report.dart';
import 'package:nahata_app/features/admin/domain/repositories/report_repository.dart';
import 'package:nahata_app/features/admin/presentation/state/reports_controller.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    _secureStore.clear();
    _mockSecureStorage();
    SharedPreferences.setMockInitialValues(<String, Object>{});
    // The data source remembers which chart path answered; one test must not
    // inherit another's resolution.
    ReportRemoteDataSource.resetChartPathCache();
  });

  // ---------------------------------------------------------------------------
  group('DateRange', () {
    test('the wire format is yyyy-MM-dd, as every other admin route uses', () {
      final range = DateRange(
        from: DateTime(2026, 8, 1),
        to: DateTime(2026, 8, 31),
      );
      expect(range.wireFrom, '2026-08-01');
      expect(range.wireTo, '2026-08-31');
      expect(range.days, 31);
      expect(range.key, '2026-08-01→2026-08-31');
    });

    test('the presets describe the windows they name', () {
      final now = DateTime(2026, 8, 15);

      expect(DateRangePreset.today.range(now: now).days, 1);
      expect(DateRangePreset.last7.range(now: now).days, 7);
      expect(
        DateRangePreset.thisMonth.range(now: now).wireFrom,
        '2026-08-01',
      );
      expect(DateRangePreset.lastMonth.range(now: now).wireFrom, '2026-07-01');
      expect(DateRangePreset.lastMonth.range(now: now).wireTo, '2026-07-31');
      expect(DateRangePreset.thisYear.range(now: now).wireFrom, '2026-01-01');
    });

    test('the previous window is the same length, ending the day before', () {
      final range = DateRange(
        from: DateTime(2026, 8, 8),
        to: DateTime(2026, 8, 14),
      );
      final previous = range.previous;
      expect(previous.wireTo, '2026-08-07');
      expect(previous.wireFrom, '2026-08-01');
      expect(previous.days, range.days);
    });

    test('two ranges over the same window are the same cache key', () {
      final a = DateRange(from: DateTime(2026, 8, 1), to: DateTime(2026, 8, 2));
      final b = DateRange(from: DateTime(2026, 8, 1), to: DateTime(2026, 8, 2));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });
  });

  // ---------------------------------------------------------------------------
  group('ReportMapper.section', () {
    test('reads the documented overview figures', () {
      final section = ReportMapper.section(
        {
          'success': true,
          'data': {
            'totalRevenue': 336000,
            'totalBookings': 420,
            'totalStudents': 180,
            'totalCoaches': 12,
            'totalMemberships': 96,
            'activeCourts': 8,
            'occupancy': 72.5,
            'growth': 12.5,
          },
        },
        figures: ReportMapper.overviewFigures,
      );

      expect(section.valueOf('revenue'), 336000);
      expect(section.valueOf('bookings'), 420);
      expect(section.valueOf('occupancy'), 72.5);
      expect(section.figure('growth')?.format, ReportFormat.percent);
      expect(section.figure('revenue')?.format, ReportFormat.currency);
      expect(section.isEmpty, isFalse);
    });

    test('a figure the endpoint omitted stays null, never zero', () {
      // A 0 here would claim there was no revenue, which the payload never said.
      final section = ReportMapper.section(
        {
          'data': {'totalBookings': 420},
        },
        figures: ReportMapper.overviewFigures,
      );

      expect(section.valueOf('bookings'), 420);
      expect(section.valueOf('revenue'), isNull);
      expect(section.figure('revenue')!.isEmpty, isTrue);
      // Only the figures that arrived get a card.
      expect(section.shownFigures.map((f) => f.key), ['bookings']);
    });

    test('snake_case and a decimal string read the same', () {
      final section = ReportMapper.section(
        {
          'data': {'total_revenue': '336000.50', 'total_bookings': 420},
        },
        figures: ReportMapper.overviewFigures,
      );
      expect(section.valueOf('revenue'), 336000.5);
      expect(section.valueOf('bookings'), 420);
    });

    test('values the module never listed are kept as extras', () {
      // Section 1 asks for "any additional values returned by API" in as many
      // words, and the same courtesy costs nothing on the other twelve.
      final section = ReportMapper.section(
        {
          'data': {
            'totalBookings': 420,
            'walkInRevenue': 12000,
            'cancellationRate': 4.5,
            'note': 'not a number',
          },
        },
        figures: ReportMapper.overviewFigures,
      );

      expect(section.extras.map((f) => f.key), [
        'walkInRevenue',
        'cancellationRate',
      ]);
      expect(section.extras.first.label, 'Walk in revenue');
      // The format is guessed from the name, and only for undocumented figures.
      expect(section.extras.first.format, ReportFormat.currency);
      expect(section.extras.last.format, ReportFormat.percent);
    });

    test('the envelope and the echoed window are never mistaken for figures',
        () {
      final section = ReportMapper.section(
        {
          'success': true,
          'message': 'Success',
          'data': {'from': '2026-08-01', 'to': '2026-08-31', 'page': 1},
        },
        figures: ReportMapper.overviewFigures,
      );
      expect(section.extras, isEmpty);
      expect(section.isEmpty, isTrue);
    });

    test('a series is read from a list of objects', () {
      final section = ReportMapper.section(
        {
          'data': {
            'totalRevenue': 1000,
            'monthlyRevenue': [
              {'month': 'Jan', 'total': 400},
              {'month': 'Feb', 'total': 600},
            ],
          },
        },
        figures: ReportMapper.revenueFigures,
        series: ReportMapper.revenueSeries,
      );

      final monthly = section.chart('monthly')!;
      expect(monthly.points.map((p) => p.label), ['Jan', 'Feb']);
      expect(monthly.points.map((p) => p.value), [400, 600]);
      expect(monthly.total, 1000);
      expect(monthly.format, ReportFormat.currency);
      // A documented series that did not arrive is empty, not absent.
      expect(section.chart('daily')!.isEmpty, isTrue);
      expect(section.shownCharts.length, 1);
    });

    test('a series is read from a label → number map too', () {
      final section = ReportMapper.section(
        {
          'data': {
            'peakHours': {'07': 3, '18': 9},
          },
        },
        series: ReportMapper.facilitySeries,
      );
      final peak = section.chart('peak')!;
      expect(peak.points.length, 2);
      expect(peak.maxValue, 9);
    });

    test('an empty payload yields an empty section', () {
      expect(ReportMapper.section(null).isEmpty, isTrue);
      expect(ReportMapper.section(const {}).isEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('ReportMapper.chart', () {
    test('reads a bare list, a wrapped list and a map', () {
      final bare = ReportMapper.chart(
        [
          {'date': '2026-08-01', 'count': 4},
          {'date': '2026-08-02', 'count': 7},
        ],
        key: 'trends',
        label: 'Booking trends',
      );
      expect(bare.points.length, 2);
      expect(bare.points.first.value, 4);

      final wrapped = ReportMapper.chart(
        {
          'success': true,
          'data': [
            {'label': 'Court 1', 'revenue': 12000},
          ],
        },
        key: 'revenue',
        label: 'Revenue by court',
      );
      expect(wrapped.points.single.label, 'Court 1');
      expect(wrapped.points.single.value, 12000);
    });

    test('a payload with no readable points is empty, not a guess', () {
      final series = ReportMapper.chart(
        {'success': true, 'message': 'Success'},
        key: 'trends',
        label: 'Booking trends',
      );
      expect(series.isEmpty, isTrue);
      expect(series.total, 0);
    });

    test('rows with no numeric value are skipped rather than plotted as 0', () {
      final series = ReportMapper.chart(
        [
          {'label': 'Mon', 'count': 4},
          {'label': 'Tue'},
          {'label': 'Wed', 'count': 6},
        ],
        key: 'trends',
        label: 'Trends',
      );
      expect(series.points.map((p) => p.label), ['Mon', 'Wed']);
    });
  });

  // ---------------------------------------------------------------------------
  group('The captured booking-trends payload', () {
    // Verbatim from a live call on 2026-08-04:
    // GET {{base_url}}/reports/booking-trends?from=2026-07-01&to=2026-08-01
    const captured = {
      'success': true,
      'data': [
        {'date': '2026-08-03', 'bookings': 5, 'revenue': 1250},
        {'date': '2026-08-04', 'bookings': 10, 'revenue': 2200},
        {'date': '2026-08-07', 'bookings': 2, 'revenue': 600},
        {'date': '2026-08-08', 'bookings': 2, 'revenue': 600},
      ],
    };

    test('reads the dates and plots the bookings, not the revenue', () {
      final series = ReportMapper.chart(
        captured,
        key: 'bookingTrends',
        label: 'Booking trends',
        valueLabel: 'Bookings',
        valueKeys: const ['bookings', 'count', 'totalBookings'],
      );

      expect(series.points.map((p) => p.label), [
        '2026-08-03',
        '2026-08-04',
        '2026-08-07',
        '2026-08-08',
      ]);
      expect(series.points.map((p) => p.value), [5, 10, 2, 2]);
      // The revenue rides along rather than being thrown away.
      expect(series.points.map((p) => p.secondary), [1250, 2200, 600, 600]);
      expect(series.total, 19);
      expect(series.maxValue, 10);
    });

    test('a revenue chart over the same shape plots the revenue', () {
      // Which figure a point means is the chart's to say: without this, a
      // two-figure row would silently plot whichever key came first.
      final series = ReportMapper.chart(
        captured,
        key: 'revenueByCourt',
        label: 'Revenue',
        format: ReportFormat.currency,
        valueKeys: const ['revenue', 'totalRevenue', 'amount'],
      );

      expect(series.points.map((p) => p.value), [1250, 2200, 600, 600]);
      expect(series.points.first.secondary, 5);
    });

    test('the live route is /reports/booking-trends, not /reports/charts/…',
        () async {
      final paths = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(jsonEncode(captured), 200);
        }),
      );

      final series = await ReportRepositoryImpl().fetchChart(
        ReportChart.bookingTrends,
        DateRange(from: DateTime(2026, 7, 1), to: DateTime(2026, 8, 1)),
      );

      // The documented `/reports/charts/…` path is never tried when the
      // captured one answers.
      expect(paths.single, endsWith('/api/reports/booking-trends'));
      expect(series.points.length, 4);
    });

    test('a 404 falls back to the documented path, once', () async {
      final paths = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          paths.add(request.url.path);
          if (!request.url.path.contains('/charts/')) {
            return http.Response(
              jsonEncode({'success': false, 'message': 'Not found'}),
              404,
            );
          }
          return http.Response(jsonEncode(captured), 200);
        }),
      );

      final repository = ReportRepositoryImpl();
      final range = DateRange(from: DateTime(2026, 7, 1), to: DateTime(2026, 8, 1));

      final first = await repository.fetchChart(ReportChart.peakHours, range);
      expect(first.points.length, 4);
      expect(paths, [
        endsWith('/api/reports/peak-hours'),
        endsWith('/api/reports/charts/peak-hours'),
      ]);

      // The winning path is remembered, so the second read pays once, not
      // twice.
      paths.clear();
      await repository.fetchChart(ReportChart.peakHours, range);
      expect(paths.single, endsWith('/api/reports/charts/peak-hours'));
    });

    test('a 401 is not retried at the other path — it is a real failure',
        () async {
      final paths = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(
            jsonEncode({'success': false, 'message': 'Unauthorized'}),
            401,
          );
        }),
      );

      await expectLater(
        ReportRepositoryImpl().fetchChart(
          ReportChart.courtPerformance,
          DateRange(from: DateTime(2026, 7, 1), to: DateTime(2026, 8, 1)),
        ),
        throwsA(isA<UnauthorizedException>()),
      );
      // One call for the report; the client's own token refresh may add its
      // own, but the alternate report path is never tried.
      expect(
        paths.where((path) => path.contains('/charts/')),
        isEmpty,
      );
    });
  });

  // ---------------------------------------------------------------------------
  group('ReportMapper.filterOptions', () {
    test('reads objects, plain strings and numbers', () {
      final options = ReportMapper.filterOptions({
        'data': {
          'sports': [
            {'id': 8, 'name': 'Badminton'},
            {'id': 9, 'name': 'Tennis'},
          ],
          'statuses': ['Active', 'Inactive'],
          'years': [2025, 2026],
          'note': 'not a list',
        },
      });

      expect(options.groups.keys, ['sports', 'statuses', 'years']);
      expect(options['sports'].first, const FilterOption(id: '8', label: 'Badminton'));
      expect(options['statuses'].first.id, 'Active');
      expect(options['years'].last.label, '2026');
    });

    test('a group is found by any of its likely names', () {
      final options = ReportMapper.filterOptions({
        'data': {
          'sportOptions': [
            {'id': '8', 'label': 'Badminton'},
          ],
        },
      });
      expect(options.find(const ['sports', 'sport', 'sportOptions']).length, 1);
      expect(options.find(const ['coaches']), isEmpty);
    });

    test('an empty payload is empty rather than a crash', () {
      expect(ReportMapper.filterOptions(null).isEmpty, isTrue);
      expect(ReportMapper.filterOptions({'data': {}}).isEmpty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  group('Report rows', () {
    test('a booking row reads the documented columns', () {
      final row = ReportMapper.bookingRow({
        'id': 71,
        'bookingReference': 'BOOK-2026-000071',
        'sportName': 'Badminton',
        'courtName': 'Court 1',
        'date': '2026-08-05',
        'startTime': '19:00:00',
        'endTime': '20:00:00',
        'amount': 800,
        'bookingStatus': 'Confirmed',
        'paymentStatus': 'Paid',
        'user': {'id': 585, 'name': 'Rahul Sharma', 'phone_number': '9876543210'},
      });

      expect(row.id, '71');
      expect(row.displayReference, 'BOOK-2026-000071');
      expect(row.userName, 'Rahul Sharma');
      expect(row.userContact, '9876543210');
      expect(row.slotLabel, '19:00 – 20:00');
      expect(row.amount, 800);
      expect(row.date, DateTime(2026, 8, 5));
    });

    test('a booking row never takes its id from the embedded user', () {
      // Inheriting `user.id` would name the wrong record in the export.
      final row = ReportMapper.bookingRow({
        'id': 71,
        'user': {'id': 585, 'name': 'Rahul'},
      });
      expect(row.id, '71');
    });

    test('a student row reads the documented columns', () {
      final row = ReportMapper.studentRow({
        'id': 'st-1',
        'studentName': 'Priya Nair',
        'sportName': 'Badminton',
        'coachName': 'Arjun',
        'batchName': 'Morning A',
        'membership': 'Gold Annual',
        'joiningDate': '2026-02-01',
        'status': 'Active',
      });

      expect(row.id, 'st-1');
      expect(row.displayName, 'Priya Nair');
      expect(row.batchName, 'Morning A');
      expect(row.joinedAt, DateTime(2026, 2, 1));
      expect(row.initials, 'PN');
    });

    test('a coach row reads the documented columns', () {
      final row = ReportMapper.coachRow({
        'id': 'c-1',
        'coachName': 'Arjun Nahata',
        'sportName': 'Badminton',
        'students': 24,
        'revenue': '96000.00',
        'programs': 3,
        'status': 'Active',
      });

      expect(row.id, 'c-1');
      expect(row.studentCount, 24);
      expect(row.revenue, 96000);
      expect(row.programCount, 3);
    });

    test('rows without an id are dropped', () {
      final page = ReportMapper.page<BookingReportRow>(
        {
          'data': [
            {'id': 1},
            {'sportName': 'no id'},
            {'id': 2},
          ],
        },
        map: ReportMapper.bookingRow,
        keep: (row) => row.id.isNotEmpty,
        requestedPage: 1,
        requestedLimit: 20,
      );
      expect(page.items.map((r) => r.id), ['1', '2']);
    });

    test('the documented paginated envelope is read', () {
      final page = ReportMapper.page<BookingReportRow>(
        {
          'success': true,
          'message': 'Success',
          'data': [
            {'id': 1},
          ],
          'total': 47,
          'page': 2,
          'limit': 20,
        },
        map: ReportMapper.bookingRow,
        keep: (row) => row.id.isNotEmpty,
        requestedPage: 2,
        requestedLimit: 20,
      );

      expect(page.page, 2);
      expect(page.total, 47);
      // Derived rather than guessed at 1, which would hide every later page.
      expect(page.effectiveTotalPages, 3);
    });

    test('search matches the columns an admin would type', () {
      final booking = ReportMapper.bookingRow({
        'id': '71',
        'bookingReference': 'BOOK-71',
        'userName': 'Rahul Sharma',
        'courtName': 'Court 1',
      });
      expect(booking.matches('rahul'), isTrue);
      expect(booking.matches('court 1'), isTrue);
      expect(booking.matches('book-71'), isTrue);
      expect(booking.matches('priya'), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  group('ReportFilters', () {
    test('a value is added, replaced and removed', () {
      const filters = ReportFilters();
      final withSport = filters.withValue('sport', '8');
      expect(withSport['sport'], '8');
      expect(withSport.count, 1);

      expect(withSport.withValue('sport', null)['sport'], isNull);
      expect(withSport.withValue('sport', '')['sport'], isNull);
    });

    test('the query carries the values and a trimmed search', () {
      final filters = const ReportFilters()
          .withValue('sport', '8')
          .withSearch('  rahul  ');
      expect(filters.query, {'sport': '8', 'search': 'rahul'});
      expect(const ReportFilters().query, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  group('ReportsController', () {
    test('opening a tab loads only what that tab needs', () async {
      final repository = _FakeRepository();
      final controller = ReportsController(repository);
      addTearDown(controller.dispose);

      await controller.loadCurrent();

      // The dashboard's five sections and its two charts, and nothing else.
      expect(repository.sections, containsAll([
        ReportKind.overview,
        ReportKind.revenue,
        ReportKind.memberships,
        ReportKind.coaching,
        ReportKind.facilities,
      ]));
      expect(repository.sections.contains(ReportKind.users), isFalse);
      expect(repository.charts.length, 2);
      expect(repository.tables, isEmpty);
    });

    test('a cached section is not read twice for the same window', () async {
      final repository = _FakeRepository();
      final controller = ReportsController(repository);
      addTearDown(controller.dispose);

      await controller.loadCurrent();
      final first = repository.sections.length;

      await controller.loadCurrent();
      expect(repository.sections.length, first);

      controller.setView(ReportsView.users);
      await Future<void>.delayed(Duration.zero);
      controller.setView(ReportsView.dashboard);
      await Future<void>.delayed(Duration.zero);

      // Coming back to the dashboard re-reads nothing.
      expect(repository.sections.where((k) => k == ReportKind.overview).length, 1);
    });

    test('changing the window invalidates every cache', () async {
      final repository = _FakeRepository();
      final controller = ReportsController(repository);
      addTearDown(controller.dispose);
      await controller.loadCurrent();

      expect(controller.section(ReportKind.overview).value, isNotNull);

      controller.setRange(DateRangePreset.last7.range());
      // Held figures describe the old window, so none of them survive.
      expect(controller.section(ReportKind.overview).value, isNull);

      await Future<void>.delayed(
        ReportsController.rangeDebounce + const Duration(milliseconds: 50),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.section(ReportKind.overview).value, isNotNull);
    });

    test('the range change is debounced', () async {
      final repository = _FakeRepository();
      final controller = ReportsController(repository);
      addTearDown(controller.dispose);
      await controller.loadCurrent();

      final before = repository.sections.length;
      controller.setRange(DateRangePreset.last7.range());
      controller.setRange(DateRangePreset.last30.range());
      controller.setRange(DateRangePreset.last90.range());
      expect(repository.sections.length, before);

      await Future<void>.delayed(
        ReportsController.rangeDebounce + const Duration(milliseconds: 50),
      );
      await Future<void>.delayed(Duration.zero);
      // One reload, not three.
      expect(repository.sections.length, before + 5);
    });

    test('the dashboard cards come from four different sections', () async {
      final controller = ReportsController(
        _FakeRepository(
          sectionValues: {
            ReportKind.overview: const ReportSection(
              figures: [
                ReportFigure(
                  key: 'revenue',
                  label: 'Total revenue',
                  value: 336000,
                  format: ReportFormat.currency,
                ),
                ReportFigure(key: 'students', label: 'Students', value: 180),
              ],
            ),
            ReportKind.coaching: const ReportSection(
              figures: [
                ReportFigure(
                  key: 'revenue',
                  label: 'Coaching revenue',
                  value: 96000,
                  format: ReportFormat.currency,
                ),
              ],
            ),
          },
        ),
      );
      addTearDown(controller.dispose);
      await controller.loadCurrent();

      final cards = {
        for (final card in controller.dashboardCards) card.key: card.value,
      };
      expect(cards['revenue'], 336000);
      expect(cards['students'], 180);
      expect(cards['coachingRevenue'], 96000);
      // Nothing reported it, so it stays null — the card says "Not reported".
      expect(cards['coaches'], isNull);
    });

    test('one failed section does not fail the tab', () async {
      final controller = ReportsController(
        _FakeRepository(failSections: {ReportKind.coaching}),
      );
      addTearDown(controller.dispose);

      await controller.loadCurrent();

      expect(controller.section(ReportKind.coaching).state.isFailed, isTrue);
      expect(controller.section(ReportKind.overview).state.isReady, isTrue);
      expect(controller.dashboardFailed, isFalse);
    });

    test('a failed section reports the server message and can retry', () async {
      final repository = _FakeRepository(failSections: {ReportKind.users});
      final controller = ReportsController(repository);
      addTearDown(controller.dispose);

      controller.setView(ReportsView.users);
      await Future<void>.delayed(Duration.zero);

      final slice = controller.section(ReportKind.users);
      expect(slice.state.isFailed, isTrue);
      expect(slice.error, 'The reports service is down');

      repository.failSections.clear();
      await controller.retrySection(ReportKind.users);
      expect(controller.section(ReportKind.users).state.isReady, isTrue);
    });

    test('the booking tab loads its table, chart, figures and filters',
        () async {
      final repository = _FakeRepository();
      final controller = ReportsController(repository);
      addTearDown(controller.dispose);

      controller.setView(ReportsView.bookings);
      await Future<void>.delayed(Duration.zero);

      expect(repository.tables, [ReportTable.bookings]);
      expect(repository.filterSets, [ReportFilterSet.bookings]);
      expect(repository.charts, contains(ReportChart.bookingTrends));
      expect(controller.bookings.length, 2);
    });

    test('loadMore appends the next page and never duplicates rows', () async {
      final repository = _FakeRepository(total: 40, pageSize: 20);
      final controller = ReportsController(repository);
      addTearDown(controller.dispose);

      controller.setView(ReportsView.bookings);
      await Future<void>.delayed(Duration.zero);

      expect(controller.loadedCount(ReportTable.bookings), 20);
      expect(controller.hasMore(ReportTable.bookings), isTrue);

      await controller.loadMore(ReportTable.bookings);
      expect(controller.loadedCount(ReportTable.bookings), 40);
      expect(controller.hasMore(ReportTable.bookings), isFalse);

      // At the end, another call is a no-op rather than a wasted request.
      final calls = repository.tables.length;
      await controller.loadMore(ReportTable.bookings);
      expect(repository.tables.length, calls);
    });

    test('a duplicate page from the server is not appended twice', () async {
      // A backend that echoes page one for an out-of-range page would
      // otherwise double every row on screen.
      final repository = _FakeRepository(
        total: 40,
        pageSize: 20,
        echoPageOne: true,
      );
      final controller = ReportsController(repository);
      addTearDown(controller.dispose);

      controller.setView(ReportsView.bookings);
      await Future<void>.delayed(Duration.zero);
      await controller.loadMore(ReportTable.bookings);

      expect(controller.loadedCount(ReportTable.bookings), 20);
    });

    test('search is debounced and goes to the server', () async {
      final repository = _FakeRepository();
      final controller = ReportsController(repository);
      addTearDown(controller.dispose);

      controller.setView(ReportsView.bookings);
      await Future<void>.delayed(Duration.zero);
      final before = repository.tables.length;

      controller.onSearchChanged(ReportTable.bookings, 'rah');
      controller.onSearchChanged(ReportTable.bookings, 'rahul');
      expect(repository.tables.length, before);

      await Future<void>.delayed(
        ReportsController.searchDebounce + const Duration(milliseconds: 50),
      );
      await Future<void>.delayed(Duration.zero);

      expect(repository.tables.length, before + 1);
      expect(repository.lastFilters?.search, 'rahul');
    });

    test('a filter value is sent verbatim as the options route gave it',
        () async {
      final repository = _FakeRepository();
      final controller = ReportsController(repository);
      addTearDown(controller.dispose);

      controller.setView(ReportsView.bookings);
      await Future<void>.delayed(Duration.zero);

      controller.setFilter(ReportTable.bookings, 'sport', '8');
      await Future<void>.delayed(Duration.zero);
      expect(repository.lastFilters?['sport'], '8');

      controller.clearFilters(ReportTable.bookings);
      await Future<void>.delayed(Duration.zero);
      expect(repository.lastFilters?.isEmpty, isTrue);
    });

    test('filter options survive a window change — they are not date-scoped',
        () async {
      final repository = _FakeRepository();
      final controller = ReportsController(repository);
      addTearDown(controller.dispose);

      controller.setView(ReportsView.coaches);
      await Future<void>.delayed(Duration.zero);
      expect(repository.filterSets.length, 1);

      controller.setRange(DateRangePreset.last7.range());
      await Future<void>.delayed(
        ReportsController.rangeDebounce + const Duration(milliseconds: 50),
      );
      await Future<void>.delayed(Duration.zero);

      expect(repository.filterSets.length, 1);
      expect(controller.filterOptions(ReportFilterSet.coaches).value, isNotNull);
    });

    test('failed filter options do not fail the table', () async {
      final controller = ReportsController(
        _FakeRepository(failFilterOptions: true),
      );
      addTearDown(controller.dispose);

      controller.setView(ReportsView.coaches);
      await Future<void>.delayed(Duration.zero);

      expect(
        controller.filterOptions(ReportFilterSet.coaches).state.isFailed,
        isTrue,
      );
      expect(controller.sliceOf(ReportTable.coaches).state.isReady, isTrue);
    });

    test('refresh drops the cache for the open tab only', () async {
      final repository = _FakeRepository();
      final controller = ReportsController(repository);
      addTearDown(controller.dispose);

      controller.setView(ReportsView.users);
      await Future<void>.delayed(Duration.zero);
      final before = repository.sections.length;

      await controller.refresh();
      expect(
        repository.sections.where((k) => k == ReportKind.users).length,
        2,
      );
      expect(repository.sections.length, before + 1);
    });
  });

  // ---------------------------------------------------------------------------
  group('ReportRepositoryImpl — the wire', () {
    test('every analytics route sends the window', () async {
      final calls = <String, Map<String, String>>{};

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          calls[request.url.path] = request.url.queryParameters;
          return http.Response(
            jsonEncode({'success': true, 'data': {}}),
            200,
          );
        }),
      );

      final repository = ReportRepositoryImpl();
      final range = DateRange(
        from: DateTime(2026, 8, 1),
        to: DateTime(2026, 8, 31),
      );

      for (final kind in ReportKind.values) {
        await repository.fetchSection(kind, range);
      }

      expect(calls.keys.map((path) => path.replaceFirst('/api', '')), [
        '/reports/overview',
        '/reports/revenue',
        '/reports/bookings',
        '/reports/students/new-retention',
        '/reports/memberships',
        '/reports/users',
        '/reports/coaching',
        '/reports/facilities',
      ]);
      for (final query in calls.values) {
        expect(query['from'], '2026-08-01');
        expect(query['to'], '2026-08-31');
      }
    });

    test('every chart route is its own path', () async {
      final paths = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      final repository = ReportRepositoryImpl();
      final range = DateRange(from: DateTime(2026, 8, 1), to: DateTime(2026, 8, 31));

      for (final chart in ReportChart.values) {
        await repository.fetchChart(chart, range);
      }

      // Captured live: the module documents `/reports/charts/…` but the API
      // serves these without that segment.
      expect(paths.map((path) => path.replaceFirst('/api', '')), [
        '/reports/booking-trends',
        '/reports/revenue-by-court',
        '/reports/peak-hours',
        '/reports/court-performance',
      ]);
    });

    test('the table routes send paging, the window and the filters', () async {
      late Uri captured;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      await ReportRepositoryImpl().fetchBookingRows(
        DateRange(from: DateTime(2026, 8, 1), to: DateTime(2026, 8, 31)),
        page: 2,
        limit: 50,
        filters: const ReportFilters(
          values: {'sport': '8'},
          search: 'rahul',
        ),
      );

      expect(captured.path, endsWith('/reports/bookings/all'));
      expect(captured.queryParameters['page'], '2');
      expect(captured.queryParameters['limit'], '50');
      expect(captured.queryParameters['from'], '2026-08-01');
      expect(captured.queryParameters['sport'], '8');
      expect(captured.queryParameters['search'], 'rahul');
    });

    test('the three student and coach table routes are their own paths',
        () async {
      final paths = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(jsonEncode({'success': true, 'data': []}), 200);
        }),
      );

      final repository = ReportRepositoryImpl();
      final range = DateRange(from: DateTime(2026, 8, 1), to: DateTime(2026, 8, 31));

      await repository.fetchStudentRows(range);
      await repository.fetchCoachRows(range);

      expect(paths.map((path) => path.replaceFirst('/api', '')), [
        '/reports/students/all',
        '/reports/coaches/all',
      ]);
    });

    test('the four filter-options routes are their own paths', () async {
      final paths = <String>[];

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          paths.add(request.url.path);
          return http.Response(
            jsonEncode({'success': true, 'data': {}}),
            200,
          );
        }),
      );

      final repository = ReportRepositoryImpl();
      for (final set in ReportFilterSet.values) {
        await repository.fetchFilterOptions(set);
      }

      expect(paths.map((path) => path.replaceFirst('/api', '')), [
        '/reports/bookings/filter-options',
        '/reports/students/filter-options',
        '/reports/students/new-retention/filter-options',
        '/reports/coaches/filter-options',
      ]);
    });

    test('an unset filter is never sent as an empty parameter', () async {
      late Uri captured;

      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          captured = request.url;
          return http.Response(jsonEncode({'success': true}), 200);
        }),
      );

      await ReportRepositoryImpl().fetchCoachRows(
        DateRange(from: DateTime(2026, 8, 1), to: DateTime(2026, 8, 31)),
      );

      expect(captured.queryParameters.containsKey('search'), isFalse);
      expect(captured.queryParameters.containsKey('sport'), isFalse);
    });

    test('a failure reaches the caller as a typed exception', () async {
      ApiClient.instance.overrideHttpClient(
        MockClient((request) async {
          return http.Response(
            jsonEncode({'success': false, 'message': 'Forbidden'}),
            403,
          );
        }),
      );

      await expectLater(
        ReportRepositoryImpl().fetchSection(
          ReportKind.overview,
          DateRange(from: DateTime(2026, 8, 1), to: DateTime(2026, 8, 31)),
        ),
        throwsA(isA<ForbiddenException>()),
      );
    });
  });
}

// -----------------------------------------------------------------------------
// Fakes
// -----------------------------------------------------------------------------

class _FakeRepository implements ReportRepository {
  _FakeRepository({
    this.sectionValues = const {},
    this.total,
    this.pageSize,
    this.echoPageOne = false,
    this.failFilterOptions = false,
    Set<ReportKind>? failSections,
  }) : failSections = failSections ?? <ReportKind>{};

  final Map<ReportKind, ReportSection> sectionValues;
  final int? total;
  final int? pageSize;
  final bool echoPageOne;
  final bool failFilterOptions;
  final Set<ReportKind> failSections;

  final List<ReportKind> sections = <ReportKind>[];
  final List<ReportChart> charts = <ReportChart>[];
  final List<ReportTable> tables = <ReportTable>[];
  final List<ReportFilterSet> filterSets = <ReportFilterSet>[];
  ReportFilters? lastFilters;

  @override
  Future<ReportSection> fetchSection(ReportKind kind, DateRange range) async {
    sections.add(kind);
    if (failSections.contains(kind)) {
      throw const ServerException('The reports service is down');
    }
    return sectionValues[kind] ??
        const ReportSection(
          figures: [
            ReportFigure(key: 'total', label: 'Total', value: 1),
          ],
        );
  }

  @override
  Future<ChartSeries> fetchChart(ReportChart chart, DateRange range) async {
    charts.add(chart);
    return ChartSeries(
      key: chart.name,
      label: chart.name,
      points: const [ChartPoint(label: 'Mon', value: 4)],
    );
  }

  @override
  Future<Paged<BookingReportRow>> fetchBookingRows(
    DateRange range, {
    int page = 1,
    int limit = 20,
    ReportFilters filters = const ReportFilters(),
  }) async {
    tables.add(ReportTable.bookings);
    lastFilters = filters;

    if (pageSize != null && total != null) {
      final served = echoPageOne ? 1 : page;
      final start = (served - 1) * pageSize!;
      return Paged<BookingReportRow>(
        items: [
          for (var i = start; i < start + pageSize! && i < total!; i++)
            BookingReportRow(id: '${i + 1}'),
        ],
        page: served,
        limit: pageSize!,
        total: total!,
        totalPages: (total! / pageSize!).ceil(),
      );
    }

    return const Paged<BookingReportRow>(
      items: [BookingReportRow(id: '1'), BookingReportRow(id: '2')],
      page: 1,
      limit: 20,
      total: 2,
      totalPages: 1,
    );
  }

  @override
  Future<Paged<StudentReportRow>> fetchStudentRows(
    DateRange range, {
    int page = 1,
    int limit = 20,
    ReportFilters filters = const ReportFilters(),
  }) async {
    tables.add(ReportTable.students);
    lastFilters = filters;
    return const Paged<StudentReportRow>(
      items: [StudentReportRow(id: 's1')],
      page: 1,
      limit: 20,
      total: 1,
      totalPages: 1,
    );
  }

  @override
  Future<Paged<CoachReportRow>> fetchCoachRows(
    DateRange range, {
    int page = 1,
    int limit = 20,
    ReportFilters filters = const ReportFilters(),
  }) async {
    tables.add(ReportTable.coaches);
    lastFilters = filters;
    return const Paged<CoachReportRow>(
      items: [CoachReportRow(id: 'c1')],
      page: 1,
      limit: 20,
      total: 1,
      totalPages: 1,
    );
  }

  @override
  Future<ReportFilterOptions> fetchFilterOptions(ReportFilterSet set) async {
    filterSets.add(set);
    if (failFilterOptions) throw const ServerException('Options are down');
    return const ReportFilterOptions(
      groups: {
        'sports': [FilterOption(id: '8', label: 'Badminton')],
      },
    );
  }
}
