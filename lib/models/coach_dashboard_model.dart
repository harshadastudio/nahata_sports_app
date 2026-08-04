/// Models for the coach dashboard endpoints:
///
/// * `GET /coach/dashboard/stats`
/// * `GET /coach/dashboard/schedule/today`
/// * `GET /coach/dashboard/students/top-performers`
/// * `GET /coach/dashboard/attendance/records`
/// * `GET /coaching-enquiries/coach/my-enquiries`
///
/// The live account these were captured from has no students, no attendance
/// and no enquiries yet, so `top-performers`, `attendance/records` and
/// `my-enquiries` were all seen empty. The three models built on them accept
/// several plausible spellings per field and keep everything they don't
/// recognise in `raw`, so nothing is lost once real rows appear.
library;

/// `GET /coach/dashboard/stats` — the six headline numbers.
class CoachStats {
  const CoachStats({
    this.totalStudents = 0,
    this.presentToday = 0,
    this.sessionsToday = 0,
    this.avgPerformance = 0,
    this.totalBatches = 0,
    this.activeEnquiries = 0,
  });

  final int totalStudents;
  final int presentToday;
  final int sessionsToday;

  /// 0–100. Sent as a number; may be fractional.
  final num avgPerformance;

  final int totalBatches;
  final int activeEnquiries;

  static const CoachStats empty = CoachStats();

  /// `0` → `0%`, `82.5` → `83%`.
  String get performanceLabel => '${avgPerformance.round()}%';

  /// Attendance for today as a fraction of the roster, e.g. `3/12`.
  String get attendanceLabel => '$presentToday/$totalStudents';

  factory CoachStats.fromJson(Map<String, dynamic> json) => CoachStats(
        totalStudents: _int(json['totalStudents'] ?? json['total_students']),
        presentToday: _int(json['presentToday'] ?? json['present_today']),
        sessionsToday: _int(json['sessionsToday'] ?? json['sessions_today']),
        avgPerformance:
            _num(json['avgPerformance'] ?? json['avg_performance']),
        totalBatches: _int(json['totalBatches'] ?? json['total_batches']),
        activeEnquiries:
            _int(json['activeEnquiries'] ?? json['active_enquiries']),
      );
}

/// One row of `GET /coach/dashboard/schedule/today`.
class CoachSession {
  const CoachSession({
    this.id,
    this.batchName,
    this.startTime,
    this.endTime,
    this.court,
    this.status,
    this.studentCount = 0,
    this.sportId,
    this.sportName,
    this.program,
  });

  final int? id;
  final String? batchName;

  /// The API currently echoes the batch's free-text `schedule` into **both**
  /// [startTime] and [endTime] (`"5pm to 6pm"` in each), rather than sending
  /// two clock values. [timeLabel] handles that — do not concatenate these.
  final String? startTime;
  final String? endTime;

  /// `"TBD"` when no court has been assigned.
  final String? court;

  final String? status;
  final int studentCount;
  final int? sportId;
  final String? sportName;
  final String? program;

  bool get isActive => (status ?? '').toLowerCase() == 'active';

  /// `"5pm to 6pm"` when both fields carry the same text, `"6:00 - 7:00"`
  /// when the backend starts sending real clock values, and whichever one is
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

  /// Whether a court worth showing was assigned.
  bool get hasCourt {
    final value = (court ?? '').trim();
    return value.isNotEmpty && value.toUpperCase() != 'TBD';
  }

  factory CoachSession.fromJson(Map<String, dynamic> json) {
    final sport = json['sport'];
    final sportMap = sport is Map ? Map<String, dynamic>.from(sport) : null;
    final program = json['program'];

    return CoachSession(
      id: _int(json['id']),
      batchName: _string(json['batchName'] ?? json['batch_name']),
      startTime: _string(json['startTime'] ?? json['start_time']),
      endTime: _string(json['endTime'] ?? json['end_time']),
      court: _string(json['court']),
      status: _string(json['status']),
      studentCount: _int(json['studentCount'] ?? json['student_count']),
      sportId: _int(sportMap?['id'] ?? json['sportId']),
      sportName: _string(sportMap?['name'] ?? json['sportName']),
      program: program is Map
          ? _string(program['name'])
          : _string(program),
    );
  }

