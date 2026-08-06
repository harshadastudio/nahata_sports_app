import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/app_settings.dart';

/// The ten settings routes.
///
/// Auth, refresh-on-401, timeouts and error mapping all come from [ApiClient];
/// the two uploads go through its multipart path, which sets its own
/// `Content-Type` (with the boundary) and replays the file on a token refresh.
class SettingsRemoteDataSource {
  SettingsRemoteDataSource({ApiClient? client})
    : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  /// `GET /settings`
  Future<ApiResponse> all() {
    AdminLog.call('GET ${ApiEndpoints.settings}');
    return _api.get(ApiEndpoints.settings);
  }

  /// `GET /settings/{key}`
  Future<ApiResponse> byKey(String key) {
    AdminLog.call('GET ${ApiEndpoints.setting(key)}');
    return _api.get(ApiEndpoints.setting(key));
  }

  /// `PUT /settings/general`
  Future<ApiResponse> updateGeneral(Map<String, dynamic> body) {
    AdminLog.call('PUT ${ApiEndpoints.settingsGeneral} fields=${body.keys}');
    return _api.put(ApiEndpoints.settingsGeneral, body: body);
  }

  /// `PUT /settings/booking`
  Future<ApiResponse> updateBooking(Map<String, dynamic> body) {
    AdminLog.call('PUT ${ApiEndpoints.settingsBooking} fields=${body.keys}');
    return _api.put(ApiEndpoints.settingsBooking, body: body);
  }

  /// `PUT /settings/payment`
  ///
  /// The body carries the Razorpay key, so only the field names are traced —
  /// [AdminLog] rides on `AppLogger`, which redacts the body itself.
  Future<ApiResponse> updatePayment(Map<String, dynamic> body) {
    AdminLog.call('PUT ${ApiEndpoints.settingsPayment} fields=${body.keys}');
    return _api.put(ApiEndpoints.settingsPayment, body: body);
  }

  /// `PUT /settings/notifications`
  Future<ApiResponse> updateNotifications(Map<String, dynamic> body) {
    AdminLog.call(
      'PUT ${ApiEndpoints.settingsNotifications} fields=${body.keys}',
    );
    return _api.put(ApiEndpoints.settingsNotifications, body: body);
  }

  /// `PUT /settings/branding`
  Future<ApiResponse> updateBranding(Map<String, dynamic> body) {
    AdminLog.call('PUT ${ApiEndpoints.settingsBranding} fields=${body.keys}');
    return _api.put(ApiEndpoints.settingsBranding, body: body);
  }

  /// `POST /settings/upload-logo` / `POST /settings/upload-favicon` —
  /// multipart, under the field name the route documents.
  Future<ApiResponse> uploadImage({
    required SettingsImageKind kind,
    required String filePath,
    String? filename,
  }) {
    final path = kind == SettingsImageKind.logo
        ? ApiEndpoints.settingsUploadLogo
        : ApiEndpoints.settingsUploadFavicon;

    AdminLog.call('POST $path (multipart, field ${kind.field})');
    return _api.multipart(
      path,
      files: [
        UploadFile(field: kind.field, path: filePath, filename: filename),
      ],
    );
  }

  /// `POST /settings/reset` — restores the defaults.
  Future<ApiResponse> reset() {
    AdminLog.call('POST ${ApiEndpoints.settingsReset}');
    // The documented body is an empty object, not an absent one.
    return _api.post(ApiEndpoints.settingsReset, body: const {});
  }
}