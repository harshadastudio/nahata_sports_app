import 'employee_formats.dart';

/// The six "operations" modules — Sports, Court, Slot, Batch, Blocked Slots and
/// Fees Management — share one property: **they are complex-scoped by the API**.
/// `complexScope.js` lists EMPLOYEE in `COMPLEX_SCOPED_ROLES`, so reads return
/// only the employee's own complex and writes are stamped with it.
///
/// That is why nothing in this file carries a `sportComplexId`: sending one
/// would be ignored, and offering a complex picker would imply a choice the
/// employee does not have.

// ─────────────────────────────────────────────────────────────────────────────
// Sport
// ─────────────────────────────────────────────────────────────────────────────

/// A sport offered at the complex, from `GET /sports`.
class EmployeeSport {
  const EmployeeSport({
    required this.id,
    this.name = '',
    this.description,
    this.category,
    this.minAge,
    this.maxAge,
    this.allowedMembers,
    this.status = 'Active',
  });

  final int id;
  final String name;
  final String? description;

  /// `Indoor` | `Outdoor` | `Aquatic` | `Adventure`.
  final String? category;

  final int? minAge;
  final int? maxAge;

  /// Ceiling on how many people one booking may bring.
  final int? allowedMembers;

  final String status;

  bool get isActive => status.toLowerCase() == 'active';

  String get displayName => name.trim().isEmpty ? 'Sport #$id' : name.trim();

  /// `6–14 yrs`, `6+ yrs`, `up to 14 yrs`, or null when neither bound is set.
  String? get ageLabel {
    if (minAge == null && maxAge == null) return null;
    if (minAge != null && maxAge != null) return '$minAge–$maxAge yrs';
    if (minAge != null) return '$minAge+ yrs';
    return 'up to $maxAge yrs';
  }

  @override
  String toString() => 'EmployeeSport($id, $displayName)';
}

/// The categories the sport form offers. Fixed on the website too.
const List<String> employeeSportCategories = [
  'Indoor',
  'Outdoor',
  'Aquatic',
  'Adventure',
];

// ─────────────────────────────────────────────────────────────────────────────
// Court
// ─────────────────────────────────────────────────────────────────────────────

/// A court or ground, from `GET /courts`.
class EmployeeCourt {
  const EmployeeCourt({
    required this.id,
    this.name = '',
    this.sportId,
    this.sportName = '',
    this.capacity,
    this.surfaceType,
    this.lightingAvailable = false,
    this.hourlyRate = 0,
    this.status = 'Active',
  });

  final int id;
  final String name;
  final int? sportId;
  final String sportName;
  final int? capacity;

  /// Free text — `Synthetic`, `Wooden`, `Turf`.
  final String? surfaceType;

  final bool lightingAvailable;

  /// The default price a slot inherits unless it sets its own override.
  final num hourlyRate;

  final String status;

  bool get isActive => status.toLowerCase() == 'active';

  String get displayName => name.trim().isEmpty ? 'Court #$id' : name.trim();

  String get rateLabel => formatRupees(hourlyRate);

  @override
  String toString() => 'EmployeeCourt($id, $displayName)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Slot
// ─────────────────────────────────────────────────────────────────────────────

/// A time-slot **template** on a court, from `GET /courts/{id}/slots`.
///
/// Slots are stored as one-hour rows on purpose: partner booking feeds read
/// them literally, so a three-hour row would be published as one unbookable
/// block rather than three slots.
///
/// [availableDays] is a comma-separated day string, and **null means every
/// day** — not "no days". The form converts at the edges so nothing downstream
/// has to remember that.
class EmployeeSlot {
  const EmployeeSlot({
    required this.id,
    this.courtId,
    this.startTime = '',
    this.endTime = '',
    this.slotType = 'Regular',
    this.priceOverride,
    this.availableDays,
    this.status = 'Active',
  });

  final int id;
  final int? courtId;

  /// `HH:mm:ss` as stored.
  final String startTime;
  final String endTime;

