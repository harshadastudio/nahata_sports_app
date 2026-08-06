import '../../domain/entities/coupon.dart';
import '../../domain/entities/paged.dart';
import 'json_reader.dart';

/// Maps `/admin/coupons` and `/coupons/validate` JSON onto [AdminCoupon].
///
/// The customer-side `/coupons/active` payload was captured live (decimal
/// strings, `validUntil`, nullable `description`), and the admin routes are
/// documented in camelCase; both spellings are read here so one mapper serves
/// the console and the checkout alike.
class CouponMapper {
  const CouponMapper._();

  static const List<String> listKeys = [
    'coupons',
    'items',
    'data',
    'results',
    'rows',
  ];

  static AdminCoupon fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    final complex = _nested(source, const [
      'sportComplex',
      'sport_complex',
      'sportsComplex',
      'complex',
    ]);
    final sport = _nested(source, const ['sport', 'sportDetails']);
    final event = _nested(source, const ['eventPass', 'event_pass', 'event']);

    return AdminCoupon(
      // Top-level only: a row that embeds its sport or event must never
      // inherit that record's id.
      id: JsonReader.ownInteger(source, const ['id', '_id', 'couponId']) ?? 0,
      code: JsonReader.string(source, const [
        'code',
        'couponCode',
        'coupon_code',
      ]),
      description: JsonReader.string(source, const [
        'description',
        'details',
        'title',
      ]),
      discountTypeRaw: JsonReader.string(source, const [
        'discountType',
        'discount_type',
        'type',
      ]),
      discountValue: _number(source, const [
        'discountValue',
        'discount_value',
        'discount',
        'value',
      ]),
      maxDiscount: _number(source, const [
        'maxDiscount',
        'max_discount',
        'maxDiscountAmount',
      ]),
      minOrderAmount: _number(source, const [
        'minOrderAmount',
        'min_order_amount',
        'minOrderValue',
        'minPurchase',
      ]),
      appliesToRaw: JsonReader.string(source, const [
        'appliesTo',
        'applies_to',
        'scope',
      ]),
      platformRaw: JsonReader.string(source, const [
        'platform',
        'clientPlatform',
        'client_platform',
      ]),
      statusRaw: JsonReader.string(source, const ['status', 'couponStatus']),
      usageLimit: JsonReader.integer(source, const [
        'usageLimit',
        'usage_limit',
        'maxUses',
      ]),
      usedCount: JsonReader.integer(source, const [
        'usedCount',
        'used_count',
        'timesUsed',
        'redemptions',
      ]),
      validFrom: JsonReader.date(source, const [
        'validFrom',
        'valid_from',
        'startDate',
      ]),
      validUntil: JsonReader.date(source, const [
        'validUntil',
        'valid_until',
        'validTill',
        'valid_till',
        'validTo',
        'endDate',
        'expiryDate',
      ]),
      sportComplexId:
          JsonReader.integer(source, const [
            'sportComplexId',
            'sport_complex_id',
            'sportsComplexId',
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
      eventPassId:
          JsonReader.integer(source, const [
            'eventPassId',
            'event_pass_id',
            'eventId',
          ]) ??
          (event == null
              ? null
              : JsonReader.integer(event, const ['id', '_id'])),
      eventPassTitle:
          JsonReader.string(source, const [
            'eventPassTitle',
            'event_pass_title',
            'eventTitle',
          ]) ??
          (event == null
              ? null
              : JsonReader.string(event, const ['title', 'name'])),
      createdAt: JsonReader.date(source, const [
        'createdAt',
        'created_at',
        'createdDate',
      ]),
      raw: source,
    );
  }

  static List<AdminCoupon> listFrom(Object? body) {
    return JsonReader.records(body, keys: listKeys)
        .map(fromJson)
        // A row with no id cannot be opened, edited or deleted.
        .where((coupon) => coupon.id > 0)
        .toList(growable: false);
  }

  /// The rows the body contained, before any were dropped — used to tell "no
  /// coupons" apart from "this mapper could not read the rows".
  static List<Map<String, dynamic>> rowsIn(Object? body) =>
      JsonReader.records(body, keys: listKeys);

  static Paged<AdminCoupon> pageFrom(
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

    return Paged<AdminCoupon>(
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

  /// The single coupon inside a response body, or null when there is none.
  static AdminCoupon? maybeFromBody(Object? body) {
    if (body is! Map) return null;

    final map = Map<String, dynamic>.from(body);

    for (final key in const ['coupon', 'couponDetails']) {
      final nested = _findDeep(map, key);
      if (nested != null) {
        final coupon = fromJson(nested);
        if (coupon.id > 0 || (coupon.code ?? '').isNotEmpty) return coupon;
      }
    }

    final coupon = fromJson(map);
    // A bare `{success, message}` maps to an empty record — that is "no coupon
    // in this response", not a coupon with blank fields.
    if (coupon.id <= 0 && (coupon.code ?? '').trim().isEmpty) return null;
    return coupon;
  }

  /// Reads a `POST /coupons/validate` answer.
  ///
  /// The amounts sit beside the coupon's own fields in the captured payload
  /// (`{…, discountAmount, finalAmount, originalAmount}`), so they are read
  /// from the same object the coupon comes from.
  static CouponCheck checkFrom(
    Object? body, {
    required bool isValid,
    String? fallbackMessage,
  }) {
    final map = body is Map ? Map<String, dynamic>.from(body) : null;
    final payload = map == null ? null : _payloadOf(map);

    return CouponCheck(
      isValid: isValid,
      message:
          (map == null ? null : JsonReader.string(map, const ['message'])) ??
          fallbackMessage,
      coupon: payload == null ? null : maybeFromBody(payload),
      originalAmount: payload == null
          ? null
          : _number(payload, const ['originalAmount', 'original_amount']),
      discountAmount: payload == null
          ? null
          : _number(payload, const [
              'discountAmount',
              'discount_amount',
              'discount',
            ]),
      finalAmount: payload == null
          ? null
          : _number(payload, const [
              'finalAmount',
              'final_amount',
              'payableAmount',
            ]),
    );
  }

  static Map<String, dynamic>? _payloadOf(Map<String, dynamic> body) {
    final data = body['data'];
    if (data is Map) return Map<String, dynamic>.from(data);
    return body;
  }

  static num? _number(Map<String, dynamic> json, List<String> keys) {
    final value = JsonReader.pick(json, keys);
    if (value == null) return null;
    if (value is num) return value;
    // The live payload sends money as decimal strings ("10.00").
    return num.tryParse(value.toString().trim());
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
    for (final key in const ['coupon', 'data', 'result']) {
      final inner = json[key];
      if (inner is Map) {
        final unwrapped = Map<String, dynamic>.from(inner);
        for (final nested in const ['coupon', 'data']) {
          final deeper = unwrapped[nested];
          if (deeper is Map) return Map<String, dynamic>.from(deeper);
        }
        return unwrapped;
      }
    }
    return json;
  }
}
