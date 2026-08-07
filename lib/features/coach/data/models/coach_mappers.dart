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

/// JSON → entity for the coach dashboard.
///
/// Every reader here tolerates a null, a wrong type and a missing key: the
/// dashboard is read-mostly and a single odd row must never take a page down.
/// Rows that carry no usable id are dropped rather than surfaced as `#0`, and
/// the repository logs when that happens.
class CoachMappers {
  const CoachMappers._();

  // ---------------------------------------------------------------------------
  // Envelopes
  // ---------------------------------------------------------------------------

  /// The `data` object of a `{success, data: {...}}` body, or the body itself
  /// when the server did not wrap it.
  static Map<String, dynamic> envelope(Object? body) {
    if (body is! Map) return const {};
    final inner = body['data'];
    if (inner is Map) return Map<String, dynamic>.from(inner);
    return Map<String, dynamic>.from(body);
  }

  /// The row array of a `{success, data: [...]}` body — the shape the schedule,
  /// top-performer and autocomplete routes use.
  static List<Map<String, dynamic>> rows(Object? body) {
    if (body is List) return _objects(body);
    if (body is Map) {
      final inner = body['data'];
      if (inner is List) return _objects(inner);
    }
    return const [];
  }

  /// The row array nested under [key] inside the `data` envelope — the shape
  /// every paginated coach route uses (`students`, `records`, `progress`,
  /// `batches`, `enquiries`).
  static List<Map<String, dynamic>> rowsAt(Object? body, String key) {
    final data = envelope(body);
    final list = data[key];
    return list is List ? _objects(list) : const [];
  }

  /// Builds a page from the `{<key>, total, page, limit, totalPages}` envelope.
  ///
  /// [fallbackPage] and [fallbackLimit] are what was *asked for*: the backend
  /// echoes both, but a route that omits them must not reset the pager to
  /// page 1.
  static CoachPaged<T> pageOf<T>(
    Object? body, {
    required String key,
    required T? Function(Map<String, dynamic>) parse,
    required int fallbackPage,
    required int fallbackLimit,
  }) {
    final data = envelope(body);
    final items = rowsAt(body, key)
        .map(parse)
        .whereType<T>()
        .toList(growable: false);

    final page = _int(data['page']);
    final limit = _int(data['limit']);

    return CoachPaged<T>(
      items: items,
      page: page > 0 ? page : fallbackPage,
      limit: limit > 0 ? limit : fallbackLimit,
      total: _int(data['total']),
      totalPages: _int(data['totalPages'] ?? data['total_pages']),
    );
  }

  // ---------------------------------------------------------------------------
  // Overview
  // ---------------------------------------------------------------------------

  static CoachDashboardStats stats(Object? body) {
    final json = envelope(body);
    return CoachDashboardStats(
      totalStudents: _int(json['totalStudents']),
      presentToday: _int(json['presentToday']),
      sessionsToday: _int(json['sessionsToday']),
      avgPerformance: _num(json['avgPerformance']),
      totalBatches: _int(json['totalBatches']),
      activeEnquiries: _int(json['activeEnquiries']),
    );
  }

  static CoachSession? session(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    final sport = json['sport'];
    final sportMap = sport is Map ? Map<String, dynamic>.from(sport) : null;

    return CoachSession(
      id: id,
      batchName: _string(json['batchName']) ?? '',
      startTime: _string(json['startTime']),
      endTime: _string(json['endTime']),
      court: _string(json['court']),
      statusRaw: _string(json['status']),
      studentCount: _int(json['studentCount']),
      sportId: _intOrNull(sportMap?['id']),
      sportName: _string(sportMap?['name']),
    );
  }

  /// The row's `id` is the **student** id. Two assessments for one student
  /// would collide, but the backend caps this list at five rows ordered by
  /// score, so that is not worth de-duplicating here.
  static CoachTopPerformer? topPerformer(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    return CoachTopPerformer(
      id: id,
      name: _string(json['name']) ?? '',
      score: _num(json['performance']),
      detail: _string(json['detail']),
      sportName: _string(json['sport']),
      colorKey: _string(json['color']),
    );
  }

