import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/paged.dart';
import '../../domain/entities/report.dart';
import '../../domain/repositories/report_repository.dart';
import 'view_state.dart';

/// The report screens, in the order the module lists them.
enum ReportsView {
  dashboard('Dashboard', 'Overview'),
  revenue('Revenue', 'Revenue'),
  bookings('Bookings', 'Bookings'),
  students('Students', 'Students'),
  coaches('Coaches', 'Coaches'),
  memberships('Memberships', 'Members'),
  users('Users', 'Users'),
  coaching('Coaching', 'Coaching'),
  facilities('Facilities', 'Courts');

  const ReportsView(this.label, this.shortLabel);

  final String label;
  final String shortLabel;
}

/// One loadable piece of a report: its state, its error and its cache key.
///
/// Caching is by window: reopening a tab for a range already read is free, and
/// changing the range invalidates everything at once. This is what keeps the
/// dashboard from firing twelve requests every time a tab is tapped.
class ReportSlice<T> {
  ReportSlice();

  ViewState state = ViewState.idle;
  String? error;
  T? value;

  /// The `DateRange.key` the held value was read for.
  String? loadedFor;

  bool needs(String rangeKey) => value == null || loadedFor != rangeKey;

  bool get isFirstLoad => state.isLoading && value == null;
  bool get isRefreshing => state.isLoading && value != null;

  void reset() {
    state = ViewState.idle;
    error = null;
    value = null;
    loadedFor = null;
  }
}

/// Everything the Reports module needs.
///
/// Nineteen endpoints behind nine tabs. Rules that hold throughout:
/// * **Nothing loads until its tab is opened**, and nothing reloads while its
///   cached window still matches — the module asks for both.
/// * **The date range is the single source of truth.** Changing it clears every
///   cache and reloads only the tab on screen; the rest reload when opened.
/// * **A failed slice never fails the page** — each card, table and chart shows
///   its own retry.
class ReportsController extends ChangeNotifier {
  ReportsController(this._repository, {DateRange? initialRange})
    : _range = initialRange ?? DateRangePreset.last30.range() {
    AdminLog.life('ReportsController created');
  }

  final ReportRepository _repository;

  static const Duration searchDebounce = Duration(milliseconds: 350);
  static const Duration rangeDebounce = Duration(milliseconds: 250);
  static const List<int> pageSizes = [10, 20, 50, 100];

  ReportsView _view = ReportsView.dashboard;
  DateRange _range;
  DateRangePreset? _preset = DateRangePreset.last30;

  // Analytics sections and standalone charts, one slice each.
  final Map<ReportKind, ReportSlice<ReportSection>> _sections = {
    for (final kind in ReportKind.values) kind: ReportSlice<ReportSection>(),
  };
  final Map<ReportChart, ReportSlice<ChartSeries>> _charts = {
    for (final chart in ReportChart.values) chart: ReportSlice<ChartSeries>(),
  };
  final Map<ReportFilterSet, ReportSlice<ReportFilterOptions>> _filterOptions = {
    for (final set in ReportFilterSet.values)
      set: ReportSlice<ReportFilterOptions>(),
  };

  // The three tabular reports.
  final ReportSlice<Paged<BookingReportRow>> _bookingRows =
      ReportSlice<Paged<BookingReportRow>>();
  final ReportSlice<Paged<StudentReportRow>> _studentRows =
      ReportSlice<Paged<StudentReportRow>>();
  final ReportSlice<Paged<CoachReportRow>> _coachRows =
      ReportSlice<Paged<CoachReportRow>>();

  final Map<ReportTable, List<Object>> _accumulated = {
    for (final table in ReportTable.values) table: <Object>[],
  };
  final Map<ReportTable, int> _pages = {
    for (final table in ReportTable.values) table: 1,
  };
  final Map<ReportTable, bool> _loadingMore = {
    for (final table in ReportTable.values) table: false,
  };
  final Map<ReportTable, ReportFilters> _filters = {
    for (final table in ReportTable.values) table: const ReportFilters(),
  };
  final Map<ReportTable, String> _searchText = {
    for (final table in ReportTable.values) table: '',
  };

  int _limit = 20;

  Timer? _searchTimer;
  Timer? _rangeTimer;
  int _requestId = 0;
  bool _disposed = false;

  // --- Reads -----------------------------------------------------------------

  ReportsView get view => _view;
  DateRange get range => _range;
  DateRangePreset? get preset => _preset;
  int get limit => _limit;

  ReportSlice<ReportSection> section(ReportKind kind) => _sections[kind]!;
  ReportSlice<ChartSeries> chart(ReportChart chart) => _charts[chart]!;
  ReportSlice<ReportFilterOptions> filterOptions(ReportFilterSet set) =>
      _filterOptions[set]!;

