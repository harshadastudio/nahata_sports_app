import 'admin_role.dart';
import 'coach.dart';

/// A time of day, as slots store it.
///
/// The column is a string and the API has been seen using more than one shape
/// (`"07:00"`, `"07:00:00"`, `"7:00 PM"`), so parsing is deliberately
/// forgiving while writing is not: [wire] is always 24-hour `HH:mm`, which is
/// the one form every reader here accepts.
class SlotTime implements Comparable<SlotTime> {
  const SlotTime(this.minutesFromMidnight);

  /// Minutes since 00:00. Comparing and adding an hour are the only two things
  /// the slot rules need, and both are trivial on an integer.
  final int minutesFromMidnight;

  int get hour => minutesFromMidnight ~/ 60;
  int get minute => minutesFromMidnight % 60;

  static const int minutesPerDay = 24 * 60;

  /// Reads `"07:00"`, `"07:00:00"`, `"7:00 PM"`, `"7 PM"` and `"1900"`.
  /// Returns null for anything else rather than guessing a time.
  static SlotTime? parse(Object? value) {
    final text = (value ?? '').toString().trim();
    if (text.isEmpty || text.toLowerCase() == 'null') return null;

    final match = RegExp(
      r'^(\d{1,2})\s*[:.]?\s*(\d{2})?\s*(?::\s*\d{2})?\s*([ap]\.?m\.?)?$',
      caseSensitive: false,
    ).firstMatch(text);
    if (match == null) return null;

    var hour = int.tryParse(match.group(1) ?? '');
    final minute = int.tryParse(match.group(2) ?? '0') ?? 0;
    final meridiem = (match.group(3) ?? '').toLowerCase().replaceAll('.', '');

    if (hour == null || minute < 0 || minute > 59) return null;

    if (meridiem.isNotEmpty) {
      if (hour < 1 || hour > 12) return null;
      if (meridiem == 'pm' && hour != 12) hour += 12;
      if (meridiem == 'am' && hour == 12) hour = 0;
    } else if (hour < 0 || hour > 23) {
      return null;
    }

    return SlotTime(hour * 60 + minute);
  }

  static SlotTime fromHour(int hour) => SlotTime(hour * 60);

  /// What a save sends.
  String get wire =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// `7:00 AM`, for every label on screen.
  String get label {
    final suffix = hour < 12 ? 'AM' : 'PM';
    final twelve = hour % 12 == 0 ? 12 : hour % 12;
    return '$twelve:${minute.toString().padLeft(2, '0')} $suffix';
  }

  /// Wraps past midnight, so a 23:30 slot ending at 00:30 is representable.
  SlotTime plusMinutes(int minutes) =>
      SlotTime((minutesFromMidnight + minutes) % minutesPerDay);

  /// Minutes from this time to [other], counting a wrap past midnight as
  /// forward rather than as a negative span.
  int minutesUntil(SlotTime other) {
    final delta = other.minutesFromMidnight - minutesFromMidnight;
    return delta >= 0 ? delta : delta + minutesPerDay;
  }

  @override
  int compareTo(SlotTime other) =>
      minutesFromMidnight.compareTo(other.minutesFromMidnight);

  @override
  bool operator ==(Object other) =>
      other is SlotTime && other.minutesFromMidnight == minutesFromMidnight;

  @override
  int get hashCode => minutesFromMidnight.hashCode;

  @override
  String toString() => wire;
}

/// What a slot is for.
///
/// Enumerated by the product spec rather than by any endpoint. [slug] is what
/// goes on the wire; a value the server sends that is not in the list still
/// renders through [labelFor], so the list being wrong never hides data.
enum SlotType {
  regular('Regular'),
  premium('Premium'),
  coaching('Coaching'),
  practice('Practice');

  const SlotType(this.slug);

  final String slug;

  String get label => slug;

  static SlotType? tryParse(Object? value) {
    final wanted = (value ?? '')
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\s_\-]+'), '');
    if (wanted.isEmpty) return null;
    for (final type in SlotType.values) {
      if (type.slug.toLowerCase() == wanted) return type;
    }
    return null;
  }

  static String labelFor(String? raw) {
    final parsed = tryParse(raw);
    if (parsed != null) return parsed.label;
    final text = (raw ?? '').trim();
    if (text.isEmpty) return '—';
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }
}

/// One bookable window on a court (`/courts/{courtId}/slots`).
class CourtSlot {
  const CourtSlot({
    required this.id,
    this.courtId,
    this.startTimeRaw,
    this.endTimeRaw,
    this.availableDaysRaw,
    this.slotTypeRaw,
    this.priceOverride,
    this.statusRaw,
    this.raw = const {},
  });

  final int id;
  final int? courtId;

  final String? startTimeRaw;
  final String? endTimeRaw;

  /// Comma-separated on the wire, like a batch's days.
  final String? availableDaysRaw;

  final String? slotTypeRaw;

