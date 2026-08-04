import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';

/// Batch requests. Auth, refresh and error mapping come from [ApiClient] —
/// including for the multipart upload, which replays the file from disk if the
/// token had to be refreshed mid-request.
class BatchRemoteDataSource {
  BatchRemoteDataSource({ApiClient? client})
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// `GET /batches?status=&sportId=&page=&limit=` — the only route in the admin
  /// console that is genuinely server-paginated. Null filters are dropped by
  /// `ApiClient._buildUri`, so an unset one is absent rather than sent empty.
  Future<ApiResponse> list({
    AdminUserStatus? status,
    int? sportId,
    int page = 1,
    int limit = 20,
  }) {
    final query = <String, dynamic>{
      if (status != null) 'status': status.slug,
      if (sportId != null) 'sportId': sportId,
      'page': page,
      'limit': limit,
    };

    AdminLog.call('GET ${ApiEndpoints.batches} $query');
    return _api.get(ApiEndpoints.batches, query: query);
  }

  Future<ApiResponse> detail(int id) {
    AdminLog.call('GET ${ApiEndpoints.batchById(id)}');
    return _api.get(ApiEndpoints.batchById(id));
  }

  Future<ApiResponse> stats(int id) {
    AdminLog.call('GET ${ApiEndpoints.batchStats(id)}');
    return _api.get(ApiEndpoints.batchStats(id));
  }

  /// `GET /batches/sport/{sportId}` — the sport-wise breakdown, unpaginated.
  Future<ApiResponse> bySport(int sportId) {
    AdminLog.call('GET ${ApiEndpoints.batchesBySport(sportId)}');
    return _api.get(ApiEndpoints.batchesBySport(sportId));
  }

  /// `GET /batches/coach/{coachId}` — the coach-wise breakdown, unpaginated.
  Future<ApiResponse> byCoach(int coachId) {
    AdminLog.call('GET ${ApiEndpoints.batchesByCoach(coachId)}');
    return _api.get(ApiEndpoints.batchesByCoach(coachId));
  }

  Future<ApiResponse> create(Map<String, dynamic> body) {
    AdminLog.call('POST ${ApiEndpoints.batches} fields=${body.keys}');
    return _api.post(ApiEndpoints.batches, body: body);
  }

  Future<ApiResponse> update(int id, Map<String, dynamic> body) {
    AdminLog.call('PUT ${ApiEndpoints.batchById(id)} fields=${body.keys}');
    return _api.put(ApiEndpoints.batchById(id), body: body);
  }

  /// PATCH, like the sports routes and unlike the sports-complex ones —
  /// sending the wrong verb would 404 or 405.
  Future<ApiResponse> setStatus(int id, AdminUserStatus status) {
    AdminLog.call('PATCH ${ApiEndpoints.batchStatus(id)} → ${status.slug}');
    return _api.patch(
      ApiEndpoints.batchStatus(id),
      body: <String, dynamic>{'status': status.slug},
    );
  }

  Future<ApiResponse> remove(int id) {
    AdminLog.call('DELETE ${ApiEndpoints.batchById(id)}');
    return _api.delete(ApiEndpoints.batchById(id));
  }

  /// Multipart upload under the field name the other three modules use.
  Future<ApiResponse> uploadImage(String filePath, {String? filename}) {
    AdminLog.call('POST ${ApiEndpoints.batchUploadImage} (multipart)');
    return _api.multipart(
      ApiEndpoints.batchUploadImage,
      files: [UploadFile(field: 'image', path: filePath, filename: filename)],
    );
  }
}