  // ---------------------------------------------------------------------------
  // Students
  // ---------------------------------------------------------------------------

  static CoachStudent? student(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    return CoachStudent(
      id: id,
      name: _string(json['name']) ?? '',
      email: _string(json['email']) ?? '',
      phone: _string(json['phone']) ?? '',
      batchName: _string(json['batch']) ?? _string(json['program']) ?? '',
      enrollmentDate: _date(json['enrollmentDate']),
      statusRaw: _string(json['status']),
      attendanceRaw: _string(json['attendance']),
      performanceRaw: _string(json['performance']),
    );
  }

  // ---------------------------------------------------------------------------
  // Attendance
  // ---------------------------------------------------------------------------

  static CoachAttendanceRecord? attendanceRecord(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    // The coach-scoped route sends flat fields; `POST /attendance` echoes the
    // full Sequelize row instead, with the names nested. Both are read so a
    // write response can refresh a row without a re-fetch.
    final student = json['student'];
    final studentMap =
        student is Map ? Map<String, dynamic>.from(student) : const {};
    final user = studentMap['User'];
    final userMap = user is Map ? Map<String, dynamic>.from(user) : const {};
    final batch = json['batch'];
    final batchMap = batch is Map ? Map<String, dynamic>.from(batch) : const {};

    return CoachAttendanceRecord(
      id: id,
      studentName:
          _string(json['studentName']) ?? _string(userMap['name']) ?? '',
      studentEmail:
          _string(json['studentEmail']) ?? _string(userMap['email']) ?? '',
      batchName: _string(json['batchName']) ?? _string(batchMap['name']) ?? '',
      date: _date(json['date']),
      statusRaw: _string(json['status']),
      markedBy: _string(json['markedBy']),
      markedAt: _date(json['markedAt'] ?? json['createdAt']),
    );
  }

  // ---------------------------------------------------------------------------
  // Schedule
  // ---------------------------------------------------------------------------

  /// `sport` arrives already flattened to a string on this route, unlike the
  /// nested `{id, name}` the overview's schedule sends.
  static CoachBatch? batch(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    return CoachBatch(
      id: id,
      name: _string(json['name']) ?? '',
      sportName: _string(json['sport']),
      schedule: _string(json['schedule']),
      days: _string(json['days']),
      court: _string(json['court']),
      studentCount: _int(json['studentCount']),
      maxStudents: _int(json['maxStudents']),
      statusRaw: _string(json['status']),
      startDate: _date(json['startDate']),
      endDate: _date(json['endDate']),
      fees: _num(json['fees']),
    );
  }

  // ---------------------------------------------------------------------------
  // Progress
  // ---------------------------------------------------------------------------

  /// `id` here is the **performance record** id, which the edit and delete
  /// routes take; the student is under `studentId`.
  static CoachProgress? progress(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    return CoachProgress(
      id: id,
      studentId: _int(json['studentId']),
      sportId: _int(json['sportId']),
      studentName: _string(json['studentName']) ?? '',
      sportName: _string(json['sport']),
      batchName: _string(json['program']),
      currentScore: _num(json['currentScore']),
      skillLevelRaw: _string(json['skillLevel']),
      previousScore: _numOrNull(json['previousScore']),
      improvementRaw: _string(json['improvement']),
      lastUpdated: _date(json['lastUpdated']),
      notes: _string(json['notes']),
    );
  }

  // ---------------------------------------------------------------------------
  // Enrollments by month
  // ---------------------------------------------------------------------------