  /// Null means "charge the court's hourly rate"; a value overrides it.
  final num? priceOverride;

  final String? statusRaw;

  final Map<String, dynamic> raw;

  SlotTime? get startTime => SlotTime.parse(startTimeRaw);
  SlotTime? get endTime => SlotTime.parse(endTimeRaw);

  /// The days the slot runs, read through the coaches module's own parser so a
  /// schedule reads identically everywhere in the console.
  CoachAvailability get days => CoachAvailability.parse(availableDaysRaw);

  SlotType? get slotType => SlotType.tryParse(slotTypeRaw);
  String get slotTypeLabel => SlotType.labelFor(slotTypeRaw);

  AdminUserStatus? get status => AdminUserStatus.tryParse(statusRaw);
  String get statusLabel => status?.label ?? ((statusRaw ?? '').trim());

  /// The spec's own wording: Active is bookable, Inactive is blocked.
  bool get isBookable => status == AdminUserStatus.active;
  bool get isBlocked => status != null && !isBookable;

  bool get hasPriceOverride => priceOverride != null;

  /// `7:00 AM – 8:00 AM`, or an em dash when the times are unreadable.
  String get windowLabel {
    final start = startTime;
    final end = endTime;
    if (start == null && end == null) return '—';
    if (start == null) return 'until ${end!.label}';
    if (end == null) return 'from ${start.label}';
    return '${start.label} – ${end.label}';
  }

  /// Minutes the window covers, or null when either end is unreadable.
  int? get durationMinutes {
    final start = startTime;
    final end = endTime;
    if (start == null || end == null) return null;
    return start.minutesUntil(end);
  }

  /// True when this slot and [other] cover the same clock time on a shared
  /// day. Used to stop the form creating a slot the court cannot honour.
  ///
  /// Two windows that merely touch (08:00–09:00 and 09:00–10:00) do not
  /// overlap; that is the normal way an hourly schedule is built.
  bool overlaps(CourtSlot other) {
    final start = startTime;
    final end = endTime;
    final otherStart = other.startTime;
    final otherEnd = other.endTime;
    if (start == null || end == null) return false;
    if (otherStart == null || otherEnd == null) return false;

    if (!_sharesDay(other)) return false;

    final a = start.minutesFromMidnight;
    final b = end.minutesFromMidnight;
    final c = otherStart.minutesFromMidnight;
    final d = otherEnd.minutesFromMidnight;

    // A window that wraps past midnight is treated as running to end of day;
    // the backend owns the real calendar, and this check only has to be right
    // about the ordinary same-day case.
    final endA = b > a ? b : SlotTime.minutesPerDay;
    final endB = d > c ? d : SlotTime.minutesPerDay;

    return a < endB && c < endA;
  }

  /// Two slots share a day when their day sets intersect — or when either is
  /// unreadable, in which case the safer answer is "possibly", so the form
  /// warns rather than waving a clash through.
  bool _sharesDay(CourtSlot other) {
    final mine = days;
    final theirs = other.days;
    if (mine.isEmpty || theirs.isEmpty) return true;
    if (mine.isCustom || theirs.isCustom) return true;

    final set = mine.days.toSet();
    return theirs.days.any(set.contains);
  }

  CourtSlot copyWith({String? statusRaw}) {
    return CourtSlot(
      id: id,
      courtId: courtId,
      startTimeRaw: startTimeRaw,
      endTimeRaw: endTimeRaw,
      availableDaysRaw: availableDaysRaw,
      slotTypeRaw: slotTypeRaw,
      priceOverride: priceOverride,
      statusRaw: statusRaw ?? this.statusRaw,
      raw: raw,
    );
  }

  @override
  String toString() =>
      'CourtSlot($id, $startTimeRaw–$endTimeRaw, $slotTypeRaw, $statusRaw)';
}

/// The write payload for creating and updating a slot.
class CourtSlotDraft {
  const CourtSlotDraft({
    this.startTime,
    this.endTime,
    this.availableDays,
    this.slotType,
    this.priceOverride,
    this.clearPriceOverride = false,
    this.status,
  });

  final SlotTime? startTime;
  final SlotTime? endTime;

  /// Comma-separated, exactly as the column stores it.
  final String? availableDays;

  final SlotType? slotType;

  final num? priceOverride;

  /// Sends an explicit null, so an override can actually be removed rather
  /// than merely left unchanged.
  final bool clearPriceOverride;

  final AdminUserStatus? status;

  /// The spec's rule: a slot is exactly one hour long.
  static const int requiredMinutes = 60;

  /// Null when the pair is valid, otherwise the reason it is not.
  static String? validateWindow(SlotTime? start, SlotTime? end) {
    if (start == null) return 'Pick a start time';
    if (end == null) return 'Pick an end time';

    final minutes = start.minutesUntil(end);
    if (minutes == 0) return 'The end time cannot equal the start time';
    if (minutes != requiredMinutes) {
      return 'A slot must be exactly one hour — this one is '
          '${_duration(minutes)}';
    }
    return null;
  }

