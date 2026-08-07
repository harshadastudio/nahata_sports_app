import 'employee_formats.dart';

/// One attendance record, from `GET /attendance`.
///
/// **Read-only for an employee by design.** Attendance is marked by the coach
/// who runs the batch, and at the gate when a student pass is scanned — the
/// website's employee screen deliberately drops the Mark Attendance button for
/// the same reason. The POST route does grant EMPLOYEE, but a second person
/// marking the same `(student, batch, date)` upserts over the coach's record,
/// so the app does not offer it either.
class EmployeeAttendanceRecord {
  const EmployeeAttendanceRecord({
    required this.id,
    this.studentName = '',
    this.studentEmail = '',
    this.batchName = '',
    this.sportName = '',
    this.date,
    this.status = '',
    this.markedBy = '',
    this.markedByRole = '',
    this.notes,
  });

  final int id;
  final String studentName;
  final String studentEmail;
  final String batchName;
  final String sportName;

  final DateTime? date;

  /// `Present` | `Absent` | `Late`.
  final String status;

  final String markedBy;
  final String markedByRole;
  final String? notes;

  String get displayName =>
      studentName.trim().isEmpty ? 'Student #$id' : studentName.trim();

  String get initial =>
      displayName.trim().isEmpty ? '?' : displayName.trim()[0].toUpperCase();

  /// `Badminton / Morning Batch`, collapsing to whichever half exists.
  String get sportBatchLabel {
    final sport = sportName.trim();
    final batch = batchName.trim();
    if (sport.isEmpty && batch.isEmpty) return '—';
    if (batch.isEmpty) return sport;
    if (sport.isEmpty) return batch;
    return '$sport / $batch';
  }

  String get dateLabel => formatDay(date);

  String get markedByLabel => markedBy.trim().isEmpty ? '—' : markedBy.trim();

  @override
  String toString() => 'EmployeeAttendanceRecord($id, $displayName, $status)';
}
