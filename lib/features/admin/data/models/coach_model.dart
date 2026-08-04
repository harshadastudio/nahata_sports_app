import '../../domain/entities/coach.dart';
import 'json_reader.dart';

/// Maps `/coaches` JSON onto [Coach].
///
/// Like every other admin mapper, each field is read through an ordered list of
/// candidate keys (camelCase then snake_case then the legacy spellings), so a
/// route that names something differently still fills the column instead of
/// silently rendering an em dash.
class CoachMapper {
  const CoachMapper._();

  static Coach fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    final sport = _nested(source, const ['sport', 'primarySport', 'sportInfo']);
    final complex = _nested(source, const [
      'sportComplex',
      'sport_complex',
      'sportsComplex',
      'complex',
    ]);

    return Coach(
      id: JsonReader.integer(source, const ['id', '_id', 'coachId']) ?? 0,
      name: JsonReader.string(source, const ['name', 'coachName', 'fullName']),
      email: JsonReader.string(source, const ['email', 'emailAddress']),
      phone: JsonReader.string(source, const [
        'phone',
        'phoneNumber',
        'mobile',
        'contact',
      ]),
      image: JsonReader.string(source, const [
        'image',
        'imageUrl',
        'image_url',
        'photo',
        'profileImage',
        'avatar',
      ]),
      sportId:
          JsonReader.integer(source, const [
            'sportId',
            'sport_id',
            'primarySportId',
          ]) ??
          (sport == null
              ? null
              : JsonReader.integer(sport, const ['id', '_id'])),
      sportName:
          JsonReader.string(source, const [
            'sportName',
            'sport_name',
            'primarySport',
          ]) ??
          (sport == null
              ? null
              : JsonReader.string(sport, const ['name', 'title'])),
      sportNames: _sportNames(source),
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
      ground: JsonReader.string(source, const [
        'ground',
        'groundName',
        'ground_name',
        'court',
      ]),
      // The category describes the sport, so it is read off the coach payload
      // first and then out of a nested sport object.
      categoryRaw:
          JsonReader.string(source, const [
            'category',
            'sportCategory',
            'sport_category',
          ]) ??
          (sport == null
              ? null
              : JsonReader.string(sport, const ['category', 'type'])),
      experience: JsonReader.string(source, const [
        'experience',
        'experienceYears',
        'yearsOfExperience',
      ]),
      price: _number(
        JsonReader.pick(source, const [
          'price',
          'fee',
          'coachingFee',
          'hourlyRate',
        ]),
      ),
      certification: JsonReader.string(source, const [
        'certification',
        'certifications',
        'certificate',
      ]),
      qualifications: JsonReader.string(source, const [
        'qualifications',
        'qualification',
      ]),
      specialization: JsonReader.string(source, const [
        'specialization',
        'specialisation',
        'speciality',
        'specialty',
      ]),
      bio: JsonReader.string(source, const ['bio', 'about', 'description']),
      availabilityRaw: _availability(source),
      statusRaw: JsonReader.string(source, const ['status', 'coachStatus']),
      createdAt: JsonReader.date(source, const [
        'createdAt',
        'created_at',
        'createdOn',
        'joiningDate',
      ]),
      raw: source,
    );
  }

  static List<Coach> listFrom(Object? body) {
    return JsonReader.records(
          body,
          keys: const ['coaches', 'items', 'data', 'results', 'records'],
        )
        .map(fromJson)
        .where((coach) => coach.id != 0)
        .toList(growable: false);
  }

  static Coach? maybeFromBody(Object? body) {
    if (body is! Map) return null;
    final coach = fromJson(Map<String, dynamic>.from(body));
    return coach.id == 0 ? null : coach;
  }

  /// The URL returned by `POST /coaches/upload-image`.
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

  /// Availability arrives either as the documented string or as a list of days.
  /// A list is joined into the same comma-separated form the form writes, so
  /// both shapes read back identically through [CoachAvailability].
  static String? _availability(Map<String, dynamic> json) {
    final value = JsonReader.pick(json, const [
      'availability',
      'availableDays',
      'available_days',
      'schedule',
    ]);
    if (value == null) return null;
    if (value is String) {
      final text = value.trim();
      return text.isEmpty ? null : text;
    }
    if (value is Iterable) {
      final days = JsonReader.asStringList(value);
      return days.isEmpty ? null : days.join(', ');
    }
    return value.toString().trim();
  }

  /// Assigned sports, from a list of strings or of objects.
  static List<String> _sportNames(Map<String, dynamic> json) {
    for (final key in const [
      'sports',
      'assignedSports',
      'assigned_sports',
      'sportNames',
    ]) {
      final value = json[key];
      if (value is List) {
        final names = JsonReader.asStringList(value);
        if (names.isNotEmpty) return names;
      }
    }
    return const [];
  }

  /// A fee that may arrive as a number or as `"1200"`, and must not become 0
  /// just because it was unparseable.
  static num? _number(Object? value) {
    if (value == null) return null;
    if (value is num) return value;
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    // Strips a currency symbol and grouping so `"₹1,200"` still reads as 1200.
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
    for (final key in const ['coach', 'data', 'result']) {
      final inner = json[key];
      if (inner is Map) {
        final unwrapped = Map<String, dynamic>.from(inner);
        for (final nested in const ['coach', 'data']) {
          final deeper = unwrapped[nested];
          if (deeper is Map) return Map<String, dynamic>.from(deeper);
        }
        return unwrapped;
      }
    }
    return json;
  }
}

/// Maps `GET /coaches/{coachId}/stats`.
class CoachStatsMapper {
  const CoachStatsMapper._();

  static CoachStats fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    return CoachStats(
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
      totalStudents: JsonReader.integer(source, const [
        'totalStudents',
        'total_students',
        'students',
        'studentCount',
        'enrolledStudents',
      ]),
      statusRaw: JsonReader.string(source, const ['status', 'coachStatus']),
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

/// Maps `GET /coaches/{coachId}/password`.
class CoachCredentialsMapper {
  const CoachCredentialsMapper._();

  static CoachCredentials fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    return CoachCredentials(
      email: JsonReader.string(source, const ['email', 'emailAddress']),
      password: JsonReader.string(source, const [
        'temporaryPassword',
        'temporary_password',
        'tempPassword',
        'password',
        'plainPassword',
        'defaultPassword',
      ]),
    );
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    for (final key in const ['credentials', 'coach', 'data', 'result']) {
      final inner = json[key];
      if (inner is Map) return Map<String, dynamic>.from(inner);
    }
    return json;
  }
}
