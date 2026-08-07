/// A student on the coach's roster.
///
/// From `GET /coach/dashboard/students/my-students`, which lists **enrollments**
/// rather than people: a student enrolled in two of the coach's batches comes
/// back twice, once per batch, with the same [id]. The list is therefore keyed
/// on `(id, batch)` in the UI, not on [id] alone.
class CoachStudent {
  const CoachStudent({
    required this.id,
    this.name = '',
    this.email = '',
    this.phone = '',
    this.batchName = '',
    this.enrollmentDate,
    this.statusRaw,
    this.attendanceRaw,
    this.performanceRaw,
  });

  /// The `Student` row id — what every other coach route expects as
  /// `studentId`.
  final int id;

  final String name;
  final String email;
  final String phone;

  /// The batch this enrollment is for. `"Not Assigned"` when the join carried
  /// no batch.
  final String batchName;

  final DateTime? enrollmentDate;

  /// The **enrollment** status (`Active`, `Dropped`, `Transferred`, …), not the
  /// student's account status.
  final String? statusRaw;

  /// Sent pre-formatted as a percentage string, e.g. `"85%"`, computed across
  /// this coach's batches only.
  final String? attendanceRaw;

  /// Sent pre-formatted, e.g. `"78%"`, or `"N/A"` when the student has never
  /// been assessed.
  final String? performanceRaw;

  String get displayName => name.trim().isEmpty ? 'Unknown' : name.trim();

  String get initial => displayName.substring(0, 1).toUpperCase();

  String get statusLabel => (statusRaw ?? '').trim();

  bool get isActive => statusLabel.toLowerCase() == 'active';

  String get attendanceLabel => (attendanceRaw ?? '').trim().isEmpty
      ? '—'
      : attendanceRaw!.trim();

  /// `"N/A"` is the API's own wording for "never assessed"; it is passed
  /// through rather than reworded so the app and the website agree.
  String get performanceLabel => (performanceRaw ?? '').trim().isEmpty
      ? 'N/A'
      : performanceRaw!.trim();

  bool get hasPerformance => performanceLabel.toUpperCase() != 'N/A';

  /// Attendance as a number, for sorting and for colouring the row. `null`
  /// when the string could not be read.
  int? get attendancePercent {
    final digits = RegExp(r'\d+').firstMatch(attendanceLabel)?.group(0);
    return digits == null ? null : int.tryParse(digits);
  }

  /// The contact line under the name, skipping whichever part is missing.
  String get contactLabel => [
        if (phone.trim().isNotEmpty) phone.trim(),
        if (email.trim().isNotEmpty) email.trim(),
      ].join(' · ');

  @override
  String toString() => 'CoachStudent($id, $name, $batchName)';
}
