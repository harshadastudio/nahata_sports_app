import '../../core/admin_log.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../../domain/entities/enrollment_trend.dart';
import '../../domain/entities/live_enquiry.dart';
import '../../domain/entities/sport_distribution.dart';
import '../../domain/repositories/dashboard_repository.dart';
import '../datasources/dashboard_remote_data_source.dart';
import '../models/dashboard_charts_model.dart';
import '../models/dashboard_stats_model.dart';

/// [DashboardRepository] over the JWT backend.
///
/// Unlike the phase-1 `/admin/stats` read, these throw on failure: the home
/// page renders four independent sections, each with its own retry card, so a
/// failure has to reach the controller to be shown rather than being swallowed
/// into an empty entity that looks like "no data".
class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl({DashboardRemoteDataSource? remote})
    : _remote = remote ?? DashboardRemoteDataSource();

  final DashboardRemoteDataSource _remote;

  @override
  Future<DashboardStats> fetchStats() async {
    final response = await _remote.stats();
    if (!response.isOk) throw response.toException();

    final stats = DashboardStatsMapper.fromJson(response.payload);
    AdminLog.data('Dashboard stats → $stats');
    return stats;
  }

  @override
  Future<EnrollmentTrend> fetchEnrollmentTrends() async {
    final response = await _remote.enrollmentTrends();
    if (!response.isOk) throw response.toException();

    // Handed the whole body: this route may answer with a bare array, which
    // `ApiResponse.payload` (a Map accessor) cannot carry.
    final trend = EnrollmentTrendMapper.fromBody(response.data);
    AdminLog.data('Enrollment trends → $trend');
    return trend;
  }

  @override
  Future<SportDistribution> fetchSportDistribution() async {
    final response = await _remote.sportDistribution();
    if (!response.isOk) throw response.toException();

    final distribution = SportDistributionMapper.fromBody(response.data);
    AdminLog.data('Sport distribution → $distribution');
    return distribution;
  }

  @override
  Future<List<LiveEnquiry>> fetchLiveEnquiries({int? limit}) async {
    final response = await _remote.liveEnquiries(limit: limit);
    if (!response.isOk) throw response.toException();

    final enquiries = LiveEnquiryMapper.listFrom(response.data);
    AdminLog.data('Live enquiries → ${enquiries.length} rows');
    return enquiries;
  }
}
