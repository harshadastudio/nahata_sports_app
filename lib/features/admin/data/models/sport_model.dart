import '../../domain/entities/sport.dart';
import 'json_reader.dart';

/// Maps `/sports` JSON onto [Sport].
class SportMapper {
  const SportMapper._();

  static Sport fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    final complex = _nested(source, const [
      'sportComplex',
      'sport_complex',
      'sportsComplex',
      'complex',
      'ground',
    ]);

    // Programmes arrive either as a counter, as a list of names, or as a list
    // of objects — all three are read so the row badge and its tooltip are
    // filled from whichever shape this route uses.
    final programs = _programNames(source);

    return Sport(
      id: JsonReader.integer(source, const ['id', '_id', 'sportId']) ?? 0,
      name: JsonReader.string(source, const [
        'name',
        'sportName',
        'title',
      ]),
      image: JsonReader.string(source, const [
        'image',
        'imageUrl',
        'image_url',
        'photo',
        'coverImage',
      ]),
      sportComplexId:
          JsonReader.integer(source, const [
            'sportComplexId',
            'sport_complex_id',
            'sportsComplexId',
            'complexId',
            'groundId',
          ]) ??
          (complex == null
              ? null
              : JsonReader.integer(complex, const ['id', '_id'])),
      sportComplexName:
          JsonReader.string(source, const [
            'sportComplexName',
            'sport_complex_name',
            'complexName',
            'groundName',
          ]) ??
          (complex == null
              ? null
              : JsonReader.string(complex, const ['name', 'title'])),
      categoryRaw: JsonReader.string(source, const [
        'category',
        'sportCategory',
        'type',
      ]),
      description: JsonReader.string(source, const ['description', 'about']),
      equipmentRequired: JsonReader.string(source, const [
        'equipmentRequired',
        'equipment_required',
        'equipment',
      ]),
      achievements: JsonReader.string(source, const [
        'achievements',
        'achievement',
      ]),
      completeInformation: JsonReader.string(source, const [
        'completeInformation',
        'complete_information',
        'fullInformation',
        'details',
      ]),
      minAge: JsonReader.integer(source, const ['minAge', 'min_age', 'ageFrom']),
      maxAge: JsonReader.integer(source, const ['maxAge', 'max_age', 'ageTo']),
      duration: JsonReader.string(source, const [
        'duration',
        'sessionDuration',
        'session_duration',
      ]),
      allowedMembers: JsonReader.integer(source, const [
        'allowedMembers',
        'allowed_members',
        'maxMembers',
        'capacity',
      ]),
      statusRaw: JsonReader.string(source, const ['status', 'sportStatus']),
      showOnFrontend: JsonReader.boolean(source, const [
        'showOnFrontend',
        'show_on_frontend',
        'showOnFront',
        'isVisible',
        'visible',
      ]),
      programCount:
          JsonReader.integer(source, const [
            'programCount',
            'program_count',
            'totalPrograms',
            'programsCount',
            'batchCount',
            'totalBatches',
          ]) ??
          (programs.isEmpty ? null : programs.length),
      courtCount: JsonReader.integer(source, const [
        'courtCount',
        'court_count',
        'totalCourts',
        'courtsCount',
      ]),
      availableCourts: JsonReader.integer(source, const [
        'availableCourts',
        'available_courts',
        'activeCourts',
        'freeCourts',
      ]),
      programNames: programs,
      createdAt: JsonReader.date(source, const [
        'createdAt',
        'created_at',
        'createdOn',
      ]),
      raw: source,
    );
  }

  static List<Sport> listFrom(Object? body) {
    return JsonReader.records(
          body,
          keys: const [
            'sports',
            'items',
            'data',
            'results',
            'records',
          ],
        )
        .map(fromJson)
        .where((sport) => sport.id != 0)
        .toList(growable: false);
  }

  static Sport? maybeFromBody(Object? body) {
    if (body is! Map) return null;
    final sport = fromJson(Map<String, dynamic>.from(body));
    return sport.id == 0 ? null : sport;
  }

  /// The URL returned by `POST /sports/upload-image`.
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

  /// Programme names, from a list of strings or of objects.
  static List<String> _programNames(Map<String, dynamic> json) {
    for (final key in const [
      'programs',
      'programmes',
      'programNames',
      'batches',
    ]) {
      final value = json[key];
      if (value is List) {
        final names = JsonReader.asStringList(value);
        if (names.isNotEmpty) return names;
      }
    }
    return const [];
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
    for (final key in const ['sport', 'data', 'result']) {
      final inner = json[key];
      if (inner is Map) {
        final unwrapped = Map<String, dynamic>.from(inner);
        for (final nested in const ['sport', 'data']) {
          final deeper = unwrapped[nested];
          if (deeper is Map) return Map<String, dynamic>.from(deeper);
        }
        return unwrapped;
      }
    }
    return json;
  }
}

/// Maps `GET /sports/{sportId}/stats`.
class SportStatsMapper {
  const SportStatsMapper._();

  static SportStats fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    return SportStats(
      totalPrograms: JsonReader.integer(source, const [
        'totalPrograms',
        'total_programs',
        'programs',
        'programCount',
        'totalBatches',
      ]),
      activePrograms: JsonReader.integer(source, const [
        'activePrograms',
        'active_programs',
        'activeBatches',
        'runningPrograms',
      ]),
      totalCourts: JsonReader.integer(source, const [
        'totalCourts',
        'total_courts',
        'courts',
        'courtCount',
      ]),
      totalStudents: JsonReader.integer(source, const [
        'totalStudents',
        'total_students',
        'students',
        'studentCount',
        'enrolledStudents',
      ]),
    );
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
