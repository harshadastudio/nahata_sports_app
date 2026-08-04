import '../../domain/entities/batch.dart';
import 'json_reader.dart';

/// Maps `/batches` JSON onto [AdminBatch].
///
/// The same batch comes back with slightly different nested shapes depending on
/// the route — `/batches` embeds the sport image, `/batches/sport/{id}` embeds
/// the coach's ground, `/batches/{id}` embeds the coach's experience — so every
/// field is read through an ordered list of candidate keys and then out of the
/// nested `sport` / `coach` objects.
class BatchMapper {
  const BatchMapper._();

  static AdminBatch fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    final sport = _nested(source, const ['sport', 'sportInfo']);
    final coach = _nested(source, const ['coach', 'coachInfo']);
    final complex = _nested(source, const [
      'sportComplex',
      'sport_complex',
      'sportsComplex',
      'complex',
    ]);

    return AdminBatch(
      id: JsonReader.integer(source, const ['id', '_id', 'batchId']) ?? 0,
      name: JsonReader.string(source, const ['name', 'batchName', 'title']),
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
          JsonReader.string(source, const [
            'sportName',
            'sport_name',
          ]) ??
          (sport == null
              ? null
              : JsonReader.string(sport, const ['name', 'title'])),
      coachId:
          JsonReader.integer(source, const ['coachId', 'coach_id']) ??
          (coach == null
              ? null
              : JsonReader.integer(coach, const ['id', '_id'])),
      coachName:
          JsonReader.string(source, const [
            'coachName',
            'coach_name',
          ]) ??
          (coach == null
              ? null
              : JsonReader.string(coach, const ['name', 'title'])),
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
              : JsonReader.string(complex, const ['name', 'title'])) ??
          // `/batches/sport/{id}` carries the venue only as the coach's ground.
          (coach == null
              ? null
              : JsonReader.string(coach, const ['ground', 'groundName'])),
      schedule: JsonReader.string(source, const ['schedule', 'timing']),
      daysRaw: _days(source),
      startDate: JsonReader.date(source, const ['startDate', 'start_date']),
      endDate: JsonReader.date(source, const ['endDate', 'end_date']),
      startTime: JsonReader.string(source, const ['startTime', 'start_time']),
      endTime: JsonReader.string(source, const ['endTime', 'end_time']),
      maxStudents: JsonReader.integer(source, const [
        'maxStudents',
        'max_students',
        'capacity',
        'totalSeats',
      ]),
      currentStudents: JsonReader.integer(source, const [
        'currentStudents',
        'current_students',
        'enrolledStudents',
        'studentCount',
      ]),
      fees: number(
        JsonReader.pick(source, const ['fees', 'fee', 'price', 'amount']),
      ),
      ageGroup: JsonReader.string(source, const [
        'ageGroup',
        'age_group',
        'ageRange',
      ]),
      duration: JsonReader.string(source, const ['duration', 'courseDuration']),
      description: JsonReader.string(source, const ['description', 'about']),
      features: _features(source),
      statusRaw: JsonReader.string(source, const ['status', 'batchStatus']),
      createdAt: JsonReader.date(source, const [
        'createdAt',
        'created_at',
        'createdOn',
      ]),
      raw: source,
    );
  }

  /// `GET /batches` — the list plus its pagination meta.
  ///
  /// The documented shape is `{ batches, currentPage, totalPages, totalItems,
  /// itemsPerPage }`, but a route that answers with a bare list still works:
  /// the result then describes a single page holding everything it returned,
  /// so the pagination bar stays truthful either way.
  static BatchPageResult pageFrom(
    Object? body, {
    required int requestedPage,
    required int requestedLimit,
  }) {
    final batches = listFrom(body);

    final meta = body is Map ? Map<String, dynamic>.from(body) : null;
    final envelope = meta == null ? null : _metaEnvelope(meta);

    final page =
        (envelope == null
            ? null
            : JsonReader.integer(envelope, const [
                'currentPage',
                'current_page',
                'page',
              ])) ??
        requestedPage;

    final total =
        (envelope == null
            ? null
            : JsonReader.integer(envelope, const [
                'totalItems',
                'total_items',
                'total',
                'count',
              ])) ??
        batches.length;

    final perPage =
        (envelope == null
            ? null
            : JsonReader.integer(envelope, const [
                'itemsPerPage',
                'items_per_page',
                'perPage',
                'limit',
                'pageSize',
              ])) ??
        requestedLimit;

    final totalPages =
        (envelope == null
            ? null
            : JsonReader.integer(envelope, const [
                'totalPages',
                'total_pages',
                'pages',
                'lastPage',
              ])) ??
        // Derived rather than assumed to be 1: a route that sends a total but
        // no page count would otherwise hide every page after the first.
        (perPage > 0 && total > 0 ? (total / perPage).ceil() : 1);

    return BatchPageResult(
      batches: batches,
      page: page,
      totalPages: totalPages < 1 ? 1 : totalPages,
      totalItems: total,
      perPage: perPage < 1 ? requestedLimit : perPage,
    );
  }

  static List<AdminBatch> listFrom(Object? body) {
    return JsonReader.records(
          body,
          keys: const ['batches', 'items', 'data', 'results', 'records'],
        )
        .map(fromJson)
        .where((batch) => batch.id != 0)
        .toList(growable: false);
  }

  static AdminBatch? maybeFromBody(Object? body) {
    if (body is! Map) return null;
    final batch = fromJson(Map<String, dynamic>.from(body));
    return batch.id == 0 ? null : batch;
  }

  /// The URL returned by `POST /batches/upload-image`.
  ///
  /// The route may answer with a bare string, or with the URL under any of a
  /// handful of keys — all of which are accepted rather than guessed at.
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

    // One more level down, for `{ "data": { "image": ... } }`.
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

  /// Days arrive either as the documented comma-separated string or as a list.
  /// A list is joined into the same form, so both shapes read back identically
  /// through `CoachAvailability`.
  static String? _days(Map<String, dynamic> json) {
    final value = JsonReader.pick(json, const [
      'days',
      'weekDays',
      'week_days',
      'scheduleDays',
    ]);
    if (value == null) return null;
    if (value is String) {
      final text = value.trim();
      if (text.isEmpty) return null;
      // Normalises `"Monday,Tuesday"` to `"Monday, Tuesday"` for display; the
      // parser accepts either.
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

  static List<String> _features(Map<String, dynamic> json) {
    for (final key in const ['features', 'inclusions', 'highlights']) {
      final value = json[key];
      if (value == null) continue;
      final list = JsonReader.asStringList(value);
      if (list.isNotEmpty) return list;
    }
    return const [];
  }

  /// A number that may arrive as `2500`, `"2500.00"` or `"₹2,500"`, and must
  /// not become 0 just because it was unparseable.
  static num? number(Object? value) {
    if (value == null) return null;
    if (value is num) return value;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    return num.tryParse(text.replaceAll(RegExp(r'[^0-9.\-]'), ''));
  }

  /// Where the pagination counters live — beside the list, or inside a meta
  /// block, or one level down in `data`.
  static Map<String, dynamic>? _metaEnvelope(Map<String, dynamic> body) {
    for (final key in const ['meta', 'pagination', 'pageInfo']) {
      final value = body[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    if (body.containsKey('currentPage') ||
        body.containsKey('totalPages') ||
        body.containsKey('totalItems')) {
      return body;
    }
    final data = body['data'];
    if (data is Map) return _metaEnvelope(Map<String, dynamic>.from(data));
    return null;
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
    for (final key in const ['batch', 'data', 'result']) {
      final inner = json[key];
      if (inner is Map) {
        final unwrapped = Map<String, dynamic>.from(inner);
        for (final nested in const ['batch', 'data']) {
          final deeper = unwrapped[nested];
          if (deeper is Map) return Map<String, dynamic>.from(deeper);
        }
        return unwrapped;
      }
    }
    return json;
  }
}

/// Maps `GET /batches/{batchId}/stats`.
class BatchStatsMapper {
  const BatchStatsMapper._();

  static BatchStatistics fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    return BatchStatistics(
      batchName: JsonReader.string(source, const ['batchName', 'name']),
      // The route sends these as plain strings, not as nested objects.
      sportName: _label(source, const ['sport', 'sportName']),
      coachName: _label(source, const ['coach', 'coachName']),
      maxStudents: JsonReader.integer(source, const [
        'maxStudents',
        'max_students',
        'capacity',
      ]),
      currentStudents: JsonReader.integer(source, const [
        'currentStudents',
        'current_students',
      ]),
      enrolledStudents: JsonReader.integer(source, const [
        'enrolledStudents',
        'enrolled_students',
        'enrollments',
      ]),
      availableSlots: JsonReader.integer(source, const [
        'availableSlots',
        'available_slots',
        'availableSeats',
        'remainingSlots',
      ]),
      occupancyPercentage: JsonReader.integer(source, const [
        'occupancyPercentage',
        'occupancy_percentage',
        'occupancy',
      ]),
      fees: BatchMapper.number(
        JsonReader.pick(source, const ['fees', 'fee', 'price']),
      ),
      statusRaw: JsonReader.string(source, const ['status', 'batchStatus']),
      startDate: JsonReader.date(source, const ['startDate', 'start_date']),
      endDate: JsonReader.date(source, const ['endDate', 'end_date']),
    );
  }

  /// Reads a value that is a plain string on this route but an object on the
  /// list route, so the drawer fills either way.
  static String? _label(Map<String, dynamic> json, List<String> keys) {
    final value = JsonReader.pick(json, keys);
    if (value == null) return null;
    if (value is Map) {
      return JsonReader.string(Map<String, dynamic>.from(value), const [
        'name',
        'title',
      ]);
    }
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    for (final key in const ['stats', 'statistics', 'data', 'result']) {
      final inner = json[key];
      if (inner is Map) {
        final unwrapped = Map<String, dynamic>.from(inner);
        final deeper = unwrapped['stats'];
        if (deeper is Map) return Map<String, dynamic>.from(deeper);
        return unwrapped;
      }
    }
    return json;
  }
}
