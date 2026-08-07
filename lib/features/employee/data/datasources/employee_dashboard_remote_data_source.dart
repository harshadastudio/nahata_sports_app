import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_response.dart';
import '../../core/employee_log.dart';

/// The routes the employee dashboard talks to.
///
/// Auth, refresh-on-401, timeouts and error mapping all come from [ApiClient];
/// this layer only shapes requests and traces them. Nothing here interprets a
/// response — that is the mapper's job.
///
/// Every route is complex-scoped server-side for an EMPLOYEE, so no complex id
/// appears anywhere in this file.
class EmployeeDashboardRemoteDataSource {
  EmployeeDashboardRemoteDataSource({ApiClient? client})
      : _api = client ?? ApiClient.instance;

  final ApiClient _api;

  // ───────────────────────────────────────────────────────────────────────────
  // Overview
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /reports/overview`
  Future<ApiResponse> overview() {
    EmployeeLog.call('GET ${ApiEndpoints.reportsOverview}');
    return _api.get(ApiEndpoints.reportsOverview);
  }

  /// `GET /auth/staff-details` — this employee's own employment record.
  Future<ApiResponse> staffDetails() {
    EmployeeLog.call('GET ${ApiEndpoints.staffDetails}');
    return _api.get(ApiEndpoints.staffDetails);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Bookings
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /bookings?page=&limit=&date=&sportId=&paymentStatus=&bookingStatus=`
  ///
  /// [sortBy]/[sortOrder] are only sent by the overview's "recent" query; the
  /// list itself takes the backend's default ordering.
  Future<ApiResponse> bookings({
    required int page,
    required int limit,
    String? date,
    int? sportId,
    String? paymentStatus,
    String? bookingStatus,
    String? sortBy,
    String? sortOrder,
  }) {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (_has(date)) 'date': date!.trim(),
      if (sportId != null && sportId > 0) 'sportId': sportId,
      if (_has(paymentStatus)) 'paymentStatus': paymentStatus!.trim(),
      if (_has(bookingStatus)) 'bookingStatus': bookingStatus!.trim(),
      if (_has(sortBy)) 'sortBy': sortBy!.trim(),
      if (_has(sortOrder)) 'sortOrder': sortOrder!.trim(),
    };