  ReportSlice<Paged<BookingReportRow>> get bookingRows => _bookingRows;
  ReportSlice<Paged<StudentReportRow>> get studentRows => _studentRows;
  ReportSlice<Paged<CoachReportRow>> get coachRows => _coachRows;

  ReportFilters filtersFor(ReportTable table) => _filters[table]!;
  String searchFor(ReportTable table) => _searchText[table]!;
  bool isLoadingMore(ReportTable table) => _loadingMore[table]!;

  /// Every row loaded so far for [table] — page one plus each appended page.
  List<BookingReportRow> get bookings =>
      _accumulated[ReportTable.bookings]!.cast<BookingReportRow>();
  List<StudentReportRow> get students =>
      _accumulated[ReportTable.students]!.cast<StudentReportRow>();
  List<CoachReportRow> get coaches =>
      _accumulated[ReportTable.coaches]!.cast<CoachReportRow>();

  Paged<Object>? _pageOf(ReportTable table) => switch (table) {
    ReportTable.bookings => _bookingRows.value,
    ReportTable.students => _studentRows.value,
    ReportTable.coaches => _coachRows.value,
  };

  ReportSlice<Object> sliceOf(ReportTable table) => switch (table) {
    ReportTable.bookings => _bookingRows as ReportSlice<Object>,
    ReportTable.students => _studentRows as ReportSlice<Object>,
    ReportTable.coaches => _coachRows as ReportSlice<Object>,
  };

  int loadedCount(ReportTable table) => _accumulated[table]!.length;

  int? totalCount(ReportTable table) => _pageOf(table)?.total;

  bool hasMore(ReportTable table) {
    final page = _pageOf(table);
    if (page == null) return false;
    final total = page.effectiveTotalPages;
    return total > 0 && _pages[table]! < total;
  }

  /// The eight cards the dashboard opens with, drawn from four sections.
  ///
  /// Each keeps its own source so a card can say "not reported" without the
  /// others being dragged down with it.
  List<ReportFigure> get dashboardCards {
    final overview = _sections[ReportKind.overview]!.value;
    final coaching = _sections[ReportKind.coaching]!.value;
    final facilities = _sections[ReportKind.facilities]!.value;
    final memberships = _sections[ReportKind.memberships]!.value;

    ReportFigure card(
      String key,
      String label,
      ReportFigure? source,
      ReportFormat format,
    ) => ReportFigure(
      key: key,
      label: label,
      value: source?.value,
      format: format,
    );

    return [
      card(
        'revenue',
        'Revenue',
        overview?.figure('revenue'),
        ReportFormat.currency,
      ),
      card(
        'bookings',
        'Total bookings',
        overview?.figure('bookings'),
        ReportFormat.count,
      ),
      card(
        'members',
        'Active members',
        memberships?.figure('active') ?? overview?.figure('memberships'),
        ReportFormat.count,
      ),
      card(
        'students',
        'Students',
        overview?.figure('students'),
        ReportFormat.count,
      ),
      card(
        'coaches',
        'Coaches',
        overview?.figure('coaches'),
        ReportFormat.count,
      ),
      card(
        'utilization',
        'Court utilization',
        facilities?.figure('utilization') ?? overview?.figure('occupancy'),
        ReportFormat.percent,
      ),
      card(
        'coachingRevenue',
        'Coaching revenue',
        coaching?.figure('revenue'),
        ReportFormat.currency,
      ),
      card(
        'facilityRevenue',
        'Facility revenue',
        _sections[ReportKind.revenue]!.value?.figure('total'),
        ReportFormat.currency,
      ),
    ];
  }

  /// True while the dashboard is still assembling its first set of figures.
  bool get dashboardIsLoading => _dashboardKinds.any(
    (kind) => _sections[kind]!.isFirstLoad,
  );

  /// The dashboard's own sources failed as a whole — worth a retry banner.
  bool get dashboardFailed => _dashboardKinds.every(
    (kind) => _sections[kind]!.state.isFailed,
  );

  static const List<ReportKind> _dashboardKinds = [
    ReportKind.overview,
    ReportKind.revenue,
    ReportKind.memberships,
    ReportKind.coaching,
    ReportKind.facilities,
  ];

  // --- Navigation and window -------------------------------------------------

  /// Opens a tab and loads only what that tab needs, and only if it is stale.
  void setView(ReportsView view) {
    if (_view == view) return;
    AdminLog.ui('Reports view → ${view.name}');
    _view = view;
    notifyListeners();
    loadCurrent();
  }

