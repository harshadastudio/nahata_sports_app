import '../../domain/entities/paged.dart';
import '../../domain/entities/visitor_pass.dart';
import 'json_reader.dart';

/// Maps `/visitor-passes` JSON onto [VisitorPass].
///
/// The module documents the request bodies in camelCase (`visitorName`,
/// `passCode`), and the responses ship with no captured example, so every field
/// is read through an ordered list of candidate keys — the snake_case spelling
/// of the same field is accepted everywhere rather than silently rendering a
/// blank column.
class VisitorPassMapper {
  const VisitorPassMapper._();

  /// Where a list of passes can be found in a response body.
  static const List<String> listKeys = [
    'visitorPasses',
    'visitor_passes',
    'passes',
    'visitors',
    'items',
    'data',
    'results',
    'rows',
  ];

  static VisitorPass fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    final complex = _nested(source, const [
      'sportComplex',
      'sport_complex',
      'sportsComplex',
      'complex',
    ]);
    final creator = _nested(source, const [
      'createdBy',
      'created_by',
      'generatedBy',
      'generated_by',
      'creator',
      'user',
    ]);

    return VisitorPass(
      // Top-level only: a row that embeds the issuing `user` would otherwise
      // inherit that person's id and every `/{id}` call would address the
      // wrong record.
      id:
          JsonReader.ownInteger(source, const [
            'id',
            '_id',
            'visitorPassId',
            'visitor_pass_id',
            'passId',
          ]) ??
          0,
      passCode: JsonReader.string(source, const [
        'passCode',
        'pass_code',
        'code',
        'visitorPassCode',
        'passcode',
      ]),
      visitorName: JsonReader.string(source, const [
        'visitorName',
        'visitor_name',
        'name',
        'fullName',
        'full_name',
      ]),
      phoneNumber: JsonReader.string(source, const [
        'phoneNumber',
        'phone_number',
        'phone',
        'mobile',
        'contact',
      ]),
      visitPurpose: JsonReader.string(source, const [
        'visitPurpose',
        'visit_purpose',
        'purpose',
        'reason',
      ]),
      statusRaw: JsonReader.string(source, const [
        'status',
        'passStatus',
        'pass_status',
        'currentStatus',
        'current_status',
        'state',
      ]),
      qrCode: JsonReader.string(source, const [
        'qrCode',
        'qr_code',
        'qrCodeUrl',
        'qr_code_url',
        'qrCodeImage',
        'qr_code_image',
        'qrImage',
        'qrData',
        'qr_data',
        'qr',
      ]),
      entryTime: JsonReader.date(source, const [
        'entryTime',
        'entry_time',
        'checkInTime',
        'check_in_time',
        'checkedInAt',
        'inTime',
        'in_time',
      ]),
      exitTime: JsonReader.date(source, const [
        'exitTime',
        'exit_time',
        'checkOutTime',
        'check_out_time',
        'checkedOutAt',
        'outTime',
        'out_time',
      ]),
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
            'venue',
          ]) ??
          (complex == null
              ? null
              : JsonReader.string(complex, const ['name', 'title'])),
      createdByName:
          JsonReader.string(source, const [
            'createdByName',
            'created_by_name',
            'generatedByName',
            'generated_by_name',
            'issuedBy',
          ]) ??
          (creator == null
              ? null
              : JsonReader.string(creator, const [
                  'name',
                  'fullName',
                  'full_name',
                  'email',
                ])) ??
          // A bare `createdBy: "Reception"` never becomes a nested map, so it
          // is read as text once the object form has been ruled out.
          (creator != null
              ? null
              : JsonReader.string(source, const ['createdBy', 'created_by'])),
      createdAt: JsonReader.date(source, const [
        'createdAt',
        'created_at',
        'generatedAt',
        'generated_at',
        'generatedDate',
        'issueDate',
        'date',
      ]),
      raw: source,
    );
  }

  static List<VisitorPass> listFrom(Object? body) {
    return JsonReader.records(body, keys: listKeys)
        .map(fromJson)
        // A row with neither an id nor a code cannot be opened, shared or
        // deleted, so it is dropped rather than shown as an inert card.
        .where((pass) => pass.hasReference)
        .toList(growable: false);
  }

  /// The rows the body contained, before any were dropped. Used to tell "the
  /// list is empty" apart from "the mapper could not read the list".
  static List<Map<String, dynamic>> rowsIn(Object? body) =>
      JsonReader.records(body, keys: listKeys);

  /// Builds the page from the documented envelope
  /// (`{data: [], total, page, limit}`), tolerating a `meta`/`pagination` block
  /// instead.
  static Paged<VisitorPass> pageFrom(
    Object? body, {
    required int fallbackPage,
    required int fallbackLimit,
  }) {
    final items = listFrom(body);
    final meta = JsonReader.meta(body);

    final total =
        JsonReader.integer(meta, const [
          'total',
          'totalItems',
          'totalRecords',
          'totalCount',
          'count',
        ]) ??
        items.length;

    final totalPages =
        JsonReader.integer(meta, const [
          'totalPages',
          'total_pages',
          'pageCount',
          'lastPage',
        ]) ??
        0;

    return Paged<VisitorPass>(
      items: items,
      page:
          JsonReader.integer(meta, const [
            'page',
            'currentPage',
            'current_page',
          ]) ??
          fallbackPage,
      limit:
          JsonReader.integer(meta, const [
            'limit',
            'perPage',
            'per_page',
            'pageSize',
          ]) ??
          fallbackLimit,
      total: total,
      totalPages: totalPages,
    );
  }

  /// The single pass inside a response body, or null when there is none.
  static VisitorPass? maybeFromBody(Object? body) {
    if (body is! Map) return null;

    final map = Map<String, dynamic>.from(body);

    // A verify/lookup response may answer with the pass under its own key
    // rather than directly inside `data`.
    for (final key in const [
      'visitorPass',
      'visitor_pass',
      'pass',
      'visitor',
    ]) {
      final nested = _findDeep(map, key);
      if (nested != null) {
        final pass = fromJson(nested);
        if (pass.hasReference || (pass.visitorName ?? '').isNotEmpty) {
          return pass;
        }
      }
    }

    final pass = fromJson(map);
    // The envelope alone (`{success, message}`) maps to an empty record — that
    // is "no pass in this response", not a pass with blank fields.
    if (!pass.hasReference &&
        (pass.visitorName ?? '').trim().isEmpty &&
        pass.statusRaw == null) {
      return null;
    }
    return pass;
  }

  /// Reads the check result out of a verify / lookup body.
  static VisitorPassCheck checkFrom(
    Object? body, {
    required bool readOnly,
    required bool success,
    VisitorScanType? scanType,
    String? fallbackMessage,
  }) {
    final map = body is Map ? Map<String, dynamic>.from(body) : null;

    return VisitorPassCheck(
      success: success,
      readOnly: readOnly,
      message:
          (map == null ? null : JsonReader.string(map, const ['message'])) ??
          fallbackMessage,
      pass: maybeFromBody(body),
      scanType:
          scanType ??
          (map == null
              ? null
              : VisitorScanType.tryParse(
                  JsonReader.pick(map, const ['scanType', 'scan_type']),
                )),
      valid: map == null
          ? null
          : JsonReader.boolean(map, const ['valid', 'isValid', 'is_valid']),
    );
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

  /// Finds [key] at the top level or one envelope down.
  static Map<String, dynamic>? _findDeep(
    Map<String, dynamic> json,
    String key,
  ) {
    final direct = json[key];
    if (direct is Map) return Map<String, dynamic>.from(direct);

    for (final envelope in const ['data', 'result']) {
      final inner = json[envelope];
      if (inner is Map) {
        final nested = inner[key];
        if (nested is Map) return Map<String, dynamic>.from(nested);
      }
    }
    return null;
  }

  static Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
    for (final key in const [
      'visitorPass',
      'visitor_pass',
      'pass',
      'data',
      'result',
    ]) {
      final inner = json[key];
      if (inner is Map) {
        final unwrapped = Map<String, dynamic>.from(inner);
        for (final nested in const ['visitorPass', 'visitor_pass', 'pass']) {
          final deeper = unwrapped[nested];
          if (deeper is Map) return Map<String, dynamic>.from(deeper);
        }
        return unwrapped;
      }
    }
    return json;
  }
}