  static List<CoachSession> listFrom(Object? data) => _list(data)
      .map(CoachSession.fromJson)
      .toList(growable: false);
}

/// One row of `GET /coach/dashboard/students/top-performers`.
///
/// Shape unverified — see the library note above.
class TopPerformer {
  const TopPerformer({
    this.id,
    this.name,
    this.batchName,
    this.sportName,
    this.score,
    this.attendancePercent,
    this.avatar,
    this.raw = const <String, dynamic>{},
  });

  final int? id;
  final String? name;
  final String? batchName;
  final String? sportName;

  /// Performance score, 0–100.
  final num? score;

  /// Attendance percentage, 0–100.
  final num? attendancePercent;

  final String? avatar;

  /// Everything the API sent, so an unmapped field is still reachable.
  final Map<String, dynamic> raw;

  String get displayName => (name ?? '').trim();

  String get initial =>
      displayName.isEmpty ? '?' : displayName.substring(0, 1).toUpperCase();

  String get scoreLabel => score == null ? '-' : '${score!.round()}%';

  /// `"Basketball · Regular Batch"`, skipping whichever part is missing.
  String get subtitle => [
        if ((sportName ?? '').isNotEmpty) sportName!,
        if ((batchName ?? '').isNotEmpty) batchName!,
      ].join(' · ');

  factory TopPerformer.fromJson(Map<String, dynamic> json) {
    final student = json['student'];
    final studentMap =
        student is Map ? Map<String, dynamic>.from(student) : const {};
    final batch = json['batch'];
    final sport = json['sport'];

    return TopPerformer(
      id: _int(json['id'] ?? json['studentId'] ?? studentMap['id']),
      name: _string(json['name'] ??
          json['studentName'] ??
          json['student_name'] ??
          studentMap['name']),
      batchName: _string(
        batch is Map ? batch['name'] : json['batchName'] ?? json['batch_name'],
      ),
      sportName: _string(
        sport is Map ? sport['name'] : json['sportName'] ?? json['sport_name'],
      ),
      score: _numOrNull(json['score'] ??
          json['performance'] ??
          json['performanceScore'] ??
          json['avgPerformance']),
      attendancePercent: _numOrNull(
          json['attendancePercentage'] ?? json['attendance'] ??
              json['attendancePercent']),
      avatar: _string(json['avatar'] ??
          json['profile_picture'] ??
          json['profilePicture'] ??
          studentMap['avatar']),
      raw: json,
    );
  }

  static List<TopPerformer> listFrom(Object? data) => _list(data)
      .map(TopPerformer.fromJson)
      .toList(growable: false);
}

/// One row of `GET /coach/dashboard/attendance/records`.
///
/// Shape unverified — see the library note above.
class CoachAttendanceRecord {
  const CoachAttendanceRecord({
    this.id,
    this.studentName,
    this.batchName,
    this.date,
    this.status,
    this.markedAt,
    this.raw = const <String, dynamic>{},
  });

  final int? id;
  final String? studentName;
  final String? batchName;

  /// `yyyy-MM-dd`.
  final String? date;

  /// `Present`, `Absent`, `Late`, …
  final String? status;

  final DateTime? markedAt;
  final Map<String, dynamic> raw;

  bool get isPresent => (status ?? '').toLowerCase() == 'present';

  DateTime? get dateTime => DateTime.tryParse(date ?? '');

  factory CoachAttendanceRecord.fromJson(Map<String, dynamic> json) {
    final student = json['student'];
    final studentMap =
        student is Map ? Map<String, dynamic>.from(student) : const {};
    final batch = json['batch'];

    return CoachAttendanceRecord(
      id: _int(json['id']),
      studentName: _string(json['studentName'] ??
          json['student_name'] ??
          json['name'] ??
          studentMap['name']),
      batchName: _string(
        batch is Map ? batch['name'] : json['batchName'] ?? json['batch_name'],
      ),
      date: _string(json['date'] ?? json['attendanceDate']),
      status: _string(json['status'] ?? json['attendanceStatus']),
      markedAt: DateTime.tryParse(
          (json['markedAt'] ?? json['createdAt'] ?? '').toString()),
      raw: json,
    );
  }

  static List<CoachAttendanceRecord> listFrom(Object? data) => _list(data)
      .map(CoachAttendanceRecord.fromJson)
      .toList(growable: false);
}

