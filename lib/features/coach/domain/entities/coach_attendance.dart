/// Attendance entities for the coach's attendance sheet.
///
/// Reads come from `GET /coach/dashboard/attendance/records`, which is scoped
/// to the coach's own batches. Writes go to `POST /attendance`, which is shared
/// with admin and employee.
///
/// ⚠️ Do **not** read the roster from `GET /attendance`: for a caller with the
/// `COACH` role the backend applies no complex scoping at all, so that route
/// returns every coach's records. Only the `/coach/dashboard` read is safe.
library;

/// The four states the backend accepts. Sent capitalised exactly as spelled
/// here — `markAttendance` validates against this vocabulary and rejects
/// anything else with a 400.
enum CoachAttendanceStatus {
  present('Present'),
  absent('Absent'),
  late('Late'),
  leave('Leave');

  const CoachAttendanceStatus(this.slug);

  /// The wire value. Case matters.
  final String slug;

  String get label => slug;

  /// Parses a value from the API, tolerating casing drift. Falls back to
  /// [present] only when the text is empty; an unrecognised value returns null
  /// so the UI can show it verbatim rather than silently mislabel a record.
  static CoachAttendanceStatus? tryParse(String? value) {
    final text = (value ?? '').trim().toLowerCase();
    if (text.isEmpty) return null;
    for (final status in CoachAttendanceStatus.values) {
      if (status.slug.toLowerCase() == text) return status;
    }
    return null;
  }
}

/// One already-marked attendance record.
class CoachAttendanceRecord {
  const CoachAttendanceRecord({
    required this.id,
    this.studentName = '',
    this.studentEmail = '',
    this.batchName = '',
    this.date,
    this.statusRaw,
    this.markedBy,
    this.markedAt,
  });

  final int id;
  final String studentName;
  final String studentEmail;

  /// `"N/A"` when the join carried no batch.
  final String batchName;

  /// The date the attendance is *for*, not when it was recorded.
  final DateTime? date;

  final String? statusRaw;

  /// The coach's own name — the API fills this in from the authenticated
  /// coach rather than from the record's `markedBy` user, so it says who is
  /// *looking*, not necessarily who marked it.
  final String? markedBy;

  /// When the row was created.
  final DateTime? markedAt;

  CoachAttendanceStatus? get status =>
      CoachAttendanceStatus.tryParse(statusRaw);

  bool get isPresent => status == CoachAttendanceStatus.present;

  /// Falls back to the raw string so an unmapped status is still shown.
  String get statusLabel => status?.label ?? (statusRaw ?? '').trim();

  String get displayName =>
      studentName.trim().isEmpty ? 'Unknown' : studentName.trim();

  String get initial => displayName.substring(0, 1).toUpperCase();

  /// `yyyy-MM-dd`, for grouping rows by day.
  String get dateKey {
    final value = date;
    if (value == null) return '';
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  @override
  String toString() =>
      'CoachAttendanceRecord($id, $studentName, $dateKey, $statusLabel)';
}

/// One line of the mark-attendance sheet, ready to be sent.
///
/// `POST /attendance` upserts on `(studentId, batchId, date)`, so re-sending a
/// line corrects the earlier mark rather than creating a duplicate — which is
/// what lets the sheet be saved more than once.
class CoachAttendanceDraft {
  const CoachAttendanceDraft({
    required this.studentId,
    required this.batchId,
    required this.date,
    required this.status,
    this.checkInTime,
    this.notes,
  });

  final int studentId;
  final int batchId;

  /// `yyyy-MM-dd`.
  final String date;

  final CoachAttendanceStatus status;

  /// `HH:mm:ss`. Optional — the backend keeps the existing value when this is
  /// null on an update.
  final String? checkInTime;

  final String? notes;

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'batchId': batchId,
        'date': date,
        'status': status.slug,
        if (checkInTime != null && checkInTime!.trim().isNotEmpty)
          'checkInTime': checkInTime!.trim(),
        if (notes != null && notes!.trim().isNotEmpty) 'notes': notes!.trim(),
      };

  CoachAttendanceDraft copyWith({
    CoachAttendanceStatus? status,
    String? checkInTime,
    String? notes,
  }) {
    return CoachAttendanceDraft(
      studentId: studentId,
      batchId: batchId,
      date: date,
      status: status ?? this.status,
      checkInTime: checkInTime ?? this.checkInTime,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() =>
      'CoachAttendanceDraft(student: $studentId, batch: $batchId, $date, '
      '${status.slug})';
}
