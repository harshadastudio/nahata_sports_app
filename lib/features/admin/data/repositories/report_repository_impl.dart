import '../../../../core/network/api_response.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/paged.dart';
import '../../domain/entities/report.dart';
import '../../domain/repositories/report_repository.dart';
import '../datasources/report_remote_data_source.dart';
import '../models/report_model.dart';

/// [ReportRepository] over the JWT backend.
class ReportRepositoryImpl implements ReportRepository {
  ReportRepositoryImpl({ReportRemoteDataSource? remote})
    : _remote = remote ?? ReportRemoteDataSource();

  final ReportRemoteDataSource _remote;

  @override
  Future<ReportSection> fetchSection(ReportKind kind, DateRange range) async {
    final response = await switch (kind) {
      ReportKind.overview => _remote.overview(range),
      ReportKind.revenue => _remote.revenue(range),
      ReportKind.bookings => _remote.bookingAnalytics(range),
      ReportKind.retention => _remote.retention(range),
      ReportKind.memberships => _remote.memberships(range),
      ReportKind.users => _remote.users(range),
      ReportKind.coaching => _remote.coaching(range),
      ReportKind.facilities => _remote.facilities(range),
    };
    if (!response.isOk) throw response.toException();

    final section = ReportMapper.section(
      response.data,
      figures: _figuresFor(kind),
      series: _seriesFor(kind),
    );

    _warnIfEmpty(kind.name, section, response);
    AdminLog.data('Report ${kind.name} → $section');
    return section;
  }

  @override
  Future<ChartSeries> fetchChart(ReportChart chart, DateRange range) async {
    final response = await switch (chart) {
      ReportChart.bookingTrends => _remote.bookingTrends(range),
      ReportChart.revenueByCourt => _remote.revenueByCourt(range),
      ReportChart.peakHours => _remote.peakHours(range),
      ReportChart.courtPerformance => _remote.courtPerformance(range),
    };
    if (!response.isOk) throw response.toException();

    final series = switch (chart) {
      // The captured payload sends `{date, bookings, revenue}`, so the chart
      // has to say which of the two it plots; the other rides along as the
      // point's secondary value.
      ReportChart.bookingTrends => ReportMapper.chart(
        response.data,
        key: 'bookingTrends',
        label: 'Booking trends',
        valueLabel: 'Bookings',
        valueKeys: const ['bookings', 'count', 'totalBookings'],
        secondaryLabel: 'Revenue',
        secondaryFormat: ReportFormat.currency,
      ),
      ReportChart.revenueByCourt => ReportMapper.chart(
        response.data,
        key: 'revenueByCourt',
        label: 'Revenue by court',
        valueLabel: 'Revenue',
        format: ReportFormat.currency,
        valueKeys: const ['revenue', 'totalRevenue', 'amount'],
      ),
      ReportChart.peakHours => ReportMapper.chart(
        response.data,
        key: 'peakHours',
        label: 'Peak hours',
        valueLabel: 'Bookings',
        valueKeys: const ['bookings', 'count', 'totalBookings'],
      ),
      ReportChart.courtPerformance => ReportMapper.chart(
        response.data,
        key: 'courtPerformance',
        label: 'Court performance',
        valueLabel: 'Bookings',
        valueKeys: const ['bookings', 'count', 'totalBookings'],
      ),
    };

    if (series.isEmpty) {
      AdminLog.data(
        'Chart ${chart.name} came back with no readable points. Top-level '
        'keys: ${_keysOf(response.data)} — the series may be under a key '
        'ReportMapper.chart does not try yet.',
      );
    }
    AdminLog.data('Chart ${chart.name} → $series');
    return series;
  }

  @override
  Future<Paged<BookingReportRow>> fetchBookingRows(
    DateRange range, {
    int page = 1,
    int limit = 20,
    ReportFilters filters = const ReportFilters(),
  }) async {
    final response = await _remote.bookingRows(
      range,
      page: page,
      limit: limit,
      filters: filters,
    );
    if (!response.isOk) throw response.toException();

    final result = ReportMapper.page<BookingReportRow>(
      response.data,
      map: ReportMapper.bookingRow,
      keep: (row) => row.id.isNotEmpty,
      requestedPage: page,
      requestedLimit: limit,
    );
    _warnIfUnreadable('booking report', response, result.items.length);
    AdminLog.data('Booking report → $result');
    return result;
  }

