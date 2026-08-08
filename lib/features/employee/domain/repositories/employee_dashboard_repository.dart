import '../entities/employee_attendance.dart';
import '../entities/employee_booking.dart';
import '../entities/employee_coach.dart';
import '../entities/employee_enquiry.dart';
import '../entities/employee_fee.dart';
import '../entities/employee_master.dart';
import '../entities/employee_notification.dart';
import '../entities/employee_overview.dart';
import '../entities/employee_paged.dart';
import '../entities/employee_payment.dart';
import '../entities/employee_staff_details.dart';
import '../entities/employee_user.dart';

/// Everything the employee dashboard reads and writes.
///
/// Two rules hold across the whole interface:
///
/// 1. **No complex id is ever passed.** `complexScope.js` lists EMPLOYEE in
///    `COMPLEX_SCOPED_ROLES`, so the backend resolves the caller's own complex
///    and both filters reads and stamps writes with it. A client-supplied value
///    would be ignored.
/// 2. **Reads throw on failure.** Each controller decides what a failure means
///    for its own section — one dead panel must not blank a whole page.
abstract class EmployeeDashboardRepository {
  // ───────────────────────────────────────────────────────────────────────────
  // Overview
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /reports/overview` — the headline numbers.
  Future<EmployeeStats> getStats();

  /// The newest few bookings, for the dashboard's activity strip.
  Future<List<EmployeeRecentBooking>> getRecentBookings({int limit = 5});

  // ───────────────────────────────────────────────────────────────────────────
  // Profile
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /auth/staff-details` — this employee's own employment record
  /// (employee id, designation, department, shift, joining date, …).
  ///
  /// Read-only: an admin maintains these, and `PUT /auth/profile` answers 403
  /// for staff logins.
  Future<EmployeeStaffDetails> getStaffDetails();

