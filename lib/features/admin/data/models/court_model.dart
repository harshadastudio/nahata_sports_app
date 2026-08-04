import '../../domain/entities/court.dart';
import 'json_reader.dart';

/// Maps `/courts` JSON onto [Court].
///
/// The nested associations arrive under Sequelize's own model names as well as
/// the camelCase ones — the storefront's `BookedCourt` already reads
/// `SportComplex` with a capital S from a live payload — so both spellings are
/// candidates here.
class CourtMapper {
  const CourtMapper._();

  static Court fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    final sport = _nested(source, const ['Sport', 'sport', 'sportInfo']);
    final complex = _nested(source, const [
      'SportComplex',
      'sportComplex',
      'sport_complex',
      'sportsComplex',
      'complex',
    ]);

    return Court(
      id: JsonReader.integer(source, const ['id', '_id', 'courtId']) ?? 0,
      name: JsonReader.string(source, const ['name', 'courtName', 'title']),
      image: JsonReader.string(source, const [
        'image',
        'imageUrl',
        'image_url',
        'photo',
        'coverImage',
      ]),
      sportId:
          JsonReader.integer(source, const ['sportId', 'sport_id']) ??
          (sport == null
              ? null
              : JsonReader.integer(sport, const ['id', '_id'])),
      sportName:
          JsonReader.string(source, const ['sportName', 'sport_name']) ??
          (sport == null
              ? null
              : JsonReader.string(sport, const ['name', 'title'])),
      sportComplexId:
          JsonReader.integer(source, const [
            'sportComplexId',
            'sport_complex_id',
            'sportsComplexId',
            'complexId',
          ]) ??
          (complex == null
              ? null
              : JsonReader.integer(complex, const ['id', '_id'])),
      sportComplexName:
          JsonReader.string(source, const [
            'sportComplexName',
            'sport_complex_name',
            'complexName',
          ]) ??
          (complex == null
              ? null
              : JsonReader.string(complex, const ['name', 'title'])),
      description: JsonReader.string(source, const ['description', 'about']),
      capacity: JsonReader.integer(source, const [
        'capacity',
        'maxPlayers',
        'max_players',
        'maxCapacity',
      ]),
      surfaceType: JsonReader.string(source, const [
        'surfaceType',
        'surface_type',
        'surface',
      ]),
      lightingAvailable: JsonReader.boolean(source, const [
        'lightingAvailable',
        'lighting_available',
        'hasLighting',
        'lighting',
        'floodlights',
      ]),
      equipmentAvailable: _equipment(source),
      hourlyRate: number(
        JsonReader.pick(source, const [
          'hourlyRate',
          'hourly_rate',
          'pricePerHour',
          'rate',
          'price',
        ]),
      ),
      statusRaw: JsonReader.string(source, const ['status', 'courtStatus']),
      showOnFrontend: JsonReader.boolean(source, const [
        'showOnFrontend',
        'show_on_frontend',
        'showOnFront',
        'isVisible',
        'visible',
      ]),
      slotCount: JsonReader.integer(source, const [
        'slotCount',
        'slot_count',
        'totalSlots',
        'slotsCount',
      ]),
      availableSlotCount: JsonReader.integer(source, const [
        'availableSlots',
        'available_slots',
        'availableSlotCount',
        'freeSlots',
      ]),
      createdAt: JsonReader.date(source, const [
        'createdAt',
        'created_at',
        'createdOn',
      ]),
      raw: source,
    );
  }

  static List<Court> listFrom(Object? body) {
    return JsonReader.records(
          body,
          keys: const ['courts', 'items', 'data', 'results', 'records'],
        )
        .map(fromJson)
        .where((court) => court.id != 0)
        .toList(growable: false);
  }

  static Court? maybeFromBody(Object? body) {
    if (body is! Map) return null;
    final court = fromJson(Map<String, dynamic>.from(body));
    return court.id == 0 ? null : court;
  }

  /// The URL returned by the upload route, in any of the shapes the sibling
  /// upload routes use.
  static String? uploadedUrlFrom(Object? body) {
    if (body is String) {
      final text = body.trim();
      return text.isEmpty ? null : text;
    }
    if (body is! Map) return null;

    const keys = [
      'imageUrl',
      'image_url',
      'image',
      'url',
      'path',
      'location',
      'filename',
      'fileName',
    ];

    final source = Map<String, dynamic>.from(body);
    final direct = JsonReader.string(source, keys);
    if (direct != null) return direct;

    for (final key in const ['data', 'result', 'file']) {
      final inner = source[key];
      if (inner is Map) {
        final nested = JsonReader.string(
          Map<String, dynamic>.from(inner),
          keys,
        );
        if (nested != null) return nested;
      } else if (inner is String && inner.trim().isNotEmpty) {
        return inner.trim();
      }
    }
    return null;
  }

  /// Equipment is free text on the wire, but a route that sends a list is
  /// joined rather than dropped.
  static String? _equipment(Map<String, dynamic> json) {
    final value = JsonReader.pick(json, const [
      'equipmentAvailable',
      'equipment_available',
      'equipment',
      'amenities',
    ]);
    if (value == null) return null;
    if (value is String) {
      final text = value.trim();
      return text.isEmpty ? null : text;
    }
    if (value is Iterable) {
      final items = JsonReader.asStringList(value);
      return items.isEmpty ? null : items.join(', ');
    }
    if (value is bool) return value ? 'Yes' : 'No';
    return value.toString().trim();
  }

  /// A rate that may arrive as `800`, `"800.00"` or `"₹800"`, and must not
  /// become 0 just because it was unparseable.
  static num? number(Object? value) {
    if (value == null) return null;
    if (value is num) return value;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return num.tryParse(text.replaceAll(RegExp(r'[^0-9.\-]'), ''));
  }

  static Map<String, dynamic>? _nested(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = json[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return null;
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    for (final key in const ['court', 'data', 'result']) {
      final inner = json[key];
      if (inner is Map) {
        final unwrapped = Map<String, dynamic>.from(inner);
        for (final nested in const ['court', 'data']) {
          final deeper = unwrapped[nested];
          if (deeper is Map) return Map<String, dynamic>.from(deeper);
        }
        return unwrapped;
      }
    }
    return json;
  }
}
