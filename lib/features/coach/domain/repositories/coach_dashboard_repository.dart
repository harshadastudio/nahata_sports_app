import '../entities/coach_attendance.dart';
import '../entities/coach_batch.dart';
import '../entities/coach_enquiry.dart';
import '../entities/coach_enrollment.dart';
import '../entities/coach_fee.dart';
import '../entities/coach_notification.dart';
import '../entities/coach_option.dart';
import '../entities/coach_overview.dart';
import '../entities/coach_paged.dart';
import '../entities/coach_pass_scan.dart';
import '../entities/coach_progress.dart';
import '../entities/coach_student.dart';

/// Everything the coach dashboard reads and writes.
///
/// The coach is identified by the bearer token throughout — no method takes a
/// coach id, and none can be made to act on another coach's data.
///
/// **Error contract**: these throw `ApiException` on failure rather than
/// returning an empty result. Sections that must survive a partial outage
/// (the overview loads three endpoints at once) catch at the controller, so a
/// dead section degrades on its own instead of blanking the page.
abstract class CoachDashboardRepository {
  // ---------------------------------------------------------------------------
  // Overview
  // ---------------------------------------------------------------------------

  Future<CoachDashboardStats> getStats();

  /// Today's sessions. See [CoachSession] for what the backend actually puts
  /// in the time and court fields.
  Future<List<CoachSession>> getTodaySchedule();

  /// The five highest-scoring students on this coach's roster.
  Future<List<CoachTopPerformer>> getTopPerformers();

  // ---------------------------------------------------------------------------
  // Students
  // ---------------------------------------------------------------------------

  /// One page of the roster. Rows are enrollments, so a student in two batches
  /// appears twice — see [CoachStudent].
  ///
  /// [search] matches the student's name only, and [status] filters on the
  /// **enrollment** status.
  Future<CoachPaged<CoachStudent>> getStudents({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
  });

  /// One month's roster, grouped batch-wise.
  ///
  /// [month] is `yyyy-MM`; passing null lets the backend pick. **Always read
  /// the selection back from the returned view's `month`** — the request is a
  /// suggestion, and the backend falls back when the named month has no data.
  Future<CoachEnrollmentMonthView> getEnrollmentsByMonth({
    String? month,
    String? search,
    String? status,
  });

  // ---------------------------------------------------------------------------
  // Schedule
  // ---------------------------------------------------------------------------

  /// The coach's batches — the closest thing the backend has to a timetable.
  Future<CoachPaged<CoachBatch>> getBatches({
    int page = 1,
    int limit = 20,
    String? status,
    int? sportId,
  });

  // ---------------------------------------------------------------------------
  // Progress
  // ---------------------------------------------------------------------------

  /// Assessments for the coach's own students, newest first.
  Future<CoachPaged<CoachProgress>> getProgress({
    int page = 1,
    int limit = 20,
    int? studentId,
    int? sportId,
  });

  /// Records a **new** dated assessment. Never replaces the previous one —
  /// that history is what the improvement figure is computed from.
  Future<void> createProgress(CoachProgressDraft draft);

  /// Edits an existing assessment. [id] is the performance record's id, not
  /// the student's.
  Future<void> updateProgress(int id, CoachProgressDraft draft);

  Future<void> deleteProgress(int id);

  // ---------------------------------------------------------------------------
  // Attendance
  // ---------------------------------------------------------------------------

  /// Already-marked records, newest first, scoped to the coach's own batches.
  ///
  /// [date] is `yyyy-MM-dd`.
  Future<CoachPaged<CoachAttendanceRecord>> getAttendanceRecords({
    int page = 1,
    int limit = 20,
    String? date,
    String? status,
    int? batchId,
  });

  /// Marks (or corrects) one student's attendance. Upserts on
  /// `(studentId, batchId, date)`.
  Future<void> markAttendance(CoachAttendanceDraft draft);

