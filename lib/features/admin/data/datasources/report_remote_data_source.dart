import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/api_response.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/report.dart';

/// Reports requests. Auth, refresh, timeouts and error mapping come from
/// [ApiClient], which also prints method, URL, headers, query, body, status,
/// response and elapsed time in debug builds.
class ReportRemoteDataSource {
  ReportRemoteDataSource({ApiClient? client})
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// Every report route takes the same window.
  Future<ApiResponse> _windowed(String path, DateRange range) {
    final query = <String, dynamic>{
      'from': range.wireFrom,
      'to': range.wireTo,
    };
    AdminLog.call('GET $path $query');
    return _api.get(path, query: query);
  }

  Future<ApiResponse> _plain(String path) {
    AdminLog.call('GET $path');
    return _api.get(path);
  }

  /// A paginated report list, with the window and any filters the sheet set.
  Future<ApiResponse> _list(
    String path,
    DateRange range, {
    required int page,
    required int limit,
    ReportFilters filters = const ReportFilters(),
  }) {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      'from': range.wireFrom,
      'to': range.wireTo,
      // Sent verbatim as the filter-options route gave them. Null and empty
      // values are dropped by `ApiClient._buildUri`.
      ...filters.query,
    };
    AdminLog.call('GET $path $query');
    return _api.get(path, query: query);
  }

  // --- Analytics -------------------------------------------------------------

  Future<ApiResponse> overview(DateRange range) =>
      _windowed(ApiEndpoints.reportsOverview, range);

  Future<ApiResponse> revenue(DateRange range) =>
      _windowed(ApiEndpoints.reportsRevenue, range);

  Future<ApiResponse> bookingAnalytics(DateRange range) =>
      _windowed(ApiEndpoints.reportsBookings, range);

  Future<ApiResponse> retention(DateRange range) =>
      _windowed(ApiEndpoints.reportsRetention, range);

  Future<ApiResponse> memberships(DateRange range) =>
      _windowed(ApiEndpoints.reportsMemberships, range);

  Future<ApiResponse> users(DateRange range) =>
      _windowed(ApiEndpoints.reportsUsers, range);

  Future<ApiResponse> coaching(DateRange range) =>
      _windowed(ApiEndpoints.reportsCoaching, range);

  Future<ApiResponse> facilities(DateRange range) =>
      _windowed(ApiEndpoints.reportsFacilities, range);

  // --- Charts ----------------------------------------------------------------

  /// Which of the two paths answered last time, per chart.
  ///
  /// Static so it survives a rebuilt data source: once a backend has told us
  /// which shape it serves, no later call pays for the wrong guess again.
  static final Map<String, String> _resolvedChartPaths = <String, String>{};

  /// The documented path and the captured one differ, and only one chart was
  /// ever captured — so the proven shape is tried first and the documented one
  /// is used if the server says that route does not exist.
  ///
  /// Only a 404 triggers the fallback. A 401 or a 500 is a real failure, and
  /// retrying it at a second URL would hide it behind a second error.
  Future<ApiResponse> _chart(
    String primary,
    String fallback,
    DateRange range,
  ) async {
    final known = _resolvedChartPaths[primary];
    if (known != null) return _windowed(known, range);

    try {
      final response = await _windowed(primary, range);
      _resolvedChartPaths[primary] = primary;
      return response;
    } on NotFoundException {
      AdminLog.data(
        '$primary answered 404 — trying the documented $fallback instead.',
      );
    }

    final alternate = await _windowed(fallback, range);
    _resolvedChartPaths[primary] = fallback;
    return alternate;
  }

  /// Only for tests, which must not inherit another test's resolution.
  static void resetChartPathCache() => _resolvedChartPaths.clear();

  Future<ApiResponse> bookingTrends(DateRange range) => _chart(
    ApiEndpoints.reportsChartBookingTrends,
    ApiEndpoints.reportsChartBookingTrendsAlt,
    range,
  );

  Future<ApiResponse> revenueByCourt(DateRange range) => _chart(
    ApiEndpoints.reportsChartRevenueByCourt,
    ApiEndpoints.reportsChartRevenueByCourtAlt,
    range,
  );

  Future<ApiResponse> peakHours(DateRange range) => _chart(
    ApiEndpoints.reportsChartPeakHours,
    ApiEndpoints.reportsChartPeakHoursAlt,
    range,
  );

  Future<ApiResponse> courtPerformance(DateRange range) => _chart(
    ApiEndpoints.reportsChartCourtPerformance,
    ApiEndpoints.reportsChartCourtPerformanceAlt,
    range,
  );

  // --- Tables ----------------------------------------------------------------

  Future<ApiResponse> bookingRows(
    DateRange range, {
    int page = 1,
    int limit = 20,
    ReportFilters filters = const ReportFilters(),
  }) => _list(
    ApiEndpoints.reportsBookingsAll,
    range,
    page: page,
    limit: limit,
    filters: filters,
  );

  Future<ApiResponse> studentRows(
    DateRange range, {
    int page = 1,
    int limit = 20,
    ReportFilters filters = const ReportFilters(),
  }) => _list(
    ApiEndpoints.reportsStudentsAll,
    range,
    page: page,
    limit: limit,
    filters: filters,
  );

  Future<ApiResponse> coachRows(
    DateRange range, {
    int page = 1,
    int limit = 20,
    ReportFilters filters = const ReportFilters(),
  }) => _list(
    ApiEndpoints.reportsCoachesAll,
    range,
    page: page,
    limit: limit,
    filters: filters,
  );

  // --- Filter options --------------------------------------------------------

  Future<ApiResponse> bookingFilterOptions() =>
      _plain(ApiEndpoints.reportsBookingFilters);

  Future<ApiResponse> studentFilterOptions() =>
      _plain(ApiEndpoints.reportsStudentFilters);

  Future<ApiResponse> retentionFilterOptions() =>
      _plain(ApiEndpoints.reportsRetentionFilters);

  Future<ApiResponse> coachFilterOptions() =>
      _plain(ApiEndpoints.reportsCoachFilters);
}