  /// `Regular` | `Peak`.
  final String slotType;

  /// Overrides the court's hourly rate for this slot. Null = inherit.
  final num? priceOverride;

  /// `"Mon,Wed,Fri"`, or null for every day.
  final String? availableDays;

  final String status;

  bool get isActive => status.toLowerCase() == 'active';

  /// `9:00 AM – 10:00 AM`.
  String get timeLabel {
    final from = formatClock(startTime);
    final to = formatClock(endTime);
    if (from == null && to == null) return '—';
    if (to == null) return from!;
    if (from == null) return to;
    return '$from – $to';
  }

  String get priceLabel =>
      priceOverride == null ? '—' : formatRupees(priceOverride);

  /// The days as chips, in week order. Empty means "every day".
  List<String> get days => parseSlotDays(availableDays);

  String get daysLabel {
    final parsed = days;
    return parsed.length == employeeWeekDays.length
        ? 'All days'
        : parsed.join(', ');
  }

  @override
  String toString() => 'EmployeeSlot($id, $timeLabel, $status)';
}

/// Week order, and the exact spellings the API stores.
const List<String> employeeWeekDays = [
  'Mon',
  'Tue',
  'Wed',
  'Thu',
  'Fri',
  'Sat',
  'Sun',
];

/// `"Wed,Mon"` → `["Mon", "Wed"]`. A null or blank string is every day, which
/// is how the rest of the system reads "no day restriction".
List<String> parseSlotDays(String? raw) {
  final text = raw?.trim();
  if (text == null || text.isEmpty) return List.of(employeeWeekDays);

  final parts = text
      .split(',')
      .map((p) => p.trim().toLowerCase())
      .where((p) => p.isNotEmpty)
      .map((p) => p.length > 3 ? p.substring(0, 3) : p)
      .toSet();

  return employeeWeekDays
      .where((d) => parts.contains(d.toLowerCase()))
      .toList(growable: false);
}

/// The inverse: every day (or none picked) is stored as null.
String? encodeSlotDays(Iterable<String> selected) {
  final days = employeeWeekDays.where(selected.contains).toList();
  if (days.isEmpty || days.length == employeeWeekDays.length) return null;
  return days.join(',');
}

/// The fields the slot form writes.
class EmployeeSlotDraft {
  const EmployeeSlotDraft({
    required this.startTime,
    required this.endTime,
    this.slotType = 'Regular',
    this.priceOverride,
    this.days = employeeWeekDays,
    this.status = 'Active',
  });

  /// `HH:mm` from the time picker; the API wants seconds, added on the way out.
  final String startTime;
  final String endTime;

  final String slotType;
  final num? priceOverride;
  final List<String> days;
  final String status;

  Map<String, dynamic> toBody() => {
        'startTime': _withSeconds(startTime),
        'endTime': _withSeconds(endTime),
        'slotType': slotType,
        'priceOverride': priceOverride,
        'availableDays': encodeSlotDays(days),
        'status': status,
      };

