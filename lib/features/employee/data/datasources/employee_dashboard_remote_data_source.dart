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

  /// `GET /coaching-enquiries/all?page=&limit=&status=&search=&fromDate=&toDate=`
  ///
  /// [toDate] is compared against a **timestamp**, not a date, so a bare
  /// `2026-08-31` excludes everything logged during that day. The caller passes
  /// the day already suffixed with `T23:59:59.999`; see
  /// `EmployeeDashboardRepositoryImpl.getEnquiries`.
  Future<ApiResponse> enquiries({
    required int page,
    required int limit,
    String? status,
    String? search,
    String? fromDate,
    String? toDate,
  }) {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (_has(status)) 'status': status!.trim(),
      if (_has(search)) 'search': search!.trim(),
      if (_has(fromDate)) 'fromDate': fromDate!.trim(),
      if (_has(toDate)) 'toDate': toDate!.trim(),
    };

    EmployeeLog.call('GET ${ApiEndpoints.coachingEnquiriesAll} $query');
    return _api.get(ApiEndpoints.coachingEnquiriesAll, query: query);
  }

  /// `POST /coaching-enquiries/admin/create` — a walk-in enquiry typed at the
  /// desk.
  Future<ApiResponse> createEnquiry(Map<String, dynamic> body) {
    EmployeeLog.call(
      'POST ${ApiEndpoints.coachingEnquiryAdminCreate} fields=${body.keys}',
    );
    return _api.post(ApiEndpoints.coachingEnquiryAdminCreate, body: body);
  }

  /// `PUT /coaching-enquiries/admin/{enquiryId}`
  Future<ApiResponse> updateEnquiry(int id, Map<String, dynamic> body) {
    EmployeeLog.call(
      'PUT ${ApiEndpoints.coachingEnquiryAdmin(id)} fields=${body.keys}',
    );
    return _api.put(ApiEndpoints.coachingEnquiryAdmin(id), body: body);
  }

  /// `PATCH /coaching-enquiries/{enquiryId}/status`
  Future<ApiResponse> setEnquiryStatus(int id, String status) {
    EmployeeLog.call(
      'PATCH ${ApiEndpoints.coachingEnquiryStatus(id)} → $status',
    );
    return _api.patch(
      ApiEndpoints.coachingEnquiryStatus(id),
      body: {'status': status},
    );
  }

  /// `DELETE /coaching-enquiries/{enquiryId}`
  Future<ApiResponse> deleteEnquiry(int id) {
    EmployeeLog.call('DELETE ${ApiEndpoints.coachingEnquiry(id)}');
    return _api.delete(ApiEndpoints.coachingEnquiry(id));
  }

  /// `POST /coaching-enquiries/{enquiryId}/approve-and-enroll`
  ///
  /// The body is optional server-side: the route defaults the fee record it
  /// opens to `Pending` / `0` when nothing is supplied, which is what the plain
  /// Approve action relies on.
  Future<ApiResponse> approveEnquiry(int id, {Map<String, dynamic>? body}) {
    EmployeeLog.call(
      'POST ${ApiEndpoints.coachingEnquiryApproveAndEnroll(id)}',
    );
    return _api.post(
      ApiEndpoints.coachingEnquiryApproveAndEnroll(id),
      body: body,
    );
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
  ///
  /// `countAsRevenue: true` (BOOK) records the block as a paid booking;
  /// re-posting with the opposite value on an already-blocked slot is the
  /// un-bill/re-bill correction — it changes only the billed flag.
  Future<ApiResponse> blockSlot({
    required int courtId,
    required int slotId,
    required String date,
    String? notes,
    bool countAsRevenue = false,
    num? amount,
  }) {
    final body = <String, dynamic>{
      'date': date,
      'countAsRevenue': countAsRevenue,
      if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
      if (amount != null) 'amount': amount,
    };

    EmployeeLog.call(
      'POST ${ApiEndpoints.courtSlotBlock(courtId, slotId)} $body',
    );
    return _api.post(ApiEndpoints.courtSlotBlock(courtId, slotId), body: body);
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
  // Students
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /students?page=&limit=&search=`
  ///
  /// Serves both the Student List screen and the Fees Management picker — the
  /// picker simply asks for one large page and ignores the pagination.
  Future<ApiResponse> students({
    int page = 1,
    int limit = 300,
    String? search,
  }) {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (_has(search)) 'search': search!.trim(),
    };
    EmployeeLog.call('GET ${ApiEndpoints.students} $query');
    return _api.get(ApiEndpoints.students, query: query);
  }

  /// `GET /students/{studentId}`
  Future<ApiResponse> student(int id) {
    EmployeeLog.call('GET ${ApiEndpoints.student(id)}');
    return _api.get(ApiEndpoints.student(id));
  }

  /// `PUT /students/{studentId}`
  Future<ApiResponse> updateStudent(int id, Map<String, dynamic> body) {
    EmployeeLog.call('PUT ${ApiEndpoints.student(id)} fields=${body.keys}');
    return _api.put(ApiEndpoints.student(id), body: body);
  }

  /// `DELETE /students/{studentId}`
  Future<ApiResponse> deleteStudent(int id) {
    EmployeeLog.call('DELETE ${ApiEndpoints.student(id)}');
    return _api.delete(ApiEndpoints.student(id));
  }

  /// `POST /students/{studentId}/feedback`
  Future<ApiResponse> sendStudentFeedback(int id, Map<String, dynamic> body) {
    EmployeeLog.call('POST ${ApiEndpoints.studentFeedback(id)}');
    return _api.post(ApiEndpoints.studentFeedback(id), body: body);
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Coupons
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /admin/coupons?page=&limit=&search=&status=`
  Future<ApiResponse> coupons({
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

    EmployeeLog.call('GET ${ApiEndpoints.adminCoupons} $query');
    return _api.get(ApiEndpoints.adminCoupons, query: query);
  }

  /// `GET /admin/coupons/{couponId}` — the single coupon the edit form seeds
  /// itself from, so it never opens over a stale list row.
  Future<ApiResponse> coupon(int id) {
    EmployeeLog.call('GET ${ApiEndpoints.adminCoupon(id)}');
    return _api.get(ApiEndpoints.adminCoupon(id));
  }

  /// `POST /admin/coupons`
  Future<ApiResponse> createCoupon(Map<String, dynamic> body) {
    EmployeeLog.call('POST ${ApiEndpoints.adminCoupons} fields=${body.keys}');
    return _api.post(ApiEndpoints.adminCoupons, body: body);
  }

  /// `PUT /admin/coupons/{couponId}`
  Future<ApiResponse> updateCoupon(int id, Map<String, dynamic> body) {
    EmployeeLog.call(
      'PUT ${ApiEndpoints.adminCoupon(id)} fields=${body.keys}',
    );
    return _api.put(ApiEndpoints.adminCoupon(id), body: body);
  }

  /// `DELETE /admin/coupons/{couponId}`
  Future<ApiResponse> deleteCoupon(int id) {
    EmployeeLog.call('DELETE ${ApiEndpoints.adminCoupon(id)}');
    return _api.delete(ApiEndpoints.adminCoupon(id));
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Visitor passes
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /visitor-passes?page=&limit=`
  Future<ApiResponse> visitorPasses({
    required int page,
    required int limit,
  }) {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    EmployeeLog.call('GET ${ApiEndpoints.visitorPasses} $query');
    return _api.get(ApiEndpoints.visitorPasses, query: query);
  }

  /// `GET /visitor-passes/{idOrCode}`
  ///
  /// The route takes either the numeric id or the pass number
  /// (`VP-20260812-F1D246`), which is why this is not typed to an int.
  Future<ApiResponse> visitorPass(Object idOrCode) {
    EmployeeLog.call('GET ${ApiEndpoints.visitorPass(idOrCode)}');
    return _api.get(ApiEndpoints.visitorPass(idOrCode));
  }

  /// `POST /visitor-passes`
  Future<ApiResponse> createVisitorPass(Map<String, dynamic> body) {
    EmployeeLog.call('POST ${ApiEndpoints.visitorPasses} fields=${body.keys}');
    return _api.post(ApiEndpoints.visitorPasses, body: body);
  }

  /// `POST /visitor-passes/{visitorPassId}/send-email`
  Future<ApiResponse> emailVisitorPass(int id, Map<String, dynamic> body) {
    EmployeeLog.call('POST ${ApiEndpoints.visitorPassSendEmail(id)}');
    return _api.post(ApiEndpoints.visitorPassSendEmail(id), body: body);
  }

  /// `DELETE /visitor-passes/{visitorPassId}`
  Future<ApiResponse> deleteVisitorPass(int id) {
    EmployeeLog.call('DELETE ${ApiEndpoints.visitorPass(id)}');
    return _api.delete(ApiEndpoints.visitorPass(id));
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Events
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /event-passes?page=&limit=&timeframe=`
  ///
  /// [timeframe] is `upcoming` or `past`; omitting it asks for both.
  Future<ApiResponse> events({
    required int page,
    required int limit,
    String? timeframe,
  }) {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (_has(timeframe)) 'timeframe': timeframe!.trim(),
    };

    EmployeeLog.call('GET ${ApiEndpoints.eventPasses} $query');
    return _api.get(ApiEndpoints.eventPasses, query: query);
  }

  /// `GET /event-passes/{eventPassId}` — the one call that reliably carries the
  /// slots, custom fields and FAQs together.
  Future<ApiResponse> event(int id) {
    EmployeeLog.call('GET ${ApiEndpoints.eventPass(id)}');
    return _api.get(ApiEndpoints.eventPass(id));
  }

  /// `POST /event-passes`
  Future<ApiResponse> createEvent(Map<String, dynamic> body) {
    EmployeeLog.call('POST ${ApiEndpoints.eventPasses} fields=${body.keys}');
    return _api.post(ApiEndpoints.eventPasses, body: body);
  }

  /// `PUT /event-passes/{eventPassId}`
  Future<ApiResponse> updateEvent(int id, Map<String, dynamic> body) {
    EmployeeLog.call('PUT ${ApiEndpoints.eventPass(id)} fields=${body.keys}');
    return _api.put(ApiEndpoints.eventPass(id), body: body);
  }

  /// `DELETE /event-passes/{eventPassId}`
  Future<ApiResponse> deleteEvent(int id) {
    EmployeeLog.call('DELETE ${ApiEndpoints.eventPass(id)}');
    return _api.delete(ApiEndpoints.eventPass(id));
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Event bookings (Issue Event Pass)
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /event-passes/bookings/all?page=&limit=`
  Future<ApiResponse> eventBookings({
    required int page,
    required int limit,
  }) {
    final query = <String, dynamic>{'page': page, 'limit': limit};
    EmployeeLog.call('GET ${ApiEndpoints.allEventBookings} $query');
    return _api.get(ApiEndpoints.allEventBookings, query: query);
  }

  /// `POST /event-passes/individual-passes/{passId}/send-email`
  Future<ApiResponse> emailIndividualPass(
    int passId,
    Map<String, dynamic> body,
  ) {
    EmployeeLog.call(
      'POST ${ApiEndpoints.eventPassIndividualSendEmail(passId)}',
    );
    return _api.post(
      ApiEndpoints.eventPassIndividualSendEmail(passId),
      body: body,
    );
  }

  /// `DELETE /event-passes/bookings/{eventBookingId}`
  Future<ApiResponse> deleteEventBooking(int id) {
    EmployeeLog.call('DELETE ${ApiEndpoints.eventBooking(id)}');
    return _api.delete(ApiEndpoints.eventBooking(id));
  }

  /// `DELETE /event-passes/bookings` with `{ids: [..]}` — the bulk delete.
  Future<ApiResponse> deleteEventBookings(List<int> ids) {
    EmployeeLog.call(
      'DELETE ${ApiEndpoints.eventBookings} ids=${ids.length}',
    );
    return _api.delete(ApiEndpoints.eventBookings, body: {'ids': ids});
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Contact enquiries
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /contact-us/admin?page=&limit=&status=`
  Future<ApiResponse> contactEnquiries({
    required int page,
    required int limit,
    String? status,
  }) {
    final query = <String, dynamic>{
      'page': page,
      'limit': limit,
      if (_has(status)) 'status': status!.trim(),
    };

    EmployeeLog.call('GET ${ApiEndpoints.contactUsAdmin} $query');
    return _api.get(ApiEndpoints.contactUsAdmin, query: query);
  }

  /// `GET /contact-us/admin/{enquiryId}` — the full enquiry, which the detail
  /// sheet re-reads rather than trusting the list row's copy of the message.
  Future<ApiResponse> contactEnquiry(String id) {
    EmployeeLog.call('GET ${ApiEndpoints.contactUsAdminEnquiry(id)}');
    return _api.get(ApiEndpoints.contactUsAdminEnquiry(id));
  }

  /// `PATCH /contact-us/admin/{enquiryId}/status`
  Future<ApiResponse> setContactEnquiryStatus(String id, String status) {
    EmployeeLog.call(
      'PATCH ${ApiEndpoints.contactUsAdminEnquiryStatus(id)} → $status',
    );
    return _api.patch(
      ApiEndpoints.contactUsAdminEnquiryStatus(id),
      body: {'status': status},
    );
  }

  /// `DELETE /contact-us/admin/{enquiryId}` — a soft delete server-side.
  Future<ApiResponse> deleteContactEnquiry(String id) {
    EmployeeLog.call('DELETE ${ApiEndpoints.contactUsAdminEnquiry(id)}');
    return _api.delete(ApiEndpoints.contactUsAdminEnquiry(id));
  }

  static bool _has(String? value) => value != null && value.trim().isNotEmpty;
}