  /// The whole month view. Unlike the paginated routes this answers one
  /// object, so it is read straight off the `data` envelope.
  static CoachEnrollmentMonthView enrollmentMonth(Object? body) {
    final data = envelope(body);

    final months = _objectsAt(data['months'])
        .map(_enrollmentMonth)
        .whereType<CoachEnrollmentMonth>()
        .toList(growable: false);

    final batches = _objectsAt(data['batches'])
        .map(_enrollmentGroup)
        .whereType<CoachEnrollmentGroup>()
        .toList(growable: false);

    return CoachEnrollmentMonthView(
      month: _string(data['month']) ?? '',
      label: _string(data['label']) ?? '',
      months: months,
      summary: _enrollmentSummary(data['summary']),
      batches: batches,
    );
  }

  static CoachEnrollmentMonth? _enrollmentMonth(Map<String, dynamic> json) {
    final month = _string(json['month']);
    // Keyed on the month string, so a row without one is unusable.
    if (month == null) return null;

    return CoachEnrollmentMonth(
      month: month,
      label: _string(json['label']) ?? '',
      count: _int(json['count']),
    );
  }

  static CoachEnrollmentSummary _enrollmentSummary(Object? value) {
    if (value is! Map) return CoachEnrollmentSummary.empty;
    final json = Map<String, dynamic>.from(value);

    return CoachEnrollmentSummary(
      totalStudents: _int(json['totalStudents']),
      totalBatches: _int(json['totalBatches']),
      newThisMonth: _int(json['newThisMonth']),
      continuing: _int(json['continuing']),
      expiring: _int(json['expiring']),
      active: _int(json['active']),
      paid: _int(json['paid']),
      pending: _int(json['pending']),
    );
  }

  static CoachEnrollmentGroup? _enrollmentGroup(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    final students = _objectsAt(json['students'])
        .map(_enrollment)
        .whereType<CoachEnrollment>()
        .toList(growable: false);

    return CoachEnrollmentGroup(
      batchId: id,
      name: _string(json['name']) ?? '',
      sportName: _string(json['sport']),
      schedule: _string(json['schedule']),
      days: _string(json['days']),
      startTime: _string(json['startTime']),
      endTime: _string(json['endTime']),
      batchStatusRaw: _string(json['batchStatus']),
      fees: _numOrNull(json['fees']),
      maxStudents: _intOrNull(json['maxStudents']),
      students: students,
      // Trusts the API's own count for the header, but falls back to what was
      // actually parsed so a dropped row cannot make the two disagree.
      count: _int(json['count']) > 0 ? _int(json['count']) : students.length,
      newCount: _int(json['newCount']),
    );
  }

  /// Keyed on `enrollmentId` (the `StudentBatches` row), not on the student —
  /// one student can hold two enrollments in the same batch over time.
  static CoachEnrollment? _enrollment(Map<String, dynamic> json) {
    final id = _int(json['enrollmentId']);
    if (id <= 0) return null;

    return CoachEnrollment(
      enrollmentId: id,
      studentId: _int(json['id']),
      name: _string(json['name']) ?? '',
      email: _string(json['email']) ?? '',
      phone: _string(json['phone']) ?? '',
      enrollmentDate: _string(json['enrollmentDate']),
      validTill: _string(json['validTill']),
      validTillSource: _string(json['validTillSource']),
      isNew: _bool(json['isNew']),
      expiring: _bool(json['expiring']),
      statusRaw: _string(json['status']),
      paymentStatusRaw: _string(json['paymentStatus']),
      approvalStatusRaw: _string(json['approvalStatus']),
      amountPaid: _num(json['amountPaid']),
      feesPaid: _bool(json['feesPaid']),
    );
  }

  // ---------------------------------------------------------------------------
  // Enquiries
  // ---------------------------------------------------------------------------

