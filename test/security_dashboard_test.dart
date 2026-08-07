import 'package:flutter_test/flutter_test.dart';

import 'package:nahata_app/features/admin/domain/entities/paged.dart';
import 'package:nahata_app/features/admin/domain/entities/visitor_pass.dart';
import 'package:nahata_app/features/admin/domain/repositories/visitor_pass_repository.dart';
import 'package:nahata_app/features/admin/presentation/state/view_state.dart';
import 'package:nahata_app/features/security/domain/entities/security_dashboard_data.dart';
import 'package:nahata_app/features/security/presentation/state/security_dashboard_controller.dart';
import 'package:nahata_app/models/sports_complex_model.dart';

/// A fixed "now" so every window and every derived figure is deterministic.
final DateTime _now = DateTime(2026, 8, 7, 14, 30);
DateTime get _today => DateTime(2026, 8, 7);

VisitorPass _pass({
  required int id,
  DateTime? created,
  DateTime? entry,
  DateTime? exit,
  String? status,
  String? name,
  String? purpose = 'Meeting',
  String? phone = '9876543210',
  String? staff = 'Ravi Gate',
}) {
  return VisitorPass(
    id: id,
    passCode: 'NS-$id',
    visitorName: name ?? 'Visitor $id',
    phoneNumber: phone,
    visitPurpose: purpose,
    statusRaw: status,
    entryTime: entry,
    exitTime: exit,
    createdByName: staff,
    createdAt: created ?? _today.add(const Duration(hours: 9)),
  );
}

/// Serves canned pages, and records what was asked for.
class _FakeRepository implements VisitorPassRepository {
  _FakeRepository(this.pages);

  /// One entry per page, in order.
  final List<List<VisitorPass>> pages;

  final List<int> requestedPages = [];
  int totalPages = 0;

