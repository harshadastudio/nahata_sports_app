import '../../../../core/api/role_api_map.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../core/admin_log.dart';

/// `GET /contact-us/admin` — the Contact Enquiries queue.
///
/// **Deliberately one data source for both administrative roles.** ADMIN and
/// COMPLEX_ADMIN call the identical route with their own bearer token and the
/// backend decides the scope; no `/contact-us/complex-admin` has been confirmed
/// to exist, so none is invented here. [RoleApiMap] records that decision, and
/// resolving the path through it means a future role-specific endpoint is a
/// change to the map rather than to this file.
///
/// Auth, refresh, timeouts and error mapping all come from [ApiClient]; the
/// role/module trace comes from it too.
class ContactEnquiryRemoteDataSource {
  ContactEnquiryRemoteDataSource({ApiClient? client})
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// The confirmed URL: `?page=1&limit=10`.
  ///
  /// Nothing else is sent. `status` and `search` are not in the confirmed
  /// query and their parameter names have never been documented — an invented
  /// one would be ignored silently, which would look exactly like a filter that
  /// works but returns everything.
  Future<ApiResponse> list({int page = 1, int limit = 10}) {
    final route = RoleApiMap.require(ApiModule.contactEnquiries);
    final query = <String, dynamic>{'page': page, 'limit': limit};

    AdminLog.call('GET ${route.path} $query');
    return _api.get(route.path, query: query);
  }
}