  /// Unlike the other coach routes, this one returns raw Sequelize rows: the
  /// sport and batch names arrive nested under `sport` / `batch` rather than
  /// flattened, and `name`/`email`/`phone` are the **enquiry's own** columns,
  /// not the joined `user`.
  static CoachEnquiry? enquiry(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    final sport = json['sport'];
    final sportMap = sport is Map ? Map<String, dynamic>.from(sport) : const {};
    final batch = json['batch'];
    final batchMap = batch is Map ? Map<String, dynamic>.from(batch) : const {};

    return CoachEnquiry(
      id: id,
      referenceNumber: _string(json['referenceNumber']),
      name: _string(json['name']) ?? '',
      email: _string(json['email']) ?? '',
      phone: _string(json['phone']) ?? '',
      message: _string(json['message']),
      statusRaw: _string(json['status']),
      sportName: _string(sportMap['name']),
      batchName: _string(batchMap['name']),
      createdAt: _date(json['createdAt']),
    );
  }

  // ---------------------------------------------------------------------------
  // Fees
  // ---------------------------------------------------------------------------

  /// A fee record is a raw `StudentBatches` Sequelize row: the student's name
  /// sits two levels down under `student.User`, and the batch carries the fee
  /// this payment is measured against.
  static CoachFee? fee(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    final student = json['student'];
    final studentMap =
        student is Map ? Map<String, dynamic>.from(student) : const {};
    final user = studentMap['User'];
    final userMap = user is Map ? Map<String, dynamic>.from(user) : const {};

    final batch = json['batch'];
    final batchMap = batch is Map ? Map<String, dynamic>.from(batch) : const {};
    final sport = batchMap['sport'];
    final sportMap = sport is Map ? Map<String, dynamic>.from(sport) : const {};

    return CoachFee(
      id: id,
      studentId: _int(json['studentId'] ?? studentMap['id']),
      studentName: _string(userMap['name']) ?? '',
      studentPhone: _string(userMap['phone_number']) ?? '',
      batchId: _int(json['batchId'] ?? batchMap['id']),
      batchName: _string(batchMap['name']) ?? '',
      sportName: _string(sportMap['name']),
      enrollmentDate: _string(json['enrollmentDate']),
      validTill: _string(json['validTill']),
      enrollmentStatusRaw: _string(json['status']),
      paymentStatusRaw: _string(json['paymentStatus']),
      approvalStatusRaw: _string(json['approvalStatus']),
      paymentModeRaw: _string(json['paymentMode']),
      amountPaid: _num(json['amountPaid']),
      batchFees: _numOrNull(batchMap['fees']),
      notes: _string(json['notes']),
      approvedAt: _date(json['approvedAt']),
    );
  }

  static CoachFeeStats feeStats(Object? body) {
    final json = envelope(body);
    return CoachFeeStats(
      total: _int(json['total']),
      paid: _int(json['paid']),
      unpaid: _int(json['unpaid']),
      overdue: _int(json['overdue']),
      pendingApproval: _int(json['pendingApproval']),
    );
  }

  // ---------------------------------------------------------------------------
  // Notifications
  // ---------------------------------------------------------------------------

  static CoachNotification? notification(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    return CoachNotification(
      id: id,
      title: _string(json['title']) ?? '',
      message: _string(json['message']) ?? '',
      typeRaw: _string(json['type']),
      isRead: _bool(json['isRead']),
      actionUrl: _string(json['actionUrl']),
      sentAt: _date(json['sentAt'] ?? json['createdAt']),
    );
  }

  static CoachNotificationRecipient? recipient(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;

    return CoachNotificationRecipient(
      id: id,
      name: _string(json['name']) ?? '',
      email: _string(json['email']) ?? '',
      role: _string(json['role']),
    );
  }

  /// The notification routes answer `{success, data: [...], pagination: {...}}`
  /// — the rows sit directly under `data`, and the meta block is called
  /// `pagination` rather than being folded in beside them like every other
  /// coach route.
  static CoachPaged<CoachNotification> notificationPage(
    Object? body, {
    required int fallbackPage,
    required int fallbackLimit,
  }) {
    final items = rows(body)
        .map(notification)
        .whereType<CoachNotification>()
        .toList(growable: false);

    final meta = body is Map ? body['pagination'] : null;
    final metaMap = meta is Map ? Map<String, dynamic>.from(meta) : const {};

    final page = _int(metaMap['currentPage']);
    final totalPages = _int(metaMap['totalPages']);

    return CoachPaged<CoachNotification>(
      items: items,
      page: page > 0 ? page : fallbackPage,
      limit: fallbackLimit,
      total: _int(metaMap['totalItems']),
      totalPages: totalPages,
    );
  }