    EmployeeLog.call('GET ${ApiEndpoints.bookings} $query');
    return _api.get(ApiEndpoints.bookings, query: query);
  }

  /// `PUT /bookings/{bookingId}`
  Future<ApiResponse> updateBooking(int id, Map<String, dynamic> body) {
    EmployeeLog.call('PUT ${ApiEndpoints.booking(id)} fields=${body.keys}');
    return _api.put(ApiEndpoints.booking(id), body: body);
  }

  /// `DELETE /bookings/{bookingId}`
  Future<ApiResponse> deleteBooking(int id) {
    EmployeeLog.call('DELETE ${ApiEndpoints.booking(id)}');
    return _api.delete(ApiEndpoints.booking(id));
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Payments
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /payments/all?page=&limit=&status=&type=&search=`
  Future<ApiResponse> payments({
    required int page,
    required int limit,
    String? status,
    String? type,
    String? search,
  }) {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (_has(status)) 'status': status!.trim(),
      if (_has(type)) 'type': type!.trim(),
      if (_has(search)) 'search': search!.trim(),
    };

    EmployeeLog.call('GET ${ApiEndpoints.paymentsAll} $query');
    return _api.get(ApiEndpoints.paymentsAll, query: query);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Attendance
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /attendance?page=&limit=&date=&status=&batchId=`
  Future<ApiResponse> attendance({
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

    EmployeeLog.call('GET ${ApiEndpoints.attendance} $query');
    return _api.get(ApiEndpoints.attendance, query: query);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Coaches
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /coaches?page=&limit=&search=`
  Future<ApiResponse> coaches({
    required int page,
    required int limit,
    String? search,
  }) {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (_has(search)) 'search': search!.trim(),
    };

    EmployeeLog.call('GET ${ApiEndpoints.coaches} $query');
    return _api.get(ApiEndpoints.coaches, query: query);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Coaching enquiries
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /coaching-enquiries/all?page=&limit=&status=&search=`
  Future<ApiResponse> enquiries({
    required int page,
    required int limit,
    String? status,
    String? search,
  }) {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (_has(status)) 'status': status!.trim(),
      if (_has(search)) 'search': search!.trim(),
    };

    EmployeeLog.call('GET ${ApiEndpoints.coachingEnquiriesAll} $query');
    return _api.get(ApiEndpoints.coachingEnquiriesAll, query: query);
  }

  /// `POST /coaching-enquiries/{enquiryId}/approve-and-enroll`
  ///
  /// Sent without a body — the website sends none, and the route defaults the
  /// fee record to `Pending` / `0` when nothing is supplied.
  Future<ApiResponse> approveEnquiry(int id) {
    EmployeeLog.call(
      'POST ${ApiEndpoints.coachingEnquiryApproveAndEnroll(id)}',
    );
    return _api.post(ApiEndpoints.coachingEnquiryApproveAndEnroll(id));
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Fees
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /fees?page=&limit=&approvalStatus=&paymentStatus=&search=&batchId=`
  Future<ApiResponse> fees({
    required int page,
    required int limit,
    String? approvalStatus,
    String? paymentStatus,
    String? search,
    int? batchId,
  }) {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (_has(approvalStatus)) 'approvalStatus': approvalStatus!.trim(),
      if (_has(paymentStatus)) 'paymentStatus': paymentStatus!.trim(),
      if (_has(search)) 'search': search!.trim(),
      if (batchId != null && batchId > 0) 'batchId': batchId,
    };

    EmployeeLog.call('GET ${ApiEndpoints.fees} $query');
    return _api.get(ApiEndpoints.fees, query: query);
  }

  /// `GET /fees/stats`
  Future<ApiResponse> feeStats() {
    EmployeeLog.call('GET ${ApiEndpoints.feesStats}');
    return _api.get(ApiEndpoints.feesStats);
  }

  /// `PATCH /fees/{feeId}/approve` — unlocks the student's gate pass.
  Future<ApiResponse> approveFee(int id) {
    EmployeeLog.call('PATCH ${ApiEndpoints.feeApprove(id)}');
    return _api.patch(ApiEndpoints.feeApprove(id));
  }

  /// `PATCH /fees/{feeId}/reject`
  Future<ApiResponse> rejectFee(int id) {
    EmployeeLog.call('PATCH ${ApiEndpoints.feeReject(id)}');
    return _api.patch(ApiEndpoints.feeReject(id));
  }

  /// `POST /fees`
  Future<ApiResponse> createFee(Map<String, dynamic> body) {
    EmployeeLog.call('POST ${ApiEndpoints.fees} fields=${body.keys}');
    return _api.post(ApiEndpoints.fees, body: body);
  }

  /// `PUT /fees/{feeId}`
  Future<ApiResponse> updateFee(int id, Map<String, dynamic> body) {
    EmployeeLog.call('PUT ${ApiEndpoints.fee(id)} fields=${body.keys}');
    return _api.put(ApiEndpoints.fee(id), body: body);
  }

  /// `DELETE /fees/{feeId}`
  Future<ApiResponse> deleteFee(int id) {
    EmployeeLog.call('DELETE ${ApiEndpoints.fee(id)}');
    return _api.delete(ApiEndpoints.fee(id));
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Users
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /admin/users?page=&limit=&search=&status=&membership_type=`
  ///
  /// Note `membership_type`, not `membershipType` — this route reads the column
  /// name straight off the query string.
  Future<ApiResponse> users({
    required int page,
    required int limit,
    String? search,
    String? status,
    String? membershipType,
  }) {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (_has(search)) 'search': search!.trim(),
      if (_has(status)) 'status': status!.trim(),
      if (_has(membershipType)) 'membership_type': membershipType!.trim(),
    };

    EmployeeLog.call('GET ${ApiEndpoints.adminUsers} $query');
    return _api.get(ApiEndpoints.adminUsers, query: query);
  }

  /// `PUT /admin/users/{userId}`
  Future<ApiResponse> updateUser(Object id, Map<String, dynamic> body) {
    EmployeeLog.call('PUT ${ApiEndpoints.adminUser(id)} fields=${body.keys}');
    return _api.put(ApiEndpoints.adminUser(id), body: body);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Notifications
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /notifications?page=&limit=` — the employee's own inbox.
  Future<ApiResponse> notifications({
    required int page,
    required int limit,
  }) {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    EmployeeLog.call('GET ${ApiEndpoints.notifications} $query');
    return _api.get(ApiEndpoints.notifications, query: query);
  }

  /// `GET /notifications/unread-count`
  Future<ApiResponse> unreadCount() {
    EmployeeLog.call('GET ${ApiEndpoints.notificationsUnreadCount}');
    return _api.get(ApiEndpoints.notificationsUnreadCount);
  }

  /// `PATCH /notifications/{notificationId}/read`
  Future<ApiResponse> markNotificationRead(int id) {
    EmployeeLog.call('PATCH ${ApiEndpoints.notificationRead(id)}');
    return _api.patch(ApiEndpoints.notificationRead(id));
  }

  /// `PATCH /notifications/mark-all-read`
  Future<ApiResponse> markAllNotificationsRead() {
    EmployeeLog.call('PATCH ${ApiEndpoints.notificationsMarkAllRead}');
    return _api.patch(ApiEndpoints.notificationsMarkAllRead);
  }

  /// `GET /notifications/audience` — EMPLOYEE-only.
  Future<ApiResponse> audience() {
    EmployeeLog.call('GET ${ApiEndpoints.notificationsAudience}');
    return _api.get(ApiEndpoints.notificationsAudience);
  }

  /// `POST /notifications/send`
  Future<ApiResponse> sendNotification(Map<String, dynamic> body) {
    EmployeeLog.call(
      'POST ${ApiEndpoints.notificationsSend} recipient=${body['recipient']}',
    );
    return _api.post(ApiEndpoints.notificationsSend, body: body);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Sports
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /sports?limit=&search=`
  Future<ApiResponse> sports({int limit = 200, String? search}) {
    final query = <String, dynamic>{
      'limit': limit,
      if (_has(search)) 'search': search!.trim(),
    };
    EmployeeLog.call('GET ${ApiEndpoints.sports} $query');
    return _api.get(ApiEndpoints.sports, query: query);
  }

  Future<ApiResponse> createSport(Map<String, dynamic> body) {
    EmployeeLog.call('POST ${ApiEndpoints.sports} fields=${body.keys}');
    return _api.post(ApiEndpoints.sports, body: body);
  }

  Future<ApiResponse> updateSport(int id, Map<String, dynamic> body) {
    EmployeeLog.call('PUT ${ApiEndpoints.sport(id)} fields=${body.keys}');
    return _api.put(ApiEndpoints.sport(id), body: body);
  }

  Future<ApiResponse> deleteSport(int id) {
    EmployeeLog.call('DELETE ${ApiEndpoints.sport(id)}');
    return _api.delete(ApiEndpoints.sport(id));
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Courts
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /courts?limit=&sportId=`
  Future<ApiResponse> courts({int limit = 200, int? sportId}) {
    final query = <String, dynamic>{
      'limit': limit,
      if (sportId != null && sportId > 0) 'sportId': sportId,
    };
    EmployeeLog.call('GET ${ApiEndpoints.courts} $query');
    return _api.get(ApiEndpoints.courts, query: query);
  }

  Future<ApiResponse> createCourt(Map<String, dynamic> body) {
    EmployeeLog.call('POST ${ApiEndpoints.courts} fields=${body.keys}');
    return _api.post(ApiEndpoints.courts, body: body);
  }

  Future<ApiResponse> updateCourt(int id, Map<String, dynamic> body) {
    EmployeeLog.call('PUT ${ApiEndpoints.court(id)} fields=${body.keys}');
    return _api.put(ApiEndpoints.court(id), body: body);
  }

  Future<ApiResponse> deleteCourt(int id) {
    EmployeeLog.call('DELETE ${ApiEndpoints.court(id)}');
    return _api.delete(ApiEndpoints.court(id));
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Slots
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /courts/{courtId}/slots`
  Future<ApiResponse> slots(int courtId) {
    EmployeeLog.call('GET ${ApiEndpoints.courtSlots(courtId)}');
    return _api.get(ApiEndpoints.courtSlots(courtId));
  }

  Future<ApiResponse> createSlot(int courtId, Map<String, dynamic> body) {
    EmployeeLog.call(
      'POST ${ApiEndpoints.courtSlots(courtId)} fields=${body.keys}',
    );
    return _api.post(ApiEndpoints.courtSlots(courtId), body: body);
  }

  Future<ApiResponse> updateSlot(
    int courtId,
    int slotId,
    Map<String, dynamic> body,
  ) {
    EmployeeLog.call(
      'PUT ${ApiEndpoints.courtSlot(courtId, slotId)} fields=${body.keys}',
    );
    return _api.put(ApiEndpoints.courtSlot(courtId, slotId), body: body);
  }

  Future<ApiResponse> deleteSlot(int courtId, int slotId) {
    EmployeeLog.call('DELETE ${ApiEndpoints.courtSlot(courtId, slotId)}');
    return _api.delete(ApiEndpoints.courtSlot(courtId, slotId));
  }

  /// `PATCH /courts/{courtId}/slots/{slotId}/toggle`
  ///
  /// The status is explicit: the route sets what it is told rather than
  /// flipping, and a bodyless PATCH answers 400.
  Future<ApiResponse> setSlotStatus(int courtId, int slotId, String status) {
    EmployeeLog.call(
      'PATCH ${ApiEndpoints.courtSlotToggle(courtId, slotId)} → $status',
    );
    return _api.patch(
      ApiEndpoints.courtSlotToggle(courtId, slotId),
      body: {'status': status},
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Blocked slots
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /courts/{courtId}/available-slots?date=`
  Future<ApiResponse> availableSlots({
    required int courtId,
    required String date,
  }) {
    EmployeeLog.call(
      'GET ${ApiEndpoints.courtAvailableSlots(courtId)} date=$date',
    );
    return _api.get(
      ApiEndpoints.courtAvailableSlots(courtId),
      query: {'date': date},
    );
  }

  /// `POST /courts/{courtId}/slots/{slotId}/block` — that date only.
  Future<ApiResponse> blockSlot({
    required int courtId,
    required int slotId,
    required String date,
  }) {
    EmployeeLog.call(
      'POST ${ApiEndpoints.courtSlotBlock(courtId, slotId)} date=$date',
    );
    return _api.post(
      ApiEndpoints.courtSlotBlock(courtId, slotId),
      body: {'date': date},
    );
  }

  /// `POST /courts/{courtId}/slots/{slotId}/unblock`
  Future<ApiResponse> unblockSlot({
    required int courtId,
    required int slotId,
    required String date,
  }) {
    EmployeeLog.call(
      'POST ${ApiEndpoints.courtSlotUnblock(courtId, slotId)} date=$date',
    );
    return _api.post(
      ApiEndpoints.courtSlotUnblock(courtId, slotId),
      body: {'date': date},
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Batches
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /batches?limit=`
  Future<ApiResponse> batches({int limit = 200}) {
    EmployeeLog.call('GET ${ApiEndpoints.batches} limit=$limit');
    return _api.get(ApiEndpoints.batches, query: {'limit': limit});
  }

  Future<ApiResponse> createBatch(Map<String, dynamic> body) {
    EmployeeLog.call('POST ${ApiEndpoints.batches} fields=${body.keys}');
    return _api.post(ApiEndpoints.batches, body: body);
  }

  Future<ApiResponse> updateBatch(int id, Map<String, dynamic> body) {
    EmployeeLog.call('PUT ${ApiEndpoints.batchById(id)} fields=${body.keys}');
    return _api.put(ApiEndpoints.batchById(id), body: body);
  }

  Future<ApiResponse> deleteBatch(int id) {
    EmployeeLog.call('DELETE ${ApiEndpoints.batchById(id)}');
    return _api.delete(ApiEndpoints.batchById(id));
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Pickers
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /students?limit=&search=`
  Future<ApiResponse> students({int limit = 300, String? search}) {
    final query = <String, dynamic>{
      'limit': limit,
      if (_has(search)) 'search': search!.trim(),
    };
    EmployeeLog.call('GET ${ApiEndpoints.students} $query');
    return _api.get(ApiEndpoints.students, query: query);
  }

  static bool _has(String? value) => value != null && value.trim().isNotEmpty;
}
