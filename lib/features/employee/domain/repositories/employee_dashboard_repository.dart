import '../entities/employee_attendance.dart';
import '../entities/employee_booking.dart';
import '../entities/employee_coach.dart';
import '../entities/employee_contact_enquiry.dart';
import '../entities/employee_coupon.dart';
import '../entities/employee_enquiry.dart';
import '../entities/employee_event.dart';
import '../entities/employee_event_booking.dart';
import '../entities/employee_fee.dart';
import '../entities/employee_master.dart';
import '../entities/employee_notification.dart';
import '../entities/employee_overview.dart';
import '../entities/employee_paged.dart';
import '../entities/employee_payment.dart';
import '../entities/employee_staff_details.dart';
import '../entities/employee_student.dart';
import '../entities/employee_user.dart';
import '../entities/employee_visitor_pass.dart';

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
  ///
  /// [from] and [to] are inclusive calendar days. The API compares `toDate`
  /// against a timestamp, so the implementation extends [to] to the end of that
  /// day — a bare date would silently exclude everything logged during it.
  Future<EmployeePaged<EmployeeEnquiry>> getEnquiries({
    int page = 1,
    int limit = 20,
    String? status,
    String? search,
    DateTime? from,
    DateTime? to,
  });

  /// `POST /coaching-enquiries/admin/create` — a walk-in enquiry typed at the
  /// desk.
  ///
  /// The route also **registers the student**: it creates a User and a Student
  /// when the email is new and emails them their login. The result carries the
  /// new enquiry's id and that `studentAccount` block, so the desk can say
  /// whether credentials went out.
  Future<EmployeeEnquiryCreateResult> createEnquiry(EmployeeEnquiryDraft draft);

  /// `PUT /coaching-enquiries/admin/{id}`.
  ///
  /// Answers 400 once the enquiry is Approved — the enrolment already exists,
  /// and editing the enquiry would not move it.
  Future<void> updateEnquiry(int id, EmployeeEnquiryDraft draft);

  /// `PATCH /coaching-enquiries/{id}/status`.
  ///
  /// Handles every status **except** `Approved`: marking an enquiry approved
  /// without enrolling anyone is exactly what [approveEnquiry] exists to avoid.
  Future<void> setEnquiryStatus(int id, String status);

  /// `DELETE /coaching-enquiries/{id}`.
  Future<void> deleteEnquiry(int id);

  /// `POST /coaching-enquiries/{id}/approve-and-enroll`.
  ///
  /// ⚠️ Not a status change: it creates the student (or reuses their account),
  /// enrols them in the batch and opens a fee record, in one transaction.
  /// Answers 400 when the batch is full or the enquiry is already settled.
  ///
  /// [draft] seeds that fee record; the default opens it as `Pending` / `0`,
  /// which is what the route does with no body at all.
  Future<void> approveEnquiry(
    int id, {
    EmployeeEnquiryApprovalDraft draft = EmployeeEnquiryApprovalDraft.pending,
  });

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
  ///
  /// `countAsRevenue: true` (BOOK) records the block as a paid booking;
  /// re-posting with the opposite value on an already-blocked slot is the
  /// un-bill/re-bill correction and only changes the billed flag.
  Future<void> blockSlotForDate({
    required int courtId,
    required int slotId,
    required String date,
    String? notes,
    bool countAsRevenue = false,
    num? amount,
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

  // ───────────────────────────────────────────────────────────────────────────
  // Students (the Student List module)
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /students` — the desk's student list.
  Future<EmployeePaged<EmployeeStudent>> getStudents({
    int page = 1,
    int limit = 20,
    String? search,
  });

  /// `GET /students/{id}`.
  Future<EmployeeStudent> getStudent(int id);

  /// `PUT /students/{id}` — only the five fields the panel form owns. The
  /// values are written through to the linked account.
  Future<void> updateStudent(int id, EmployeeStudentDraft draft);

  /// `DELETE /students/{id}`.
  Future<void> deleteStudent(int id);

  /// `POST /students/{id}/feedback` — a note the student sees on their own
  /// dashboard.
  Future<void> sendStudentFeedback(int id, EmployeeStudentFeedbackDraft draft);

  // ───────────────────────────────────────────────────────────────────────────
  // Coupons
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /admin/coupons`.
  Future<EmployeePaged<EmployeeCoupon>> getCoupons({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
  });

  /// `GET /admin/coupons/{id}` — one coupon, read fresh so the edit form does
  /// not open over a list row that has since moved on.
  Future<EmployeeCoupon> getCoupon(int id);

  /// `POST /admin/coupons`. The code is uppercased and must be unique.
  Future<void> createCoupon(EmployeeCouponDraft draft);

  /// `PUT /admin/coupons/{id}`. The code cannot be changed, so the draft omits
  /// it when it is an edit.
  Future<void> updateCoupon(int id, EmployeeCouponDraft draft);

  /// `DELETE /admin/coupons/{id}`.
  Future<void> deleteCoupon(int id);

  // ───────────────────────────────────────────────────────────────────────────
  // Visitor passes
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /visitor-passes`.
  Future<EmployeePaged<EmployeeVisitorPass>> getVisitorPasses({
    int page = 1,
    int limit = 20,
  });

  /// `GET /visitor-passes/{idOrCode}` — one pass, by its numeric id or by its
  /// pass number (`VP-20260812-F1D246`). The detail sheet re-reads through this
  /// so it shows the gate's current status rather than the list's snapshot.
  Future<EmployeeVisitorPass> getVisitorPass(Object idOrCode);

  /// `POST /visitor-passes` — returns the pass that was generated, so the sheet
  /// can show its number and QR code without a second read.
  Future<EmployeeVisitorPass?> createVisitorPass(
    EmployeeVisitorPassDraft draft,
  );

  /// `POST /visitor-passes/{id}/send-email` — emails the pass and its QR code
  /// to any address.
  Future<void> emailVisitorPass(int id, EmployeeVisitorPassEmailDraft draft);

  /// `DELETE /visitor-passes/{id}`.
  Future<void> deleteVisitorPass(int id);

  // ───────────────────────────────────────────────────────────────────────────
  // Events
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /event-passes` — the split is made server-side by [timeframe].
  Future<EmployeePaged<EmployeeEvent>> getEvents({
    int page = 1,
    int limit = 20,
    EmployeeEventTimeframe timeframe = EmployeeEventTimeframe.upcoming,
  });

  /// `GET /event-passes/{id}` — the one read that reliably carries the slots,
  /// custom fields and FAQs together.
  Future<EmployeeEvent> getEvent(int id);

  /// `POST /event-passes`.
  Future<void> createEvent(EmployeeEventDraft draft);

  /// `PUT /event-passes/{id}` — the same body as create. A child carrying its
  /// existing id is updated in place; one left out of the array is removed.
  Future<void> updateEvent(int id, EmployeeEventDraft draft);

  /// `DELETE /event-passes/{id}`.
  Future<void> deleteEvent(int id);

  // ───────────────────────────────────────────────────────────────────────────
  // Event bookings (Issue Event Pass)
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /event-passes/bookings/all`.
  ///
  /// Each row carries its own `individualPasses[]`, so there is no second call
  /// to fetch the passes on a booking.
  Future<EmployeePaged<EmployeeEventBooking>> getEventBookings({
    int page = 1,
    int limit = 20,
  });

  /// `POST /event-passes/individual-passes/{passId}/send-email`.
  Future<void> emailEventPass(int passId, EmployeeEventPassEmailDraft draft);

  /// `DELETE /event-passes/bookings/{id}` — the booking and its passes.
  Future<void> deleteEventBooking(int id);

  /// `DELETE /event-passes/bookings` with `{ids}` — the bulk delete.
  ///
  /// Returns how many ids were sent, so the caller can report the count it
  /// actually removed rather than assuming the whole selection landed.
  Future<int> deleteEventBookings(List<int> ids);

  // ───────────────────────────────────────────────────────────────────────────
  // Contact enquiries
  // ───────────────────────────────────────────────────────────────────────────

  /// `GET /contact-us/admin` — the rows **and** the `statusCounts` block that
  /// comes beside them, which no other route in this console sends.
  Future<EmployeeContactEnquiryPage> getContactEnquiries({
    int page = 1,
    int limit = 20,
    String? status,
  });

  /// `GET /contact-us/admin/{id}` — the full enquiry. The list row's message
  /// is what the queue shows; this is what the detail sheet reads.
  Future<EmployeeContactEnquiry> getContactEnquiry(String id);

  /// `PATCH /contact-us/admin/{id}/status`.
  ///
  /// [status] is the lower-case wire value (`new` | `read` | `replied`), not a
  /// display string — see [EmployeeContactEnquiry.statuses].
  Future<void> setContactEnquiryStatus(String id, String status);

  /// `DELETE /contact-us/admin/{id}` — a soft delete server-side.
  Future<void> deleteContactEnquiry(String id);
}

/// One page of contact enquiries, plus the counters that arrived with it.
///
/// `GET /contact-us/admin` is the only route in this console that nests its
/// pagination *inside* `data` and adds a `statusCounts` sibling, so its result
/// carries the counts rather than throwing them away to fit the shared page
/// shape.
class EmployeeContactEnquiryPage {
  const EmployeeContactEnquiryPage({
    this.page = const EmployeePaged<EmployeeContactEnquiry>(),
    this.counts = EmployeeContactEnquiryCounts.none,
  });

  final EmployeePaged<EmployeeContactEnquiry> page;
  final EmployeeContactEnquiryCounts counts;

  @override
  String toString() => 'EmployeeContactEnquiryPage($page, $counts)';
}
