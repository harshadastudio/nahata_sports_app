import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/membership.dart';

/// Membership requests. Auth, refresh, timeouts and error mapping all come
/// from [ApiClient], which also prints URL, headers, body, status, response and
/// elapsed time in debug builds.
class MembershipRemoteDataSource {
  MembershipRemoteDataSource({ApiClient? client})
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// `GET /memberships?page=&limit=&status=`
  Future<ApiResponse> list({
    int page = 1,
    int limit = 20,
    MembershipStatus? status,
  }) {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (status != null) 'status': status.slug,
    };
    AdminLog.call('GET ${ApiEndpoints.memberships} $query');
    return _api.get(ApiEndpoints.memberships, query: query);
  }

  /// `GET /memberships/stats`
  Future<ApiResponse> stats() {
    AdminLog.call('GET ${ApiEndpoints.membershipsStats}');
    return _api.get(ApiEndpoints.membershipsStats);
  }

  /// `GET /memberships/{membershipId}`
  Future<ApiResponse> detail(String id) {
    AdminLog.call('GET ${ApiEndpoints.membership(id)}');
    return _api.get(ApiEndpoints.membership(id));
  }

  /// `GET /memberships/user/{userId}`
  Future<ApiResponse> forUser(String userId) {
    AdminLog.call('GET ${ApiEndpoints.membershipsForUser(userId)}');
    return _api.get(ApiEndpoints.membershipsForUser(userId));
  }

  /// `GET /memberships/user/{userId}/active`
  Future<ApiResponse> activeForUser(String userId) {
    AdminLog.call('GET ${ApiEndpoints.activeMembershipForUser(userId)}');
    return _api.get(ApiEndpoints.activeMembershipForUser(userId));
  }

  /// `POST /memberships`
  Future<ApiResponse> create(Map<String, dynamic> body) {
    AdminLog.call('POST ${ApiEndpoints.memberships} fields=${body.keys}');
    return _api.post(ApiEndpoints.memberships, body: body);
  }

  /// `PUT /memberships/{membershipId}` — only the changed fields.
  Future<ApiResponse> update(String id, Map<String, dynamic> body) {
    AdminLog.call('PUT ${ApiEndpoints.membership(id)} fields=${body.keys}');
    return _api.put(ApiEndpoints.membership(id), body: body);
  }

  /// `PATCH /memberships/{membershipId}/status`
  Future<ApiResponse> setStatus(String id, MembershipStatus status) {
    AdminLog.call('PATCH ${ApiEndpoints.membershipStatus(id)} → ${status.slug}');
    return _api.patch(
      ApiEndpoints.membershipStatus(id),
      body: {'status': status.slug},
    );
  }

  /// `PATCH /memberships/{membershipId}/payment-status`
  Future<ApiResponse> setPaymentStatus(
    String id,
    MembershipPaymentStatus payment,
  ) {
    AdminLog.call(
      'PATCH ${ApiEndpoints.membershipPaymentStatus(id)} → ${payment.slug}',
    );
    return _api.patch(
      ApiEndpoints.membershipPaymentStatus(id),
      body: {'paymentStatus': payment.slug},
    );
  }

  /// `PATCH /memberships/{membershipId}/cancel`
  Future<ApiResponse> cancel(String id, String reason) {
    AdminLog.call('PATCH ${ApiEndpoints.membershipCancel(id)}');
    return _api.patch(
      ApiEndpoints.membershipCancel(id),
      body: {'reason': reason},
    );
  }

  /// `POST /memberships/{membershipId}/renew`
  Future<ApiResponse> renew(
    String id, {
    required int validityDays,
    required num totalAmount,
  }) {
    AdminLog.call('POST ${ApiEndpoints.membershipRenew(id)}');
    return _api.post(
      ApiEndpoints.membershipRenew(id),
      body: {'validity': validityDays, 'totalAmount': totalAmount},
    );
  }

  /// `DELETE /memberships/{membershipId}`
  Future<ApiResponse> remove(String id) {
    AdminLog.call('DELETE ${ApiEndpoints.membership(id)}');
    return _api.delete(ApiEndpoints.membership(id));
  }

  /// `POST /memberships/check-expired` — the maintenance sweep, empty body.
  Future<ApiResponse> checkExpired() {
    AdminLog.call('POST ${ApiEndpoints.membershipsCheckExpired}');
    return _api.post(
      ApiEndpoints.membershipsCheckExpired,
      body: const <String, dynamic>{},
    );
  }
}
