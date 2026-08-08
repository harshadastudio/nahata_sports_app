import '../../core/employee_log.dart';
import '../../domain/entities/employee_attendance.dart';
import '../../domain/entities/employee_booking.dart';
import '../../domain/entities/employee_coach.dart';
import '../../domain/entities/employee_enquiry.dart';
import '../../domain/entities/employee_fee.dart';
import '../../domain/entities/employee_master.dart';
import '../../domain/entities/employee_notification.dart';
import '../../domain/entities/employee_overview.dart';
import '../../domain/entities/employee_paged.dart';
import '../../domain/entities/employee_payment.dart';
import '../../domain/entities/employee_staff_details.dart';
import '../../domain/entities/employee_user.dart';
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
  }) async {
    final response = await _remote.enquiries(
      page: page,
      limit: limit,
      status: status,
      search: search,
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
  Future<void> approveEnquiry(int id) async {
    final response = await _remote.approveEnquiry(id);
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
  }) async {
    final response = await _remote.blockSlot(
      courtId: courtId,
      slotId: slotId,
      date: date,
    );
    if (!response.isOk) throw response.toException();
    EmployeeLog.success('Slot $slotId blocked for $date');
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
  // Diagnostics
  // ───────────────────────────────────────────────────────────────────────────

  /// Says when rows were parsed away.
  ///
  /// A row is dropped only when it carries no usable id, which means a real
  /// record is missing from a screen an employee is making decisions on — worth
  /// a line in the console even though it is not worth an error state.
  static void _warnIfDropped(int received, int kept, String what) {
    if (received == kept) return;
    EmployeeLog.failure(
      'Dropped ${received - kept} of $received $what rows — no usable id',
    );
  }
}
