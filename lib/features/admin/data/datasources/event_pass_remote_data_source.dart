import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../core/admin_log.dart';

/// Event pass requests. Auth, refresh and error mapping come from [ApiClient].
class EventPassRemoteDataSource {
  EventPassRemoteDataSource({ApiClient? client})
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// `GET /event-passes?page=&limit=`
  ///
  /// The collection shows the route without paging parameters, but the
  /// response is documented as paginated by the storefront model, so they are
  /// sent — a backend that ignores them simply returns page one.
  Future<ApiResponse> list({int page = 1, int limit = 20}) {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    AdminLog.call('GET ${ApiEndpoints.eventPasses} $query');
    return _api.get(ApiEndpoints.eventPasses, query: query);
  }

  Future<ApiResponse> detail(int id) {
    AdminLog.call('GET ${ApiEndpoints.eventPass(id)}');
    return _api.get(ApiEndpoints.eventPass(id));
  }

  Future<ApiResponse> create(Map<String, dynamic> body) {
    // Keys only — the body carries the whole slot and FAQ arrays.
    AdminLog.call('POST ${ApiEndpoints.eventPasses} fields=${body.keys}');
    return _api.post(ApiEndpoints.eventPasses, body: body);
  }

  Future<ApiResponse> update(int id, Map<String, dynamic> body) {
    AdminLog.call('PUT ${ApiEndpoints.eventPass(id)} fields=${body.keys}');
    return _api.put(ApiEndpoints.eventPass(id), body: body);
  }

  Future<ApiResponse> remove(int id) {
    AdminLog.call('DELETE ${ApiEndpoints.eventPass(id)}');
    return _api.delete(ApiEndpoints.eventPass(id));
  }

  /// Multipart upload under the documented field name, `image`.
  Future<ApiResponse> uploadImage(String filePath, {String? filename}) {
    AdminLog.call('POST ${ApiEndpoints.eventPassUploadImage} (multipart)');
    return _api.multipart(
      ApiEndpoints.eventPassUploadImage,
      files: [UploadFile(field: 'image', path: filePath, filename: filename)],
    );
  }

  /// `GET /event-passes/bookings/all?page=&limit=`
  Future<ApiResponse> allBookings({int page = 1, int limit = 20}) {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    AdminLog.call('GET ${ApiEndpoints.allEventBookings} $query');
    return _api.get(ApiEndpoints.allEventBookings, query: query);
  }

  /// `GET /event-passes/bookings/my` — scoped to the signed-in account.
  Future<ApiResponse> myBookings() {
    AdminLog.call('GET ${ApiEndpoints.myEventBookings}');
    return _api.get(ApiEndpoints.myEventBookings);
  }

  /// `POST /event-passes/bookings/create`
  Future<ApiResponse> createBooking(Map<String, dynamic> body) {
    AdminLog.call(
      'POST ${ApiEndpoints.eventBookingCreate} fields=${body.keys}',
    );
    return _api.post(ApiEndpoints.eventBookingCreate, body: body);
  }
}
