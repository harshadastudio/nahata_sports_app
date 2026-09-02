import '../core/config/api_config.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exception.dart';
import '../core/network/api_response.dart';
import '../core/utils/app_logger.dart';
import '../models/attendance_record_model.dart';
import '../models/enrollment_model.dart';
import '../models/feedback_thread_model.dart';
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
      AppLogger.debug(
        'Dashboard returned not-ok: ${response.message}',
        name: 'Profile',
      );
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

  /// `GET /attendance/my` — the signed-in student's attendance history.
  ///
  /// Returns a bare list under `data`, newest first. Null is "this account has
  /// no attendance to show" — a staff login the route does not serve, or a
  /// call that failed — which lets the profile drop the section rather than
  /// render an error where a history should be. An empty list is a real
  /// answer: enrolled, but not marked for anything yet.
  Future<List<AttendanceRecord>?> fetchMyAttendance() async {
    try {
      final response = await _api.get(ApiEndpoints.myAttendance);
      if (!response.isOk) return null;

      final body = response.data;
      final raw = body is Map ? body['data'] : null;
      if (raw is! List) return null;

      return raw
          .whereType<Map>()
          .map(
            (row) => AttendanceRecord.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
    } on ApiException catch (e) {
      AppLogger.debug(
        'attendance/my unavailable: ${e.message}',
        name: 'Profile',
      );
      return null;
    } catch (e) {
      AppLogger.error('attendance/my failed', name: 'Profile', error: e);
      return null;
    }
  }

  /// `GET /students/me/enrollments` — the signed-in student's batches.
  ///
  /// Replaces the legacy `nahatasports.com/api/my-enrollments?user_id=`, which
  /// took the id from a query string and no token at all. This one identifies
  /// the student from the bearer token, so one account can no longer read
  /// another's enrolments by changing a number in the URL.
  ///
  /// An account with no student record answers `{success: true, data: []}`,
  /// so an empty list is a real answer and only a failure throws.
  Future<List<EnrollmentModel>> fetchMyEnrollments() async {
    final response = await _api.get(ApiEndpoints.myEnrollments);
    if (!response.isOk) throw response.toException();

    return _listOf(response, (row) => EnrollmentModel.fromJson(row));
  }

  /// `GET /fees/my` — approved enrolments as gate passes, QR already built.
  Future<List<GatePassModel>> fetchMyGatePasses() async {
    final response = await _api.get(ApiEndpoints.myGatePasses);
    if (!response.isOk) throw response.toException();

    return _listOf(response, (row) => GatePassModel.fromJson(row));
  }

  /// `GET /students/feedback` — feedback notifications for this student.
  ///
  /// Returns the raw notification rows: the shape is the shared `Notification`
  /// model the notifications screen already renders, so wrapping it in a
  /// second type here would only fork it.
  Future<List<Map<String, dynamic>>> fetchMyFeedback() async {
    final response = await _api.get(ApiEndpoints.myStudentFeedback);
    if (!response.isOk) throw response.toException();

    return _listOf(response, (row) => row);
  }

  /// `POST /students/feedback/read` — marks every feedback item read.
  ///
  /// Returns false rather than throwing: failing to clear a badge is not worth
  /// interrupting the screen the user just opened.
  Future<bool> markFeedbackRead() async {
    try {
      final response = await _api.post(ApiEndpoints.markStudentFeedbackRead);
      return response.isOk;
    } on ApiException catch (e) {
      AppLogger.debug('feedback/read failed: ${e.message}', name: 'Profile');
      return false;
    }
  }

  /// `POST /user-feedback` — auth, `{subject, rating, message}`.
  ///
  /// Name and email come off the bearer token server-side, so they are not
  /// sent. Answers 201 with the reference number the user quotes in a
  /// follow-up.
  Future<String?> submitFeedback({
    required String subject,
    required String message,
    int? rating,
  }) async {
    if (subject.trim().isEmpty) {
      throw const ValidationException('Please add a subject.');
    }
    if (message.trim().isEmpty) {
      throw const ValidationException('Please write your feedback.');
    }

    final response = await _api.post(
      ApiEndpoints.userFeedback,
      body: {
        'subject': subject.trim(),
        'message': message.trim(),
        if (rating != null) 'rating': rating,
      },
    );

    if (!response.isOk) throw response.toException();
    return response.payload['referenceNumber']?.toString();
  }

  /// `GET /user-feedback/mine` — the user's own threads.
  ///
  /// Wrapped as `data: {feedbacks: [...]}`, unlike the bare lists most of
  /// these routes return, so the reader looks inside the envelope.
  Future<List<FeedbackThread>> fetchMyFeedbackThreads() async {
    final response = await _api.get(ApiEndpoints.myUserFeedback);
    if (!response.isOk) throw response.toException();

    final data = response.data;
    final envelope = data is Map ? data['data'] : null;
    final raw = envelope is Map ? envelope['feedbacks'] : envelope;
    if (raw is! List) return const [];

    return raw
        .whereType<Map>()
        .map((row) => FeedbackThread.fromJson(Map<String, dynamic>.from(row)))
        .toList(growable: false);
  }

  /// `POST /user-feedback/{id}/reply` — auth, `{message}`.
  ///
  /// Answers 403 for someone else's thread, which the caller surfaces rather
  /// than swallowing.
  Future<bool> replyToFeedback({
    required Object id,
    required String message,
  }) async {
    if (message.trim().isEmpty) {
      throw const ValidationException('Write a reply first.');
    }

    final response = await _api.post(
      ApiEndpoints.userFeedbackReply(id),
      body: {'message': message.trim()},
    );

    if (!response.isOk) throw response.toException();
    return true;
  }

  /// The bare list these endpoints return under `data`, mapped through [build].
  ///
  /// A payload that is not a list is treated as empty rather than thrown on:
  /// every one of these routes answers `data: []` for "nothing to show", and a
  /// screen that renders an empty state is better than one that errors.
  static List<T> _listOf<T>(
    ApiResponse response,
    T Function(Map<String, dynamic> row) build,
  ) {
    final body = response.data;
    final raw = body is Map ? body['data'] : null;
    if (raw is! List) return <T>[];

    return raw
        .whereType<Map>()
        .map((row) => build(Map<String, dynamic>.from(row)))
        .toList(growable: false);
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
