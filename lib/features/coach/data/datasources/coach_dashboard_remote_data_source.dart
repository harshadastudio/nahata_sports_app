import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../core/coach_log.dart';

/// The coach dashboard routes.
///
/// Auth, refresh-on-401, timeouts and error mapping all come from [ApiClient];
/// this layer only shapes requests and traces them. Nothing here interprets a
/// response — that is the mapper's job.
class CoachDashboardRemoteDataSource {
  CoachDashboardRemoteDataSource({ApiClient? client})
      : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  // ---------------------------------------------------------------------------
  // Overview
  // ---------------------------------------------------------------------------

  /// `GET /coach/dashboard/stats`
  Future<ApiResponse> stats() {
    CoachLog.call('GET ${ApiEndpoints.coachStats}');
    return _api.get(ApiEndpoints.coachStats);
  }

  /// `GET /coach/dashboard/schedule/today`
  Future<ApiResponse> todaySchedule() {
    CoachLog.call('GET ${ApiEndpoints.coachScheduleToday}');
    return _api.get(ApiEndpoints.coachScheduleToday);
  }

  /// `GET /coach/dashboard/students/top-performers`
  Future<ApiResponse> topPerformers() {
    CoachLog.call('GET ${ApiEndpoints.coachTopPerformers}');
    return _api.get(ApiEndpoints.coachTopPerformers);
  }

  // ---------------------------------------------------------------------------
  // Students
  // ---------------------------------------------------------------------------

  /// `GET /coach/dashboard/students/my-students?page=&limit=&search=&status=`
  Future<ApiResponse> students({
    required int page,
    required int limit,
    String? search,
    String? status,
  }) {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (_has(search)) 'search': search!.trim(),
      if (_has(status)) 'status': status!.trim(),
    };