  void setRange(DateRange range, {DateRangePreset? preset}) {
    if (range.key == _range.key && preset == _preset) return;

    AdminLog.ui('Reports range → ${range.key}');
    _range = range;
    _preset = preset;

    // Everything held describes the old window, so none of it is reusable.
    _invalidate();
    notifyListeners();

    // Debounced: dragging a range picker across a month should not fire a
    // request per day.
    _rangeTimer?.cancel();
    _rangeTimer = Timer(rangeDebounce, () {
      if (_disposed) return;
      loadCurrent();
    });
  }

  void setPreset(DateRangePreset preset) =>
      setRange(preset.range(), preset: preset);

  void _invalidate() {
    _requestId++;
    for (final slice in _sections.values) {
      slice.reset();
    }
    for (final slice in _charts.values) {
      slice.reset();
    }
    _bookingRows.reset();
    _studentRows.reset();
    _coachRows.reset();
    for (final table in ReportTable.values) {
      _accumulated[table] = <Object>[];
      _pages[table] = 1;
      _loadingMore[table] = false;
    }
    // Filter options are not window-scoped, so they survive.
  }

  /// Loads whatever the open tab needs. Safe to call repeatedly: each slice
  /// checks its own cache first.
  Future<void> loadCurrent() async {
    switch (_view) {
      case ReportsView.dashboard:
        await Future.wait([
          for (final kind in _dashboardKinds) _loadSection(kind),
          _loadChart(ReportChart.bookingTrends),
          _loadChart(ReportChart.revenueByCourt),
        ]);
      case ReportsView.revenue:
        await Future.wait([
          _loadSection(ReportKind.revenue),
          _loadChart(ReportChart.revenueByCourt),
        ]);
      case ReportsView.bookings:
        await Future.wait([
          _loadSection(ReportKind.bookings),
          _loadChart(ReportChart.bookingTrends),
          _loadTable(ReportTable.bookings),
          _loadFilterOptions(ReportFilterSet.bookings),
        ]);
      case ReportsView.students:
        await Future.wait([
          _loadSection(ReportKind.retention),
          _loadTable(ReportTable.students),
          _loadFilterOptions(ReportFilterSet.students),
          _loadFilterOptions(ReportFilterSet.retention),
        ]);
      case ReportsView.coaches:
        await Future.wait([
          _loadTable(ReportTable.coaches),
          _loadFilterOptions(ReportFilterSet.coaches),
        ]);
      case ReportsView.memberships:
        await _loadSection(ReportKind.memberships);
      case ReportsView.users:
        await _loadSection(ReportKind.users);
      case ReportsView.coaching:
        await _loadSection(ReportKind.coaching);
      case ReportsView.facilities:
        await Future.wait([
          _loadSection(ReportKind.facilities),
          _loadChart(ReportChart.peakHours),
          _loadChart(ReportChart.courtPerformance),
        ]);
    }
  }

  /// Pull-to-refresh and the Refresh button: drops the cache for the open tab
  /// and reads it again.
  Future<void> refresh() async {
    AdminLog.ui('Reports refresh requested');
    _requestId++;

    for (final kind in ReportKind.values) {
      if (_kindsFor(_view).contains(kind)) _sections[kind]!.loadedFor = null;
    }
    for (final chart in _chartsFor(_view)) {
      _charts[chart]!.loadedFor = null;
    }
    final table = tableFor(_view);
    if (table != null) {
      sliceOf(table).loadedFor = null;
      _accumulated[table] = <Object>[];
      _pages[table] = 1;
    }

    await loadCurrent();
  }

  /// The table a view shows, if any.
  static ReportTable? tableFor(ReportsView view) => switch (view) {
    ReportsView.bookings => ReportTable.bookings,
    ReportsView.students => ReportTable.students,
    ReportsView.coaches => ReportTable.coaches,
    _ => null,
  };

  static List<ReportKind> _kindsFor(ReportsView view) => switch (view) {
    ReportsView.dashboard => _dashboardKinds,
    ReportsView.revenue => const [ReportKind.revenue],
    ReportsView.bookings => const [ReportKind.bookings],
    ReportsView.students => const [ReportKind.retention],
    ReportsView.memberships => const [ReportKind.memberships],
    ReportsView.users => const [ReportKind.users],
    ReportsView.coaching => const [ReportKind.coaching],
    ReportsView.facilities => const [ReportKind.facilities],
    ReportsView.coaches => const [],
  };

