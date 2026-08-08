import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';

/// Court and slot requests. Auth, refresh and error mapping come from
/// [ApiClient] — including for the multipart upload, which replays the file
/// from disk if the token had to be refreshed mid-request.
class CourtRemoteDataSource {
  CourtRemoteDataSource({ApiClient? client})
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// `GET /courts?limit=100` — the confirmed URL, shared by both roles.
  ///
  /// The route is unpaginated, so it takes `limit` but no `page`; the module
  /// consumes the whole catalogue and filters locally. `sportComplexId` and
  /// `sportId` are the two filters it accepts, and null values are dropped by
  /// `ApiClient._buildUri`, so an unset filter is absent rather than sent empty.
  Future<ApiResponse> list({int? complexId, int? sportId, int limit = 100}) {
    final query = <String, dynamic>{
      'limit': limit,
      if (complexId != null) 'sportComplexId': complexId,
      if (sportId != null) 'sportId': sportId,
    };

    AdminLog.call('GET ${ApiEndpoints.courts} $query');
    return _api.get(ApiEndpoints.courts, query: query);
  }

  Future<ApiResponse> detail(int id) {
    AdminLog.call('GET ${ApiEndpoints.court(id)}');
    return _api.get(ApiEndpoints.court(id));
  }

  Future<ApiResponse> create(Map<String, dynamic> body) {
    AdminLog.call('POST ${ApiEndpoints.courts} fields=${body.keys}');
    return _api.post(ApiEndpoints.courts, body: body);
  }

  Future<ApiResponse> update(int id, Map<String, dynamic> body) {
    AdminLog.call('PUT ${ApiEndpoints.court(id)} fields=${body.keys}');
    return _api.put(ApiEndpoints.court(id), body: body);
  }

  /// PATCH, like the sports and batch routes — sending the wrong verb would
  /// 404 or 405.
  Future<ApiResponse> setVisibility(int id, bool showOnFrontend) {
    AdminLog.call(
      'PATCH ${ApiEndpoints.courtVisibility(id)} → $showOnFrontend',
    );
    return _api.patch(
      ApiEndpoints.courtVisibility(id),
      body: <String, dynamic>{'showOnFrontend': showOnFrontend},
    );
  }

  Future<ApiResponse> remove(int id) {
    AdminLog.call('DELETE ${ApiEndpoints.court(id)}');
    return _api.delete(ApiEndpoints.court(id));
  }

  /// There is no `/courts/{id}/status` route, so a status change is a `PUT` of
  /// that one field.
  Future<ApiResponse> setStatus(int id, AdminUserStatus status) {
    AdminLog.call('PUT ${ApiEndpoints.court(id)} → status ${status.slug}');
    return _api.put(
      ApiEndpoints.court(id),
      body: <String, dynamic>{'status': status.slug},
    );
  }

  /// Multipart upload under the field name the other modules use.
  Future<ApiResponse> uploadImage(String filePath, {String? filename}) {
    const path = '${ApiEndpoints.courts}/upload-image';
    AdminLog.call('POST $path (multipart)');
    return _api.multipart(
      path,
      files: [UploadFile(field: 'image', path: filePath, filename: filename)],
    );
  }

  // --- Slots -----------------------------------------------------------------

  Future<ApiResponse> slots(int courtId) {
    AdminLog.call('GET ${ApiEndpoints.courtSlots(courtId)}');
    return _api.get(ApiEndpoints.courtSlots(courtId));
  }

  Future<ApiResponse> createSlot(int courtId, Map<String, dynamic> body) {
    AdminLog.call(
      'POST ${ApiEndpoints.courtSlots(courtId)} fields=${body.keys}',
    );
    return _api.post(ApiEndpoints.courtSlots(courtId), body: body);
  }

  Future<ApiResponse> updateSlot(
    int courtId,
    int slotId,
    Map<String, dynamic> body,
  ) {
    AdminLog.call(
      'PUT ${ApiEndpoints.courtSlot(courtId, slotId)} fields=${body.keys}',
    );
    return _api.put(ApiEndpoints.courtSlot(courtId, slotId), body: body);
  }

  /// The block / unblock switch. The route takes no body — it flips whatever
  /// the slot currently is.
  Future<ApiResponse> toggleSlot(int courtId, int slotId) {
    AdminLog.call('PATCH ${ApiEndpoints.courtSlotToggle(courtId, slotId)}');
    return _api.patch(ApiEndpoints.courtSlotToggle(courtId, slotId));
  }

  Future<ApiResponse> removeSlot(int courtId, int slotId) {
    AdminLog.call('DELETE ${ApiEndpoints.courtSlot(courtId, slotId)}');
    return _api.delete(ApiEndpoints.courtSlot(courtId, slotId));
  }

  /// `GET /courts/{courtId}/available-slots?date=yyyy-MM-dd`
  Future<ApiResponse> availableSlots(int courtId, String date) {
    AdminLog.call(
      'GET ${ApiEndpoints.courtAvailableSlots(courtId)} date=$date',
    );
    return _api.get(
      ApiEndpoints.courtAvailableSlots(courtId),
      query: <String, dynamic>{'date': date},
    );
  }

  /// `GET /courts/availability?sportComplexId=&sportId=&date=`
  Future<ApiResponse> availability({
    int? complexId,
    int? sportId,
    required String date,
  }) {
    final query = <String, dynamic>{
      if (complexId != null) 'sportComplexId': complexId,
      if (sportId != null) 'sportId': sportId,
      'date': date,
    };

    AdminLog.call('GET ${ApiEndpoints.courtsAvailability} $query');
    return _api.get(ApiEndpoints.courtsAvailability, query: query);
  }
}
