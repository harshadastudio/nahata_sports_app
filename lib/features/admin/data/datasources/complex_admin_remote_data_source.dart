import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../core/admin_log.dart';

/// Complex-admin CRUD requests.
class ComplexAdminRemoteDataSource {
  ComplexAdminRemoteDataSource({ApiClient? client})
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  Future<ApiResponse> list({
    required int page,
    required int limit,
    String? search,
  }) {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
    };

    AdminLog.call('GET ${ApiEndpoints.complexAdmins} $query');
    return _api.get(ApiEndpoints.complexAdmins, query: query);
  }

  Future<ApiResponse> create(Map<String, dynamic> body) {
    // Keys only — the body carries a password.
    AdminLog.call('POST ${ApiEndpoints.complexAdmins} fields=${body.keys}');
    return _api.post(ApiEndpoints.complexAdmins, body: body);
  }

  Future<ApiResponse> update(String id, Map<String, dynamic> body) {
    AdminLog.call('PUT ${ApiEndpoints.complexAdmin(id)} fields=${body.keys}');
    return _api.put(ApiEndpoints.complexAdmin(id), body: body);
  }

  Future<ApiResponse> remove(String id) {
    AdminLog.call('DELETE ${ApiEndpoints.complexAdmin(id)}');
    return _api.delete(ApiEndpoints.complexAdmin(id));
  }
}
