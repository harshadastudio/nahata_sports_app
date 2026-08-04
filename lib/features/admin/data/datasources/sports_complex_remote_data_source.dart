import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';

/// Sports complex requests. Auth, refresh and error mapping come from
/// [ApiClient] — including for the multipart upload, which replays the file
/// from disk if the token had to be refreshed mid-request.
class SportsComplexRemoteDataSource {
  SportsComplexRemoteDataSource({ApiClient? client})
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// The catalogue. `limit` is sent because the shared venue repository has
  /// always sent it against this route; a backend that ignores it is unharmed.
  Future<ApiResponse> list() {
    AdminLog.call('GET ${ApiEndpoints.sportsComplexes}');
    return _api.get(
      ApiEndpoints.sportsComplexes,
      query: const <String, dynamic>{'limit': 200},
    );
  }

  Future<ApiResponse> listByCity(String city) {
    final path = ApiEndpoints.sportsComplexesByCity(city);
    AdminLog.call('GET $path');
    return _api.get(path);
  }

  Future<ApiResponse> listByState(String state) {
    final path = ApiEndpoints.sportsComplexesByState(state);
    AdminLog.call('GET $path');
    return _api.get(path);
  }

  Future<ApiResponse> detail(int id) {
    AdminLog.call('GET ${ApiEndpoints.sportsComplex(id)}');
    return _api.get(ApiEndpoints.sportsComplex(id));
  }

  Future<ApiResponse> stats(int id) {
    AdminLog.call('GET ${ApiEndpoints.sportsComplexStats(id)}');
    return _api.get(ApiEndpoints.sportsComplexStats(id));
  }

  Future<ApiResponse> create(Map<String, dynamic> body) {
    AdminLog.call('POST ${ApiEndpoints.sportsComplexes} fields=${body.keys}');
    return _api.post(ApiEndpoints.sportsComplexes, body: body);
  }

  Future<ApiResponse> update(int id, Map<String, dynamic> body) {
    AdminLog.call(
      'PUT ${ApiEndpoints.sportsComplex(id)} fields=${body.keys}',
    );
    return _api.put(ApiEndpoints.sportsComplex(id), body: body);
  }

  Future<ApiResponse> remove(int id) {
    AdminLog.call('DELETE ${ApiEndpoints.sportsComplex(id)}');
    return _api.delete(ApiEndpoints.sportsComplex(id));
  }

  Future<ApiResponse> setStatus(int id, AdminUserStatus status) {
    AdminLog.call(
      'PUT ${ApiEndpoints.sportsComplexStatus(id)} → ${status.slug}',
    );
    return _api.put(
      ApiEndpoints.sportsComplexStatus(id),
      body: <String, dynamic>{'status': status.slug},
    );
  }

  Future<ApiResponse> setVisibility(int id, bool showOnFrontend) {
    AdminLog.call(
      'PUT ${ApiEndpoints.sportsComplexVisibility(id)} → $showOnFrontend',
    );
    return _api.put(
      ApiEndpoints.sportsComplexVisibility(id),
      body: <String, dynamic>{'showOnFrontend': showOnFrontend},
    );
  }

  /// Multipart upload under the documented field name, `image`.
  Future<ApiResponse> uploadImage(String filePath, {String? filename}) {
    AdminLog.call('POST ${ApiEndpoints.sportsComplexUploadImage} (multipart)');
    return _api.multipart(
      ApiEndpoints.sportsComplexUploadImage,
      files: [
        UploadFile(field: 'image', path: filePath, filename: filename),
      ],
    );
  }

  /// The URL rides as a query parameter, exactly as the route documents.
  Future<ApiResponse> deleteImage(String imageUrl) {
    AdminLog.call('DELETE ${ApiEndpoints.sportsComplexDeleteImage}');
    return _api.delete(
      ApiEndpoints.sportsComplexDeleteImage,
      query: <String, dynamic>{'imageUrl': imageUrl},
    );
  }
}
