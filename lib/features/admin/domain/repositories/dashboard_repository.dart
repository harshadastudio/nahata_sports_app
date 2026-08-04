import '../entities/dashboard_stats.dart';
import '../entities/enrollment_trend.dart';
import '../entities/live_enquiry.dart';
import '../entities/sport_distribution.dart';

/// The four reads behind the dashboard home.
///
/// Each section loads independently so one dead endpoint leaves the rest of the
/// page working. Implementations throw on failure; the controller catches per
/// section and shows that section's own retry card.
abstract class DashboardRepository {
  /// `GET /dashboard/stats`
  Future<DashboardStats> fetchStats();

  /// `GET /dashboard/enrollment-trends`
  Future<EnrollmentTrend> fetchEnrollmentTrends();

  /// `GET /dashboard/sport-distribution`
  Future<SportDistribution> fetchSportDistribution();

  /// `GET /dashboard/live-enquiries`
  Future<List<LiveEnquiry>> fetchLiveEnquiries({int? limit});
}
