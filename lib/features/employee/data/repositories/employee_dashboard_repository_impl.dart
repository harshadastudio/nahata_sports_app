import '../../../../core/network/api_exception.dart';
import '../../core/employee_log.dart';
import '../../domain/entities/employee_attendance.dart';
import '../../domain/entities/employee_booking.dart';
import '../../domain/entities/employee_coach.dart';
import '../../domain/entities/employee_contact_enquiry.dart';
import '../../domain/entities/employee_coupon.dart';
import '../../domain/entities/employee_enquiry.dart';
import '../../domain/entities/employee_event.dart';
import '../../domain/entities/employee_event_booking.dart';
import '../../domain/entities/employee_fee.dart';
import '../../domain/entities/employee_formats.dart';
import '../../domain/entities/employee_master.dart';
import '../../domain/entities/employee_notification.dart';
import '../../domain/entities/employee_overview.dart';
import '../../domain/entities/employee_paged.dart';
import '../../domain/entities/employee_payment.dart';
import '../../domain/entities/employee_staff_details.dart';
import '../../domain/entities/employee_student.dart';
import '../../domain/entities/employee_user.dart';
import '../../domain/entities/employee_visitor_pass.dart';
import '../../domain/repositories/employee_dashboard_repository.dart';
import '../datasources/employee_dashboard_remote_data_source.dart';
import '../models/employee_mappers.dart';

/// [EmployeeDashboardRepository] over the JWT backend.
///
/// Reads throw on failure; controllers decide what a failure means for their
/// section. Writes throw too — an employee has to know that an approval did not
/// land, because the next thing they do is tell the student it did.
class EmployeeDashboardRepositoryImpl implements EmployeeDashboardRepository {
  EmployeeDashboardRepositoryImpl({EmployeeDashboardRemoteDataSource? remote})
      : _remote = remote ?? EmployeeDashboardRemoteDataSource();

  final EmployeeDashboardRemoteDataSource _remote;

  // ───────────────────────────────────────────────────────────────────────────
  // Overview
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Future<EmployeeStats> getStats() async {
    final response = await _remote.overview();
    if (!response.isOk) throw response.toException();

    final stats = EmployeeMappers.stats(response.data);
    EmployeeLog.data('Overview → $stats');
    return stats;
  }