    CoachLog.call('GET ${ApiEndpoints.coachMyStudents} $query');
    return _api.get(ApiEndpoints.coachMyStudents, query: query);
  }

  /// `GET /coach/dashboard/students/enrollments-by-month?month=&search=&status=`
  ///
  /// [month] is `yyyy-MM`. Omitting it lets the backend choose — the current
  /// month when it has data, else the most recent month that does.
  Future<ApiResponse> enrollmentsByMonth({
    String? month,
    String? search,
    String? status,
  }) {
    final query = <String, dynamic>{
      if (_has(month)) 'month': month!.trim(),
      if (_has(search)) 'search': search!.trim(),
      if (_has(status)) 'status': status!.trim(),
    };

    CoachLog.call('GET ${ApiEndpoints.coachEnrollmentsByMonth} $query');
    return _api.get(ApiEndpoints.coachEnrollmentsByMonth, query: query);
  }

  // ---------------------------------------------------------------------------
  // Schedule
  // ---------------------------------------------------------------------------

  /// `GET /coach/dashboard/schedule/batches?page=&limit=&status=&sportId=`
  Future<ApiResponse> batches({
    required int page,
    required int limit,
    String? status,
    int? sportId,
  }) {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (_has(status)) 'status': status!.trim(),
      if (sportId != null && sportId > 0) 'sportId': sportId,
    };

    CoachLog.call('GET ${ApiEndpoints.coachBatches} $query');
    return _api.get(ApiEndpoints.coachBatches, query: query);
  }

  // ---------------------------------------------------------------------------
  // Progress
  // ---------------------------------------------------------------------------

  /// `GET /coach/dashboard/performance/progress?page=&limit=&studentId=&sportId=`
  Future<ApiResponse> progress({
    required int page,
    required int limit,
    int? studentId,
    int? sportId,
  }) {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (studentId != null && studentId > 0) 'studentId': studentId,
      if (sportId != null && sportId > 0) 'sportId': sportId,
    };

    CoachLog.call('GET ${ApiEndpoints.coachProgress} $query');
    return _api.get(ApiEndpoints.coachProgress, query: query);
  }

  /// `POST /coach/dashboard/performance/progress` — adds a **new** dated
  /// assessment; it never replaces the previous one.
  Future<ApiResponse> createProgress(Map<String, dynamic> body) {
    CoachLog.call('POST ${ApiEndpoints.coachProgress} fields=${body.keys}');
    return _api.post(ApiEndpoints.coachProgress, body: body);
  }

  /// `PUT /coach/dashboard/performance/progress/{performanceId}`
  Future<ApiResponse> updateProgress(int id, Map<String, dynamic> body) {
    CoachLog.call(
      'PUT ${ApiEndpoints.coachProgressRecord(id)} fields=${body.keys}',
    );
    return _api.put(ApiEndpoints.coachProgressRecord(id), body: body);
  }

  /// `DELETE /coach/dashboard/performance/progress/{performanceId}`
  Future<ApiResponse> deleteProgress(int id) {
    CoachLog.call('DELETE ${ApiEndpoints.coachProgressRecord(id)}');
    return _api.delete(ApiEndpoints.coachProgressRecord(id));
  }

  // ---------------------------------------------------------------------------
  // Attendance
  // ---------------------------------------------------------------------------

  /// `GET /coach/dashboard/attendance/records?page=&limit=&date=&status=&batchId=`
  ///
  /// The coach-scoped read. `GET /attendance` is deliberately not used: it
  /// applies no scoping for the `COACH` role and would return every coach's
  /// records.
  Future<ApiResponse> attendanceRecords({
    required int page,
    required int limit,
    String? date,
    String? status,
    int? batchId,
  }) {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (_has(date)) 'date': date!.trim(),
      if (_has(status)) 'status': status!.trim(),
      if (batchId != null && batchId > 0) 'batchId': batchId,
    };

    CoachLog.call('GET ${ApiEndpoints.coachAttendanceRecords} $query');
    return _api.get(ApiEndpoints.coachAttendanceRecords, query: query);
  }

  /// `POST /attendance` — upserts on `(studentId, batchId, date)`, so this is
  /// both "mark" and "correct".
  Future<ApiResponse> markAttendance(Map<String, dynamic> body) {
    CoachLog.call('POST ${ApiEndpoints.attendance} fields=${body.keys}');
    return _api.post(ApiEndpoints.attendance, body: body);
  }

  // ---------------------------------------------------------------------------
  // Enquiries
  // ---------------------------------------------------------------------------

  /// `GET /coaching-enquiries/coach/my-enquiries?page=&limit=&status=`
  Future<ApiResponse> enquiries({
    required int page,
    required int limit,
    String? status,
  }) {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (_has(status)) 'status': status!.trim(),
    };

    CoachLog.call('GET ${ApiEndpoints.coachEnquiries} $query');
    return _api.get(ApiEndpoints.coachEnquiries, query: query);
  }

  /// `POST /coaching-enquiries/coach/create`
  ///
  /// The coach is stamped from the token — the body must not carry a
  /// `coachId`.
  Future<ApiResponse> createEnquiry(Map<String, dynamic> body) {
    CoachLog.call('POST ${ApiEndpoints.coachCreateEnquiry} fields=${body.keys}');
    return _api.post(ApiEndpoints.coachCreateEnquiry, body: body);
  }

  /// `PATCH /coaching-enquiries/coach/{enquiryId}/status`
  Future<ApiResponse> updateEnquiryStatus(int id, String status) {
    CoachLog.call('PATCH ${ApiEndpoints.coachEnquiryStatus(id)} → $status');
    return _api.patch(
      ApiEndpoints.coachEnquiryStatus(id),
      body: {'status': status},
    );
  }

  /// `DELETE /coaching-enquiries/coach/{enquiryId}`
  Future<ApiResponse> deleteEnquiry(int id) {
    CoachLog.call('DELETE ${ApiEndpoints.coachEnquiry(id)}');
    return _api.delete(ApiEndpoints.coachEnquiry(id));
  }

  /// `POST /coaching-enquiries/{enquiryId}/approve-and-enroll`
  ///
  /// Creates the student (or reuses an existing one) and enrolls them in the
  /// enquiry's batch, inside a transaction. Refuses with a 400 when the batch
  /// is full or the enquiry is already approved.
  Future<ApiResponse> approveAndEnroll(int id, Map<String, dynamic> body) {
    CoachLog.call(
      'POST ${ApiEndpoints.coachingEnquiryApproveAndEnroll(id)} '
      'fields=${body.keys}',
    );
    return _api.post(
      ApiEndpoints.coachingEnquiryApproveAndEnroll(id),
      body: body,
    );
  }

  // ---------------------------------------------------------------------------
  // Fees
  //
  // `GET /fees` and `GET /fees/stats` are scoped to the coach's own batches by
  // the backend, so no coach filter is sent. Approve, reject and delete are
  // not exposed here at all — they answer 403 for a coach.
  // ---------------------------------------------------------------------------

  /// `GET /fees?page=&limit=&paymentStatus=&approvalStatus=&search=&batchId=`
  Future<ApiResponse> fees({
    required int page,
    required int limit,
    String? paymentStatus,
    String? approvalStatus,
    String? search,
    int? batchId,
  }) {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (_has(paymentStatus)) 'paymentStatus': paymentStatus!.trim(),
      if (_has(approvalStatus)) 'approvalStatus': approvalStatus!.trim(),
      if (_has(search)) 'search': search!.trim(),
      if (batchId != null && batchId > 0) 'batchId': batchId,
    };

    CoachLog.call('GET ${ApiEndpoints.fees} $query');
    return _api.get(ApiEndpoints.fees, query: query);
  }

  /// `GET /fees/stats`
  Future<ApiResponse> feeStats() {
    CoachLog.call('GET ${ApiEndpoints.feesStats}');
    return _api.get(ApiEndpoints.feesStats);
  }

  /// `PATCH /fees/{feeId}/payment`
  ///
  /// ⚠️ For a coach this also resets `approvalStatus` to `Pending` and stamps
  /// them as `receivedBy` — collecting is not approving.
  Future<ApiResponse> recordPayment(int id, Map<String, dynamic> body) {
    CoachLog.call('PATCH ${ApiEndpoints.feePayment(id)} fields=${body.keys}');
    return _api.patch(ApiEndpoints.feePayment(id), body: body);
  }

  /// `PUT /fees/{feeId}` — the record itself (validity, notes), as opposed to
  /// the payment on it.
  Future<ApiResponse> updateFee(int id, Map<String, dynamic> body) {
    CoachLog.call('PUT ${ApiEndpoints.fee(id)} fields=${body.keys}');
    return _api.put(ApiEndpoints.fee(id), body: body);
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  /// `GET /notifications?page=&limit=` — the signed-in coach's own inbox.
  ///
  /// `GET /notifications/admin` is deliberately not used: it is unscoped and
  /// would return every notification in the system.
  Future<ApiResponse> notifications({required int page, required int limit}) {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    CoachLog.call('GET ${ApiEndpoints.notifications} $query');
    return _api.get(ApiEndpoints.notifications, query: query);
  }

  /// `GET /notifications/unread-count`
  Future<ApiResponse> unreadCount() {
    CoachLog.call('GET ${ApiEndpoints.notificationsUnreadCount}');
    return _api.get(ApiEndpoints.notificationsUnreadCount);
  }

  /// `PATCH /notifications/{notificationId}/read`
  Future<ApiResponse> markNotificationRead(int id) {
    CoachLog.call('PATCH ${ApiEndpoints.notificationRead(id)}');
    return _api.patch(ApiEndpoints.notificationRead(id));
  }

  /// `PATCH /notifications/mark-all-read`
  Future<ApiResponse> markAllNotificationsRead() {
    CoachLog.call('PATCH ${ApiEndpoints.notificationsMarkAllRead}');
    return _api.patch(ApiEndpoints.notificationsMarkAllRead);
  }

  /// `GET /notifications/users` — the addressable audience.
  Future<ApiResponse> notificationRecipients() {
    CoachLog.call('GET ${ApiEndpoints.notificationsUsers}');
    return _api.get(ApiEndpoints.notificationsUsers);
  }

  /// `POST /notifications/send`
  Future<ApiResponse> sendNotification(Map<String, dynamic> body) {
    CoachLog.call(
      'POST ${ApiEndpoints.notificationsSend} recipient=${body['recipient']}',
    );
    return _api.post(ApiEndpoints.notificationsSend, body: body);
  }

  // ---------------------------------------------------------------------------
  // Gate pass
  // ---------------------------------------------------------------------------

  /// `POST /fees/scan-pass`
  ///
  /// ⚠️ Side-effecting for a coach — it marks the student Present. Never call
  /// this to preview a pass.
  Future<ApiResponse> scanPass(String passCode) {
    CoachLog.call('POST ${ApiEndpoints.feesScanPass}');
    return _api.post(ApiEndpoints.feesScanPass, body: {'passCode': passCode});
  }

  // ---------------------------------------------------------------------------
  // Autocomplete
  // ---------------------------------------------------------------------------

  /// `GET /coach/dashboard/autocomplete/students?search=`
  Future<ApiResponse> autocompleteStudents({String? search}) =>
      _autocomplete(ApiEndpoints.coachAutocompleteStudents, search);

  /// `GET /coach/dashboard/autocomplete/sports?search=`
  Future<ApiResponse> autocompleteSports({String? search}) =>
      _autocomplete(ApiEndpoints.coachAutocompleteSports, search);

  /// `GET /coach/dashboard/autocomplete/batches?search=`
  Future<ApiResponse> autocompleteBatches({String? search}) =>
      _autocomplete(ApiEndpoints.coachAutocompleteBatches, search);

  Future<ApiResponse> _autocomplete(String path, String? search) {
    final query = <String, dynamic>{
      if (_has(search)) 'search': search!.trim(),
    };
    CoachLog.call('GET $path $query');
    return _api.get(path, query: query);
  }

  static bool _has(String? value) => value != null && value.trim().isNotEmpty;
}
