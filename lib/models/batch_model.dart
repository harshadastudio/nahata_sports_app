/// Models for the coaching module: `/batches`, `/batches/{id}/stats` and the
/// nested `sport` / `coach` objects they embed.
///
/// The same batch is returned with slightly different nested shapes depending
/// on the endpoint (`/batches` includes the sport image, `/batches/sport/{id}`
/// includes the coach's ground, `/batches/{id}` includes the coach's
/// experience). Every field is optional here so one model covers all of them.
library;

/// A sport, as returned by `GET /sports` and as embedded inside a batch.
///
/// The embedded form carries only `id`/`name`/`category` (+`image` on
/// `/batches`); the standalone form adds description, age range and coach
/// count. Every field is optional so one type covers both.
///
/// Note that sport ids are **per ground** — "Basketball" is id 8 at Gangadham
/// Chowk and id 26 at Sinhagad Road — so a sport is only meaningful together
/// with the ground it was fetched for. [ground] records that context.
class SportRef {
  const SportRef({
    this.id,
    this.name,
    this.category,
    this.image,
    this.description,
    this.minAge,
    this.maxAge,
    this.status,
    this.coachCount,
    this.ground,
  });

  final int? id;
  final String? name;
  final String? category;
  final String? image;
  final String? description;
  final int? minAge;
  final int? maxAge;
  final String? status;

  /// Sent by the API as a string (`"1"`); parsed to an int here.
  final int? coachCount;

  /// The ground this sport was fetched for. Not part of the API payload —
  /// injected from the request so downstream screens keep the context.
  final String? ground;

  String get displayName => name ?? '';

  bool get isActive => (status ?? 'Active').toLowerCase() == 'active';

  bool get hasCoaches => (coachCount ?? 0) > 0;

  /// Age range label, e.g. `"5 - 50"`, or empty when unbounded.
  String get ageRangeLabel {
    if (minAge == null && maxAge == null) return '';
    if (minAge != null && maxAge != null) return '$minAge - $maxAge';
    return minAge != null ? '$minAge+' : 'Up to $maxAge';
  }

  factory SportRef.fromJson(Map<String, dynamic> json) => SportRef(
        id: _asInt(json['id']),
        name: _asString(json['name']),
        category: _asString(json['category']),
        image: _asString(json['image']),
        description: _asString(json['description']),
        minAge: _asInt(json['minAge'] ?? json['min_age']),
        maxAge: _asInt(json['maxAge'] ?? json['max_age']),
        status: _asString(json['status']),
        coachCount: _asInt(json['coachCount'] ?? json['coach_count']),
        ground: _asString(json['ground']),
      );

  SportRef copyWith({String? ground}) => SportRef(
        id: id,
        name: name,
        category: category,
        image: image,
        description: description,
        minAge: minAge,
        maxAge: maxAge,
        status: status,
        coachCount: coachCount,
        ground: ground ?? this.ground,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category,
        'image': image,
        'description': description,
        'minAge': minAge,
        'maxAge': maxAge,
        'status': status,
        'coachCount': coachCount,
        'ground': ground,
      };
}

/// Coach summary embedded in a batch.
class CoachRef {
  const CoachRef({
    this.id,
    this.name,
    this.email,
    this.phone,
    this.ground,
    this.experience,
  });

  final int? id;
  final String? name;
  final String? email;
  final String? phone;

  /// Present on `/batches/sport/{sportId}`.
  final String? ground;

  /// Present on `/batches/{id}`.
  final String? experience;

  String get displayName => name ?? '';

  factory CoachRef.fromJson(Map<String, dynamic> json) => CoachRef(
        id: _asInt(json['id']),
        name: _asString(json['name']),
        email: _asString(json['email']),
        phone: _asString(json['phone']),
        ground: _asString(json['ground']),
        experience: _asString(json['experience']),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'ground': ground,
        'experience': experience,
      };
}

/// A coaching batch.
class BatchModel {
  const BatchModel({
    this.id,
    this.name,
    this.sportId,
    this.coachId,
    this.sportComplexId,
    this.schedule,
    this.days,
    this.startDate,
    this.endDate,
    this.maxStudents,
    this.currentStudents,
    this.status,
    this.fees,
    this.description,
    this.ageGroup,
    this.duration,
    this.startTime,
    this.endTime,
    this.image,
    this.legacyProgramId,
    this.createdAt,
    this.updatedAt,
    this.features = const <String>[],
    this.sport,
    this.coach,
  });

