/// One of the coach's batches, from `GET /coach/dashboard/schedule/batches`.
///
/// This is the closest thing the backend has to a timetable: there is no
/// per-session table, so "My Schedule" is the coach's batches with whatever
/// day and time text each one carries.
class CoachBatch {
  const CoachBatch({
    required this.id,
    this.name = '',
    this.sportName,
    this.schedule,
    this.days,
    this.court,
    this.studentCount = 0,
    this.maxStudents = 0,
    this.statusRaw,
    this.startDate,
    this.endDate,
    this.fees = 0,
  });

  final int id;
  final String name;

  /// `"N/A"` when the batch has no sport joined.
  final String? sportName;

  /// Free text as the admin typed it — e.g. `"5pm to 6pm"`. Not a pair of
  /// clock values, so it is shown rather than parsed.
  final String? schedule;

  /// Free text again — e.g. `"Mon, Wed, Fri"`.
  final String? days;

  /// Always `"TBD"`: the `Batch` model has no court column and the route
  /// hardcodes the placeholder. See [hasCourt].
  final String? court;

  final int studentCount;

  /// `0` when no cap was set, which is why [isFull] and [fillRatio] both treat
  /// zero as "no limit" rather than "no seats".
  final int maxStudents;

  final String? statusRaw;
  final DateTime? startDate;
  final DateTime? endDate;

  /// Monthly fee for the batch, in rupees.
  final num fees;

  String get displayName => name.trim().isEmpty ? 'Batch #$id' : name.trim();

  String get statusLabel => (statusRaw ?? '').trim();

  bool get isActive => statusLabel.toLowerCase() == 'active';

  /// Whether a court worth showing was assigned — `TBD` is a placeholder.
  bool get hasCourt {
    final value = (court ?? '').trim();
    return value.isNotEmpty && value.toUpperCase() != 'TBD';
  }

  /// `"12 / 20"`, or just the head count when the batch has no cap.
  String get capacityLabel =>
      maxStudents > 0 ? '$studentCount / $maxStudents' : '$studentCount';

  /// 0–1, or `null` when the batch is uncapped and a bar would be meaningless.
  double? get fillRatio {
    if (maxStudents <= 0) return null;
    return (studentCount / maxStudents).clamp(0.0, 1.0);
  }

  bool get isFull => maxStudents > 0 && studentCount >= maxStudents;

  /// `"Mon, Wed, Fri · 5pm to 6pm"`, skipping whichever part is missing.
  String get timingLabel => [
        if ((days ?? '').trim().isNotEmpty && (days ?? '').trim() != 'TBD')
          days!.trim(),
        if ((schedule ?? '').trim().isNotEmpty &&
            (schedule ?? '').trim() != 'TBD')
          schedule!.trim(),
      ].join(' · ');

  /// Whether today falls inside the batch's run. `null` when either end is
  /// missing — an open-ended batch is neither running nor finished.
  bool? get isRunningNow {
    final from = startDate;
    final to = endDate;
    if (from == null || to == null) return null;
    final now = DateTime.now();
    return !now.isBefore(from) && !now.isAfter(to);
  }

  @override
  String toString() => 'CoachBatch($id, $name, $statusLabel)';
}
