import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/employee_vocabulary.dart';

/// Employee requests. Auth, refresh and error mapping come from [ApiClient].
class EmployeeRemoteDataSource {
  EmployeeRemoteDataSource({ApiClient? client})
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<ApiResponse> list({
    required int page,
    required int limit,
    String? search,
    AdminUserStatus? status,
    Department? department,
    Shift? shift,
    int? sportComplexId,
    String? sortBy,
    bool descending = false,
  }) {
    // Null and blank values are dropped by `ApiClient._buildUri`, so an unset
    // filter is simply absent rather than sent as `department=`.
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (status != null) 'status': status.slug,
      if (department != null) 'department': department.slug,
      if (shift != null) 'shift': shift.slug,
      if (sportComplexId != null) 'sportComplexId': sportComplexId,
      if (sortBy != null && sortBy.isNotEmpty) ...{
        'sortBy': sortBy,
        'sortOrder': descending ? 'desc' : 'asc',
      },
    };

    AdminLog.call('GET ${ApiEndpoints.employees} $query');
    return _api.get(ApiEndpoints.employees, query: query);
  }

  Future<ApiResponse> detail(String id) {
    AdminLog.call('GET ${ApiEndpoints.employee(id)}');
    return _api.get(ApiEndpoints.employee(id));
  }

  Future<ApiResponse> create(Map<String, dynamic> body) {
    // Keys only — the body carries a password.
    AdminLog.call('POST ${ApiEndpoints.employees} fields=${body.keys}');
    return _api.post(ApiEndpoints.employees, body: body);
  }

  Future<ApiResponse> update(String id, Map<String, dynamic> body) {
    AdminLog.call('PUT ${ApiEndpoints.employee(id)} fields=${body.keys}');
    return _api.put(ApiEndpoints.employee(id), body: body);
  }

  Future<ApiResponse> remove(String id) {
    AdminLog.call('DELETE ${ApiEndpoints.employee(id)}');
    return _api.delete(ApiEndpoints.employee(id));
  }

  /// The response body is a credential — [AppLogger] redacts any
  /// `*password*` field, and nothing here echoes it.
  Future<ApiResponse> credentials(String id) {
    AdminLog.call('GET ${ApiEndpoints.employeePassword(id)}');
    return _api.get(ApiEndpoints.employeePassword(id));
  }

  Future<ApiResponse> resetPassword(String id, String password) {
    // The password itself is never put in an AdminLog line.
    AdminLog.call('POST ${ApiEndpoints.employeeResetPassword(id)}');
    return _api.post(
      ApiEndpoints.employeeResetPassword(id),
      body: <String, dynamic>{'password': password},
    );
  }
}
