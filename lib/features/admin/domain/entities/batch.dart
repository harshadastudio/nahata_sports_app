import 'admin_role.dart';
import 'admin_sports_complex.dart';
import 'coach.dart';

/// A coaching batch, as the admin console needs it (`/batches`).
///
/// Deliberately a *second* model beside the storefront's `BatchModel`: that one
/// is tuned for the booking screens and stores fees, dates and counters as the
/// raw strings the API sends. Widening it would push admin-only concerns into
/// every customer-facing screen, so this one parses into real types instead —
/// the same split Phase 5 made between `SportsComplex` and
/// `AdminSportsComplex`.
///
/// Every field except [id] is nullable so a thinner list payload is never
/// padded with invented values; the UI renders "—" for anything absent.
class AdminBatch {
  const AdminBatch({
    required this.id,
    this.name,
    this.image,
    this.sportId,
    this.sportName,
    this.coachId,
    this.coachName,
    this.sportComplexId,
    this.sportComplexName,
    this.schedule,
    this.daysRaw,
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.maxStudents,
    this.currentStudents,
    this.fees,
    this.ageGroup,
    this.duration,
    this.description,
    this.features = const [],
    this.statusRaw,
    this.createdAt,
    this.raw = const {},
  });

  /// The batch id, used in every `/batches/{id}` call.
  final int id;

  final String? name;

  /// As stored by the API — possibly a relative path. Read [imageUrl] to
  /// display it.
  final String? image;

  final int? sportId;
  final String? sportName;

  final int? coachId;
  final String? coachName;

  final int? sportComplexId;
  final String? sportComplexName;

  /// Free-text window, e.g. `"7:00 PM to 8:00 PM"`.
  final String? schedule;

  /// Comma-separated on the wire, e.g. `"Monday,Tuesday"`. Read [days] for the
  /// parsed form.
  final String? daysRaw;

  final DateTime? startDate;
  final DateTime? endDate;

  /// Free text (`"7:00 PM"`), not a `TimeOfDay` — the column is a string and
  /// several rows carry ranges the clock cannot express.
  final String? startTime;
  final String? endTime;

  final int? maxStudents;
  final int? currentStudents;

  /// A decimal string on the wire (`"2500.00"`), parsed here so the table can
  /// sort and total it.
  final num? fees;

  final String? ageGroup;
  final String? duration;
  final String? description;
  final List<String> features;

  final String? statusRaw;
  final DateTime? createdAt;

  final Map<String, dynamic> raw;

  AdminUserStatus? get status => AdminUserStatus.tryParse(statusRaw);
  String get statusLabel => status?.label ?? ((statusRaw ?? '').trim());
  bool get isActive => status == AdminUserStatus.active;

  /// The API has entries like `"3 DAYS (Morning)   "`, so the name is trimmed.
  String get displayName {
    final trimmed = (name ?? '').trim();
    return trimmed.isEmpty ? 'Unnamed batch' : trimmed;
  }

  String get initials {
    final parts = displayName
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  bool get hasImage => (image ?? '').trim().isNotEmpty;

  /// The image as something a network image widget can actually load. Shares
  /// the sports complex module's resolver — the routes store URLs the same
  /// three ways.
  String? get imageUrl => resolveMediaUrl(image);

  /// The days the batch runs, read through the coaches module's own parser so
  /// a schedule reads identically in both places.
  CoachAvailability get days => CoachAvailability.parse(daysRaw);

  /// `"Monday,Tuesday"` → `"Monday, Tuesday"`.
  String get daysLabel => days.isEmpty ? '—' : days.raw;

  /// Seats left, or null when the batch never said how many there are — a
  /// missing capacity is not the same as a full batch.
  int? get availableSeats {
    final max = maxStudents;
    if (max == null) return null;
    final remaining = max - (currentStudents ?? 0);
    return remaining < 0 ? 0 : remaining;
  }

  /// 0–1, or null when there is nothing honest to divide. A capacity of zero
  /// is treated as unknown rather than as 100% full.
  double? get occupancy {
    final max = maxStudents;
    final current = currentStudents;
    if (max == null || max <= 0 || current == null) return null;
    final ratio = current / max;
    return ratio < 0 ? 0 : (ratio > 1 ? 1 : ratio);
  }

  /// The rounded percentage, or null when [occupancy] is unknown.
  int? get occupancyPercent {
    final ratio = occupancy;
    return ratio == null ? null : (ratio * 100).round();
  }

  bool get isFull => availableSeats == 0 && maxStudents != null;

  /// The session window, preferring the explicit columns and falling back to
  /// the free-text [schedule].
  String get scheduleLabel {
    final start = (startTime ?? '').trim();
    final end = (endTime ?? '').trim();
    if (start.isNotEmpty && end.isNotEmpty) return '$start to $end';
    if (start.isNotEmpty) return start;

    final text = (schedule ?? '').trim();
    return text.isEmpty ? '—' : text;
  }

  /// Text a local search should match, per the spec: batch, coach and sport.
  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return displayName.toLowerCase().contains(needle) ||
        (coachName ?? '').toLowerCase().contains(needle) ||
        (sportName ?? '').toLowerCase().contains(needle);
  }

