import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../core/admin_log.dart';

/// The eight coupon routes: six under `/admin/coupons`, plus the two
/// customer-facing ones that decide what a shopper may actually redeem.
///
/// Auth, refresh, timeouts and error mapping all come from [ApiClient]; this
/// layer only shapes requests and traces them.
class CouponRemoteDataSource {
  CouponRemoteDataSource({ApiClient? client})
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// `GET /admin/coupons?page=&limit=&search=`
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

    AdminLog.call('GET ${ApiEndpoints.adminCoupons} $query');
    return _api.get(ApiEndpoints.adminCoupons, query: query);
  }

  /// `GET /admin/coupons/{couponId}`
  Future<ApiResponse> detail(int id) {
    AdminLog.call('GET ${ApiEndpoints.adminCoupon(id)}');
    return _api.get(ApiEndpoints.adminCoupon(id));
  }

  /// `GET /admin/coupons/code/{couponCode}`
  Future<ApiResponse> byCode(String code) {
    AdminLog.call('GET ${ApiEndpoints.adminCouponByCode(code)}');
    return _api.get(ApiEndpoints.adminCouponByCode(code));
  }

  /// `POST /admin/coupons`
  Future<ApiResponse> create(Map<String, dynamic> body) {
    AdminLog.call('POST ${ApiEndpoints.adminCoupons} fields=${body.keys}');
    return _api.post(ApiEndpoints.adminCoupons, body: body);
  }

  /// `PUT /admin/coupons/{couponId}`
  Future<ApiResponse> update(int id, Map<String, dynamic> body) {
    AdminLog.call('PUT ${ApiEndpoints.adminCoupon(id)} fields=${body.keys}');
    return _api.put(ApiEndpoints.adminCoupon(id), body: body);
  }

  /// `DELETE /admin/coupons/{couponId}`
  Future<ApiResponse> remove(int id) {
    AdminLog.call('DELETE ${ApiEndpoints.adminCoupon(id)}');
    return _api.delete(ApiEndpoints.adminCoupon(id));
  }

  /// `POST /coupons/validate` — the customer route, carrying the platform
  /// header the backend needs to enforce App-only and Web-only coupons.
  Future<ApiResponse> validate(Map<String, dynamic> body) {
    AdminLog.call(
      'POST ${ApiEndpoints.validateCoupon} '
      '(${ApiConfig.clientPlatform}) fields=${body.keys}',
    );
    return _api.post(
      ApiEndpoints.validateCoupon,
      headers: ApiConfig.platformHeader,
      body: body,
    );
  }

  /// `GET /coupons/active?appliesTo=` — same header, same reason.
  Future<ApiResponse> active({String? appliesTo}) {
    final query = <String, dynamic>{
      if (appliesTo != null && appliesTo.trim().isNotEmpty)
        'appliesTo': appliesTo.trim(),
    };

    AdminLog.call(
      'GET ${ApiEndpoints.activeCoupons} $query (${ApiConfig.clientPlatform})',
    );
    return _api.get(
      ApiEndpoints.activeCoupons,
      query: query,
      headers: ApiConfig.platformHeader,
    );
  }
}
