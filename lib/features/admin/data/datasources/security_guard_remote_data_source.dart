import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/employee_vocabulary.dart';

/// Security guard requests. Auth, refresh and error mapping come from
/// [ApiClient].
class SecurityGuardRemoteDataSource {
  SecurityGuardRemoteDataSource({ApiClient? client})
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<ApiResponse> list({
    required int page,
    required int limit,
    String? search,
    AdminUserStatus? status,
    Shift? shift,
    int? sportComplexId,
    String? assignedArea,
    String? sortBy,
    bool descending = false,
  }) {
    // Null and blank values are dropped by `ApiClient._buildUri`, so an unset
    // filter is simply absent rather than sent as `shift=`.
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (status != null) 'status': status.slug,
      if (shift != null) 'shift': shift.slug,
      if (sportComplexId != null) 'sportComplexId': sportComplexId,
      if (assignedArea != null && assignedArea.trim().isNotEmpty)
        'assignedArea': assignedArea.trim(),
      if (sortBy != null && sortBy.isNotEmpty) ...{
        'sortBy': sortBy,
        'sortOrder': descending ? 'desc' : 'asc',
      },
    };

    AdminLog.call('GET ${ApiEndpoints.securityGuards} $query');
    return _api.get(ApiEndpoints.securityGuards, query: query);
  }

  Future<ApiResponse> detail(String id) {
    AdminLog.call('GET ${ApiEndpoints.securityGuard(id)}');
    return _api.get(ApiEndpoints.securityGuard(id));
  }

  Future<ApiResponse> create(Map<String, dynamic> body) {
    // Keys only — the body carries a password.
    AdminLog.call('POST ${ApiEndpoints.securityGuards} fields=${body.keys}');
    return _api.post(ApiEndpoints.securityGuards, body: body);
  }

  Future<ApiResponse> update(String id, Map<String, dynamic> body) {
    AdminLog.call('PUT ${ApiEndpoints.securityGuard(id)} fields=${body.keys}');
    return _api.put(ApiEndpoints.securityGuard(id), body: body);
  }

  Future<ApiResponse> remove(String id) {
    AdminLog.call('DELETE ${ApiEndpoints.securityGuard(id)}');
    return _api.delete(ApiEndpoints.securityGuard(id));
  }

  /// The response body is a credential — [AppLogger] redacts any
  /// `*password*` field, and nothing here echoes it.
  Future<ApiResponse> credentials(String id) {
    AdminLog.call('GET ${ApiEndpoints.securityGuardPassword(id)}');
    return _api.get(ApiEndpoints.securityGuardPassword(id));
  }

  Future<ApiResponse> resetPassword(String id, String password) {
    // The password itself is never put in an AdminLog line.
    AdminLog.call('POST ${ApiEndpoints.securityGuardResetPassword(id)}');
    return _api.post(
      ApiEndpoints.securityGuardResetPassword(id),
      body: <String, dynamic>{'password': password},
    );
  }
}