  final int? id;
  final String? name;
  final int? sportId;
  final int? coachId;
  final int? sportComplexId;

  /// Free-text window, e.g. `"7:00 PM to 8:00 PM"`.
  final String? schedule;

  /// Comma separated, e.g. `"Monday,Tuesday"`.
  final String? days;

  final String? startDate;
  final String? endDate;
  final int? maxStudents;
  final int? currentStudents;
  final String? status;

  /// Decimal string, e.g. `"2500.00"`.
  final String? fees;

  final String? description;
  final String? ageGroup;
  final String? duration;
  final String? startTime;
  final String? endTime;
  final String? image;
  final int? legacyProgramId;
  final String? createdAt;
  final String? updatedAt;
  final List<String> features;
  final SportRef? sport;
  final CoachRef? coach;

  // ---------------------------------------------------------------------------
  // Derived values for the UI
  // ---------------------------------------------------------------------------

  /// Trimmed name — the API has entries like `"3 DAYS (Morning)   "`.
  String get displayName => (name ?? '').trim();

  bool get isActive => (status ?? '').toLowerCase() == 'active';

  /// Fees without the trailing `.00`, e.g. `"2500.00"` → `"2500"`.
  String get feesLabel {
    final raw = (fees ?? '').trim();
    if (raw.isEmpty) return '0';
    final asNumber = double.tryParse(raw);
    if (asNumber == null) return raw;
    return asNumber == asNumber.roundToDouble()
        ? asNumber.toStringAsFixed(0)
        : asNumber.toStringAsFixed(2);
  }

  /// Start of the session window. Prefers the explicit `startTime` column and
  /// falls back to parsing [schedule] (`"7:00 PM to 8:00 PM"`).
  String get sessionStart {
    final explicit = (startTime ?? '').trim();
    if (explicit.isNotEmpty) return explicit;
    return _scheduleParts.$1;
  }

  String get sessionEnd {
    final explicit = (endTime ?? '').trim();
    if (explicit.isNotEmpty) return explicit;
    return _scheduleParts.$2;
  }

  (String, String) get _scheduleParts {
    final raw = (schedule ?? '').trim();
    if (raw.isEmpty) return ('', '');

    // Split on a standalone "to" / "To" / "-" separator.
    final match = RegExp(r'^(.*?)\s+(?:to|till|until|-|–)\s+(.*)$',
            caseSensitive: false)
        .firstMatch(raw);
    if (match == null) return (raw, '');
    return (match.group(1)!.trim(), match.group(2)!.trim());
  }

  /// Human month the batch starts in, e.g. `"July 2026"`. Used where the old
  /// UI showed "Starting from: …".
  String get startMonthLabel {
    final parsed = DateTime.tryParse(startDate ?? '');
    if (parsed == null) return '';
    return '${_monthNames[parsed.month - 1]} ${parsed.year}';
  }

