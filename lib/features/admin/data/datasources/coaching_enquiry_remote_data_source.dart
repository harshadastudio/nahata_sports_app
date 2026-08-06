import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../core/admin_log.dart';

/// The eight coaching-enquiry routes.
///
/// Auth, refresh-on-401, timeouts and error mapping all come from [ApiClient];
/// this layer only shapes requests and traces them.
class CoachingEnquiryRemoteDataSource {
  CoachingEnquiryRemoteDataSource({ApiClient? client})
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// `GET /coaching-enquiries?page=&limit=&search=&status=`
  ///
  /// `search` and `status` are not in the documented query — they are sent
  /// only when set, so a backend that does not implement them simply returns
  /// the unfiltered page, and nothing downstream assumes it filtered.
  Future<ApiResponse> list({
    required int page,
    required int limit,
    String? search,
    String? status,
  }) {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
    };

    AdminLog.call('GET ${ApiEndpoints.coachingEnquiries} $query');
    return _api.get(ApiEndpoints.coachingEnquiries, query: query);
  }

  /// `GET /coaching-enquiries/{enquiryId}`
  Future<ApiResponse> detail(int id) {
    AdminLog.call('GET ${ApiEndpoints.coachingEnquiry(id)}');
    return _api.get(ApiEndpoints.coachingEnquiry(id));
  }

  /// `POST /coaching-enquiries` — the one public route in this family.
  ///
  /// It is still sent with the session the console is running under: the
  /// endpoint does not require a token, but every other call this app makes
  /// carries one, and a backend that records who logged the enquiry can only
  /// do so if it is there.
  Future<ApiResponse> create(Map<String, dynamic> body) {
    AdminLog.call('POST ${ApiEndpoints.coachingEnquiries} fields=${body.keys}');
    return _api.post(ApiEndpoints.coachingEnquiries, body: body);
  }

  /// `PUT /coaching-enquiries/{enquiryId}` — status and remarks together.
  Future<ApiResponse> update(int id, Map<String, dynamic> body) {
    AdminLog.call(
      'PUT ${ApiEndpoints.coachingEnquiry(id)} fields=${body.keys}',
    );
    return _api.put(ApiEndpoints.coachingEnquiry(id), body: body);
  }

  /// `PATCH /coaching-enquiries/{enquiryId}/assign-coach`
  Future<ApiResponse> assignCoach(int id, int coachId) {
    AdminLog.call(
      'PATCH ${ApiEndpoints.coachingEnquiryAssignCoach(id)} coachId=$coachId',
    );
    return _api.patch(
      ApiEndpoints.coachingEnquiryAssignCoach(id),
      body: {'coachId': coachId},
    );
  }

  /// `PATCH /coaching-enquiries/{enquiryId}/status`
  Future<ApiResponse> updateStatus(int id, String status) {
    AdminLog.call(
      'PATCH ${ApiEndpoints.coachingEnquiryStatus(id)} status=$status',
    );
    return _api.patch(
      ApiEndpoints.coachingEnquiryStatus(id),
      body: {'status': status},
    );
  }

  /// `DELETE /coaching-enquiries/{enquiryId}`
  Future<ApiResponse> remove(int id) {
    AdminLog.call('DELETE ${ApiEndpoints.coachingEnquiry(id)}');
    return _api.delete(ApiEndpoints.coachingEnquiry(id));
  }

  /// `GET /coaching-enquiries/stats`
  Future<ApiResponse> stats() {
    AdminLog.call('GET ${ApiEndpoints.coachingEnquiryStats}');
    return _api.get(ApiEndpoints.coachingEnquiryStats);
  }
}
