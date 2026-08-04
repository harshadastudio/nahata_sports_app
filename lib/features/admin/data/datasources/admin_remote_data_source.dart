import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';

/// The only class in the admin feature that knows a URL.
///
/// Auth (`Authorization: Bearer …`), proactive refresh, one-shot replay after a
/// 401 and the mapping of every transport failure onto a typed `ApiException`
/// all come from [ApiClient] — this layer just describes the requests and
/// traces them to the console.
class AdminRemoteDataSource {
  AdminRemoteDataSource({ApiClient? client})
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<ApiResponse> stats() {
    AdminLog.call('GET ${ApiEndpoints.adminStats}');
    return _api.get(ApiEndpoints.adminStats);
  }

  Future<ApiResponse> users({
    required int page,
    required int limit,
    AdminRole? role,
    AdminUserStatus? status,
    String? search,
    String? sortBy,
    bool descending = false,
  }) {
    // Null and blank values are dropped by `ApiClient._buildUri`, so an unset
    // filter never reaches the server as `role=` or `search=null`.
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (role != null) 'role': role.slug,
      if (status != null) 'status': status.slug,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (sortBy != null && sortBy.isNotEmpty) ...{
        'sortBy': sortBy,
        'sortOrder': descending ? 'desc' : 'asc',
      },
    };

    AdminLog.call('GET ${ApiEndpoints.adminUsers} $query');
    return _api.get(ApiEndpoints.adminUsers, query: query);
  }

  Future<ApiResponse> user(String userId) {
    AdminLog.call('GET ${ApiEndpoints.adminUser(userId)}');
    return _api.get(ApiEndpoints.adminUser(userId));
  }

  Future<ApiResponse> createUser(Map<String, dynamic> body) {
    AdminLog.call('POST ${ApiEndpoints.adminCreateUser} fields=${body.keys}');
    return _api.post(ApiEndpoints.adminCreateUser, body: body);
  }

  Future<ApiResponse> updateUser(String userId, Map<String, dynamic> body) {
    AdminLog.call('PUT ${ApiEndpoints.adminUser(userId)} fields=${body.keys}');
    return _api.put(ApiEndpoints.adminUser(userId), body: body);
  }

  Future<ApiResponse> deleteUser(String userId) {
    AdminLog.call('DELETE ${ApiEndpoints.adminUser(userId)}');
    return _api.delete(ApiEndpoints.adminUser(userId));
  }

  Future<ApiResponse> rolePermissions(AdminRole role) {
    AdminLog.call('GET ${ApiEndpoints.adminRolePermissions(role.permissionsSlug)}');
    return _api.get(ApiEndpoints.adminRolePermissions(role.permissionsSlug));
  }

  Future<ApiResponse> updateRolePermissions(
    AdminRole role,
    Map<String, dynamic> body,
  ) {
    AdminLog.call(
      'PUT ${ApiEndpoints.adminRolePermissions(role.permissionsSlug)} '
      '${body['permissions'] is List ? (body['permissions'] as List).length : 0} slugs',
    );
    return _api.put(ApiEndpoints.adminRolePermissions(role.permissionsSlug), body: body);
  }
}