  @override
  Future<List<EmployeeRecentBooking>> getRecentBookings({int limit = 5}) async {
    final response = await _remote.bookings(
      page: 1,
      limit: limit,
      sortBy: 'createdAt',
      sortOrder: 'DESC',
    );
    if (!response.isOk) throw response.toException();

    final rows = EmployeeMappers.rowsAt(response.data, 'bookings');
    final bookings = rows
        .map(EmployeeMappers.booking)
        .whereType<EmployeeBooking>()
        .toList(growable: false);

    _warnIfDropped(rows.length, bookings.length, 'recent bookings');
    EmployeeLog.data('Recent bookings → ${bookings.length}');
    return bookings;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Profile
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Future<EmployeeStaffDetails> getStaffDetails() async {
    final response = await _remote.staffDetails();
    if (!response.isOk) throw response.toException();

    final details = EmployeeMappers.staffDetails(response.data);
    EmployeeLog.data('Staff details → $details');
    return details;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Bookings
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Future<EmployeePaged<EmployeeBooking>> getBookings({
    int page = 1,
    int limit = 20,
    String? date,
    int? sportId,
    String? paymentStatus,
    String? bookingStatus,
  }) async {
    final response = await _remote.bookings(
      page: page,
      limit: limit,
      date: date,
      sportId: sportId,
      paymentStatus: paymentStatus,
      bookingStatus: bookingStatus,
    );
    if (!response.isOk) throw response.toException();

    final result = EmployeeMappers.pageOf<EmployeeBooking>(
      response.data,
      key: 'bookings',
      parse: EmployeeMappers.booking,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    _warnIfDropped(
      EmployeeMappers.rowsAt(response.data, 'bookings').length,
      result.items.length,
      'bookings',
    );
    EmployeeLog.data('Bookings → $result');
    return result;
  }

  @override
  Future<void> updateBooking(
    int id, {
    String? customerName,
    String? date,
    String? startTime,
    String? endTime,
    num? totalAmount,
    String? notes,
    String? bookingStatus,
    String? paymentStatus,
    int? sportId,
    int? courtId,
  }) async {
    // Only what was actually passed goes on the wire: `PUT /bookings/{id}`
    // writes every key it receives, so including a null `notes` on a
    // "mark as paid" would wipe the note.
    final body = <String, dynamic>{
      if (customerName != null) 'customerName': customerName.trim(),
      if (date != null) 'date': date,
      if (startTime != null) 'startTime': startTime,
      if (endTime != null) 'endTime': endTime,
      if (totalAmount != null) 'totalAmount': totalAmount,
      if (notes != null) 'notes': notes.trim().isEmpty ? null : notes.trim(),
      if (bookingStatus != null) 'bookingStatus': bookingStatus,
      if (paymentStatus != null) 'paymentStatus': paymentStatus,
      if (sportId != null && sportId > 0) 'sportId': sportId,
      if (courtId != null && courtId > 0) 'courtId': courtId,
    };

    final response = await _remote.updateBooking(id, body);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Booking $id updated (${body.keys.join(', ')})');
  }

  @override
  Future<void> deleteBooking(int id) async {
    final response = await _remote.deleteBooking(id);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Booking $id deleted');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Payments
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Future<EmployeePaymentsPage> getPayments({
    int page = 1,
    int limit = 20,
    String? status,
    String? type,
    String? search,
  }) async {
    final response = await _remote.payments(
      page: page,
      limit: limit,
      status: status,
      type: type,
      search: search,
    );
    if (!response.isOk) throw response.toException();

    final result = EmployeeMappers.paymentsPage(
      response.data,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    _warnIfDropped(
      EmployeeMappers.rows(response.data).length,
      result.payments.length,
      'payments',
    );
    EmployeeLog.data('Payments → $result');
    return result;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Attendance
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Future<EmployeePaged<EmployeeAttendanceRecord>> getAttendance({
    int page = 1,
    int limit = 20,
    String? date,
    String? status,
    int? batchId,
  }) async {
    final response = await _remote.attendance(
      page: page,
      limit: limit,
      date: date,
      status: status,
      batchId: batchId,
    );
    if (!response.isOk) throw response.toException();

    final result = EmployeeMappers.pageOf<EmployeeAttendanceRecord>(
      response.data,
      key: 'attendance',
      parse: EmployeeMappers.attendance,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    _warnIfDropped(
      EmployeeMappers.rowsAt(response.data, 'attendance').length,
      result.items.length,
      'attendance',
    );
    EmployeeLog.data('Attendance → $result');
    return result;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Coaches
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Future<EmployeePaged<EmployeeCoach>> getCoaches({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    final response = await _remote.coaches(
      page: page,
      limit: limit,
      search: search,
    );
    if (!response.isOk) throw response.toException();

    final result = EmployeeMappers.pageOf<EmployeeCoach>(
      response.data,
      key: 'coaches',
      parse: EmployeeMappers.coach,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    _warnIfDropped(
      EmployeeMappers.rowsAt(response.data, 'coaches').length,
      result.items.length,
      'coaches',
    );
    EmployeeLog.data('Coaches → $result');
    return result;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Coaching enquiries
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Future<EmployeePaged<EmployeeEnquiry>> getEnquiries({
    int page = 1,
    int limit = 20,
    String? status,
    String? search,
    DateTime? from,
    DateTime? to,
  }) async {
    final response = await _remote.enquiries(
      page: page,
      limit: limit,
      status: status,
      search: search,
      fromDate: from == null ? null : formatIsoDate(from),
      // `toDate` is compared against a timestamp, so the bare day would exclude
      // everything logged during it. Extending to the last millisecond makes
      // the filter read as the inclusive day the picker showed.
      toDate: to == null ? null : '${formatIsoDate(to)}T23:59:59.999',
    );
    if (!response.isOk) throw response.toException();

    final result = EmployeeMappers.pageOf<EmployeeEnquiry>(
      response.data,
      key: 'enquiries',
      parse: EmployeeMappers.enquiry,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    _warnIfDropped(
      EmployeeMappers.rowsAt(response.data, 'enquiries').length,
      result.items.length,
      'enquiries',
    );
    EmployeeLog.data('Enquiries → $result');
    return result;
  }

  @override
  Future<EmployeeEnquiryCreateResult> createEnquiry(
    EmployeeEnquiryDraft draft,
  ) async {
    final response = await _remote.createEnquiry(draft.toJson());
    if (!response.isOk) throw response.toException();

    // The route answers with the row it created and the `studentAccount` block
    // saying whether it had to register the student. Neither is guaranteed — a
    // payload without them is not a failure, the enquiry was still created —
    // so the id falls back to the generic reader.
    final parsed = EmployeeMappers.enquiryCreateResult(response.data);
    final result = parsed.enquiryId != null
        ? parsed
        : EmployeeEnquiryCreateResult(
            enquiryId: _idOf(response.data),
            userId: parsed.userId,
            studentId: parsed.studentId,
            isNewAccount: parsed.isNewAccount,
          );

    EmployeeLog.success(
      'Enquiry created'
      '${result.enquiryId == null ? '' : ' (#${result.enquiryId})'}'
      '${result.isNewAccount ? ' — student account registered' : ''}',
    );
    return result;
  }

  @override
  Future<void> updateEnquiry(int id, EmployeeEnquiryDraft draft) async {
    final response = await _remote.updateEnquiry(id, draft.toJson());
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Enquiry $id updated');
  }

  @override
  Future<void> setEnquiryStatus(int id, String status) async {
    final response = await _remote.setEnquiryStatus(id, status);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Enquiry $id → $status');
  }

  @override
  Future<void> deleteEnquiry(int id) async {
    final response = await _remote.deleteEnquiry(id);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Enquiry $id deleted');
  }

  @override
  Future<void> approveEnquiry(
    int id, {
    EmployeeEnquiryApprovalDraft draft = EmployeeEnquiryApprovalDraft.pending,
  }) async {
    final response = await _remote.approveEnquiry(id, body: draft.toJson());
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Enquiry $id approved — student enrolled');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Fees
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Future<EmployeePaged<EmployeeFee>> getFees({
    int page = 1,
    int limit = 20,
    String? approvalStatus,
    String? paymentStatus,
    String? search,
    int? batchId,
  }) async {
    final response = await _remote.fees(
      page: page,
      limit: limit,
      approvalStatus: approvalStatus,
      paymentStatus: paymentStatus,
      search: search,
      batchId: batchId,
    );
    if (!response.isOk) throw response.toException();

    final result = EmployeeMappers.pageOf<EmployeeFee>(
      response.data,
      key: 'fees',
      parse: EmployeeMappers.fee,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    _warnIfDropped(
      EmployeeMappers.rowsAt(response.data, 'fees').length,
      result.items.length,
      'fees',
    );
    EmployeeLog.data('Fees → $result');
    return result;
  }

  @override
  Future<EmployeeFeeStats> getFeeStats() async {
    final response = await _remote.feeStats();
    if (!response.isOk) throw response.toException();

    final stats = EmployeeMappers.feeStats(response.data);
    EmployeeLog.data('Fee stats → $stats');
    return stats;
  }

  @override
  Future<void> approveFee(int id) async {
    final response = await _remote.approveFee(id);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Fee $id approved — gate pass unlocked');
  }

  @override
  Future<void> rejectFee(int id) async {
    final response = await _remote.rejectFee(id);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Fee $id rejected');
  }

  @override
  Future<void> createFee(EmployeeFeeDraft draft) async {
    final response = await _remote.createFee(draft.toCreateBody());
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Fee record created for student ${draft.studentId}');
  }

  @override
  Future<void> updateFee(int id, EmployeeFeeDraft draft) async {
    final response = await _remote.updateFee(id, draft.toUpdateBody());
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Fee $id updated');
  }

  @override
  Future<void> deleteFee(int id) async {
    final response = await _remote.deleteFee(id);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Fee $id deleted');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Users
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Future<EmployeePaged<EmployeeUser>> getUsers({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
    String? membershipType,
  }) async {
    final response = await _remote.users(
      page: page,
      limit: limit,
      search: search,
      status: status,
      membershipType: membershipType,
    );
    if (!response.isOk) throw response.toException();

    // This route puts its rows directly under `data`, with no named key —
    // `rowsAt` falls through to the bare list for exactly this case.
    final result = EmployeeMappers.pageOf<EmployeeUser>(
      response.data,
      key: 'users',
      parse: EmployeeMappers.user,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    _warnIfDropped(
      EmployeeMappers.rowsAt(response.data, 'users').length,
      result.items.length,
      'users',
    );
    EmployeeLog.data('Users → $result');
    return result;
  }

  @override
  Future<void> updateUser(Object id, Map<String, dynamic> body) async {
    final response = await _remote.updateUser(id, body);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('User $id updated');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Notifications
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Future<EmployeePaged<EmployeeNotification>> getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _remote.notifications(page: page, limit: limit);
    if (!response.isOk) throw response.toException();

    final result = EmployeeMappers.pageOf<EmployeeNotification>(
      response.data,
      key: 'notifications',
      parse: EmployeeMappers.notification,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    EmployeeLog.data('Notifications → $result');
    return result;
  }

  @override
  Future<int> getUnreadNotificationCount() async {
    final response = await _remote.unreadCount();
    if (!response.isOk) throw response.toException();

    // `count` sits at the top level here, not inside `data`.
    final body = response.data;
    final raw = body is Map ? body['count'] : null;
    final count = raw is num ? raw.toInt() : int.tryParse('$raw') ?? 0;

    EmployeeLog.data('Unread notifications → $count');
    return count;
  }

  @override
  Future<void> markNotificationRead(int id) async {
    final response = await _remote.markNotificationRead(id);
    if (!response.isOk) throw response.toException();
  }

  @override
  Future<void> markAllNotificationsRead() async {
    final response = await _remote.markAllNotificationsRead();
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('All notifications marked read');
  }

  @override
  Future<EmployeeAudience> getAudience() async {
    final response = await _remote.audience();
    if (!response.isOk) throw response.toException();

    final audience = EmployeeMappers.audience(response.data);
    EmployeeLog.data('Audience → $audience');
    return audience;
  }

  @override
  Future<String> sendNotification(EmployeeNotificationDraft draft) async {
    final response = await _remote.sendNotification(draft.toBody());
    if (!response.isOk) throw response.toException();

    EmployeeLog.success('Notification sent (${draft.mode.wire})');
    return response.message ?? 'Notification sent';
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Sports
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Future<List<EmployeeSport>> getSports({
    int limit = 200,
    String? search,
  }) async {
    final response = await _remote.sports(limit: limit, search: search);
    if (!response.isOk) throw response.toException();

    final rows = EmployeeMappers.rowsAt(response.data, 'sports');
    final sports = rows
        .map(EmployeeMappers.sport)
        .whereType<EmployeeSport>()
        .toList(growable: false);

    _warnIfDropped(rows.length, sports.length, 'sports');
    EmployeeLog.data('Sports → ${sports.length}');
    return sports;
  }

  @override
  Future<void> createSport(Map<String, dynamic> body) async {
    final response = await _remote.createSport(body);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Sport created');
  }

  @override
  Future<void> updateSport(int id, Map<String, dynamic> body) async {
    final response = await _remote.updateSport(id, body);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Sport $id updated');
  }

  @override
  Future<void> deleteSport(int id) async {
    final response = await _remote.deleteSport(id);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Sport $id deleted');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Courts
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Future<List<EmployeeCourt>> getCourts({int limit = 200, int? sportId}) async {
    final response = await _remote.courts(limit: limit, sportId: sportId);
    if (!response.isOk) throw response.toException();

    final rows = EmployeeMappers.rowsAt(response.data, 'courts');
    final courts = rows
        .map(EmployeeMappers.court)
        .whereType<EmployeeCourt>()
        .toList(growable: false);

    _warnIfDropped(rows.length, courts.length, 'courts');
    EmployeeLog.data('Courts → ${courts.length}');
    return courts;
  }

  @override
  Future<void> createCourt(Map<String, dynamic> body) async {
    final response = await _remote.createCourt(body);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Court created');
  }

  @override
  Future<void> updateCourt(int id, Map<String, dynamic> body) async {
    final response = await _remote.updateCourt(id, body);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Court $id updated');
  }

  @override
  Future<void> deleteCourt(int id) async {
    final response = await _remote.deleteCourt(id);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Court $id deleted');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Slots
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Future<List<EmployeeSlot>> getSlots(int courtId) async {
    final response = await _remote.slots(courtId);
    if (!response.isOk) throw response.toException();

    final rows = EmployeeMappers.rowsAt(response.data, 'slots');
    final slots = rows
        .map(EmployeeMappers.slot)
        .whereType<EmployeeSlot>()
        .toList(growable: false);

    _warnIfDropped(rows.length, slots.length, 'slots');
    EmployeeLog.data('Slots for court $courtId → ${slots.length}');
    return slots;
  }

  @override
  Future<void> createSlot(int courtId, Map<String, dynamic> body) async {
    final response = await _remote.createSlot(courtId, body);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Slot created on court $courtId');
  }

  @override
  Future<void> updateSlot(
    int courtId,
    int slotId,
    Map<String, dynamic> body,
  ) async {
    final response = await _remote.updateSlot(courtId, slotId, body);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Slot $slotId updated');
  }

  @override
  Future<void> deleteSlot(int courtId, int slotId) async {
    final response = await _remote.deleteSlot(courtId, slotId);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Slot $slotId deleted');
  }

  @override
  Future<void> setSlotStatus(int courtId, int slotId, String status) async {
    final response = await _remote.setSlotStatus(courtId, slotId, status);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Slot $slotId → $status (all dates)');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Blocked slots
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Future<List<EmployeeAvailableSlot>> getAvailableSlots({
    required int courtId,
    required String date,
  }) async {
    final response = await _remote.availableSlots(
      courtId: courtId,
      date: date,
    );
    if (!response.isOk) throw response.toException();

    final rows = EmployeeMappers.rows(response.data);
    final slots = rows
        .map(EmployeeMappers.availableSlot)
        .whereType<EmployeeAvailableSlot>()
        .toList(growable: false);

    _warnIfDropped(rows.length, slots.length, 'available slots');
    EmployeeLog.data('Availability $date court $courtId → ${slots.length}');
    return slots;
  }

  @override
  Future<void> blockSlotForDate({
    required int courtId,
    required int slotId,
    required String date,
    String? notes,
    bool countAsRevenue = false,
    num? amount,
  }) async {
    final response = await _remote.blockSlot(
      courtId: courtId,
      slotId: slotId,
      date: date,
      notes: notes,
      countAsRevenue: countAsRevenue,
      amount: amount,
    );
    if (!response.isOk) throw response.toException();
    EmployeeLog.success(
      'Slot $slotId blocked for $date'
      '${countAsRevenue ? ' (booked as revenue)' : ''}',
    );
  }

  @override
  Future<void> unblockSlotForDate({
    required int courtId,
    required int slotId,
    required String date,
  }) async {
    final response = await _remote.unblockSlot(
      courtId: courtId,
      slotId: slotId,
      date: date,
    );
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Slot $slotId unblocked for $date');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Batches
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Future<List<EmployeeBatch>> getBatches({int limit = 200}) async {
    final response = await _remote.batches(limit: limit);
    if (!response.isOk) throw response.toException();

    final rows = EmployeeMappers.rowsAt(response.data, 'batches');
    final batches = rows
        .map(EmployeeMappers.batch)
        .whereType<EmployeeBatch>()
        .toList(growable: false);

    _warnIfDropped(rows.length, batches.length, 'batches');
    EmployeeLog.data('Batches → ${batches.length}');
    return batches;
  }

  @override
  Future<void> createBatch(Map<String, dynamic> body) async {
    final response = await _remote.createBatch(body);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Batch created');
  }

  @override
  Future<void> updateBatch(int id, Map<String, dynamic> body) async {
    final response = await _remote.updateBatch(id, body);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Batch $id updated');
  }

  @override
  Future<void> deleteBatch(int id) async {
    final response = await _remote.deleteBatch(id);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Batch $id deleted');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Pickers
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Future<List<EmployeeOption>> getStudentOptions({
    int limit = 300,
    String? search,
  }) async {
    final response = await _remote.students(limit: limit, search: search);
    if (!response.isOk) throw response.toException();

    final options = EmployeeMappers.rowsAt(response.data, 'students')
        .map(EmployeeMappers.studentOption)
        .whereType<EmployeeOption>()
        .toList(growable: false);

    EmployeeLog.data('Student options → ${options.length}');
    return options;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Students (the Student List module)
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Future<EmployeePaged<EmployeeStudent>> getStudents({
    int page = 1,
    int limit = 20,
    String? search,
  }) async {
    final response = await _remote.students(
      page: page,
      limit: limit,
      search: search,
    );
    if (!response.isOk) throw response.toException();

    final result = EmployeeMappers.pageOf<EmployeeStudent>(
      response.data,
      key: 'students',
      parse: EmployeeMappers.student,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    _warnIfDropped(
      EmployeeMappers.rowsAt(response.data, 'students').length,
      result.items.length,
      'students',
    );
    EmployeeLog.data('Students → $result');
    return result;
  }

  @override
  Future<EmployeeStudent> getStudent(int id) async {
    final response = await _remote.student(id);
    if (!response.isOk) throw response.toException();

    final student = EmployeeMappers.student(
      _objectOf(response.data, 'student'),
    );
    if (student == null) {
      throw const ParseException('That student could not be read.');
    }

    EmployeeLog.data('Student → $student');
    return student;
  }

  @override
  Future<void> updateStudent(int id, EmployeeStudentDraft draft) async {
    final body = draft.toJson();
    if (body.isEmpty) {
      // Nothing to send. Calling anyway would answer 200 and teach the user
      // that a no-op edit "saved", so it is refused here instead.
      EmployeeLog.state('Student $id update skipped — nothing changed');
      return;
    }

    final response = await _remote.updateStudent(id, body);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Student $id updated');
  }

  @override
  Future<void> deleteStudent(int id) async {
    final response = await _remote.deleteStudent(id);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Student $id deleted');
  }

  @override
  Future<void> sendStudentFeedback(
    int id,
    EmployeeStudentFeedbackDraft draft,
  ) async {
    final response = await _remote.sendStudentFeedback(id, draft.toJson());
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Feedback sent to student $id');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Coupons
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Future<EmployeePaged<EmployeeCoupon>> getCoupons({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
  }) async {
    final response = await _remote.coupons(
      page: page,
      limit: limit,
      search: search,
      status: status,
    );
    if (!response.isOk) throw response.toException();

    // Shape A: the rows are `data` itself, with a sibling `pagination` block —
    // there is no named key to look under, so the key is the envelope's own.
    final result = EmployeeMappers.pageOf<EmployeeCoupon>(
      response.data,
      key: 'coupons',
      parse: EmployeeMappers.coupon,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    _warnIfDropped(
      EmployeeMappers.rowsAt(response.data, 'coupons').length,
      result.items.length,
      'coupons',
    );
    EmployeeLog.data('Coupons → $result');
    return result;
  }

  @override
  Future<EmployeeCoupon> getCoupon(int id) async {
    final response = await _remote.coupon(id);
    if (!response.isOk) throw response.toException();

    final coupon = EmployeeMappers.coupon(_objectOf(response.data, 'coupon'));
    if (coupon == null) {
      throw const ParseException('That coupon could not be read.');
    }

    EmployeeLog.data('Coupon → $coupon');
    return coupon;
  }

  @override
  Future<void> createCoupon(EmployeeCouponDraft draft) async {
    final response = await _remote.createCoupon(draft.toJson());
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Coupon ${draft.code.toUpperCase()} created');
  }

  @override
  Future<void> updateCoupon(int id, EmployeeCouponDraft draft) async {
    final response = await _remote.updateCoupon(id, draft.toJson());
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Coupon $id updated');
  }

  @override
  Future<void> deleteCoupon(int id) async {
    final response = await _remote.deleteCoupon(id);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Coupon $id deleted');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Visitor passes
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Future<EmployeePaged<EmployeeVisitorPass>> getVisitorPasses({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _remote.visitorPasses(page: page, limit: limit);
    if (!response.isOk) throw response.toException();

    final result = EmployeeMappers.pageOf<EmployeeVisitorPass>(
      response.data,
      key: 'passes',
      parse: EmployeeMappers.visitorPass,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    _warnIfDropped(
      EmployeeMappers.rowsAt(response.data, 'passes').length,
      result.items.length,
      'visitor passes',
    );
    EmployeeLog.data('Visitor passes → $result');
    return result;
  }

  @override
  Future<EmployeeVisitorPass> getVisitorPass(Object idOrCode) async {
    final response = await _remote.visitorPass(idOrCode);
    if (!response.isOk) throw response.toException();

    final pass = EmployeeMappers.visitorPass(_objectOf(response.data, 'pass'));
    if (pass == null) {
      throw const ParseException('That visitor pass could not be read.');
    }

    EmployeeLog.data('Visitor pass → $pass');
    return pass;
  }

  @override
  Future<EmployeeVisitorPass?> createVisitorPass(
    EmployeeVisitorPassDraft draft,
  ) async {
    final response = await _remote.createVisitorPass(draft.toJson());
    if (!response.isOk) throw response.toException();

    // The pass number and QR code are only in this answer — nothing re-reads
    // them — but a payload that did not echo the row is still a success.
    final pass = EmployeeMappers.visitorPass(
      _objectOf(response.data, 'pass'),
    );
    EmployeeLog.success('Visitor pass generated${pass == null ? '' : ' — ${pass.displayCode}'}');
    return pass;
  }

  @override
  Future<void> emailVisitorPass(
    int id,
    EmployeeVisitorPassEmailDraft draft,
  ) async {
    final response = await _remote.emailVisitorPass(id, draft.toJson());
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Visitor pass $id emailed');
  }

  @override
  Future<void> deleteVisitorPass(int id) async {
    final response = await _remote.deleteVisitorPass(id);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Visitor pass $id deleted');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Events
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Future<EmployeePaged<EmployeeEvent>> getEvents({
    int page = 1,
    int limit = 20,
    EmployeeEventTimeframe timeframe = EmployeeEventTimeframe.upcoming,
  }) async {
    final response = await _remote.events(
      page: page,
      limit: limit,
      timeframe: timeframe.queryOrNull,
    );
    if (!response.isOk) throw response.toException();

    final result = EmployeeMappers.pageOf<EmployeeEvent>(
      response.data,
      key: 'events',
      parse: EmployeeMappers.event,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    _warnIfDropped(
      EmployeeMappers.rowsAt(response.data, 'events').length,
      result.items.length,
      'events',
    );
    EmployeeLog.data('Events (${timeframe.query.isEmpty ? 'all' : timeframe.query}) → $result');
    return result;
  }

  @override
  Future<EmployeeEvent> getEvent(int id) async {
    final response = await _remote.event(id);
    if (!response.isOk) throw response.toException();

    final event = EmployeeMappers.event(_objectOf(response.data, 'event'));
    if (event == null) {
      throw const ParseException('That event could not be read.');
    }

    EmployeeLog.data('Event → $event');
    return event;
  }

  @override
  Future<void> createEvent(EmployeeEventDraft draft) async {
    final response = await _remote.createEvent(draft.toJson());
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Event created');
  }

  @override
  Future<void> updateEvent(int id, EmployeeEventDraft draft) async {
    final response = await _remote.updateEvent(id, draft.toJson());
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Event $id updated');
  }

  @override
  Future<void> deleteEvent(int id) async {
    final response = await _remote.deleteEvent(id);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Event $id deleted');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Event bookings (Issue Event Pass)
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Future<EmployeePaged<EmployeeEventBooking>> getEventBookings({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _remote.eventBookings(page: page, limit: limit);
    if (!response.isOk) throw response.toException();

    final result = EmployeeMappers.pageOf<EmployeeEventBooking>(
      response.data,
      key: 'bookings',
      parse: EmployeeMappers.eventBooking,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    _warnIfDropped(
      EmployeeMappers.rowsAt(response.data, 'bookings').length,
      result.items.length,
      'event bookings',
    );
    EmployeeLog.data('Event bookings → $result');
    return result;
  }

  @override
  Future<void> emailEventPass(
    int passId,
    EmployeeEventPassEmailDraft draft,
  ) async {
    final response = await _remote.emailIndividualPass(passId, draft.toJson());
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Pass $passId emailed');
  }

  @override
  Future<void> deleteEventBooking(int id) async {
    final response = await _remote.deleteEventBooking(id);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Event booking $id deleted');
  }

  @override
  Future<int> deleteEventBookings(List<int> ids) async {
    // Deduplicated because the selection can hold the same row twice after a
    // reload, and the route counts what it is given.
    final unique = ids.toSet().toList(growable: false);
    if (unique.isEmpty) return 0;

    final response = await _remote.deleteEventBookings(unique);
    if (!response.isOk) throw response.toException();

    EmployeeLog.success('${unique.length} event bookings deleted');
    return unique.length;
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Contact enquiries
  // ───────────────────────────────────────────────────────────────────────────

  @override
  Future<EmployeeContactEnquiryPage> getContactEnquiries({
    int page = 1,
    int limit = 20,
    String? status,
  }) async {
    final response = await _remote.contactEnquiries(
      page: page,
      limit: limit,
      status: status,
    );
    if (!response.isOk) throw response.toException();

    final result = EmployeeMappers.pageOf<EmployeeContactEnquiry>(
      response.data,
      key: 'inquiries',
      parse: EmployeeMappers.contactEnquiry,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    _warnIfDropped(
      EmployeeMappers.rowsAt(response.data, 'inquiries').length,
      result.items.length,
      'contact enquiries',
    );

    final counts = EmployeeMappers.contactEnquiryCounts(response.data);
    EmployeeLog.data('Contact enquiries → $result, $counts');

    return EmployeeContactEnquiryPage(page: result, counts: counts);
  }

  @override
  Future<EmployeeContactEnquiry> getContactEnquiry(String id) async {
    final response = await _remote.contactEnquiry(id);
    if (!response.isOk) throw response.toException();

    final enquiry = EmployeeMappers.contactEnquiry(
      _objectOf(response.data, 'inquiry'),
    );
    if (enquiry == null) {
      throw const ParseException('That enquiry could not be read.');
    }

    EmployeeLog.data('Contact enquiry → $enquiry');
    return enquiry;
  }

  @override
  Future<void> setContactEnquiryStatus(String id, String status) async {
    final response = await _remote.setContactEnquiryStatus(id, status);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Contact enquiry $id → $status');
  }

  @override
  Future<void> deleteContactEnquiry(String id) async {
    final response = await _remote.deleteContactEnquiry(id);
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Contact enquiry $id deleted');
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Diagnostics
  // ───────────────────────────────────────────────────────────────────────────

  /// Says when rows were parsed away.
  ///
  /// A row is dropped only when it carries no usable id, which means a real
  /// record is missing from a screen an employee is making decisions on — worth
  /// a line in the console even though it is not worth an error state.
  /// The single record a write or a by-id read answered with.
  ///
  /// These routes are not consistent about where they put it: some answer
  /// `{data: {...}}`, some `{data: {student: {...}}}`, and some the bare object.
  /// All three are read, so a caller never has to know which.
  static Map<String, dynamic> _objectOf(Object? body, String key) {
    if (body is Map) {
      // `{key: {...}}` at the top level.
      final direct = body[key];
      if (direct is Map) return Map<String, dynamic>.from(direct);

      final inner = body['data'];
      if (inner is Map) {
        // `{data: {key: {...}}}`.
        final nested = inner[key];
        if (nested is Map) return Map<String, dynamic>.from(nested);
        // `{data: {...}}` — the record itself.
        return Map<String, dynamic>.from(inner);
      }
      // `{data: [{...}]}` — a one-row list, which a couple of these routes
      // answer with when the id matched exactly one record.
      if (inner is List) {
        final rows = EmployeeMappers.rowsAt(body, key);
        if (rows.isNotEmpty) return rows.first;
      }
    }

    return EmployeeMappers.envelope(body);
  }

  /// The id off a create response, wherever it landed.
  static int? _idOf(Object? body) {
    final json = EmployeeMappers.envelope(body);
    final direct = json['id'];
    if (direct != null) return int.tryParse(direct.toString());

    for (final value in json.values) {
      if (value is Map && value['id'] != null) {
        return int.tryParse(value['id'].toString());
      }
    }
    return null;
  }

  static void _warnIfDropped(int received, int kept, String what) {
    if (received == kept) return;
    EmployeeLog.failure(
      'Dropped ${received - kept} of $received $what rows — no usable id',
    );
  }
}
