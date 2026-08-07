/// Entities behind the coach's Dashboard Overview.
///
/// Sources:
/// * `GET /coach/dashboard/stats`
/// * `GET /coach/dashboard/schedule/today`
/// * `GET /coach/dashboard/students/top-performers`
library;

/// The six headline numbers on the overview.
class CoachDashboardStats {
  const CoachDashboardStats({
    this.totalStudents = 0,
    this.presentToday = 0,
    this.sessionsToday = 0,
    this.avgPerformance = 0,
    this.totalBatches = 0,
    this.activeEnquiries = 0,
  });

  /// Distinct students across every batch this coach runs.
  final int totalStudents;

  /// Attendance rows marked `Present` today, across the coach's batches.
  final int presentToday;

  /// Counts the coach's **Active batches**, not sessions actually timetabled
  /// for today — the backend has no per-day session table, so a batch that
  /// does not meet today is still counted here.
  final int sessionsToday;

  /// Mean `fitnessScore` across the coach's own students, 0–100. May be
  /// fractional; the API rounds to one decimal.
  final num avgPerformance;

  final int totalBatches;

  /// Enquiries assigned to this coach still in `Pending`, `Reviewed` or
  /// `Contacted`.
  final int activeEnquiries;

  static const CoachDashboardStats empty = CoachDashboardStats();

  /// `0` → `0%`, `82.5` → `83%`.
  String get performanceLabel => '${avgPerformance.round()}%';

  /// Today's attendance as a fraction of the roster, e.g. `3/12`.
  String get attendanceLabel => '$presentToday/$totalStudents';

  /// Whether every counter is zero — a brand-new coach with nothing assigned,
  /// which the UI explains rather than showing six zeroes.
  bool get isEmpty =>
      totalStudents == 0 &&
      presentToday == 0 &&
      sessionsToday == 0 &&
      avgPerformance == 0 &&
      totalBatches == 0 &&
      activeEnquiries == 0;

  @override
  String toString() =>
      'CoachDashboardStats(students: $totalStudents, present: $presentToday, '
      'batches: $totalBatches, enquiries: $activeEnquiries)';
}

/// One row of today's schedule.
class CoachSession {
  const CoachSession({
    required this.id,
    this.batchName = '',
    this.startTime,
    this.endTime,
    this.court,
    this.statusRaw,
    this.studentCount = 0,
    this.sportId,
    this.sportName,
  });

  final int id;
  final String batchName;

  /// The API echoes the batch's free-text `schedule` column into **both**
  /// fields (`"5pm to 6pm"` in each) rather than sending two clock values.
  /// Read [timeLabel]; never concatenate these two directly.
  final String? startTime;
  final String? endTime;

  /// `"TBD"` whenever no court has been assigned — the `Batch` model has no
  /// court column, so this is currently always `TBD`. See [hasCourt].
  final String? court;

  /// The **batch** status (`Active`, `Inactive`, …), not a session lifecycle.
  /// The backend has a `determineSessionStatus` helper for In Progress /
  /// Upcoming / Completed but does not apply it to this route.
  final String? statusRaw;

  final int studentCount;
  final int? sportId;
  final String? sportName;

  bool get isActive => (statusRaw ?? '').toLowerCase() == 'active';

  String get statusLabel => (statusRaw ?? '').trim();

  /// `"5pm to 6pm"` when both fields carry the same text, `"6:00 - 7:00"` if
  /// the backend starts sending real clock values, and whichever one is
  /// present when the other is missing.
  String get timeLabel {
    final from = (startTime ?? '').trim();
    final to = (endTime ?? '').trim();
    if (from.isEmpty) return to;
    if (to.isEmpty || to == from) return from;
    return '$from - $to';
  }

  /// `"1 student"` / `"4 students"`.
  String get studentLabel =>
      '$studentCount student${studentCount == 1 ? '' : 's'}';

  /// Whether a court worth showing was assigned — `TBD` is a placeholder, not
  /// a venue.
  bool get hasCourt {
    final value = (court ?? '').trim();
    return value.isNotEmpty && value.toUpperCase() != 'TBD';
  }

  String get displayName => batchName.trim().isEmpty ? 'Session' : batchName;

  @override
  String toString() => 'CoachSession($id, $batchName, $timeLabel)';
}

/// One row of the top-performers list (the five highest `fitnessScore`s among
/// the coach's own students).
class CoachTopPerformer {
  const CoachTopPerformer({
    required this.id,
    this.name = '',
    this.score = 0,
    this.detail,
    this.sportName,
    this.colorKey,
  });

  /// The **student** id, not the performance-record id.
  final int id;

  final String name;

  /// `fitnessScore`, 0–100.
  final num score;

  /// The coach's own notes on the assessment, falling back to
  /// `"<Sport> Performance"` when there are none.
  final String? detail;

  final String? sportName;

  /// The band the API assigned: `green` ≥ 90, `blue` ≥ 80, else `orange`.
  /// Kept as sent so the app can colour the row the same way the website does.
  final String? colorKey;

  String get displayName => name.trim().isEmpty ? 'Unknown' : name.trim();

  String get initial => displayName.substring(0, 1).toUpperCase();

  String get scoreLabel => '${score.round()}%';

  /// The subtitle line, skipping whichever part is missing.
  String get subtitle {
    final text = (detail ?? '').trim();
    if (text.isNotEmpty) return text;
    return (sportName ?? '').trim();
  }

  @override
  String toString() => 'CoachTopPerformer($id, $name, $scoreLabel)';
}
