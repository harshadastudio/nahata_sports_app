import '../../../../core/api/role_api_map.dart';
import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';

/// Sport requests. Auth, refresh and error mapping come from [ApiClient] —
/// including for the multipart upload, which replays the file from disk if the
/// token had to be refreshed mid-request.
class SportRemoteDataSource {
  SportRemoteDataSource({ApiClient? client})
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// `GET /sports?page=1&limit=100&status=Active` — the confirmed URL, shared
  /// by ADMIN and COMPLEX_ADMIN. The route is the same for both roles; the
  /// backend answers within the caller's authorised scope, which is why nothing
  /// here appends `sportComplexId` on a complex admin's behalf.
  ///
  /// `status` and `sportComplexId` remain the two filters the route takes, and
  /// stay optional: null values are dropped by `ApiClient._buildUri`, so an
  /// unset filter is absent rather than sent as `status=`. `complexId` is only
  /// ever a filter the user chose — for a venue-scoped session it is pinned to
  /// the session's own complex by [ComplexScope], never picked freely.
  Future<ApiResponse> list({
    AdminUserStatus? status,
    int? complexId,
    int page = 1,
    int limit = 100,
  }) {
    final route = RoleApiMap.require(ApiModule.sports);

    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (status != null) 'status': status.slug,
      if (complexId != null) 'sportComplexId': complexId,
    };

    AdminLog.call('GET ${route.path} $query');
    return _api.get(route.path, query: query);
  }

  Future<ApiResponse> detail(int id) {
    AdminLog.call('GET ${ApiEndpoints.sport(id)}');
    return _api.get(ApiEndpoints.sport(id));
  }

  Future<ApiResponse> stats(int id) {
    AdminLog.call('GET ${ApiEndpoints.sportStats(id)}');
    return _api.get(ApiEndpoints.sportStats(id));
  }

  Future<ApiResponse> create(Map<String, dynamic> body) {
    AdminLog.call('POST ${ApiEndpoints.sports} fields=${body.keys}');
    return _api.post(ApiEndpoints.sports, body: body);
  }

  Future<ApiResponse> update(int id, Map<String, dynamic> body) {
    AdminLog.call('PUT ${ApiEndpoints.sport(id)} fields=${body.keys}');
    return _api.put(ApiEndpoints.sport(id), body: body);
  }

  Future<ApiResponse> remove(int id) {
    AdminLog.call('DELETE ${ApiEndpoints.sport(id)}');
    return _api.delete(ApiEndpoints.sport(id));
  }

  /// PATCH, not PUT — the sports routes differ from the sports-complex ones
  /// here, and sending the wrong verb would 404 or 405.
  Future<ApiResponse> setStatus(int id, AdminUserStatus status) {
    AdminLog.call('PATCH ${ApiEndpoints.sportStatus(id)} → ${status.slug}');
    return _api.patch(
      ApiEndpoints.sportStatus(id),
      body: <String, dynamic>{'status': status.slug},
    );
  }

  Future<ApiResponse> setVisibility(int id, bool showOnFrontend) {
    AdminLog.call(
      'PATCH ${ApiEndpoints.sportVisibility(id)} → $showOnFrontend',
    );
    return _api.patch(
      ApiEndpoints.sportVisibility(id),
      body: <String, dynamic>{'showOnFrontend': showOnFrontend},
    );
  }

  Future<ApiResponse> assignGround(int id, int sportComplexId) {
    AdminLog.call(
      'POST ${ApiEndpoints.sportAssignGround(id)} → complex $sportComplexId',
    );
    return _api.post(
      ApiEndpoints.sportAssignGround(id),
      body: <String, dynamic>{'sportComplexId': sportComplexId},
    );
  }

  /// Multipart upload under the documented field name, `image`.
  Future<ApiResponse> uploadImage(String filePath, {String? filename}) {
    AdminLog.call('POST ${ApiEndpoints.sportUploadImage} (multipart)');
    return _api.multipart(
      ApiEndpoints.sportUploadImage,
      files: [UploadFile(field: 'image', path: filePath, filename: filename)],
    );
  }
}
