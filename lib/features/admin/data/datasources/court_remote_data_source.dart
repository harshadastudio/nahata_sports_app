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

  /// `POST /courts/{courtId}/slots/{slotId}/block` — that date only.
  ///
  /// `countAsRevenue: true` (BOOK) records the block as a paid booking;
  /// re-posting with the opposite value on an already-blocked slot is the
  /// un-bill/re-bill correction — it changes only the billed flag.
  Future<ApiResponse> blockSlot({
    required int courtId,
    required int slotId,
    required String date,
    String? notes,
    bool countAsRevenue = false,
    num? amount,
  }) {
    final body = <String, dynamic>{
      'date': date,
      'countAsRevenue': countAsRevenue,
      if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
      if (amount != null) 'amount': amount,
    };

    AdminLog.call('POST ${ApiEndpoints.courtSlotBlock(courtId, slotId)} $body');
    return _api.post(ApiEndpoints.courtSlotBlock(courtId, slotId), body: body);
  }

  /// `POST /courts/{courtId}/slots/{slotId}/unblock` — that date only.
  Future<ApiResponse> unblockSlot({
    required int courtId,
    required int slotId,
    required String date,
  }) {
    AdminLog.call(
      'POST ${ApiEndpoints.courtSlotUnblock(courtId, slotId)} date=$date',
    );
    return _api.post(
      ApiEndpoints.courtSlotUnblock(courtId, slotId),
      body: {'date': date},
    );
  }

  /// `PATCH /courts/{courtId}/slots/{slotId}/toggle` with an explicit status —
  /// distinct from [toggleSlot], which flips whatever the slot currently is.
  /// Used to force-reactivate a recurring block, where flipping blindly would
  /// be wrong if the template were somehow already Active.
  Future<ApiResponse> setSlotStatus(int courtId, int slotId, String status) {
    AdminLog.call(
      'PATCH ${ApiEndpoints.courtSlotToggle(courtId, slotId)} → $status',
    );
    return _api.patch(
      ApiEndpoints.courtSlotToggle(courtId, slotId),
      body: {'status': status},
    );
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