  // ───────────────────────────────────────────────────────────────────────────
  // Bookings
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /bookings` — the complex's court bookings.
  Future<EmployeePaged<EmployeeBooking>> getBookings({
    int page = 1,
    int limit = 20,
    String? date,
    int? sportId,
    String? paymentStatus,
    String? bookingStatus,
  });

  /// `PUT /bookings/{id}` — a partial update. Only the fields passed are sent,
  /// so marking a booking Paid cannot accidentally clear its notes.
  ///
  /// [customerName] is stored **on the booking**, not on the account: partner
  /// bookings all share one login, so renaming the account would rename every
  /// one of that partner's bookings at once.
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
  });

  /// `DELETE /bookings/{id}`. Soft-deletes server-side.
  Future<void> deleteBooking(int id);

  // ───────────────────────────────────────────────────────────────────────────
  // Payments
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /payments/all` — the unified ledger plus the stats that came with it.
  Future<EmployeePaymentsPage> getPayments({
    int page = 1,
    int limit = 20,
    String? status,
    String? type,
    String? search,
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Attendance (read-only — see [EmployeeAttendanceRecord])
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /attendance`.
  Future<EmployeePaged<EmployeeAttendanceRecord>> getAttendance({
    int page = 1,
    int limit = 20,
    String? date,
    String? status,
    int? batchId,
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Coaches (read-only)
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /coaches`.
  Future<EmployeePaged<EmployeeCoach>> getCoaches({
    int page = 1,
    int limit = 20,
    String? search,
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Coaching enquiries
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /coaching-enquiries/all`.
  Future<EmployeePaged<EmployeeEnquiry>> getEnquiries({
    int page = 1,
    int limit = 20,
    String? status,
    String? search,
  });

  /// `POST /coaching-enquiries/{id}/approve-and-enroll`.
  ///
  /// ⚠️ Not a status change: it creates the student (or reuses their account),
  /// enrols them in the batch and opens a `Pending` fee record, in one
  /// transaction. Answers 400 when the batch is full or the enquiry is already
  /// settled.
  Future<void> approveEnquiry(int id);

  // ───────────────────────────────────────────────────────────────────────────
  // Fees
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /fees`.
  Future<EmployeePaged<EmployeeFee>> getFees({
    int page = 1,
    int limit = 20,
    String? approvalStatus,
    String? paymentStatus,
    String? search,
    int? batchId,
  });

  /// `GET /fees/stats`.
  Future<EmployeeFeeStats> getFeeStats();

  /// `PATCH /fees/{id}/approve` — **this is what unlocks the student's gate
  /// pass**, which is why it is not a coach route.
  Future<void> approveFee(int id);

  /// `PATCH /fees/{id}/reject`.
  Future<void> rejectFee(int id);

  /// `POST /fees` — Fees Management only.
  Future<void> createFee(EmployeeFeeDraft draft);

  /// `PUT /fees/{id}` — the record itself, not the approval on it.
  Future<void> updateFee(int id, EmployeeFeeDraft draft);

  /// `DELETE /fees/{id}`.
  Future<void> deleteFee(int id);

  // ───────────────────────────────────────────────────────────────────────────
  // Users
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /admin/users`. Granted to EMPLOYEE despite the path.
  Future<EmployeePaged<EmployeeUser>> getUsers({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
    String? membershipType,
  });

  /// `PUT /admin/users/{id}`. Creating and deleting users are admin-only, so
  /// they are deliberately absent from this interface.
  Future<void> updateUser(Object id, Map<String, dynamic> body);

  // ───────────────────────────────────────────────────────────────────────────
  // Notifications
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /notifications` — the employee's own inbox.
  Future<EmployeePaged<EmployeeNotification>> getNotifications({
    int page = 1,
    int limit = 20,
  });

  /// `GET /notifications/unread-count`.
  Future<int> getUnreadNotificationCount();

  /// `PATCH /notifications/{id}/read`.
  Future<void> markNotificationRead(int id);

  /// `PATCH /notifications/mark-all-read`.
  Future<void> markAllNotificationsRead();

  /// `GET /notifications/audience` — the coaches and students of this
  /// employee's own complex.
  Future<EmployeeAudience> getAudience();

  /// `POST /notifications/send`.
  Future<String> sendNotification(EmployeeNotificationDraft draft);

  // ───────────────────────────────────────────────────────────────────────────
  // Sports
  // ───────────────────────────────────────────────────────────────────────────

  Future<List<EmployeeSport>> getSports({int limit = 200, String? search});
  Future<void> createSport(Map<String, dynamic> body);
  Future<void> updateSport(int id, Map<String, dynamic> body);
  Future<void> deleteSport(int id);

  // ───────────────────────────────────────────────────────────────────────────
  // Courts
  // ───────────────────────────────────────────────────────────────────────────

  Future<List<EmployeeCourt>> getCourts({int limit = 200, int? sportId});
  Future<void> createCourt(Map<String, dynamic> body);
  Future<void> updateCourt(int id, Map<String, dynamic> body);
  Future<void> deleteCourt(int id);

  // ───────────────────────────────────────────────────────────────────────────
  // Slots (the recurring template on a court)
  // ───────────────────────────────────────────────────────────────────────────

  Future<List<EmployeeSlot>> getSlots(int courtId);
  Future<void> createSlot(int courtId, Map<String, dynamic> body);
  Future<void> updateSlot(int courtId, int slotId, Map<String, dynamic> body);
  Future<void> deleteSlot(int courtId, int slotId);

  /// `PATCH /courts/{courtId}/slots/{slotId}/toggle` with an explicit status —
  /// a bodyless PATCH answers 400.
  ///
  /// ⚠️ This flips the **template**, so it applies to every date. Use
  /// [blockSlotForDate] for a single day.
  Future<void> setSlotStatus(int courtId, int slotId, String status);

  // ───────────────────────────────────────────────────────────────────────────
  // Blocked slots (one date at a time)
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /courts/{courtId}/available-slots?date=`.
  Future<List<EmployeeAvailableSlot>> getAvailableSlots({
    required int courtId,
    required String date,
  });

  /// `POST /courts/{courtId}/slots/{slotId}/block` — that date only.
  Future<void> blockSlotForDate({
    required int courtId,
    required int slotId,
    required String date,
  });

  /// `POST /courts/{courtId}/slots/{slotId}/unblock`.
  Future<void> unblockSlotForDate({
    required int courtId,
    required int slotId,
    required String date,
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Batches
  // ───────────────────────────────────────────────────────────────────────────

  Future<List<EmployeeBatch>> getBatches({int limit = 200});
  Future<void> createBatch(Map<String, dynamic> body);
  Future<void> updateBatch(int id, Map<String, dynamic> body);
  Future<void> deleteBatch(int id);

  // ───────────────────────────────────────────────────────────────────────────
  // Pickers
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /students` — for the Fees Management create form.
  Future<List<EmployeeOption>> getStudentOptions({
    int limit = 300,
    String? search,
  });
}