  /// Merges a detail read over the list row, keeping anything detail omitted.
  AdminBatch mergedWith(AdminBatch other) {
    return AdminBatch(
      id: other.id == 0 ? id : other.id,
      name: other.name ?? name,
      image: other.image ?? image,
      sportId: other.sportId ?? sportId,
      sportName: other.sportName ?? sportName,
      coachId: other.coachId ?? coachId,
      coachName: other.coachName ?? coachName,
      sportComplexId: other.sportComplexId ?? sportComplexId,
      sportComplexName: other.sportComplexName ?? sportComplexName,
      schedule: other.schedule ?? schedule,
      daysRaw: other.daysRaw ?? daysRaw,
      startDate: other.startDate ?? startDate,
      endDate: other.endDate ?? endDate,
      startTime: other.startTime ?? startTime,
      endTime: other.endTime ?? endTime,
      maxStudents: other.maxStudents ?? maxStudents,
      currentStudents: other.currentStudents ?? currentStudents,
      fees: other.fees ?? fees,
      ageGroup: other.ageGroup ?? ageGroup,
      duration: other.duration ?? duration,
      description: other.description ?? description,
      features: other.features.isEmpty ? features : other.features,
      statusRaw: other.statusRaw ?? statusRaw,
      createdAt: other.createdAt ?? createdAt,
      raw: {...raw, ...other.raw},
    );
  }

  /// Returns a copy with one field changed — used by the optimistic status
  /// write, which must not wait for a list reload to repaint.
  AdminBatch copyWith({
    String? statusRaw,
    int? currentStudents,
    String? image,
    bool clearImage = false,
  }) {
    return AdminBatch(
      id: id,
      name: name,
      image: clearImage ? null : (image ?? this.image),
      sportId: sportId,
      sportName: sportName,
      coachId: coachId,
      coachName: coachName,
      sportComplexId: sportComplexId,
      sportComplexName: sportComplexName,
      schedule: schedule,
      daysRaw: daysRaw,
      startDate: startDate,
      endDate: endDate,
      startTime: startTime,
      endTime: endTime,
      maxStudents: maxStudents,
      currentStudents: currentStudents ?? this.currentStudents,
      fees: fees,
      ageGroup: ageGroup,
      duration: duration,
      description: description,
      features: features,
      statusRaw: statusRaw ?? this.statusRaw,
      createdAt: createdAt,
      raw: raw,
    );
  }

  @override
  String toString() =>
      'AdminBatch($id, $name, sport: $sportId, coach: $coachId, '
      '$currentStudents/$maxStudents, $statusRaw)';
}

/// Counters from `GET /batches/{batchId}/stats`.
///
/// Every counter is nullable: the drawer shows an em dash for one the endpoint
/// did not send rather than a zero it cannot vouch for. [currentStudents] and
/// [enrolledStudents] are kept apart because the route sends both and they are
/// not always equal — enrolment can include records the batch no longer counts.
class BatchStatistics {
  const BatchStatistics({
    this.batchName,
    this.sportName,
    this.coachName,
    this.maxStudents,
    this.currentStudents,
    this.enrolledStudents,
    this.availableSlots,
    this.occupancyPercentage,
    this.fees,
    this.statusRaw,
    this.startDate,
    this.endDate,
  });

  final String? batchName;
  final String? sportName;
  final String? coachName;

  final int? maxStudents;
  final int? currentStudents;
  final int? enrolledStudents;
  final int? availableSlots;

  /// Sent as a whole percent (`75`), not a ratio.
  final int? occupancyPercentage;

  final num? fees;
  final String? statusRaw;
  final DateTime? startDate;
  final DateTime? endDate;

  AdminUserStatus? get status => AdminUserStatus.tryParse(statusRaw);

  /// 0–1 for the ring. Prefers the server's own percentage and falls back to
  /// dividing the two counters when it did not send one.
  double? get occupancy {
    final percent = occupancyPercentage;
    if (percent != null) return (percent / 100).clamp(0.0, 1.0);

    final max = maxStudents;
    final current = currentStudents;
    if (max == null || max <= 0 || current == null) return null;
    return (current / max).clamp(0.0, 1.0);
  }

  bool get isEmpty =>
      maxStudents == null &&
      currentStudents == null &&
      enrolledStudents == null &&
      availableSlots == null &&
      occupancyPercentage == null;

  @override
  String toString() =>
      'BatchStatistics($currentStudents/$maxStudents, '
      'enrolled: $enrolledStudents, free: $availableSlots, '
      '$occupancyPercentage%)';
}

/// One page of `GET /batches`, which — unlike `/sports` and `/coaches` — really
/// is paginated: it answers
/// `{ batches, currentPage, totalPages, totalItems, itemsPerPage }`.
class BatchPageResult {
  const BatchPageResult({
    this.batches = const [],
    this.page = 1,
    this.totalPages = 1,
    this.totalItems = 0,
    this.perPage = 10,
  });

