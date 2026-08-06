import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../core/admin_log.dart';

/// The seven visitor-pass routes. Auth, refresh, timeouts and error mapping all
/// come from [ApiClient]; this layer only shapes requests and traces them.
class VisitorPassRemoteDataSource {
  VisitorPassRemoteDataSource({ApiClient? client})
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// `GET /visitor-passes?page=&limit=&search=`
  ///
  /// `search` is not in the documented query, so it is only sent when the desk
  /// actually typed something. A backend that does not implement it simply
  /// answers with the unfiltered page — which is why the parameter is never
  /// sent empty, and why nothing downstream assumes the rows came back
  /// filtered.
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

    AdminLog.call('GET ${ApiEndpoints.visitorPasses} $query');
    return _api.get(ApiEndpoints.visitorPasses, query: query);
  }

  /// `GET /visitor-passes/{visitorPassId}` — the segment may be a numeric id or
  /// a pass code.
  Future<ApiResponse> detail(String idOrCode) {
    AdminLog.call('GET ${ApiEndpoints.visitorPass(idOrCode)}');
    return _api.get(ApiEndpoints.visitorPass(idOrCode));
  }

  /// `POST /visitor-passes`
  Future<ApiResponse> create(Map<String, dynamic> body) {
    AdminLog.call('POST ${ApiEndpoints.visitorPasses} fields=${body.keys}');
    return _api.post(ApiEndpoints.visitorPasses, body: body);
  }

  /// `POST /visitor-passes/verify` — **advances the pass**: `In` then `Out`.
  Future<ApiResponse> verify({
    required String passCode,
    required String scanType,
  }) {
    AdminLog.call(
      'POST ${ApiEndpoints.visitorPassVerify} scanType=$scanType '
      'passCode=$passCode',
    );
    return _api.post(
      ApiEndpoints.visitorPassVerify,
      body: {'passCode': passCode, 'scanType': scanType},
    );
  }

  /// `POST /visitor-passes/lookup` — read-only; never changes the status.
  Future<ApiResponse> lookup(String passCode) {
    AdminLog.call('POST ${ApiEndpoints.visitorPassLookup} passCode=$passCode');
    return _api.post(
      ApiEndpoints.visitorPassLookup,
      body: {'passCode': passCode},
    );
  }

  /// `POST /visitor-passes/{visitorPassId}/send-email`
  Future<ApiResponse> sendEmail({
    required String idOrCode,
    required String recipientEmail,
    required String recipientName,
  }) {
    AdminLog.call(
      'POST ${ApiEndpoints.visitorPassSendEmail(idOrCode)} '
      'to=$recipientEmail',
    );
    return _api.post(
      ApiEndpoints.visitorPassSendEmail(idOrCode),
      body: {'recipientEmail': recipientEmail, 'recipientName': recipientName},
    );
  }

  /// `DELETE /visitor-passes/{visitorPassId}` — ADMIN / COMPLEX_ADMIN only.
  Future<ApiResponse> remove(String idOrCode) {
    AdminLog.call('DELETE ${ApiEndpoints.visitorPass(idOrCode)}');
    return _api.delete(ApiEndpoints.visitorPass(idOrCode));
  }
}