  @override
  Future<Paged<StudentReportRow>> fetchStudentRows(
    DateRange range, {
    int page = 1,
    int limit = 20,
    ReportFilters filters = const ReportFilters(),
  }) async {
    final response = await _remote.studentRows(
      range,
      page: page,
      limit: limit,
      filters: filters,
    );
    if (!response.isOk) throw response.toException();

    final result = ReportMapper.page<StudentReportRow>(
      response.data,
      map: ReportMapper.studentRow,
      keep: (row) => row.id.isNotEmpty,
      requestedPage: page,
      requestedLimit: limit,
    );
    _warnIfUnreadable('student report', response, result.items.length);
    AdminLog.data('Student report → $result');
    return result;
  }

  @override
  Future<Paged<CoachReportRow>> fetchCoachRows(
    DateRange range, {
    int page = 1,
    int limit = 20,
    ReportFilters filters = const ReportFilters(),
  }) async {
    final response = await _remote.coachRows(
      range,
      page: page,
      limit: limit,
      filters: filters,
    );
    if (!response.isOk) throw response.toException();

    final result = ReportMapper.page<CoachReportRow>(
      response.data,
      map: ReportMapper.coachRow,
      keep: (row) => row.id.isNotEmpty,
      requestedPage: page,
      requestedLimit: limit,
    );
    _warnIfUnreadable('coach report', response, result.items.length);
    AdminLog.data('Coach report → $result');
    return result;
  }

  @override
  Future<ReportFilterOptions> fetchFilterOptions(ReportFilterSet set) async {
    final response = await switch (set) {
      ReportFilterSet.bookings => _remote.bookingFilterOptions(),
      ReportFilterSet.students => _remote.studentFilterOptions(),
      ReportFilterSet.retention => _remote.retentionFilterOptions(),
      ReportFilterSet.coaches => _remote.coachFilterOptions(),
    };
    if (!response.isOk) throw response.toException();

    final options = ReportMapper.filterOptions(response.data);
    AdminLog.data('Filter options ${set.name} → $options');
    return options;
  }

  // ---------------------------------------------------------------------------

  static List<FigureSpec> _figuresFor(ReportKind kind) => switch (kind) {
    ReportKind.overview => ReportMapper.overviewFigures,
    ReportKind.revenue => ReportMapper.revenueFigures,
    ReportKind.bookings => ReportMapper.bookingFigures,
    ReportKind.retention => ReportMapper.retentionFigures,
    ReportKind.memberships => ReportMapper.membershipFigures,
    ReportKind.users => ReportMapper.userFigures,
    ReportKind.coaching => ReportMapper.coachingFigures,
    ReportKind.facilities => ReportMapper.facilityFigures,
  };

  static List<SeriesSpec> _seriesFor(ReportKind kind) => switch (kind) {
    ReportKind.revenue => ReportMapper.revenueSeries,
    ReportKind.bookings => ReportMapper.bookingSeries,
    ReportKind.retention => ReportMapper.retentionSeries,
    ReportKind.memberships => ReportMapper.membershipSeries,
    ReportKind.users => ReportMapper.userSeries,
    ReportKind.facilities => ReportMapper.facilitySeries,
    ReportKind.overview || ReportKind.coaching => const [],
  };

  /// Says in the log which kind of empty this was.
  ///
  /// With no captured payload, "the window has no data" and "this mapper could
  /// not read the payload" look identical on screen. This names the keys that
  /// did arrive, so a fix is one spec entry away.
  static void _warnIfEmpty(
    String what,
    ReportSection section,
    ApiResponse response,
  ) {
    if (!section.isEmpty) return;
    AdminLog.data(
      'Report $what came back with nothing readable. Top-level keys: '
      '${_keysOf(response.data)} — if a figure is under one of these, add it '
      'to the spec in ReportMapper.',
    );
  }

  static void _warnIfUnreadable(
    String what,
    ApiResponse response,
    int parsed,
  ) {
    if (parsed > 0) return;

    final rows = ReportMapper.rowsIn(response.data);
    if (rows.isEmpty) {
      AdminLog.data(
        'No $what rows in the response. Top-level keys: '
        '${_keysOf(response.data)}',
      );
      return;
    }

    AdminLog.failure(
      '${rows.length} $what rows were returned but none carried a readable '
      'id, so all were dropped. Row keys: ${rows.first.keys.toList()}',
    );
  }

  static List<String> _keysOf(Object? body) =>
      body is Map ? body.keys.map((key) => key.toString()).toList() : const [];
}
