import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../core/admin_log.dart';

/// The four dashboard-home reads. Auth, refresh and error mapping come from
/// [ApiClient]; this layer only describes the requests.
class DashboardRemoteDataSource {
  DashboardRemoteDataSource({ApiClient? client})
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<ApiResponse> stats() {
    AdminLog.call('GET ${ApiEndpoints.dashboardStats}');
    return _api.get(ApiEndpoints.dashboardStats);
  }

  Future<ApiResponse> enrollmentTrends() {
    AdminLog.call('GET ${ApiEndpoints.dashboardEnrollmentTrends}');
    return _api.get(ApiEndpoints.dashboardEnrollmentTrends);
  }

  Future<ApiResponse> sportDistribution() {
    AdminLog.call('GET ${ApiEndpoints.dashboardSportDistribution}');
    return _api.get(ApiEndpoints.dashboardSportDistribution);
  }

  Future<ApiResponse> liveEnquiries({int? limit}) {
    // Null query values are dropped by ApiClient, so an unset limit is simply
    // not sent and the server's own default applies.
    AdminLog.call(
      'GET ${ApiEndpoints.dashboardLiveEnquiries}'
      '${limit == null ? '' : ' (limit $limit)'}',
    );
    return _api.get(
      ApiEndpoints.dashboardLiveEnquiries,
      query: {if (limit != null) 'limit': limit},
    );
  }
}
