import '../../domain/entities/membership.dart';
import '../../domain/entities/paged.dart';
import 'court_model.dart';
import 'json_reader.dart';

/// Maps `/memberships` JSON onto [Membership].
///
/// The list envelope is documented for this module — `{success, message, data,
/// total, page, limit}`, counters at the top level beside the rows — but no
/// *sample row* was supplied, so every field reads through ordered candidate
/// keys (camelCase, snake_case, and the Sequelize association names).
class MembershipMapper {
  const MembershipMapper._();

  static Membership fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);
    final user = _nested(source, const ['user', 'User', 'member', 'customer']);
    final plan = _nested(source, const ['plan', 'Plan', 'membershipPlan']);

    return Membership(
      // Top-level only: a membership row embeds the member as `user`, and
      // inheriting `user.id` would make every `/{id}` call address the wrong
      // record — the bug the security-guard module was shipped with.
      id:
          JsonReader.ownString(source, const [
            'id',
            '_id',
            'membershipId',
            'membership_id',
          ]) ??
          '',
      userId:
          JsonReader.ownString(source, const ['userId', 'user_id']) ??
          (user == null
              ? null
              : JsonReader.string(user, const ['id', '_id'])),
      userName:
          JsonReader.string(source, const [
            'userName',
            'user_name',
            'memberName',
          ]) ??
          (user == null
              ? null
              : JsonReader.string(user, const ['name', 'fullName'])),
      userEmail:
          JsonReader.string(source, const ['userEmail', 'email']) ??
          (user == null ? null : JsonReader.string(user, const ['email'])),
      userPhone:
          JsonReader.string(source, const [
            'userPhone',
            'phone',
            'phoneNumber',
          ]) ??
          (user == null
              ? null
              : JsonReader.string(user, const [
                  'phone_number',
                  'phoneNumber',
                  'phone',
                ])),
      planId:
          JsonReader.string(source, const ['planId', 'plan_id', 'planCode']) ??
          (plan == null
              ? null
              : JsonReader.string(plan, const ['id', 'code'])),
      planName:
          JsonReader.string(source, const ['planName', 'plan_name']) ??
          (plan == null
              ? null
              : JsonReader.string(plan, const ['name', 'title'])),
      price: CourtMapper.number(
        JsonReader.pick(source, const ['price', 'planPrice', 'amount']),
      ),
      validityDays: JsonReader.integer(source, const [
        'validity',
        'validityDays',
        'validity_days',
        'durationDays',
      ]),
      bookingLimit: JsonReader.integer(source, const [
        'bookings',
        'bookingLimit',
        'booking_limit',
        'maxBookings',
      ]),
      bookingsUsed: JsonReader.integer(source, const [
        'bookingsUsed',
        'bookings_used',
        'usedBookings',
        'bookingsConsumed',
      ]),
      discountPercent: CourtMapper.number(
        JsonReader.pick(source, const [
          'discount',
          'discountPercent',
          'discount_percent',
        ]),
      ),
      discountApplied: CourtMapper.number(
        JsonReader.pick(source, const ['discountApplied', 'discount_applied']),
      ),
      totalAmount: CourtMapper.number(
        JsonReader.pick(source, const [
          'totalAmount',
          'total_amount',
          'finalAmount',
        ]),
      ),
      accessType: JsonReader.string(source, const ['accessType', 'access_type']),
      features: _features(source),
      startDate: JsonReader.date(source, const ['startDate', 'start_date']),
      endDate: JsonReader.date(source, const [
        'endDate',
        'end_date',
        'expiryDate',
        'expiry_date',
      ]),
      statusRaw: JsonReader.string(source, const [
        'status',
        'membershipStatus',
        'membership_status',
      ]),
      paymentStatusRaw: JsonReader.string(source, const [
        'paymentStatus',
        'payment_status',
      ]),
      autoRenew: JsonReader.boolean(source, const [
        'autoRenew',
        'auto_renew',
        'isAutoRenew',
      ]),
      cancellationReason: JsonReader.string(source, const [
        'cancellationReason',
        'cancellation_reason',
        'cancelReason',
        'reason',
      ]),
      createdAt: JsonReader.date(source, const ['createdAt', 'created_at']),
      updatedAt: JsonReader.date(source, const ['updatedAt', 'updated_at']),
      raw: source,
    );
  }

  static const List<String> listKeys = [
    'memberships',
    'Memberships',
    'items',
    'data',
    'results',
    'records',
    'rows',
  ];

  /// The rows the payload carried, before the id filter — lets the repository
  /// tell an empty list apart from a list it could not read.
  static List<Map<String, dynamic>> rowsIn(Object? body) =>
      JsonReader.records(body, keys: listKeys);

  static List<Membership> listFrom(Object? body) {
    return rowsIn(body)
        .map(fromJson)
        // A row with no id is inert: it cannot be opened, updated or deleted.
        .where((membership) => membership.id.isNotEmpty)
        .toList(growable: false);
  }

  static Membership? maybeFromBody(Object? body) {
    if (body is! Map) return null;
    final membership = fromJson(Map<String, dynamic>.from(body));
    return membership.id.isEmpty ? null : membership;
  }

  /// `GET /memberships` — `{data: [...], total, page, limit}`, with the
  /// counters at the top level rather than in a meta block. `meta`/`pagination`
  /// are still read as fallbacks, and a bare list degrades to one full page.
  static Paged<Membership> pageFrom(
    Object? body, {
    required int requestedPage,
    required int requestedLimit,
  }) {
    final items = listFrom(body);
    final counters = _counters(body);

    int? read(List<String> keys) =>
        counters == null ? null : JsonReader.integer(counters, keys);

    final page = read(const ['page', 'currentPage', 'current_page']) ??
        requestedPage;
    final limit =
        read(const ['limit', 'perPage', 'per_page', 'itemsPerPage', 'pageSize']) ??
        requestedLimit;
    final total =
        read(const ['total', 'totalItems', 'total_items', 'count']) ??
        items.length;
    final totalPages = read(const [
      'totalPages',
      'total_pages',
      'pages',
      'lastPage',
    ]);

    return Paged<Membership>(
      items: items,
      page: page < 1 ? 1 : page,
      limit: limit < 1 ? requestedLimit : limit,
      total: total,
      // Left at 0 when the route did not say: `Paged.effectiveTotalPages`
      // derives it from the total, and deriving beats guessing 1, which would
      // hide every page after the first.
      totalPages: totalPages ?? 0,
    );
  }

  /// Where this route put the counters.
  static Map<String, dynamic>? _counters(Object? body) {
    if (body is! Map) return null;
    final map = Map<String, dynamic>.from(body);

    for (final key in const ['pagination', 'meta', 'pageInfo']) {
      final value = map[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }

    // The documented shape: total/page/limit as siblings of `data`.
    if (map.containsKey('total') ||
        map.containsKey('page') ||
        map.containsKey('totalPages')) {
      return map;
    }

    final data = map['data'];
    if (data is Map) return _counters(data);
    return null;
  }

  static List<String> _features(Map<String, dynamic> json) {
    for (final key in const ['features', 'benefits', 'planFeatures']) {
      final value = json[key];
      if (value is List) {
        final features = value
            .map((entry) => entry?.toString().trim() ?? '')
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false);
        if (features.isNotEmpty) return features;
      }
      // Some backends store the list as one comma- or newline-separated string.
      if (value is String && value.trim().isNotEmpty) {
        final features = value
            .split(RegExp(r'[\r\n,]+'))
            .map((entry) => entry.trim())
            .where((entry) => entry.isNotEmpty)
            .toList(growable: false);
        if (features.isNotEmpty) return features;
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
    for (final key in const ['membership', 'data', 'result']) {
      final inner = json[key];
      if (inner is Map) {
        final unwrapped = Map<String, dynamic>.from(inner);
        for (final nested in const ['membership', 'data']) {
          final deeper = unwrapped[nested];
          if (deeper is Map) return Map<String, dynamic>.from(deeper);
        }
        return unwrapped;
      }
    }
    return json;
  }
}

/// Maps `/memberships/stats` onto [MembershipStats].
class MembershipStatsMapper {
  const MembershipStatsMapper._();

  static MembershipStats fromJson(Object? body) {
    if (body is! Map) return const MembershipStats();
    var source = Map<String, dynamic>.from(body);

    final data = source['data'];
    if (data is Map) source = Map<String, dynamic>.from(data);

    final stats = source['stats'];
    if (stats is Map) source = Map<String, dynamic>.from(stats);

    // Counters are sometimes grouped per status rather than flattened.
    final byStatus = source['byStatus'] ?? source['statusCounts'];
    final grouped = byStatus is Map
        ? Map<String, dynamic>.from(byStatus)
        : const <String, dynamic>{};

    int? count(List<String> keys, String groupedKey) =>
        JsonReader.integer(source, keys) ??
        (grouped.isEmpty
            ? null
            : JsonReader.integer(grouped, [
                groupedKey,
                groupedKey.toLowerCase(),
                groupedKey.toUpperCase(),
              ]));

    return MembershipStats(
      total: count(const [
        'total',
        'totalMemberships',
        'total_memberships',
        'count',
      ], 'Total'),
      active: count(const [
        'active',
        'activeMemberships',
        'active_memberships',
      ], 'Active'),
      inactive: count(const [
        'inactive',
        'inactiveMemberships',
        'inactive_memberships',
      ], 'Inactive'),
      expired: count(const [
        'expired',
        'expiredMemberships',
        'expired_memberships',
      ], 'Expired'),
      cancelled: count(const [
        'cancelled',
        'canceled',
        'cancelledMemberships',
        'cancelled_memberships',
      ], 'Cancelled'),
      revenue: CourtMapper.number(
        JsonReader.pick(source, const [
          'revenue',
          'totalRevenue',
          'total_revenue',
          'earnings',
        ]),
      ),
    );
  }
}