  @override
  Future<Paged<VisitorPass>> fetchVisitorPasses({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    requestedPages.add(page);
    final index = page - 1;
    final items = index < pages.length ? pages[index] : <VisitorPass>[];
    return Paged<VisitorPass>(
      items: items,
      page: page,
      limit: limit,
      total: pages.fold<int>(0, (sum, rows) => sum + rows.length),
      totalPages: totalPages == 0 ? pages.length : totalPages,
    );
  }

  @override
  Future<VisitorPass> fetchVisitorPass(String idOrCode) async =>
      throw UnimplementedError();

  @override
  Future<VisitorPass> createVisitorPass(VisitorPassDraft draft) async =>
      throw UnimplementedError();

  @override
  Future<VisitorPassCheck> verifyPass({
    required String passCode,
    required VisitorScanType scanType,
  }) async =>
      throw UnimplementedError();

  @override
  Future<VisitorPassCheck> lookupPass(String passCode) async =>
      throw UnimplementedError();

  @override
  Future<String> sendPassEmail({
    required String idOrCode,
    required String recipientEmail,
    required String recipientName,
  }) async =>
      throw UnimplementedError();

  @override
  Future<void> deleteVisitorPass(String idOrCode) async =>
      throw UnimplementedError();

  @override
  Future<List<SportsComplex>> fetchSportComplexes({bool refresh = false}) async =>
      const [];
}

void main() {
  group('SecurityWindow', () {
    test('today runs midnight to midnight', () {
      final window = SecurityWindow.of(SecurityRange.today, _now);

      expect(window.start, _today);
      expect(window.end, _today.add(const Duration(days: 1)));
      // A pass created a minute before midnight is still today's.
      expect(
        window.contains(_today.add(const Duration(hours: 23, minutes: 59))),
        isTrue,
      );
      expect(window.contains(_today.subtract(const Duration(minutes: 1))),
          isFalse);
      expect(window.isSingleDay, isTrue);
    });

    test('yesterday is the day before, and its previous window the day before that',
        () {
      final window = SecurityWindow.of(SecurityRange.yesterday, _now);

      expect(window.start, DateTime(2026, 8, 6));
      expect(window.end, _today);
      expect(window.previous.start, DateTime(2026, 8, 5));
      expect(window.previous.end, DateTime(2026, 8, 6));
    });

    test('this week starts on Monday', () {
      // 7 Aug 2026 is a Friday.
      final window = SecurityWindow.of(SecurityRange.thisWeek, _now);

      expect(window.start, DateTime(2026, 8, 3));
      expect(window.start.weekday, DateTime.monday);
      expect(window.end, _today.add(const Duration(days: 1)));
    });

    test('this month starts on the first', () {
      final window = SecurityWindow.of(SecurityRange.thisMonth, _now);

      expect(window.start, DateTime(2026, 8));
      expect(window.days, 7);
    });

    test('a custom range covers whole days, and a backwards one is corrected',
        () {
      final window = SecurityWindow.of(
        SecurityRange.custom,
        _now,
        customStart: DateTime(2026, 8, 1, 18),
        customEnd: DateTime(2026, 8, 3, 4),
      );

      expect(window.start, DateTime(2026, 8, 1));
      expect(window.end, DateTime(2026, 8, 4));

      final backwards = SecurityWindow.of(
        SecurityRange.custom,
        _now,
        customStart: DateTime(2026, 8, 5),
        customEnd: DateTime(2026, 8, 2),
      );
      expect(backwards.start.isBefore(backwards.end), isTrue);
    });
  });

  group('SecurityDashboardData', () {
    late List<VisitorPass> passes;

    setUp(() {
      passes = [
        // Inside: entered at 08:00, never left.
        _pass(
          id: 1,
          created: _today.add(const Duration(hours: 7, minutes: 50)),
          entry: _today.add(const Duration(hours: 8)),
          status: 'Checked In',
        ),
        // Completed: in at 08:10, out at 08:35.
        _pass(
          id: 2,
          created: _today.add(const Duration(hours: 8)),
          entry: _today.add(const Duration(hours: 8, minutes: 10)),
          exit: _today.add(const Duration(hours: 8, minutes: 35)),
          status: 'Checked Out',
          purpose: 'Delivery',
        ),
        // Pending: pass issued, never scanned.
        _pass(
          id: 3,
          created: _today.add(const Duration(hours: 9)),
          status: 'Pending',
          staff: 'Sunita Desk',
        ),
        // Yesterday, for the trend.
        _pass(
          id: 4,
          created: _today.subtract(const Duration(hours: 20)),
          entry: _today.subtract(const Duration(hours: 19)),
          exit: _today.subtract(const Duration(hours: 18)),
          status: 'Checked Out',
        ),
      ];
    });

    SecurityDashboardData build([SecurityRange range = SecurityRange.today]) =>
        SecurityDashboardData.from(
          all: passes,
          window: SecurityWindow.of(range, _now),
          now: _now,
        );

    test('counts today correctly', () {
      final data = build();

      expect(data.totalPasses, 3, reason: 'three passes issued today');
      expect(data.visitorsInWindow, 3);
      expect(data.pending, 1);
      expect(data.checkedOut, 1);
      expect(data.inside, 1);
      // Still usable: the pending one plus the visitor still inside.
      expect(data.active, 2);
      // "Already OUT / expired" — the completed visit counts here.
      expect(data.expired, 1);
    });

    test('compares against the previous window for the trend', () {
      final data = build();

      expect(data.visitorsInPreviousWindow, 1, reason: 'one pass yesterday');
      expect(data.visitorsMetric.total, 3);
      expect(data.visitorsMetric.lastMonth, 1);
      expect(data.visitorsMetric.growth, 200);
      expect(data.visitorsMetric.isPositive, isTrue);
    });

    test('reports no growth figure when there is no baseline', () {
      passes = [passes.first];
      final data = build();

      expect(data.visitorsInPreviousWindow, 0);
      // +100% off a zero yesterday would be a claim the data cannot support.
      expect(data.visitorsMetric.growth, isNull);
    });

    test('counts everyone inside, even if they entered before the window', () {
      passes.add(
        _pass(
          id: 5,
          created: _today.subtract(const Duration(days: 1, hours: 2)),
          entry: _today.subtract(const Duration(hours: 22)),
          status: 'Checked In',
        ),
      );

      final data = build();

      // Issued yesterday, so not in today's totals...
      expect(data.totalPasses, 3);
      // ...but still in the building, so the gate must see them.
      expect(data.inside, 2);
      expect(data.insidePasses, hasLength(2));
    });

    test('builds the timeline newest first, from movement times', () {
      final data = build();

      // Two entries and one exit happened today.
      expect(data.timeline, hasLength(3));
      expect(data.timeline.first.timeLabel, '08:35');
      expect(data.timeline.first.isEntry, isFalse);
      expect(data.timeline.first.title, contains('exited'));
      expect(data.timeline.last.timeLabel, '08:00');
      expect(data.timeline.last.isEntry, isTrue);
    });

    test('breaks the statuses down for the pie, dropping empty slices', () {
      final labels =
          build().statusBreakdown.points.map((p) => p.label).toList();

      expect(labels, ['Pending', 'Inside', 'Completed']);
      expect(build().statusBreakdown.total, 3);
    });

    test('keeps all 24 buckets in the hourly series', () {
      final hourly = build().hourlyTrend;

      expect(hourly.points, hasLength(24));
      expect(hourly.points[8].label, '08:00');
      expect(hourly.points[8].value, 2, reason: 'two entries in the 8am hour');
      expect(hourly.points[9].value, 0);
    });

    test('charts seven days, with quiet days as zero', () {
      final daily = build().dailyTrend;

      expect(daily.points, hasLength(7));
      expect(daily.points.last.label, '7/8');
      expect(daily.points.last.value, 3);
      expect(daily.points[5].value, 1, reason: 'yesterday had one pass');
      expect(daily.points.first.value, 0);
    });

    test('offers the distinct purposes and staff for the filters', () {
      final data = build();

      expect(data.purposes, ['Delivery', 'Meeting']);
      expect(data.staff, ['Ravi Gate', 'Sunita Desk']);
    });

    test('an empty sweep produces empty series, not zero-value charts', () {
      passes = [];
      final data = build();

      expect(data.isEmpty, isTrue);
      expect(data.statusBreakdown.isEmpty, isTrue);
      expect(data.hourlyTrend.isEmpty, isTrue);
      expect(data.dailyTrend.isEmpty, isTrue);
      expect(data.timeline, isEmpty);
    });

    test('a pass with no status falls back to what its timestamps imply', () {
      passes = [
        _pass(
          id: 9,
          created: _today.add(const Duration(hours: 10)),
          entry: _today.add(const Duration(hours: 10, minutes: 5)),
          status: null,
        ),
      ];

      final data = build();
      expect(data.inside, 1);
      expect(data.pending, 0);
    });
  });

  group('SecurityDashboardController', () {
    test('sweeps until the pages fall outside the window', () async {
      final repository = _FakeRepository([
        [_pass(id: 1, created: _today.add(const Duration(hours: 9)))],
        [_pass(id: 2, created: _today.subtract(const Duration(hours: 30)))],
        [_pass(id: 3, created: _today.subtract(const Duration(days: 9)))],
      ]);

      final controller = SecurityDashboardController(
        repository,
        clock: () => _now,
      );
      await controller.load();

      expect(controller.state, ViewState.ready);
      // Page 2 is entirely older than today, so page 3 is never asked for.
      expect(repository.requestedPages, [1, 2]);
      expect(controller.data.totalPasses, 1);
      expect(controller.truncated, isFalse);
      controller.dispose();
    });

    test('serves the cache inside the TTL and re-sweeps when forced', () async {
      final repository = _FakeRepository([
        [_pass(id: 1, created: _today.add(const Duration(hours: 9)))],
      ]);

      final controller = SecurityDashboardController(
        repository,
        clock: () => _now,
      );

      await controller.load();
      await controller.load();
      expect(repository.requestedPages, hasLength(1));

      await controller.refresh();
      expect(repository.requestedPages, hasLength(2));
      controller.dispose();
    });

    test('flags a truncated sweep rather than under-reporting silently',
        () async {
      // Every page is inside the window and claims another follows, so the
      // sweep can only stop at the cap.
      final repository = _FakeRepository(
        List.generate(
          SecurityDashboardController.maxPages + 3,
          (index) => [
            _pass(
              id: index + 1,
              created: _today.add(Duration(minutes: index)),
            ),
          ],
        ),
      );

      final controller = SecurityDashboardController(
        repository,
        clock: () => _now,
      );
      await controller.load();

      expect(
        repository.requestedPages,
        hasLength(SecurityDashboardController.maxPages),
      );
      expect(controller.truncated, isTrue);
      controller.dispose();
    });

    test('filters the activity table without changing the cards', () async {
      final repository = _FakeRepository([
        [
          _pass(
            id: 1,
            created: _today.add(const Duration(hours: 9)),
            status: 'Pending',
            purpose: 'Meeting',
          ),
          _pass(
            id: 2,
            created: _today.add(const Duration(hours: 10)),
            entry: _today.add(const Duration(hours: 10, minutes: 2)),
            status: 'Checked In',
            purpose: 'Delivery',
            name: 'Asha Kulkarni',
          ),
        ],
      ]);

      final controller = SecurityDashboardController(
        repository,
        clock: () => _now,
      );
      await controller.load();

      expect(controller.filteredPasses, hasLength(2));

      controller.setStatusFilter(VisitorPassStatus.pending);
      expect(controller.filteredPasses, hasLength(1));
      expect(controller.filteredPasses.single.id, 1);
      // The cards still describe the whole window.
      expect(controller.data.totalPasses, 2);
      expect(controller.hasFilters, isTrue);

      controller.setStatusFilter(null);
      controller.setPurposeFilter('Delivery');
      expect(controller.filteredPasses.single.id, 2);

      controller.clearFilters();
      expect(controller.filteredPasses, hasLength(2));
      expect(controller.activeFilterCount, 0);
      controller.dispose();
    });

    test('searches name, phone, code and purpose', () async {
      final repository = _FakeRepository([
        [
          _pass(
            id: 1,
            created: _today.add(const Duration(hours: 9)),
            name: 'Asha Kulkarni',
            phone: '9000000001',
          ),
          _pass(
            id: 2,
            created: _today.add(const Duration(hours: 10)),
            name: 'Bhavesh Rao',
            phone: '9000000002',
            purpose: 'Delivery',
          ),
        ],
      ]);

      final controller = SecurityDashboardController(
        repository,
        clock: () => _now,
      );
      await controller.load();

      // Debounced for the UI, but the filter itself reads the live value.
      controller.onSearchChanged('asha');
      expect(controller.filteredPasses.single.visitorName, 'Asha Kulkarni');

      controller.onSearchChanged('9000000002');
      expect(controller.filteredPasses.single.id, 2);

      controller.onSearchChanged('NS-1');
      expect(controller.filteredPasses.single.id, 1);

      controller.onSearchChanged('delivery');
      expect(controller.filteredPasses.single.id, 2);

      controller.clearSearch();
      expect(controller.filteredPasses, hasLength(2));
      controller.dispose();
    });

    test('pages the activity table in memory', () async {
      final rows = List.generate(
        45,
        (index) => _pass(
          id: index + 1,
          created: _today.add(Duration(minutes: index)),
        ),
      );
      final repository = _FakeRepository([rows])..totalPages = 1;

      final controller = SecurityDashboardController(
        repository,
        clock: () => _now,
      );
      await controller.load();

      expect(controller.activityPageCount, 3);
      expect(controller.activityRows, hasLength(20));
      expect(controller.canPagePrevious, isFalse);

      controller.nextActivityPage();
      expect(controller.activityPage, 2);
      controller.goToActivityPage(3);
      expect(controller.activityRows, hasLength(5));
      expect(controller.canPageNext, isFalse);

      // A filter that shrinks the list must not strand the table on a page
      // that no longer exists.
      controller.onSearchChanged('NS-1');
      controller.goToActivityPage(1);
      expect(controller.activityPage, 1);
      // Only one request went out: paging is in memory.
      expect(repository.requestedPages, hasLength(1));
      controller.dispose();
    });

    test('surfaces a failed load instead of showing empty figures', () async {
      final repository = _ThrowingRepository();
      final controller = SecurityDashboardController(
        repository,
        clock: () => _now,
      );

      await controller.load();

      expect(controller.state, ViewState.failed);
      expect(controller.error, isNotNull);
      expect(controller.hasData, isFalse);
      controller.dispose();
    });
  });
}

class _ThrowingRepository extends _FakeRepository {
  _ThrowingRepository() : super(const []);

  @override
  Future<Paged<VisitorPass>> fetchVisitorPasses({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    throw Exception('network down');
  }
}