  final List<AdminBatch> batches;
  final int page;
  final int totalPages;
  final int totalItems;
  final int perPage;

  bool get hasMore => page < totalPages;

  @override
  String toString() =>
      'BatchPageResult(page $page/$totalPages, ${batches.length} of '
      '$totalItems)';
}

/// A coach and the batches they run, for the coach-wise breakdown
/// (`GET /batches/coach/{coachId}`).
class CoachBatchLoad {
  const CoachBatchLoad({
    required this.coachId,
    this.coachName,
    this.batches = const [],
  });

  final int coachId;
  final String? coachName;
  final List<AdminBatch> batches;

  int get totalBatches => batches.length;

  int get activeBatches => batches.where((batch) => batch.isActive).length;

  /// Null when not one batch reported a headcount — a zero there would claim
  /// the coach has no students when the API simply did not say.
  int? get currentStudents {
    var total = 0;
    var known = false;
    for (final batch in batches) {
      final current = batch.currentStudents;
      if (current == null) continue;
      known = true;
      total += current;
    }
    return known ? total : null;
  }

  int? get maxStudents {
    var total = 0;
    var known = false;
    for (final batch in batches) {
      final max = batch.maxStudents;
      if (max == null) continue;
      known = true;
      total += max;
    }
    return known ? total : null;
  }

  /// The coach's overall fill rate across every batch they run.
  double? get occupancy {
    final max = maxStudents;
    final current = currentStudents;
    if (max == null || max <= 0 || current == null) return null;
    return (current / max).clamp(0.0, 1.0);
  }

  /// Every distinct schedule window the coach works, in the order first seen.
  List<String> get schedules {
    final seen = <String>{};
    final result = <String>[];
    for (final batch in batches) {
      final label = batch.scheduleLabel;
      if (label == '—') continue;
      if (seen.add(label.toLowerCase())) result.add(label);
    }
    return result;
  }
}

/// The write payload for create and update.
class BatchDraft {
  const BatchDraft({
    this.name,
    this.sportId,
    this.coachId,
    this.sportComplexId,
    this.schedule,
    this.days,
    this.startDate,
    this.endDate,
    this.startTime,
    this.endTime,
    this.maxStudents,
    this.fees,
    this.ageGroup,
    this.duration,
    this.description,
    this.features,
    this.image,
    this.status,
  });

  final String? name;
  final int? sportId;
  final int? coachId;
  final int? sportComplexId;

  final String? schedule;

  /// Comma-separated, exactly as the column stores it.
  final String? days;

  final DateTime? startDate;
  final DateTime? endDate;
  final String? startTime;
  final String? endTime;

  final int? maxStudents;
  final num? fees;

  final String? ageGroup;
  final String? duration;
  final String? description;
  final List<String>? features;

  /// The URL returned by the upload route, or empty to send no image.
  final String? image;

  final AdminUserStatus? status;

  /// `yyyy-MM-dd`, which is the shape every date the API returns is in.
  static String? formatDate(DateTime? value) {
    if (value == null) return null;
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  /// `POST /batches`.
  ///
  /// Optional text fields are sent as `""` rather than omitted: that is the
  /// shape the sibling create payloads document, and it lets a create
  /// explicitly leave a column blank.
  Map<String, dynamic> toCreateJson() {
    return <String, dynamic>{
      'name': (name ?? '').trim(),
      'sportId': sportId,
      'coachId': coachId,
      'sportComplexId': sportComplexId,
      'schedule': (schedule ?? '').trim(),
      'days': (days ?? '').trim(),
      'startDate': formatDate(startDate),
      'endDate': formatDate(endDate),
      'startTime': (startTime ?? '').trim(),
      'endTime': (endTime ?? '').trim(),
      'maxStudents': maxStudents,
      'fees': fees,
      'ageGroup': (ageGroup ?? '').trim(),
      'duration': (duration ?? '').trim(),
      'description': (description ?? '').trim(),
      'features': features ?? const <String>[],
      'image': (image ?? '').trim(),
      'status': (status ?? AdminUserStatus.active).slug,
    };
  }

  /// `PUT /batches/{batchId}`.
  ///
  /// Only the six fields the route documents as editable are sent. The sport,
  /// coach, complex and the whole schedule are deliberately absent: the edit
  /// dialog renders those read-only for the same reason.
  ///
  /// A field the form never set (null) is omitted; one the admin deliberately
  /// blanked is sent empty, or a description could never be cleared once
  /// written.
  Map<String, dynamic> toUpdateJson() {
    final body = <String, dynamic>{};

    void put(String key, Object? value) {
      if (value == null) return;
      body[key] = value is String ? value.trim() : value;
    }

    put('name', name);
    put('fees', fees);
    put('maxStudents', maxStudents);
    put('description', description);
    put('duration', duration);
    put('status', status?.slug);

    return body;
  }
}
