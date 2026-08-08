import '../../../../core/network/api_exception.dart';
import '../../core/coach_log.dart';
import '../../domain/entities/coach_attendance.dart';
import '../../domain/entities/coach_batch.dart';
import '../../domain/entities/coach_enquiry.dart';
import '../../domain/entities/coach_enrollment.dart';
import '../../domain/entities/coach_fee.dart';
import '../../domain/entities/coach_notification.dart';
import '../../domain/entities/coach_option.dart';
import '../../domain/entities/coach_overview.dart';
import '../../domain/entities/coach_paged.dart';
import '../../domain/entities/coach_pass_scan.dart';
import '../../domain/entities/coach_progress.dart';
import '../../domain/entities/coach_student.dart';
import '../../domain/repositories/coach_dashboard_repository.dart';
import '../datasources/coach_dashboard_remote_data_source.dart';
import '../models/coach_mappers.dart';

/// [CoachDashboardRepository] over the JWT backend.
///
/// Reads throw on failure; the controllers decide what a failure means for
/// their section. The one exception is [markAttendanceSheet], which is
/// deliberately partial-tolerant — see its doc on the interface.
class CoachDashboardRepositoryImpl implements CoachDashboardRepository {
  CoachDashboardRepositoryImpl({CoachDashboardRemoteDataSource? remote})
      : _remote = remote ?? CoachDashboardRemoteDataSource();

  final CoachDashboardRemoteDataSource _remote;

  // ---------------------------------------------------------------------------
  // Overview
  // ---------------------------------------------------------------------------

  @override
  Future<CoachDashboardStats> getStats() async {
    final response = await _remote.stats();
    if (!response.isOk) throw response.toException();

    final stats = CoachMappers.stats(response.data);
    CoachLog.data('Coach stats → $stats');
    return stats;
  }

  @override
  Future<List<CoachSession>> getTodaySchedule() async {
    final response = await _remote.todaySchedule();
    if (!response.isOk) throw response.toException();

    final rows = CoachMappers.rows(response.data);
    final sessions = rows
        .map(CoachMappers.session)
        .whereType<CoachSession>()
        .toList(growable: false);

    _warnIfDropped(rows.length, sessions.length, 'today\'s schedule', rows);
    CoachLog.data("Today's schedule → ${sessions.length} sessions");
    return sessions;
  }

  @override
  Future<List<CoachTopPerformer>> getTopPerformers() async {
    final response = await _remote.topPerformers();
    if (!response.isOk) throw response.toException();

    final rows = CoachMappers.rows(response.data);
    final performers = rows
        .map(CoachMappers.topPerformer)
        .whereType<CoachTopPerformer>()
        .toList(growable: false);

    _warnIfDropped(rows.length, performers.length, 'top performers', rows);
    CoachLog.data('Top performers → ${performers.length}');
    return performers;
  }

  // ---------------------------------------------------------------------------
  // Students
  // ---------------------------------------------------------------------------