  /// Days rendered for humans: `"Monday,Tuesday"` → `"Monday, Tuesday"`.
  String get daysLabel =>
      (days ?? '').split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).join(', ');

  int get availableSlots {
    final max = maxStudents ?? 0;
    final current = currentStudents ?? 0;
    final remaining = max - current;
    return remaining < 0 ? 0 : remaining;
  }

  bool get isFull => maxStudents != null && availableSlots == 0;

  static const List<String> _monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];

  // ---------------------------------------------------------------------------

  factory BatchModel.fromJson(Map<String, dynamic> json) {
    return BatchModel(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      sportId: _asInt(json['sportId'] ?? json['sport_id']),
      coachId: _asInt(json['coachId'] ?? json['coach_id']),
      sportComplexId: _asInt(json['sportComplexId'] ?? json['sport_complex_id']),
      schedule: _asString(json['schedule']),
      days: _asString(json['days']),
      startDate: _asString(json['startDate'] ?? json['start_date']),
      endDate: _asString(json['endDate'] ?? json['end_date']),
      maxStudents: _asInt(json['maxStudents'] ?? json['max_students']),
      currentStudents: _asInt(json['currentStudents'] ?? json['current_students']),
      status: _asString(json['status']),
      fees: _asString(json['fees'] ?? json['price']),
      description: _asString(json['description']),
      ageGroup: _asString(json['ageGroup'] ?? json['age_group']),
      duration: _asString(json['duration']),
      startTime: _asString(json['startTime'] ?? json['start_time']),
      endTime: _asString(json['endTime'] ?? json['end_time']),
      image: _asString(json['image']),
      legacyProgramId: _asInt(json['legacyProgramId']),
      createdAt: _asString(json['createdAt']),
      updatedAt: _asString(json['updatedAt']),
      features: _asStringList(json['features']),
      sport: _asObject(json['sport']) == null
          ? null
          : SportRef.fromJson(_asObject(json['sport'])!),
      coach: _asObject(json['coach']) == null
          ? null
          : CoachRef.fromJson(_asObject(json['coach'])!),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sportId': sportId,
        'coachId': coachId,
        'sportComplexId': sportComplexId,
        'schedule': schedule,
        'days': days,
        'startDate': startDate,
        'endDate': endDate,
        'maxStudents': maxStudents,
        'currentStudents': currentStudents,
        'status': status,
        'fees': fees,
        'description': description,
        'ageGroup': ageGroup,
        'duration': duration,
        'startTime': startTime,
        'endTime': endTime,
        'image': image,
        'legacyProgramId': legacyProgramId,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
        'features': features,
        'sport': sport?.toJson(),
        'coach': coach?.toJson(),
      };
}

/// `GET /batches` — one page of results.
class BatchPage {
  const BatchPage({
    this.batches = const <BatchModel>[],
    this.currentPage = 1,
    this.totalPages = 1,
    this.totalItems = 0,
    this.itemsPerPage = 10,
  });

  final List<BatchModel> batches;
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int itemsPerPage;

  bool get hasMore => currentPage < totalPages;

  factory BatchPage.fromJson(Map<String, dynamic> json) {
    final raw = json['batches'];
    return BatchPage(
      batches: raw is List
          ? raw
              .whereType<Map>()
              .map((b) => BatchModel.fromJson(Map<String, dynamic>.from(b)))
              .toList(growable: false)
          : const <BatchModel>[],
      currentPage: _asInt(json['currentPage']) ?? 1,
      totalPages: _asInt(json['totalPages']) ?? 1,
      totalItems: _asInt(json['totalItems']) ?? 0,
      itemsPerPage: _asInt(json['itemsPerPage']) ?? 10,
    );
  }
}

/// `GET /batches/{id}/stats`
class BatchStats {
  const BatchStats({
    this.batchId,
    this.batchName,
    this.sport,
    this.coach,
    this.maxStudents,
    this.currentStudents,
    this.enrolledStudents,
    this.availableSlots,
    this.occupancyPercentage,
    this.status,
    this.fees,
    this.startDate,
    this.endDate,
  });

  final int? batchId;
  final String? batchName;
  final String? sport;
  final String? coach;
  final int? maxStudents;
  final int? currentStudents;
  final int? enrolledStudents;
  final int? availableSlots;
  final int? occupancyPercentage;
  final String? status;
  final String? fees;
  final String? startDate;
  final String? endDate;

  bool get isFull => (availableSlots ?? 1) <= 0;

  factory BatchStats.fromJson(Map<String, dynamic> json) => BatchStats(
        batchId: _asInt(json['batchId']),
        batchName: _asString(json['batchName']),
        sport: _asString(json['sport']),
        coach: _asString(json['coach']),
        maxStudents: _asInt(json['maxStudents']),
        currentStudents: _asInt(json['currentStudents']),
        enrolledStudents: _asInt(json['enrolledStudents']),
        availableSlots: _asInt(json['availableSlots']),
        occupancyPercentage: _asInt(json['occupancyPercentage']),
        status: _asString(json['status']),
        fees: _asString(json['fees']),
        startDate: _asString(json['startDate']),
        endDate: _asString(json['endDate']),
      );
}

// -----------------------------------------------------------------------------
// Shared parsing helpers — all null- and type-tolerant.
// -----------------------------------------------------------------------------

String? _asString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return null;
  return text;
}

int? _asInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

List<String> _asStringList(Object? value) {
  if (value is List) {
    return value
        .where((e) => e != null)
        .map((e) => e.toString())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  }
  return const <String>[];
}

Map<String, dynamic>? _asObject(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}
