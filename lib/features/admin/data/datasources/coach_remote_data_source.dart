import '../../../../core/api/role_api_map.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';

/// Coach requests. Auth, refresh and error mapping come from [ApiClient] —
/// including for the multipart upload, which replays the file from disk if the
/// token had to be refreshed mid-request.
class CoachRemoteDataSource {
  CoachRemoteDataSource({ApiClient? client})
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// `GET /coaches?page=1&limit=100` — the confirmed Coaches URL.
  ///
  /// This is the route a COMPLEX_ADMIN's Coaches screen calls, with its own
  /// `Authorization: Bearer` token; the backend decides the authorised scope
  /// from the JWT, so no `sportComplexId` is appended here. ADMIN's Coaches
  /// module has always used the same route. It is **never** `/admin/employees`
  /// — employees and coaches are different modules on different endpoints.
  ///
  /// `status` stays the one optional filter; a null value is dropped by
  /// `ApiClient._buildUri`, so an unset filter is absent rather than `status=`.
  Future<ApiResponse> list({
    AdminUserStatus? status,
    int page = 1,
    int limit = 100,
  }) {
    final route = RoleApiMap.require(ApiModule.coaches);

    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (status != null) 'status': status.slug,
    };

    AdminLog.call('GET ${route.path} $query');
    return _api.get(route.path, query: query);
  }

  /// `GET /coaches/sport/{sportId}` — the sport filter is a route of its own,
  /// not a query parameter, so it cannot carry the status alongside it.
  Future<ApiResponse> listBySport(int sportId) {
    AdminLog.call('GET ${ApiEndpoints.coachesBySport(sportId)}');
    return _api.get(ApiEndpoints.coachesBySport(sportId));
  }

  Future<ApiResponse> detail(int id) {
    AdminLog.call('GET ${ApiEndpoints.coach(id)}');
    return _api.get(ApiEndpoints.coach(id));
  }

  Future<ApiResponse> stats(int id) {
    AdminLog.call('GET ${ApiEndpoints.coachStatsFor(id)}');
    return _api.get(ApiEndpoints.coachStatsFor(id));
  }

  Future<ApiResponse> create(Map<String, dynamic> body) {
    // Keys only — the body carries a password.
    AdminLog.call('POST ${ApiEndpoints.coaches} fields=${body.keys}');
    return _api.post(ApiEndpoints.coaches, body: body);
  }

  Future<ApiResponse> update(int id, Map<String, dynamic> body) {
    AdminLog.call('PUT ${ApiEndpoints.coach(id)} fields=${body.keys}');
    return _api.put(ApiEndpoints.coach(id), body: body);
  }

  Future<ApiResponse> remove(int id) {
    AdminLog.call('DELETE ${ApiEndpoints.coach(id)}');
    return _api.delete(ApiEndpoints.coach(id));
  }

  /// `GET /coaches/{coachId}/password`. `AppLogger` redacts any `*password*`
  /// field, and nothing here echoes it.
  Future<ApiResponse> credentials(int id) {
    AdminLog.call('GET ${ApiEndpoints.coachPassword(id)}');
    return _api.get(ApiEndpoints.coachPassword(id));
  }

  Future<ApiResponse> resetPassword(int id, String password) {
    // The password itself is never put in an AdminLog line.
    AdminLog.call('POST ${ApiEndpoints.coachResetPassword(id)}');
    return _api.post(
      ApiEndpoints.coachResetPassword(id),
      body: <String, dynamic>{'password': password},
    );
  }

  /// Multipart upload under the documented field name, `image`.
  Future<ApiResponse> uploadImage(String filePath, {String? filename}) {
    AdminLog.call('POST ${ApiEndpoints.coachUploadImage} (multipart)');
    return _api.multipart(
      ApiEndpoints.coachUploadImage,
      files: [UploadFile(field: 'image', path: filePath, filename: filename)],
    );
  }
}