  @override
  Future<CoachPaged<CoachStudent>> getStudents({
    int page = 1,
    int limit = 20,
    String? search,
    String? status,
  }) async {
    final response = await _remote.students(
      page: page,
      limit: limit,
      search: search,
      status: status,
    );
    if (!response.isOk) throw response.toException();

    final result = CoachMappers.pageOf<CoachStudent>(
      response.data,
      key: 'students',
      parse: CoachMappers.student,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    _warnIfDropped(
      CoachMappers.rowsAt(response.data, 'students').length,
      result.items.length,
      'my students',
      CoachMappers.rowsAt(response.data, 'students'),
    );
    CoachLog.data('My students → $result');
    return result;
  }

  @override
  Future<CoachEnrollmentMonthView> getEnrollmentsByMonth({
    String? month,
    String? search,
    String? status,
  }) async {
    final response = await _remote.enrollmentsByMonth(
      month: month,
      search: search,
      status: status,
    );
    if (!response.isOk) throw response.toException();

    final view = CoachMappers.enrollmentMonth(response.data);
    CoachLog.data('Enrollments by month → $view');
    return view;
  }

  // ---------------------------------------------------------------------------
  // Schedule
  // ---------------------------------------------------------------------------

  @override
  Future<CoachPaged<CoachBatch>> getBatches({
    int page = 1,
    int limit = 20,
    String? status,
    int? sportId,
  }) async {
    final response = await _remote.batches(
      page: page,
      limit: limit,
      status: status,
      sportId: sportId,
    );
    if (!response.isOk) throw response.toException();

    final result = CoachMappers.pageOf<CoachBatch>(
      response.data,
      key: 'batches',
      parse: CoachMappers.batch,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    _warnIfDropped(
      CoachMappers.rowsAt(response.data, 'batches').length,
      result.items.length,
      'my batches',
      CoachMappers.rowsAt(response.data, 'batches'),
    );
    CoachLog.data('My batches → $result');
    return result;
  }

  // ---------------------------------------------------------------------------
  // Progress
  // ---------------------------------------------------------------------------

  @override
  Future<CoachPaged<CoachProgress>> getProgress({
    int page = 1,
    int limit = 20,
    int? studentId,
    int? sportId,
  }) async {
    final response = await _remote.progress(
      page: page,
      limit: limit,
      studentId: studentId,
      sportId: sportId,
    );
    if (!response.isOk) throw response.toException();

    final result = CoachMappers.pageOf<CoachProgress>(
      response.data,
      key: 'progress',
      parse: CoachMappers.progress,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    CoachLog.data('Student progress → $result');
    return result;
  }

  @override
  Future<void> createProgress(CoachProgressDraft draft) async {
    // Refused here rather than by a 400, so the form can point at the field.
    if ((draft.studentId ?? 0) <= 0) {
      throw const ValidationException('Pick a student.');
    }
    if ((draft.sportId ?? 0) <= 0) {
      throw const ValidationException('Pick a sport.');
    }
    _assertScore(draft.fitnessScore, required: true);

    final response = await _remote.createProgress(draft.toCreateJson());
    if (!response.isOk) throw response.toException();

    CoachLog.success('Recorded progress for student ${draft.studentId}');
  }

  @override
  Future<void> updateProgress(int id, CoachProgressDraft draft) async {
    _assertScore(draft.fitnessScore, required: false);

    final body = draft.toUpdateJson();
    if (body.isEmpty) {
      throw const BadRequestException('Nothing to update.');
    }

    final response = await _remote.updateProgress(id, body);
    if (!response.isOk) throw response.toException();

    CoachLog.success('Updated progress record $id');
  }

  @override
  Future<void> deleteProgress(int id) async {
    final response = await _remote.deleteProgress(id);
    if (!response.isOk) throw response.toException();
    CoachLog.success('Deleted progress record $id');
  }

  /// The backend rejects anything outside 0–100 with a 400; checked here so
  /// the form says so without a round trip.
  static void _assertScore(num? score, {required bool required}) {
    if (score == null) {
      if (required) {
        throw const ValidationException('Enter a fitness score.');
      }
      return;
    }
    if (score < 0 || score > 100) {
      throw const ValidationException(
        'The fitness score must be between 0 and 100.',
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Attendance
  // ---------------------------------------------------------------------------

  @override
  Future<CoachPaged<CoachAttendanceRecord>> getAttendanceRecords({
    int page = 1,
    int limit = 20,
    String? date,
    String? status,
    int? batchId,
  }) async {
    final response = await _remote.attendanceRecords(
      page: page,
      limit: limit,
      date: date,
      status: status,
      batchId: batchId,
    );
    if (!response.isOk) throw response.toException();

    final result = CoachMappers.pageOf<CoachAttendanceRecord>(
      response.data,
      key: 'records',
      parse: CoachMappers.attendanceRecord,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    CoachLog.data('Attendance records → $result');
    return result;
  }

  @override
  Future<void> markAttendance(CoachAttendanceDraft draft) async {
    if (draft.studentId <= 0) {
      throw const ValidationException('Pick a student to mark.');
    }
    if (draft.batchId <= 0) {
      throw const ValidationException('Pick the batch this session is for.');
    }
    if (draft.date.trim().isEmpty) {
      throw const ValidationException('Pick the date to mark attendance for.');
    }

    final response = await _remote.markAttendance(draft.toJson());
    if (!response.isOk) throw response.toException();

    CoachLog.success('Marked ${draft.status.slug} → $draft');
  }

  @override
  Future<List<({CoachAttendanceDraft draft, String error})>>
      markAttendanceSheet(List<CoachAttendanceDraft> drafts) async {
    final failures = <({CoachAttendanceDraft draft, String error})>[];

    // Sent one at a time rather than concurrently: the backend upserts each
    // line, and a burst of parallel writes against the same batch/date has no
    // benefit worth the risk of the roster half-saving under a rate limit.
    for (final draft in drafts) {
      try {
        await markAttendance(draft);
      } on ApiException catch (e) {
        CoachLog.failure('Attendance line failed: $draft', error: e);
        failures.add((draft: draft, error: e.message));
      } catch (e) {
        CoachLog.failure('Attendance line failed: $draft', error: e);
        failures.add((draft: draft, error: 'Could not save this student.'));
      }
    }

    if (failures.isEmpty) {
      CoachLog.success('Attendance sheet saved — ${drafts.length} students');
    } else {
      CoachLog.failure(
        '${failures.length} of ${drafts.length} attendance lines failed',
      );
    }
    return failures;
  }

  // ---------------------------------------------------------------------------
  // Enquiries
  // ---------------------------------------------------------------------------

  @override
  Future<CoachPaged<CoachEnquiry>> getEnquiries({
    int page = 1,
    int limit = 20,
    CoachEnquiryStatus? status,
  }) async {
    final response = await _remote.enquiries(
      page: page,
      limit: limit,
      status: status?.slug,
    );
    if (!response.isOk) throw response.toException();

    final result = CoachMappers.pageOf<CoachEnquiry>(
      response.data,
      key: 'enquiries',
      parse: CoachMappers.enquiry,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    CoachLog.data('Coach enquiries → $result');
    return result;
  }

  @override
  Future<void> createEnquiry(CoachEnquiryDraft draft) async {
    // Refused here rather than by a 400, so the form can point at the field.
    if (draft.name.trim().isEmpty) {
      throw const ValidationException("Enter the student's name.");
    }
    if (draft.email.trim().isEmpty) {
      throw const ValidationException('Enter an email address.');
    }
    if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(draft.email.trim())) {
      throw const ValidationException('Enter a valid email address.');
    }
    if (draft.normalisedPhone.length != 10) {
      throw const ValidationException(
        'The phone number must be exactly 10 digits.',
      );
    }
    if (draft.batchId <= 0) {
      throw const ValidationException('Pick a batch.');
    }

    final response = await _remote.createEnquiry(draft.toJson());
    if (!response.isOk) throw response.toException();

    CoachLog.success('Logged coaching enquiry for ${draft.name}');
  }

  @override
  Future<void> updateEnquiryStatus({
    required int id,
    required CoachEnquiryStatus status,
  }) async {
    // `Approved` is admin-only. Caught here so the UI never offers an action
    // the server is guaranteed to refuse.
    if (!status.isCoachSettable) {
      throw ValidationException(
        'A coach cannot set an enquiry to ${status.slug}.',
      );
    }

    final response = await _remote.updateEnquiryStatus(id, status.slug);
    if (!response.isOk) throw response.toException();

    CoachLog.success('Enquiry $id → ${status.slug}');
  }

  @override
  Future<void> deleteEnquiry(int id) async {
    final response = await _remote.deleteEnquiry(id);
    if (!response.isOk) throw response.toException();
    CoachLog.success('Deleted enquiry $id');
  }

  @override
  Future<void> approveAndEnroll({
    required int id,
    CoachPaymentStatus? paymentStatus,
    num? amountPaid,
    String? notes,
  }) async {
    if (amountPaid != null && amountPaid < 0) {
      throw const ValidationException('The amount cannot be negative.');
    }

    final response = await _remote.approveAndEnroll(id, {
      // The backend defaults these, but sending them explicitly keeps the
      // enrollment's opening state the coach's choice rather than a default
      // they cannot see.
      'paymentStatus': (paymentStatus ?? CoachPaymentStatus.pending).slug,
      'amountPaid': amountPaid ?? 0,
      if ((notes ?? '').trim().isNotEmpty) 'notes': notes!.trim(),
    });
    if (!response.isOk) throw response.toException();

    CoachLog.success('Approved enquiry $id and enrolled the student');
  }

  // ---------------------------------------------------------------------------
  // Fees
  // ---------------------------------------------------------------------------

  @override
  Future<CoachPaged<CoachFee>> getFees({
    int page = 1,
    int limit = 20,
    CoachPaymentStatus? paymentStatus,
    CoachApprovalStatus? approvalStatus,
    String? search,
    int? batchId,
  }) async {
    final response = await _remote.fees(
      page: page,
      limit: limit,
      paymentStatus: paymentStatus?.slug,
      approvalStatus: approvalStatus?.slug,
      search: search,
      batchId: batchId,
    );
    if (!response.isOk) throw response.toException();

    final result = CoachMappers.pageOf<CoachFee>(
      response.data,
      key: 'fees',
      parse: CoachMappers.fee,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    _warnIfDropped(
      CoachMappers.rowsAt(response.data, 'fees').length,
      result.items.length,
      'fee records',
      CoachMappers.rowsAt(response.data, 'fees'),
    );
    CoachLog.data('Fees → $result');
    return result;
  }

  @override
  Future<CoachFeeStats> getFeeStats() async {
    final response = await _remote.feeStats();
    if (!response.isOk) throw response.toException();

    final stats = CoachMappers.feeStats(response.data);
    CoachLog.data('Fee stats → $stats');
    return stats;
  }

  @override
  Future<void> recordPayment({
    required int id,
    required CoachPaymentDraft draft,
  }) async {
    if (draft.isEmpty) {
      throw const BadRequestException('Nothing to record.');
    }
    if (draft.amountPaid != null && draft.amountPaid! < 0) {
      throw const ValidationException('The amount cannot be negative.');
    }

    final response = await _remote.recordPayment(id, draft.toJson());
    if (!response.isOk) throw response.toException();

    // Worth logging loudly: the record has just been pushed back into the
    // approval queue, whatever it was before.
    CoachLog.success(
      'Payment recorded on fee $id — approval reset to Pending',
    );
  }

  @override
  Future<void> updateFeeRecord({
    required int id,
    required CoachFeeEdit edit,
  }) async {
    if (edit.isEmpty) {
      throw const BadRequestException('Nothing to update.');
    }
    if (edit.amountPaid != null && edit.amountPaid! < 0) {
      throw const ValidationException('The amount cannot be negative.');
    }

    final response = await _remote.updateFee(id, edit.toJson());
    if (!response.isOk) throw response.toException();

    // Same reason the payment write logs loudly: a coach's edit pushes the
    // record back into the approval queue whatever it was before.
    CoachLog.success(
      'Updated fee record $id — approval reset to Pending',
    );
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  @override
  Future<CoachPaged<CoachNotification>> getNotifications({
    int page = 1,
    int limit = 20,
  }) async {
    final response = await _remote.notifications(page: page, limit: limit);
    if (!response.isOk) throw response.toException();

    final result = CoachMappers.notificationPage(
      response.data,
      fallbackPage: page,
      fallbackLimit: limit,
    );

    CoachLog.data('Notifications → $result');
    return result;
  }

  @override
  Future<int> getUnreadNotificationCount() async {
    final response = await _remote.unreadCount();
    if (!response.isOk) throw response.toException();

    // The route answers `{success, data: {count}}` in the common case, but a
    // bare `{success, count}` has been seen too — both are read.
    final payload = response.payload;
    final count = payload['count'] ?? payload['unreadCount'] ?? payload['data'];
    return int.tryParse(count?.toString() ?? '') ?? 0;
  }

  @override
  Future<void> markNotificationRead(int id) async {
    final response = await _remote.markNotificationRead(id);
    if (!response.isOk) throw response.toException();
    CoachLog.success('Notification $id read');
  }

  @override
  Future<void> markAllNotificationsRead() async {
    final response = await _remote.markAllNotificationsRead();
    if (!response.isOk) throw response.toException();
    CoachLog.success('All notifications read');
  }

  @override
  Future<List<CoachNotificationRecipient>> getNotificationRecipients() async {
    final response = await _remote.notificationRecipients();
    if (!response.isOk) throw response.toException();

    final recipients = CoachMappers.rows(response.data)
        .map(CoachMappers.recipient)
        .whereType<CoachNotificationRecipient>()
        .toList(growable: false);

    CoachLog.data('Notification recipients → ${recipients.length}');
    return recipients;
  }

  @override
  Future<void> sendNotification(CoachNotificationDraft draft) async {
    if (draft.title.trim().isEmpty) {
      throw const ValidationException('Enter a title.');
    }
    if (draft.message.trim().isEmpty) {
      throw const ValidationException('Enter a message.');
    }
    if (!draft.isBroadcast && draft.userIds.isEmpty) {
      throw const ValidationException('Pick at least one recipient.');
    }

    final response = await _remote.sendNotification(draft.toJson());
    if (!response.isOk) throw response.toException();

    CoachLog.success(
      'Sent notification "${draft.title}" to '
      '${draft.isBroadcast ? 'everyone' : '${draft.userIds.length} recipients'}',
    );
  }

  // ---------------------------------------------------------------------------
  // Gate pass
  // ---------------------------------------------------------------------------

  @override
  Future<CoachPassScan> scanStudentPass(String passCode) async {
    final code = passCode.trim();
    if (code.isEmpty) {
      throw const ValidationException('Scan or enter a pass code.');
    }

    final response = await _remote.scanPass(code);
    if (!response.isOk) throw response.toException();

    // The backend's own sentence is preferred over anything composed here, so
    // the app and the gate terminal say the same thing.
    final scan = CoachMappers.passScan(
      response.data,
      message: response.message,
    );
    CoachLog.success('Pass scan → $scan');
    return scan;
  }

  // ---------------------------------------------------------------------------
  // Pickers
  // ---------------------------------------------------------------------------

  @override
  Future<List<CoachOption>> searchStudents({String? search}) async {
    final response = await _remote.autocompleteStudents(search: search);
    if (!response.isOk) throw response.toException();

    final options = CoachMappers.options(response.data);
    CoachLog.data('Student options → ${options.length}');
    return options;
  }

  @override
  Future<List<CoachOption>> searchSports({String? search}) async {
    final response = await _remote.autocompleteSports(search: search);
    if (!response.isOk) throw response.toException();

    final options = CoachMappers.options(response.data);
    CoachLog.data('Sport options → ${options.length}');
    return options;
  }

  @override
  Future<List<CoachOption>> searchBatches({String? search}) async {
    final response = await _remote.autocompleteBatches(search: search);
    if (!response.isOk) throw response.toException();

    final options = CoachMappers.options(response.data);
    CoachLog.data('Batch options → ${options.length}');
    return options;
  }

  // ---------------------------------------------------------------------------
  // Diagnostics
  // ---------------------------------------------------------------------------

  /// Says in the log when rows arrived but none survived mapping — the one
  /// failure that otherwise looks identical to "there is nothing here".
  static void _warnIfDropped(
    int received,
    int parsed,
    String what,
    List<Map<String, dynamic>> rows,
  ) {
    if (received == 0 || parsed > 0) return;
    CoachLog.failure(
      '$received rows were returned for $what but none carried a readable id, '
      'so all were dropped. Row keys: ${rows.first.keys.toList()}',
    );
  }
}