  static String _duration(int minutes) {
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '$rest min';
    if (rest == 0) return '$hours hr';
    return '$hours hr $rest min';
  }

  /// `POST /courts/{courtId}/slots`
  Map<String, dynamic> toCreateJson() {
    return <String, dynamic>{
      'startTime': startTime?.wire,
      'endTime': endTime?.wire,
      'availableDays': (availableDays ?? '').trim(),
      'slotType': (slotType ?? SlotType.regular).slug,
      'priceOverride': priceOverride,
      'status': (status ?? AdminUserStatus.active).slug,
    };
  }

  /// `PUT /courts/{courtId}/slots/{slotId}`.
  ///
  /// Only the three fields the route documents as editable — the times, the
  /// price override and the status. A field the form never set is omitted, so
  /// an edit never blanks a column the admin did not touch.
  Map<String, dynamic> toUpdateJson() {
    final body = <String, dynamic>{};

    if (startTime != null) body['startTime'] = startTime!.wire;
    if (endTime != null) body['endTime'] = endTime!.wire;

    // Distinguishes "leave it alone" from "remove it": only the explicit clear
    // sends null.
    if (clearPriceOverride) {
      body['priceOverride'] = null;
    } else if (priceOverride != null) {
      body['priceOverride'] = priceOverride;
    }

    if (status != null) body['status'] = status!.slug;

    return body;
  }
}

/// One entry from `GET /courts/{courtId}/available-slots?date=`.
///
/// The route answers for a specific date, so this is a *state* rather than a
/// schedule: the same slot is available on one day and booked on the next.
class AvailableSlot {
  const AvailableSlot({
    this.slotId,
    this.startTimeRaw,
    this.endTimeRaw,
    this.isAvailable,
    this.isBlocked,
    this.statusRaw,
    this.price,
    this.raw = const {},
  });

  final int? slotId;
  final String? startTimeRaw;
  final String? endTimeRaw;

  /// Null when the payload said nothing either way — rendered as unknown
  /// rather than assumed free.
  final bool? isAvailable;
  final bool? isBlocked;

  final String? statusRaw;
  final num? price;

  final Map<String, dynamic> raw;

  SlotTime? get startTime => SlotTime.parse(startTimeRaw);
  SlotTime? get endTime => SlotTime.parse(endTimeRaw);

  String get windowLabel {
    final start = startTime;
    final end = endTime;
    if (start == null) return '—';
    if (end == null) return start.label;
    return '${start.label} – ${end.label}';
  }

  /// The three states the spec colours: available, booked, blocked.
  SlotAvailability get availability {
    if (isBlocked == true) return SlotAvailability.blocked;

    final status = (statusRaw ?? '').trim().toLowerCase();
    if (status.contains('block')) return SlotAvailability.blocked;
    if (status.contains('book') || status.contains('occupied')) {
      return SlotAvailability.booked;
    }
    if (status == 'available' || status == 'free') {
      return SlotAvailability.available;
    }

    if (isAvailable == true) return SlotAvailability.available;
    if (isAvailable == false) return SlotAvailability.booked;

    return SlotAvailability.unknown;
  }

  @override
  String toString() =>
      'AvailableSlot($startTimeRaw–$endTimeRaw, ${availability.name})';
}

/// How a window reads on a given date.
enum SlotAvailability {
  available('Available'),
  booked('Booked'),
  blocked('Blocked'),

  /// The payload did not say. Shown as such rather than guessed either way —
  /// telling an admin a court is free when it is not is the expensive mistake.
  unknown('Unknown');

  const SlotAvailability(this.label);

  final String label;
}

/// One row of `GET /courts/availability`.
///
/// The spec is explicit that this view must not expose court names: it answers
/// "is there a court free at 7pm", not "which one". So the model carries the
/// window and a count, and deliberately has no name field.
class AvailabilityWindow {
  const AvailabilityWindow({
    this.startTimeRaw,
    this.endTimeRaw,
    this.availableCourts,
    this.totalCourts,
    this.raw = const {},
  });

  final String? startTimeRaw;
  final String? endTimeRaw;

  /// How many courts are free in this window, when the route says.
  final int? availableCourts;
  final int? totalCourts;

  final Map<String, dynamic> raw;

  SlotTime? get startTime => SlotTime.parse(startTimeRaw);
  SlotTime? get endTime => SlotTime.parse(endTimeRaw);

  String get windowLabel {
    final start = startTime;
    final end = endTime;
    if (start == null) return '—';
    if (end == null) return start.label;
    return '${start.label} – ${end.label}';
  }

  /// True only when the route positively said a court is free. A window with
  /// no counter is not treated as bookable.
  bool get hasAvailability => (availableCourts ?? 0) > 0;

  @override
  String toString() =>
      'AvailabilityWindow($startTimeRaw–$endTimeRaw, '
      '$availableCourts/$totalCourts)';
}