  // ---------------------------------------------------------------------------
  // Gate pass
  // ---------------------------------------------------------------------------

  /// [message] comes off the *top level* of the body, not out of `data`, so it
  /// is passed in separately by the repository.
  static CoachPassScan passScan(Object? body, {String? message}) {
    final json = envelope(body);
    final student = json['student'];
    final studentMap =
        student is Map ? Map<String, dynamic>.from(student) : const {};

    return CoachPassScan(
      passCode: _string(json['passCode']) ?? '',
      outcomeRaw: _string(json['attendanceState']),
      message: message,
      date: _string(json['date']),
      checkInTime: _string(json['checkInTime']),
      studentName: _string(studentMap['name']) ?? '',
      studentPhone: _string(studentMap['phone']) ?? '',
      bloodGroup: _string(studentMap['bloodGroup']) ?? '',
      dob: _string(studentMap['dob']),
      avatar: _string(studentMap['avatar']),
      batchName: _string(json['batchName']) ?? '',
      sportName: _string(json['sportName']) ?? '',
      sportImage: _string(json['sportImage']),
      coachName: _string(json['coachName']) ?? '',
      batchDays: _string(json['batchDays']) ?? '',
      startTime: _string(json['startTime']) ?? '',
      endTime: _string(json['endTime']) ?? '',
    );
  }

  // ---------------------------------------------------------------------------
  // Autocomplete
  // ---------------------------------------------------------------------------

  static CoachOption? option(Map<String, dynamic> json) {
    final id = _int(json['id']);
    if (id <= 0) return null;
    return CoachOption(id: id, name: _string(json['name']) ?? '');
  }

  static List<CoachOption> options(Object? body) =>
      rows(body).map(option).whereType<CoachOption>().toList(growable: false);

  // ---------------------------------------------------------------------------
  // Primitives
  // ---------------------------------------------------------------------------

  static List<Map<String, dynamic>> _objects(List<dynamic> list) => list
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: false);

  /// [_objects] for a value that may not be a list at all — the nested arrays
  /// inside the enrollments response, where a missing key is normal.
  static List<Map<String, dynamic>> _objectsAt(Object? value) =>
      value is List ? _objects(value) : const <Map<String, dynamic>>[];

  static int _int(Object? value) => _intOrNull(value) ?? 0;

  static int? _intOrNull(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString().trim() ?? '');
  }

  static num _num(Object? value) => _numOrNull(value) ?? 0;

  /// Kept apart from [_num] where zero and "absent" mean different things —
  /// a batch fee of ₹0 is not the same as a batch with no fee set.
  static num? _numOrNull(Object? value) {
    if (value is num) return value;
    return num.tryParse(value?.toString().trim() ?? '');
  }

  /// Tolerates the `1` / `"true"` spellings a JSON boolean can arrive as when
  /// it has been through a database driver.
  static bool _bool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().trim().toLowerCase();
    return text == 'true' || text == '1';
  }

  /// Trims, and treats the literal strings `"null"` and `""` as absent — both
  /// appear in these responses where a join found nothing.
  static String? _string(Object? value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty || text == 'null') return null;
    return text;
  }

  /// Reads a `DATEONLY` (`"2026-08-06"`) or a full ISO timestamp. Returns null
  /// rather than a fallback date so the UI can tell "no date" apart from
  /// "the epoch".
  static DateTime? _date(Object? value) {
    if (value is DateTime) return value;
    final text = _string(value);
    if (text == null) return null;
    return DateTime.tryParse(text);
  }
}
