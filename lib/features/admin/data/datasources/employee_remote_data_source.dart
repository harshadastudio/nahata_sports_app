import '../../../../core/api/role_api_map.dart';
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

  /// `GET /admin/employees?page=1&limit=10&search=&department=&status=` — the
  /// confirmed ADMIN Employees URL, sent with those four filter keys present
  /// even when empty, exactly as captured.
  ///
  /// This is an ADMIN-side route and stays one: [RoleApiMap] has no
  /// COMPLEX_ADMIN binding for the Employees module, so a venue-scoped session
  /// reaching this method fails loudly rather than being quietly redirected to
  /// `/coaches`. Employees are not coaches.
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
    final route = RoleApiMap.require(ApiModule.employees);

    // `search`, `department` and `status` are always present — the confirmed
    // URL sends them empty rather than omitting them. `shift`, the complex and
    // the sort keys are ours, not the captured URL's, so those stay optional
    // and are dropped when unset.
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      'search': search?.trim() ?? '',
      'department': department?.slug ?? '',
      'status': status?.slug ?? '',
      if (shift != null) 'shift': shift.slug,
      if (sportComplexId != null) 'sportComplexId': sportComplexId,
      if (sortBy != null && sortBy.isNotEmpty) ...{
        'sortBy': sortBy,
        'sortOrder': descending ? 'desc' : 'asc',
      },
    };

    AdminLog.call('GET ${route.path} $query');
    return _api.get(route.path, query: query);
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
