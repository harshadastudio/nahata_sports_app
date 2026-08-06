import '../../domain/entities/coaching_enquiry.dart';
import '../../domain/entities/paged.dart';
import 'json_reader.dart';

/// Maps `/coaching-enquiries` JSON onto [CoachingEnquiry].
///
/// No response for these routes was captured, so every field is read through
/// an ordered list of candidate keys. The names lead with what the documented
/// request bodies use (`sportId`, `sportComplexId`, `message`), then the
/// spellings the two enquiry payloads this app already reads use — the coach's
/// own list and the dashboard's live-enquiries card.
class CoachingEnquiryMapper {
  const CoachingEnquiryMapper._();

  static const List<String> listKeys = [
    'enquiries',
    'coachingEnquiries',
    'coaching_enquiries',
    'inquiries',
    'items',
    'data',
    'results',
    'rows',
  ];

  static CoachingEnquiry fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    final sport = _nested(source, const ['sport', 'sportDetails']);
    final complex = _nested(source, const [
      'sportComplex',
      'sport_complex',
      'sportsComplex',
      'complex',
    ]);
    final coach = _nested(source, const [
      'assignedCoach',
      'assigned_coach',
      'coach',
    ]);
    final batch = _nested(source, const ['batch']);
    final user = _nested(source, const ['user', 'customer']);

