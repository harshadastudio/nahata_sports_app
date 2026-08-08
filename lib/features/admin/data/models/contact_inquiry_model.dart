import '../../../../models/sports_complex_model.dart';
import '../../domain/entities/contact_inquiry.dart';
import '../../domain/entities/paged.dart';
import 'json_reader.dart';

/// Maps `GET /contact-us/admin` onto [ContactInquiryPage].
///
/// The envelope is captured, not guessed:
///
/// ```json
/// {"success": true, "data": {
///    "inquiries":   [ … ],
///    "pagination":  {"total": 1, "page": 1, "limit": 10, "totalPages": 1},
///    "statusCounts":{"new": 0, "read": 1, "replied": 0, "total": 1}}}
/// ```
///
/// Rows, counters and counts are three siblings under `data` — a shape no other
/// module in the console uses, which is why this mapper reads the envelope
/// itself rather than going through a shared page helper.
class ContactInquiryMapper {
  const ContactInquiryMapper._();

  /// Field names are read through [JsonReader] with camelCase **and**
  /// snake_case candidates, as everywhere else in this console: only one
  /// response has been seen, and a sibling route spelling `full_name` should
  /// not blank the column.
  static ContactInquiry? fromJson(Map<String, dynamic> json) {
    // Rows are keyed by a UUID string. A row with no id is dropped: it could
    // not be opened, and a synthetic key would collide the moment two arrived.
    final id = JsonReader.ownString(json, const ['id', 'inquiryId', 'uuid']);
    if (id == null || id.trim().isEmpty) return null;

    return ContactInquiry(
      id: id.trim(),
      fullName:
          JsonReader.string(json, const [
            'fullName',
            'full_name',
            'name',
            'senderName',
          ])?.trim() ??
          '',
      email: JsonReader.string(json, const ['email', 'emailAddress']),
      subject: JsonReader.string(json, const ['subject', 'title']),
      message: JsonReader.string(json, const ['message', 'body', 'enquiry']),
      statusRaw: JsonReader.string(json, const ['status', 'state']),
      referenceNumber: JsonReader.string(json, const [
        'referenceNumber',
        'reference_number',
        'reference',
        'ticketNumber',
      ]),
      sportComplexId: JsonReader.integer(json, const [
        'sportComplexId',
        'sport_complex_id',
        'complexId',
      ]),
      sportComplex: _complex(json),
      ipAddress: JsonReader.string(json, const ['ipAddress', 'ip_address', 'ip']),
      userAgent: JsonReader.string(json, const ['userAgent', 'user_agent']),
      createdAt: JsonReader.date(json, const ['createdAt', 'created_at']),
      updatedAt: JsonReader.date(json, const ['updatedAt', 'updated_at']),
      deletedAt: JsonReader.date(json, const ['deletedAt', 'deleted_at']),
    );
  }

  /// The nested venue. Read from the row's **own** `sportComplex` key rather
  /// than through a searching read, so a complex nested somewhere else in the
  /// payload cannot be mistaken for this row's.
  static SportsComplex? _complex(Map<String, dynamic> json) {
    final raw = JsonReader.own(json, const [
      'sportComplex',
      'sport_complex',
      'sportsComplex',
    ]);
    if (raw is! Map) return null;
    return SportsComplex.fromJson(Map<String, dynamic>.from(raw));
  }

  static List<ContactInquiry> listFrom(Object? data) {
    final records = JsonReader.records(
      data,
      keys: const ['inquiries', 'enquiries', 'contactInquiries', 'items'],
    );

    return records
        .map(fromJson)
        .whereType<ContactInquiry>()
        .toList(growable: false);
  }

  /// The whole answer: rows, pagination and status counts.
  ///
  /// [fallbackPage] and [fallbackLimit] are what was *asked for*, used when the
  /// payload omits its own — a response with no `pagination` should still know
  /// which page it is, or the pager would jump back to 1 on every load.
  static ContactInquiryPage pageFrom(
    Object? body, {
    int fallbackPage = 1,
    int fallbackLimit = 10,
  }) {
    final envelope = _envelope(body);
    final items = listFrom(envelope.isEmpty ? body : envelope);

    final pagination = _objectAt(envelope, const ['pagination', 'meta', 'page']);

    final total =
        JsonReader.integer(pagination, const ['total', 'totalItems', 'count']) ??
        items.length;
    final page =
        JsonReader.integer(pagination, const ['page', 'currentPage']) ??
        fallbackPage;
    final limit =
        JsonReader.integer(pagination, const ['limit', 'perPage', 'pageSize']) ??
        fallbackLimit;
    final totalPages =
        JsonReader.integer(pagination, const ['totalPages', 'pages']) ?? 0;

    return ContactInquiryPage(
      page: Paged<ContactInquiry>(
        items: items,
        page: page <= 0 ? fallbackPage : page,
        limit: limit <= 0 ? fallbackLimit : limit,
        total: total,
        totalPages: totalPages,
      ),
      counts: countsFrom(
        _objectAt(envelope, const ['statusCounts', 'status_counts', 'counts']),
      ),
    );
  }

  /// `data.statusCounts`. `new` is read under its wire spelling — the enum
  /// member is `isNew` only because Dart reserves the word.
  static ContactStatusCounts countsFrom(Map<String, dynamic> json) {
    int read(List<String> keys) => JsonReader.integer(json, keys) ?? 0;

    return ContactStatusCounts(
      isNew: read(const ['new', 'isNew', 'unread']),
      read: read(const ['read', 'seen']),
      replied: read(const ['replied', 'responded', 'answered']),
      total: read(const ['total', 'all', 'count']),
    );
  }

  /// The `data` object, or the body itself when the server did not wrap it.
  static Map<String, dynamic> _envelope(Object? body) {
    if (body is! Map) return const <String, dynamic>{};
    final map = Map<String, dynamic>.from(body);

    final inner = map['data'];
    if (inner is Map) return Map<String, dynamic>.from(inner);

    return map;
  }

  static Map<String, dynamic> _objectAt(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = source[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }
    return const <String, dynamic>{};
  }
}