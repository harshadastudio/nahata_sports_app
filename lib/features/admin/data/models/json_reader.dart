/// Tolerant readers for the admin payloads.
///
/// The API mixes `snake_case` and `camelCase` between routes (`join_date` on
/// one, `joinedAt` on another) and sends numbers as both `int` and `"12"`.
/// Rather than guessing one spelling and silently rendering blanks, every
/// mapper reads through these helpers with an ordered list of candidate keys.
class JsonReader {
  const JsonReader._();

  /// First non-null value among [keys], searched at the top level and then one
  /// level down inside a `data` / `user` / `attributes` envelope.
  static Object? pick(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null) return value;
    }
    for (final envelope in const ['data', 'user', 'attributes', 'profile']) {
      final inner = json[envelope];
      if (inner is Map) {
        for (final key in keys) {
          final value = inner[key];
          if (value != null) return value;
        }
      }
    }
    return null;
  }

  /// First non-null value among [keys], **at the top level only**.
  ///
  /// [pick] falls back into a `data` / `user` / `attributes` / `profile`
  /// envelope, which is right for display fields — a staff record that carries
  /// its person's name only inside a nested `user` should still fill the Name
  /// column. It is wrong for identifiers: a security guard row looks like
  /// `{ "id": 22, "userId": 585, "user": { "id": 585, … } }`, and inheriting
  /// `user.id` would make every `/{id}` call address the wrong record. Read
  /// ids through this.
  static Object? own(Map<String, dynamic> json, List<String> keys) {
    for (final key in keys) {
      final value = json[key];
      if (value != null) return value;
    }
    return null;
  }

  static String? ownString(Map<String, dynamic> json, List<String> keys) =>
      _text(own(json, keys));

  static int? ownInteger(Map<String, dynamic> json, List<String> keys) =>
      asInt(own(json, keys));

  static String? string(Map<String, dynamic> json, List<String> keys) =>
      _text(pick(json, keys));

  static String? _text(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    if (text.isEmpty || text == 'null') return null;
    return text;
  }

  static int? integer(Map<String, dynamic> json, List<String> keys) {
    final value = pick(json, keys);
    return asInt(value);
  }

  static int? asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString().trim());
  }

  static bool? boolean(Map<String, dynamic> json, List<String> keys) {
    final value = pick(json, keys);
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    switch (value.toString().trim().toLowerCase()) {
      case 'true':
      case '1':
      case 'yes':
      case 'verified':
        return true;
      case 'false':
      case '0':
      case 'no':
      case 'unverified':
        return false;
    }
    return null;
  }

  static DateTime? date(Map<String, dynamic> json, List<String> keys) {
    final value = pick(json, keys);
    if (value == null) return null;
    if (value is int) {
      // Seconds vs milliseconds — anything below ~year 2286 in ms is seconds.
      final ms = value < 100000000000 ? value * 1000 : value;
      return DateTime.fromMillisecondsSinceEpoch(ms);
    }
    final text = value.toString().trim();
    if (text.isEmpty) return null;
    final parsed = DateTime.tryParse(text);
    if (parsed != null) return parsed;
    // `dd-MM-yyyy` / `dd/MM/yyyy`, which the legacy routes still emit.
    final match = RegExp(
      r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})',
    ).firstMatch(text);
    if (match != null) {
      return DateTime.tryParse(
        '${match.group(3)}-${match.group(2)!.padLeft(2, '0')}-'
        '${match.group(1)!.padLeft(2, '0')}',
      );
    }
    return null;
  }

  /// A list of strings from either a real list or a comma-separated string.
  /// Objects in the list are reduced to their `name`/`title`/`label`.
  static List<String> stringList(Map<String, dynamic> json, List<String> keys) {
    final value = pick(json, keys);
    return asStringList(value);
  }

  static List<String> asStringList(Object? value) {
    if (value == null) return const [];
    if (value is String) {
      return value
          .split(',')
          .map((part) => part.trim())
          .where((part) => part.isNotEmpty)
          .toList(growable: false);
    }
    if (value is Iterable) {
      return value
          .map(_labelOf)
          .where((part) => part.isNotEmpty)
          .toList(growable: false);
    }
    return const [];
  }

  static String _labelOf(Object? entry) {
    if (entry == null) return '';
    if (entry is Map) {
      for (final key in const ['name', 'title', 'label', 'slug', 'sportName']) {
        final value = entry[key];
        if (value != null && value.toString().trim().isNotEmpty) {
          return value.toString().trim();
        }
      }
      return '';
    }
    return entry.toString().trim();
  }

  /// The list of records inside a paginated body, wherever the route put it.
  static List<Map<String, dynamic>> records(
    Object? body, {
    List<String> keys = const ['users', 'items', 'records', 'results', 'rows'],
  }) {
    if (body is List) return _cast(body);

    if (body is Map) {
      for (final key in keys) {
        final value = body[key];
        if (value is List) return _cast(value);
      }
      final data = body['data'];
      if (data is List) return _cast(data);
      if (data is Map) {
        for (final key in keys) {
          final value = data[key];
          if (value is List) return _cast(value);
        }
      }
    }
    return const [];
  }

  static List<Map<String, dynamic>> _cast(List<dynamic> list) {
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }

  /// The pagination meta block, wherever the route put it.
  static Map<String, dynamic> meta(Object? body) {
    if (body is! Map) return const {};
    for (final key in const ['meta', 'pagination', 'pageInfo']) {
      final value = body[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    final data = body['data'];
    if (data is Map) {
      for (final key in const ['meta', 'pagination', 'pageInfo']) {
        final value = data[key];
        if (value is Map) return Map<String, dynamic>.from(value);
      }
      // Counters sometimes sit beside the list rather than in a meta block.
      return Map<String, dynamic>.from(data);
    }
    return Map<String, dynamic>.from(body);
  }
}