    return CoachingEnquiry(
      // Top-level only: these rows embed the enquirer's `user` and often the
      // assigned `coach`, and inheriting either id would make every
      // `/{id}` call address the wrong record.
      id:
          JsonReader.ownInteger(source, const [
            'id',
            '_id',
            'enquiryId',
            'enquiry_id',
          ]) ??
          0,
      referenceNumber: JsonReader.string(source, const [
        'referenceNumber',
        'reference_number',
        'reference',
      ]),
      name:
          JsonReader.string(source, const [
            'name',
            'customerName',
            'customer_name',
            'fullName',
            'full_name',
          ]) ??
          (user == null
              ? null
              : JsonReader.string(user, const ['name', 'fullName'])),
      phone:
          JsonReader.string(source, const [
            'phone',
            'phoneNumber',
            'phone_number',
            'mobile',
            'contact',
          ]) ??
          (user == null
              ? null
              : JsonReader.string(user, const [
                  'phone',
                  'phoneNumber',
                  'phone_number',
                ])),
      email:
          JsonReader.string(source, const ['email', 'emailAddress']) ??
          (user == null ? null : JsonReader.string(user, const ['email'])),
      message: JsonReader.string(source, const [
        'message',
        'enquiry',
        'query',
        'description',
        'notes',
      ]),
      statusRaw: JsonReader.string(source, const [
        'status',
        'enquiryStatus',
        'enquiry_status',
        'currentStatus',
      ]),
      remarks: JsonReader.string(source, const [
        'remarks',
        'remark',
        'adminRemarks',
        'admin_remarks',
        'comment',
        'comments',
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
            'sportTitle',
          ]) ??
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
            'ground',
            'venue',
          ]) ??
          (complex == null
              ? null
              : JsonReader.string(complex, const ['name', 'title'])),
      assignedCoachId:
          JsonReader.ownInteger(source, const [
            'assignedCoachId',
            'assigned_coach_id',
            'coachId',
            'coach_id',
          ]) ??
          (coach == null
              ? null
              : JsonReader.integer(coach, const ['id', '_id'])),
      assignedCoachName:
          JsonReader.string(source, const [
            'assignedCoachName',
            'assigned_coach_name',
            'coachName',
            'coach_name',
          ]) ??
          (coach == null
              ? null
              : JsonReader.string(coach, const ['name', 'fullName'])),
      batchId:
          JsonReader.integer(source, const ['batchId', 'batch_id']) ??
          (batch == null
              ? null
              : JsonReader.integer(batch, const ['id', '_id'])),
      batchName:
          JsonReader.string(source, const ['batchName', 'batch_name']) ??
          (batch == null
              ? null
              : JsonReader.string(batch, const ['name', 'title'])),
      createdAt: JsonReader.date(source, const [
        'createdAt',
        'created_at',
        'createdDate',
        'enquiryDate',
        'date',
      ]),
      updatedAt: JsonReader.date(source, const [
        'updatedAt',
        'updated_at',
        'modifiedAt',
        'lastUpdated',
      ]),
      raw: source,
    );
  }

  static List<CoachingEnquiry> listFrom(Object? body) {
    return JsonReader.records(body, keys: listKeys)
        .map(fromJson)
        // A row with no id cannot be opened, updated or deleted.
        .where((enquiry) => enquiry.id > 0)
        .toList(growable: false);
  }

  /// The rows the body contained, before any were dropped — used to tell "no
  /// enquiries" apart from "this mapper could not read the rows".
  static List<Map<String, dynamic>> rowsIn(Object? body) =>
      JsonReader.records(body, keys: listKeys);

  static Paged<CoachingEnquiry> pageFrom(
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

    return Paged<CoachingEnquiry>(
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

  /// The single enquiry inside a response body, or null when there is none.
  static CoachingEnquiry? maybeFromBody(Object? body) {
    if (body is! Map) return null;

    final map = Map<String, dynamic>.from(body);

    for (final key in const [
      'enquiry',
      'coachingEnquiry',
      'coaching_enquiry',
    ]) {
      final nested = _findDeep(map, key);
      if (nested != null) {
        final enquiry = fromJson(nested);
        if (enquiry.id > 0) return enquiry;
      }
    }

    final enquiry = fromJson(map);
    // A bare `{success, message}` maps to an empty record — that is "no
    // enquiry in this response", not an enquiry with blank fields.
    if (enquiry.id <= 0 && (enquiry.name ?? '').trim().isEmpty) return null;
    return enquiry;
  }

  /// Reads `GET /coaching-enquiries/stats`.
  ///
  /// The counters are accepted either flat (`{total, new, contacted, …}`) or
  /// under a `byStatus` / `statusCounts` block, which is how the other stats
  /// routes in this backend group them.
  static CoachingEnquiryStats statsFrom(Object? body) {
    if (body is! Map) return const CoachingEnquiryStats();

    final map = Map<String, dynamic>.from(body);
    final payload = _statsPayload(map);
    final byStatus = _nested(payload, const [
      'byStatus',
      'by_status',
      'statusCounts',
      'status_counts',
      'statuses',
    ]);

    // A `byStatus` block is keyed by the status as the API writes it — `New`,
    // `Joined` — while the flat form uses lower-case field names. Lower-casing
    // the keys lets one candidate list read both.
    final grouped = byStatus == null
        ? null
        : <String, dynamic>{
            for (final entry in byStatus.entries)
              entry.key.toLowerCase(): entry.value,
          };

    int? read(List<String> keys) {
      final direct = JsonReader.integer(payload, keys);
      if (direct != null) return direct;
      if (grouped == null) return null;
      return JsonReader.integer(grouped, keys);
    }

    return CoachingEnquiryStats(
      total: read(const [
        'total',
        'totalEnquiries',
        'total_enquiries',
        'all',
        'count',
      ]),
      newCount: read(const [
        'new',
        'newCount',
        'new_count',
        'newEnquiries',
        'pending',
      ]),
      contacted: read(const ['contacted', 'contactedCount', 'contacted_count']),
      interested: read(const [
        'interested',
        'interestedCount',
        'interested_count',
      ]),
      joined: read(const [
        'joined',
        'joinedCount',
        'joined_count',
        'converted',
      ]),
      closed: read(const ['closed', 'closedCount', 'closed_count']),
      raw: payload,
    );
  }

  static Map<String, dynamic> _statsPayload(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map) {
      final inner = Map<String, dynamic>.from(data);
      final stats = inner['stats'];
      if (stats is Map) return Map<String, dynamic>.from(stats);
      return inner;
    }
    return body;
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
    // `user` is deliberately absent: the enquirer's record is a *field* of the
    // enquiry, not the enquiry itself.
    for (final key in const [
      'enquiry',
      'coachingEnquiry',
      'coaching_enquiry',
      'data',
      'result',
    ]) {
      final inner = json[key];
      if (inner is Map) {
        final unwrapped = Map<String, dynamic>.from(inner);
        for (final nested in const ['enquiry', 'coachingEnquiry', 'data']) {
          final deeper = unwrapped[nested];
          if (deeper is Map) return Map<String, dynamic>.from(deeper);
        }
        return unwrapped;
      }
    }
    return json;
  }
}