  /// Saves a whole sheet, one request per line.
  ///
  /// Returns the drafts that failed, paired with the reason, so the sheet can
  /// report a partial save instead of claiming success or losing the lines
  /// that did go through. An empty list means everything saved.
  Future<List<({CoachAttendanceDraft draft, String error})>> markAttendanceSheet(
    List<CoachAttendanceDraft> drafts,
  );

  // ---------------------------------------------------------------------------
  // Enquiries
  // ---------------------------------------------------------------------------

  /// Enquiries assigned to this coach, newest first.
  Future<CoachPaged<CoachEnquiry>> getEnquiries({
    int page = 1,
    int limit = 20,
    CoachEnquiryStatus? status,
  });

  /// Logs a new enquiry on a prospect's behalf. It lands on the admin desk as
  /// `Pending` and notifies them.
  Future<void> createEnquiry(CoachEnquiryDraft draft);

  /// Moves an enquiry along.
  ///
  /// Only [CoachEnquiryStatus.coachSettable] values are accepted; anything
  /// else is refused before the round trip rather than by a 400.
  Future<void> updateEnquiryStatus({
    required int id,
    required CoachEnquiryStatus status,
  });

  Future<void> deleteEnquiry(int id);

  /// Approves an enquiry and enrolls the student in its batch.
  ///
  /// This is **not** reachable through [updateEnquiryStatus] — `Approved` is
  /// refused there — because approving does more than move a status: it
  /// creates the student record and their enrollment in one transaction.
  /// A coach is allowed to do it for their own complex's enquiries.
  ///
  /// Throws when the batch is full or the enquiry was already approved.
  Future<void> approveAndEnroll({
    required int id,
    CoachPaymentStatus? paymentStatus,
    num? amountPaid,
    String? notes,
  });

  // ---------------------------------------------------------------------------
  // Fees
  //
  // Already scoped to the coach's own batches by the backend. Approve, reject
  // and delete are absent on purpose — a coach gets a 403.
  // ---------------------------------------------------------------------------

  Future<CoachPaged<CoachFee>> getFees({
    int page = 1,
    int limit = 20,
    CoachPaymentStatus? paymentStatus,
    CoachApprovalStatus? approvalStatus,
    String? search,
    int? batchId,
  });

  Future<CoachFeeStats> getFeeStats();

  /// Records a payment against a fee record.
  ///
  /// ⚠️ Also resets the record's approval to `Pending` server-side — see
  /// [CoachPaymentDraft].
  Future<void> recordPayment({
    required int id,
    required CoachPaymentDraft draft,
  });

  /// Edits the record itself — the validity date and the notes, as opposed to
  /// the payment on it. [validTill] is `yyyy-MM-dd`.
  Future<void> updateFeeRecord({
    required int id,
    String? validTill,
    String? notes,
  });

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  /// The coach's own inbox, newest first.
  Future<CoachPaged<CoachNotification>> getNotifications({
    int page = 1,
    int limit = 20,
  });

  Future<int> getUnreadNotificationCount();

  Future<void> markNotificationRead(int id);

  Future<void> markAllNotificationsRead();

  /// Everyone a notification can be addressed to.
  Future<List<CoachNotificationRecipient>> getNotificationRecipients();

  /// Sends a notification.
  Future<void> sendNotification(CoachNotificationDraft draft);

  // ---------------------------------------------------------------------------
  // Gate pass
  // ---------------------------------------------------------------------------

  /// Scans a student gate pass.
  ///
  /// ⚠️ Side-effecting for a coach: it marks the student Present for today.
  /// See [CoachPassScan].
  Future<CoachPassScan> scanStudentPass(String passCode);

  // ---------------------------------------------------------------------------
  // Pickers
  // ---------------------------------------------------------------------------

  /// Students on this coach's roster, for a picker. Capped at 20 rows by the
  /// backend, so [search] is required to reach the rest.
  Future<List<CoachOption>> searchStudents({String? search});

  /// Sports the coach actually teaches, derived from their batches.
  Future<List<CoachOption>> searchSports({String? search});

  /// The coach's **Active** batches. Inactive batches are not offered.
  Future<List<CoachOption>> searchBatches({String? search});
}