  static String _withSeconds(String time) {
    final text = time.trim();
    return text.split(':').length >= 3 ? text : '$text:00';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Blocked slots (a court's availability on one date)
// ─────────────────────────────────────────────────────────────────────────────

/// One slot's state on a **specific date**, from
/// `GET /courts/{id}/available-slots?date=`.
///
/// Distinct from [EmployeeSlot], which is the recurring template. A row here
/// says what is happening to that template on the chosen day.
class EmployeeAvailableSlot {
  const EmployeeAvailableSlot({
    required this.id,
    this.startTime = '',
    this.endTime = '',
    this.slotType = 'Regular',
    this.price = 0,
    this.isBooked = false,
    this.isUserBooked = false,
    this.isBlocked = false,
    this.blockedBy,
    this.blockId,
  });

  final int id;
  final String startTime;
  final String endTime;
  final String slotType;
  final num price;

  /// Unavailable for **any** reason — a customer booking or a block.
  final bool isBooked;

  /// A paying customer holds it. Never blockable or releasable from here; the
  /// booking has to be cancelled instead.
  final bool isUserBooked;

  final bool isBlocked;

  /// `Admin` | `KheloMore` | `Huddle` | `Template` | null.
  final String? blockedBy;

  final int? blockId;

  /// Held by an aggregator feed. Releasable — the venue must never be locked
  /// out of its own courts by a partner.
  bool get isPartnerBlock =>
      isBlocked &&
      (blockedBy ?? '').isNotEmpty &&
      blockedBy != 'Admin' &&
      blockedBy != 'Template';

  /// The legacy all-dates block: the slot **template** was set Inactive, so
  /// there is no date row to release. Unblocking it reopens every date, which
  /// is why the UI confirms first.
  bool get isRecurringBlock => blockedBy == 'Template';

  String get timeLabel {
    final from = formatClock(startTime);
    final to = formatClock(endTime);
    if (from == null && to == null) return '—';
    if (to == null) return from!;
    if (from == null) return to;
    return '$from – $to';
  }

  String get stateLabel {
    if (isUserBooked) return 'Booked by user';
    if (isPartnerBlock) return 'Blocked by $blockedBy';
    if (isBlocked) return 'Blocked';
    return 'Available';
  }

  @override
  String toString() => 'EmployeeAvailableSlot($id, $timeLabel, $stateLabel)';
}

// ─────────────────────────────────────────────────────────────────────────────
// Batch
// ─────────────────────────────────────────────────────────────────────────────

/// A coaching batch, from `GET /batches`.
class EmployeeBatch {
  const EmployeeBatch({
    required this.id,
    this.name = '',
    this.sportId,
    this.sportName = '',
    this.coachId,
    this.coachName = '',
    this.schedule,
    this.days,
    this.startDate,
    this.endDate,
    this.maxStudents,
    this.currentStudents,
    this.fees = 0,
    this.status = 'Active',
  });

  final int id;
  final String name;
  final int? sportId;
  final String sportName;

  /// Null when the batch is unassigned, which is allowed.
  final int? coachId;
  final String coachName;

  /// Free text — `6:00 AM - 7:30 AM`.
  final String? schedule;

  /// Free text — `Mon,Wed,Fri`. Unlike a slot's `availableDays` this is not
  /// parsed anywhere; the API stores whatever is typed.
  final String? days;

  final DateTime? startDate;
  final DateTime? endDate;

  final int? maxStudents;
  final int? currentStudents;

  final num fees;

  /// `Active` | `Inactive` | `Completed` | `Cancelled`.
  final String status;

  bool get isActive => status.toLowerCase() == 'active';

  String get displayName => name.trim().isEmpty ? 'Batch #$id' : name.trim();

  String get feesLabel => formatRupees(fees);

  /// `12/20`, or just the head count when there is no cap.
  String get occupancyLabel {
    final current = currentStudents ?? 0;
    final max = maxStudents;
    return max == null ? '$current' : '$current/$max';
  }

  bool get isFull {
    final max = maxStudents;
    if (max == null) return false;
    return (currentStudents ?? 0) >= max;
  }

  /// `6:00 AM - 7:30 AM` when set, else the day string, else an em dash.
  String get scheduleLabel {
    final s = schedule?.trim();
    if (s != null && s.isNotEmpty) return s;
    final d = days?.trim();
    if (d != null && d.isNotEmpty) return d;
    return '—';
  }

  String get startLabel => formatDay(startDate);
  String get endLabel => formatDay(endDate);

  @override
  String toString() => 'EmployeeBatch($id, $displayName, $status)';
}

/// The statuses the batch form offers — a superset of the two every other
/// module uses, because a batch can also be finished or called off.
const List<String> employeeBatchStatuses = [
  'Active',
  'Inactive',
  'Completed',
  'Cancelled',
];

/// The two-state status the sport, court and slot forms use.
const List<String> employeeActiveStatuses = ['Active', 'Inactive'];
