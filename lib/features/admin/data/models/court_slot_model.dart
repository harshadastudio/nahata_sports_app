import '../../domain/entities/admin_role.dart';
import '../../domain/entities/court_slot.dart';
import 'court_model.dart';
import 'json_reader.dart';

/// Maps `/courts/{courtId}/slots` JSON onto [CourtSlot].
class CourtSlotMapper {
  const CourtSlotMapper._();

  static CourtSlot fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    return CourtSlot(
      id: JsonReader.integer(source, const ['id', '_id', 'slotId']) ?? 0,
      courtId: JsonReader.integer(source, const ['courtId', 'court_id']),
      startTimeRaw: JsonReader.string(source, const [
        'startTime',
        'start_time',
        'from',
        'slotStart',
      ]),
      endTimeRaw: JsonReader.string(source, const [
        'endTime',
        'end_time',
        'to',
        'slotEnd',
      ]),
      availableDaysRaw: _days(source),
      slotTypeRaw: JsonReader.string(source, const [
        'slotType',
        'slot_type',
        'type',
      ]),
      priceOverride: CourtMapper.number(
        JsonReader.pick(source, const [
          'priceOverride',
          'price_override',
          'customPrice',
          'price',
        ]),
      ),
      statusRaw: JsonReader.string(source, const ['status', 'slotStatus']),
      raw: source,
    );
  }

  static List<CourtSlot> listFrom(Object? body) {
    return JsonReader.records(
          body,
          keys: const ['slots', 'items', 'data', 'results', 'records'],
        )
        .map(fromJson)
        .where((slot) => slot.id != 0)
        .toList(growable: false);
  }

  static CourtSlot? maybeFromBody(Object? body) {
    if (body is! Map) return null;
    final slot = fromJson(Map<String, dynamic>.from(body));
    return slot.id == 0 ? null : slot;
  }

  /// The status a toggle settled on, when the response says. Null means the
  /// route answered without one, and the caller should re-read rather than
  /// assume.
  static AdminUserStatus? statusFrom(Object? body) {
    if (body is! Map) return null;
    final source = _unwrap(Map<String, dynamic>.from(body));

    final status = JsonReader.string(source, const ['status', 'slotStatus']);
    final parsed = AdminUserStatus.tryParse(status);
    if (parsed != null) return parsed;

    // Some toggles answer with a boolean instead of a status word.
    final blocked = JsonReader.boolean(source, const [
      'isBlocked',
      'blocked',
      'is_blocked',
    ]);
    if (blocked != null) {
      return blocked ? AdminUserStatus.inactive : AdminUserStatus.active;
    }

    final active = JsonReader.boolean(source, const [
      'isActive',
      'active',
      'bookable',
    ]);
    if (active != null) {
      return active ? AdminUserStatus.active : AdminUserStatus.inactive;
    }

    return null;
  }

  /// Days arrive either as a comma-separated string or as a list, normalised
  /// to the one form `CoachAvailability` reads.
  static String? _days(Map<String, dynamic> json) {
    final value = JsonReader.pick(json, const [
      'availableDays',
      'available_days',
      'days',
      'weekDays',
    ]);
    if (value == null) return null;
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return null;
      return text
          .split(',')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .join(', ');
    }
    if (value is Iterable) {
      final days = JsonReader.asStringList(value);
      return days.isEmpty ? null : days.join(', ');
    }
    return value.toString().trim();
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    for (final key in const ['slot', 'courtSlot', 'data', 'result']) {
      final inner = json[key];
      if (inner is Map) {
        final unwrapped = Map<String, dynamic>.from(inner);
        for (final nested in const ['slot', 'data']) {
          final deeper = unwrapped[nested];
          if (deeper is Map) return Map<String, dynamic>.from(deeper);
        }
        return unwrapped;
      }
    }
    return json;
  }
}

/// Maps `GET /courts/{courtId}/available-slots?date=`.
class AvailableSlotMapper {
  const AvailableSlotMapper._();

  static AvailableSlot fromJson(Map<String, dynamic> json) {
    return AvailableSlot(
      slotId: JsonReader.integer(json, const ['id', 'slotId', 'slot_id']),
      startTimeRaw: JsonReader.string(json, const [
        'startTime',
        'start_time',
        'from',
        'time',
      ]),
      endTimeRaw: JsonReader.string(json, const [
        'endTime',
        'end_time',
        'to',
      ]),
      isAvailable: JsonReader.boolean(json, const [
        'isAvailable',
        'is_available',
        'available',
        'bookable',
      ]),
      isBlocked: JsonReader.boolean(json, const [
        'isBlocked',
        'is_blocked',
        'blocked',
      ]),
      statusRaw: JsonReader.string(json, const ['status', 'slotStatus']),
      price: CourtMapper.number(
        JsonReader.pick(json, const ['price', 'amount', 'priceOverride']),
      ),
      raw: json,
    );
  }

  static List<AvailableSlot> listFrom(Object? body) {
    return JsonReader.records(
          body,
          keys: const [
            'availableSlots',
            'available_slots',
            'slots',
            'items',
            'data',
            'results',
          ],
        )
        .map(fromJson)
        .toList(growable: false);
  }
}

/// Maps `GET /courts/availability`.
///
/// The route is documented as answering without naming courts, so the mapper
/// reads only the window and the counters — a court name in the payload is
/// deliberately ignored rather than surfaced.
class AvailabilityMapper {
  const AvailabilityMapper._();

  static AvailabilityWindow fromJson(Map<String, dynamic> json) {
    return AvailabilityWindow(
      startTimeRaw: JsonReader.string(json, const [
        'startTime',
        'start_time',
        'from',
        'time',
      ]),
      endTimeRaw: JsonReader.string(json, const [
        'endTime',
        'end_time',
        'to',
      ]),
      availableCourts: JsonReader.integer(json, const [
        'availableCourts',
        'available_courts',
        'availableCount',
        'available',
        'count',
      ]),
      totalCourts: JsonReader.integer(json, const [
        'totalCourts',
        'total_courts',
        'total',
      ]),
      raw: json,
    );
  }

  static List<AvailabilityWindow> listFrom(Object? body) {
    return JsonReader.records(
          body,
          keys: const [
            'availability',
            'availableSlots',
            'slots',
            'windows',
            'items',
            'data',
            'results',
          ],
        )
        .map(fromJson)
        .where((window) => window.startTimeRaw != null)
        .toList(growable: false);
  }
}