/// One row of `GET /coaching-enquiries/coach/my-enquiries`.
///
/// Shape unverified — see the library note above. The field names mirror the
/// body accepted by `POST /coaching-enquiries`.
class CoachEnquiry {
  const CoachEnquiry({
    this.id,
    this.referenceNumber,
    this.name,
    this.email,
    this.phone,
    this.message,
    this.status,
    this.sportName,
    this.batchName,
    this.createdAt,
    this.raw = const <String, dynamic>{},
  });

  final int? id;

  /// e.g. `NSC-20260729-F0DAK`.
  final String? referenceNumber;

  final String? name;
  final String? email;
  final String? phone;
  final String? message;

  /// `New`, `Contacted`, `Converted`, `Closed`, …
  final String? status;

  final String? sportName;
  final String? batchName;
  final DateTime? createdAt;
  final Map<String, dynamic> raw;

  String get displayName => (name ?? '').trim();

  bool get isOpen {
    final value = (status ?? '').toLowerCase();
    return value.isEmpty || value == 'new' || value == 'pending' ||
        value == 'active' || value == 'contacted';
  }

  factory CoachEnquiry.fromJson(Map<String, dynamic> json) {
    final sport = json['sport'];
    final batch = json['batch'];
    final user = json['user'];
    final userMap = user is Map ? Map<String, dynamic>.from(user) : const {};

    return CoachEnquiry(
      id: _int(json['id']),
      referenceNumber:
          _string(json['referenceNumber'] ?? json['reference_number']),
      name: _string(json['name'] ??
          json['user_name'] ??
          json['userName'] ??
          userMap['name']),
      email: _string(
          json['email'] ?? json['user_email'] ?? userMap['email']),
      phone: _string(json['phone'] ??
          json['user_contact'] ??
          json['phone_number'] ??
          userMap['phone_number'] ??
          userMap['phone']),
      message: _string(json['message']),
      status: _string(json['status']),
      sportName: _string(
        sport is Map ? sport['name'] : json['sportName'] ?? json['sport_name'],
      ),
      batchName: _string(
        batch is Map ? batch['name'] : json['batchName'] ?? json['batch_name'],
      ),
      createdAt: DateTime.tryParse(
          (json['createdAt'] ?? json['created_at'] ?? '').toString()),
      raw: json,
    );
  }

  static List<CoachEnquiry> listFrom(Object? data) => _list(data)
      .map(CoachEnquiry.fromJson)
      .toList(growable: false);
}

/// The `{ items, total, page, limit, totalPages }` envelope the coach list
/// endpoints share. The item key differs per endpoint (`enquiries`,
/// `records`), so it is passed in.
class CoachPage<T> {
  const CoachPage({
    this.items = const [],
    this.total = 0,
    this.page = 1,
    this.limit = 10,
    this.totalPages = 0,
  });

  final List<T> items;
  final int total;
  final int page;
  final int limit;
  final int totalPages;

  bool get isEmpty => items.isEmpty;

  /// `totalPages` is `0` when there is nothing to list, so compare against it
  /// rather than assuming at least one page exists.
  bool get hasMore => page < totalPages;

  static CoachPage<T> fromJson<T>(
    Map<String, dynamic> json, {
    required String itemsKey,
    required List<T> Function(Object?) parse,
  }) {
    return CoachPage<T>(
      items: parse(json[itemsKey]),
      total: _int(json['total']),
      page: _int(json['page']) == 0 ? 1 : _int(json['page']),
      limit: _int(json['limit']),
      totalPages: _int(json['totalPages'] ?? json['total_pages']),
    );
  }
}

// -----------------------------------------------------------------------------
// Parsing helpers — every one of them tolerates nulls and wrong types.
// -----------------------------------------------------------------------------

List<Map<String, dynamic>> _list(Object? data) {
  if (data is! List) return const <Map<String, dynamic>>[];
  return data
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList(growable: false);
}

int _int(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

num _num(Object? value) => _numOrNull(value) ?? 0;

num? _numOrNull(Object? value) {
  if (value is num) return value;
  return num.tryParse(value?.toString() ?? '');
}

String? _string(Object? value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty || text == 'null') ? null : text;
}