  static List<ReportChart> _chartsFor(ReportsView view) => switch (view) {
    ReportsView.dashboard => const [
      ReportChart.bookingTrends,
      ReportChart.revenueByCourt,
    ],
    ReportsView.revenue => const [ReportChart.revenueByCourt],
    ReportsView.bookings => const [ReportChart.bookingTrends],
    ReportsView.facilities => const [
      ReportChart.peakHours,
      ReportChart.courtPerformance,
    ],
    _ => const [],
  };

  // --- Slice loading ---------------------------------------------------------

  Future<void> _loadSection(ReportKind kind, {bool force = false}) async {
    final slice = _sections[kind]!;
    if (!force && !slice.needs(_range.key)) return;
    if (slice.state.isLoading) return;

    final id = _requestId;
    final rangeKey = _range.key;

    slice.state = ViewState.loading;
    slice.error = null;
    _safeNotify();

    try {
      final value = await _repository.fetchSection(kind, _range);
      if (_disposed || id != _requestId) return;
      slice.value = value;
      slice.loadedFor = rangeKey;
      slice.state = ViewState.ready;
    } on ApiException catch (error) {
      if (_disposed || id != _requestId) return;
      slice.state = ViewState.failed;
      slice.error = error.message;
      AdminLog.failure('Report ${kind.name} failed: ${error.message}');
    } catch (error, stackTrace) {
      if (_disposed || id != _requestId) return;
      slice.state = ViewState.failed;
      slice.error = 'Could not load this report. Please try again.';
      AdminLog.failure(
        'Report ${kind.name} crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> _loadChart(ReportChart chart, {bool force = false}) async {
    final slice = _charts[chart]!;
    if (!force && !slice.needs(_range.key)) return;
    if (slice.state.isLoading) return;

    final id = _requestId;
    final rangeKey = _range.key;

    slice.state = ViewState.loading;
    slice.error = null;
    _safeNotify();

    try {
      final value = await _repository.fetchChart(chart, _range);
      if (_disposed || id != _requestId) return;
      slice.value = value;
      slice.loadedFor = rangeKey;
      slice.state = ViewState.ready;
    } on ApiException catch (error) {
      if (_disposed || id != _requestId) return;
      slice.state = ViewState.failed;
      slice.error = error.message;
    } catch (error, stackTrace) {
      if (_disposed || id != _requestId) return;
      slice.state = ViewState.failed;
      slice.error = 'Could not load this chart.';
      AdminLog.failure(
        'Chart ${chart.name} crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  /// Filter options are not window-scoped: they are read once and kept.
  Future<void> _loadFilterOptions(
    ReportFilterSet set, {
    bool force = false,
  }) async {
    final slice = _filterOptions[set]!;
    if (!force && slice.value != null) return;
    if (slice.state.isLoading) return;

    slice.state = ViewState.loading;
    _safeNotify();

    try {
      slice.value = await _repository.fetchFilterOptions(set);
      if (_disposed) return;
      slice.state = ViewState.ready;
    } catch (error, stackTrace) {
      if (_disposed) return;
      // The table still works; only the dropdowns are missing, so this is not
      // a page error.
      slice.state = ViewState.failed;
      AdminLog.failure(
        'Filter options ${set.name} failed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  Future<void> _loadTable(ReportTable table, {bool force = false}) async {
    final slice = sliceOf(table);
    if (!force && !slice.needs(_range.key)) return;
    if (slice.state.isLoading) return;

    final id = _requestId;
    final rangeKey = _range.key;

    slice.state = ViewState.loading;
    slice.error = null;
    _safeNotify();

    try {
      final page = await _fetchTablePage(table, 1);
      if (_disposed || id != _requestId) return;

      _accumulated[table] = List<Object>.from(page.items);
      _pages[table] = 1;
      _store(table, page);
      slice.loadedFor = rangeKey;
      slice.state = ViewState.ready;
    } on ApiException catch (error) {
      if (_disposed || id != _requestId) return;
      slice.state = ViewState.failed;
      slice.error = error.message;
    } catch (error, stackTrace) {
      if (_disposed || id != _requestId) return;
      slice.state = ViewState.failed;
      slice.error = 'Could not load this report. Please try again.';
      AdminLog.failure(
        'Report table ${table.name} crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _safeNotify();
    }
  }

  /// Appends the next page — the infinite scroll.
  ///
  /// A no-op while another read is running, so a fast flick cannot request the
  /// same page twice.
  Future<void> loadMore(ReportTable table) async {
    final slice = sliceOf(table);
    if (_loadingMore[table]! || slice.state.isLoading || !hasMore(table)) {
      return;
    }

    final id = _requestId;
    final next = _pages[table]! + 1;
    _loadingMore[table] = true;
    _safeNotify();

    AdminLog.state('Report ${table.name} appending page $next');

    try {
      final page = await _fetchTablePage(table, next);
      if (_disposed || id != _requestId) return;

      // Guarded against a backend that echoes page one for an out-of-range
      // page: appending it would duplicate every row already on screen.
      final seen = _accumulated[table]!.map(_idOf).toSet();
      final fresh = page.items
          .where((row) => !seen.contains(_idOf(row)))
          .toList(growable: false);

      _accumulated[table] = [..._accumulated[table]!, ...fresh];
      _pages[table] = page.page > _pages[table]! ? page.page : next;
      _store(table, page);
    } on ApiException catch (error) {
      // The rows already on screen stay; only the append failed.
      AdminLog.failure('Could not append page $next', error: error);
    } catch (error, stackTrace) {
      AdminLog.failure(
        'Report append crashed',
        error: error,
        stackTrace: stackTrace,
      );
    } finally {
      _loadingMore[table] = false;
      _safeNotify();
    }
  }

  Future<Paged<Object>> _fetchTablePage(ReportTable table, int page) async {
    final filters = _filters[table]!;
    switch (table) {
      case ReportTable.bookings:
        return _repository.fetchBookingRows(
          _range,
          page: page,
          limit: _limit,
          filters: filters,
        );
      case ReportTable.students:
        return _repository.fetchStudentRows(
          _range,
          page: page,
          limit: _limit,
          filters: filters,
        );
      case ReportTable.coaches:
        return _repository.fetchCoachRows(
          _range,
          page: page,
          limit: _limit,
          filters: filters,
        );
    }
  }

  void _store(ReportTable table, Paged<Object> page) {
    switch (table) {
      case ReportTable.bookings:
        _bookingRows.value = Paged<BookingReportRow>(
          items: page.items.cast<BookingReportRow>(),
          page: page.page,
          limit: page.limit,
          total: page.total,
          totalPages: page.totalPages,
        );
      case ReportTable.students:
        _studentRows.value = Paged<StudentReportRow>(
          items: page.items.cast<StudentReportRow>(),
          page: page.page,
          limit: page.limit,
          total: page.total,
          totalPages: page.totalPages,
        );
      case ReportTable.coaches:
        _coachRows.value = Paged<CoachReportRow>(
          items: page.items.cast<CoachReportRow>(),
          page: page.page,
          limit: page.limit,
          total: page.total,
          totalPages: page.totalPages,
        );
    }
  }

  static String _idOf(Object row) => switch (row) {
    BookingReportRow row => row.id,
    StudentReportRow row => row.id,
    CoachReportRow row => row.id,
    _ => row.hashCode.toString(),
  };

  // --- Retries ---------------------------------------------------------------

  Future<void> retrySection(ReportKind kind) => _loadSection(kind, force: true);
  Future<void> retryChart(ReportChart chart) => _loadChart(chart, force: true);
  Future<void> retryTable(ReportTable table) => _loadTable(table, force: true);
  Future<void> reloadFilterOptions(ReportFilterSet set) =>
      _loadFilterOptions(set, force: true);

  // --- Table search and filters ---------------------------------------------

  void onSearchChanged(ReportTable table, String value) {
    if (_searchText[table] == value) return;
    _searchText[table] = value;
    notifyListeners();

    // Debounced: the search goes to the server, so a keystroke must not.
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDebounce, () {
      if (_disposed) return;
      _filters[table] = _filters[table]!.withSearch(value);
      _loadTable(table, force: true);
    });
  }

  void clearSearch(ReportTable table) {
    if (_searchText[table]!.isEmpty && _filters[table]!.search.isEmpty) return;
    _searchTimer?.cancel();
    _searchText[table] = '';
    _filters[table] = _filters[table]!.withSearch('');
    _loadTable(table, force: true);
  }

  void setFilter(ReportTable table, String key, String? value) {
    final next = _filters[table]!.withValue(key, value);
    if (next.query.toString() == _filters[table]!.query.toString()) return;
    _filters[table] = next;
    _loadTable(table, force: true);
  }

  void clearFilters(ReportTable table) {
    if (_filters[table]!.isEmpty && _searchText[table]!.isEmpty) return;
    _searchTimer?.cancel();
    _searchText[table] = '';
    _filters[table] = const ReportFilters();
    _loadTable(table, force: true);
  }

  void setLimit(int limit) {
    if (_limit == limit) return;
    _limit = limit;
    final table = tableFor(_view);
    if (table != null) _loadTable(table, force: true);
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _searchTimer?.cancel();
    _rangeTimer?.cancel();
    AdminLog.life('ReportsController disposed');
    super.dispose();
  }
}
