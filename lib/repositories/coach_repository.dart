import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/utils/app_logger.dart';
import '../models/coach_dashboard_model.dart';

/// Everything the coach dashboard loads. Bearer auth, refresh-and-retry and
/// error mapping all come from [ApiClient].
///
/// Reads never throw: a failed call resolves to an empty result so one dead
/// section cannot take the whole dashboard down. The failure is logged.
class CoachRepository {
  CoachRepository._();

  static final CoachRepository instance = CoachRepository._();

  final ApiClient _api = ApiClient.instance;

  // ---------------------------------------------------------------------------
  // Dashboard
  // ---------------------------------------------------------------------------

  /// `GET /coach/dashboard/stats`
  Future<CoachStats> fetchStats() async {
    try {
      final response = await _api.get(ApiEndpoints.coachStats);
      if (!response.isOk) return CoachStats.empty;
      return CoachStats.fromJson(response.payload);
    } catch (e) {
      AppLogger.error('Coach stats failed', name: 'Coach', error: e);
      return CoachStats.empty;
    }
  }

  /// `GET /coach/dashboard/schedule/today` — today's sessions, in the order
  /// the API returns them.
  Future<List<CoachSession>> fetchTodaySchedule() async {
    try {
      final response = await _api.get(ApiEndpoints.coachScheduleToday);
      if (!response.isOk) return const <CoachSession>[];
      return CoachSession.listFrom(_dataList(response.data));
    } catch (e) {
      AppLogger.error('Today\'s schedule failed', name: 'Coach', error: e);
      return const <CoachSession>[];
    }
  }

  /// `GET /coach/dashboard/students/top-performers`
  Future<List<TopPerformer>> fetchTopPerformers() async {
    try {
      final response = await _api.get(ApiEndpoints.coachTopPerformers);
      if (!response.isOk) return const <TopPerformer>[];
      return TopPerformer.listFrom(_dataList(response.data));
    } catch (e) {
      AppLogger.error('Top performers failed', name: 'Coach', error: e);
      return const <TopPerformer>[];
    }
  }

  /// `GET /coach/dashboard/attendance/records?page=&limit=`
  Future<CoachPage<CoachAttendanceRecord>> fetchAttendanceRecords({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await _api.get(
        ApiEndpoints.coachAttendanceRecords,
        query: {'page': page, 'limit': limit},
      );
      if (!response.isOk) return const CoachPage<CoachAttendanceRecord>();

      return CoachPage.fromJson<CoachAttendanceRecord>(
        response.payload,
        itemsKey: 'records',
        parse: CoachAttendanceRecord.listFrom,
      );
    } catch (e) {
      AppLogger.error('Attendance records failed', name: 'Coach', error: e);
      return const CoachPage<CoachAttendanceRecord>();
    }
  }

  // ---------------------------------------------------------------------------
  // Enquiries
  // ---------------------------------------------------------------------------

  /// `GET /coaching-enquiries/coach/my-enquiries?page=&limit=`
  ///
  /// The coach is identified by the bearer token — no id is sent.
  Future<CoachPage<CoachEnquiry>> fetchMyEnquiryPage({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final response = await _api.get(
        ApiEndpoints.coachEnquiries,
        query: {'page': page, 'limit': limit},
      );
      if (!response.isOk) return const CoachPage<CoachEnquiry>();

      return CoachPage.fromJson<CoachEnquiry>(
        response.payload,
        itemsKey: 'enquiries',
        parse: CoachEnquiry.listFrom,
      );
    } catch (e) {
      AppLogger.error('Coach enquiries failed', name: 'Coach', error: e);
      return const CoachPage<CoachEnquiry>();
    }
  }

  /// Every enquiry, following pagination. [maxPages] is a safety stop so a bad
  /// `totalPages` can never spin forever.
  Future<List<CoachEnquiry>> fetchMyEnquiries({
    int limit = 20,
    int maxPages = 20,
  }) async {
    final all = <CoachEnquiry>[];

    var page = 1;
    while (page <= maxPages) {
      final result = await fetchMyEnquiryPage(page: page, limit: limit);
      all.addAll(result.items);
      if (!result.hasMore || result.isEmpty) break;
      page++;
    }

    if (page > maxPages) {
      AppLogger.debug('Stopped at the $maxPages page cap', name: 'Coach');
    }

    return all;
  }

  // ---------------------------------------------------------------------------
  // Permissions
  // ---------------------------------------------------------------------------

  /// `GET /permissions/{role}` — the slugs a role is granted.
  ///
  /// `/auth/profile` already returns the signed-in user's own permissions, so
  /// this is only needed to read the full set for a role.
  Future<List<String>> fetchRolePermissions(String role) async {
    try {
      final response = await _api.get(ApiEndpoints.permissionsForRole(role));
      if (!response.isOk) return const <String>[];

      // Sent at the top level, not inside a `data` envelope.
      final body = response.data;
      final raw = body is Map ? body['permissions'] : null;
      if (raw is! List) return const <String>[];

      return raw
          .map((p) => p.toString().trim())
          .where((p) => p.isNotEmpty)
          .toList(growable: false);
    } on ApiException catch (e) {
      AppLogger.debug('Role permissions unavailable: ${e.message}',
          name: 'Coach');
      return const <String>[];
    } catch (e) {
      AppLogger.error('Role permissions failed', name: 'Coach', error: e);
      return const <String>[];
    }
  }

  /// These endpoints return a bare list under `data`, which [ApiResponse.payload]
  /// (a `Map` accessor) cannot carry.
  static Object? _dataList(Object? body) =>
      body is Map ? body['data'] : null;
}
