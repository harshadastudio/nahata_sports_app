import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/utils/app_logger.dart';
import '../models/student_profile_model.dart';

/// Student dashboard payload (`GET /student_dashboard`).
class StudentDashboard {
  const StudentDashboard({this.student, this.pass, this.raw = const {}});

  final Map<String, dynamic>? student;
  final Map<String, dynamic>? pass;
  final Map<String, dynamic> raw;

  bool get hasStudent => student != null;

  /// Resolved photo URL for the student, or `null` when there is none.
  ///
  /// The API returns either a bare filename or a full URL; both are handled.
  /// [version] busts the image cache after an upload.
  String? photoUrl({String? version}) {
    final photo = student?['student_photo'];
    if (photo == null) return null;

    final value = photo.toString().trim();
    if (value.isEmpty) return null;

    final base = value.startsWith('http')
        ? value
        : '${ApiConfig.mediaBaseUrl}/students/$value';

    return version == null || version.isEmpty ? base : '$base?v=$version';
  }

  factory StudentDashboard.fromJson(Map<String, dynamic> json) {
    return StudentDashboard(
      student: _map(json['student']),
      pass: _map(json['pass']),
      raw: json,
    );
  }

  static Map<String, dynamic>? _map(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}

/// Endpoints on the legacy backend that back the More screen and the profile
/// editor. Routed through [ApiClient] so they get the same auth header,
/// refresh-and-retry and error mapping as everything else.
class UserRepository {
  UserRepository._();

  static final UserRepository instance = UserRepository._();

  final ApiClient _api = ApiClient.instance;

  /// `GET /student_dashboard?student_id=…`
  Future<StudentDashboard> fetchDashboard(String studentId) async {
    final response = await _api.get(
      ApiEndpoints.studentDashboard,
      baseUrl: ApiConfig.legacyBaseUrl,
      query: {'student_id': studentId},
    );

    if (!response.isOk) {
      AppLogger.debug('Dashboard returned not-ok: ${response.message}',
          name: 'Profile');
      return const StudentDashboard();
    }

    return StudentDashboard.fromJson(response.payload);
  }

  /// `GET /students/me` — the signed-in user's student record, with their
  /// account details nested under `User`.
  ///
  /// Returns null when the response carries no student (for accounts that are
  /// not students), so callers can fall back to the cached profile.
  Future<StudentProfile?> fetchMyStudentProfile() async {
    try {
      final response = await _api.get(ApiEndpoints.studentMe);
      if (!response.isOk) return null;

      final payload = response.payload;
      if (payload.isEmpty) return null;

      return StudentProfile.fromJson(payload);
    } on ApiException catch (e) {
      AppLogger.debug('students/me unavailable: ${e.message}', name: 'Profile');
      return null;
    } catch (e) {
      AppLogger.error('students/me failed', name: 'Profile', error: e);
      return null;
    }
  }

  /// `GET /{userId}/edit`
  Future<Map<String, dynamic>?> fetchUserDetails(String userId) async {
    final response = await _api.get(
      ApiEndpoints.userEdit(userId),
      baseUrl: ApiConfig.legacyBaseUrl,
    );

    if (!response.isOk) return null;

    final payload = response.payload;
    return payload.isEmpty ? null : payload;
  }

  /// `POST /{userId}/update` — multipart so the avatar can ride along.
  Future<Map<String, dynamic>> updateUser({
    required String userId,
    required Map<String, String> fields,
    List<UploadFile> files = const [],
  }) async {
    final response = await _api.multipart(
      ApiEndpoints.userUpdate(userId),
      baseUrl: ApiConfig.legacyBaseUrl,
      fields: fields,
      files: files,
    );

    if (!response.isOk) {
      throw Exception(response.message ?? 'Update failed');
    }

    return response.payload;
  }

  /// `DELETE /students/{userId}`
  Future<bool> deleteAccount(String userId) async {
    final response = await _api.delete(
      ApiEndpoints.deleteStudent(userId),
      baseUrl: ApiConfig.legacyBaseUrl,
    );
    return response.isOk;
  }
}
