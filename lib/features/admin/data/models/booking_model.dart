import '../../domain/entities/booking.dart';
import 'court_model.dart';
import 'json_reader.dart';

/// Maps `/bookings` JSON onto [Booking].
///
/// The nested associations arrive under Sequelize's own model names as well as
/// the camelCase ones — live `/courts/bookings/my` payloads use `SportComplex`
/// with a capital S — so both spellings are candidates.
class BookingMapper {
  const BookingMapper._();

  static Booking fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    final court = _nested(source, const ['Court', 'court', 'courtInfo']);
    final sport = _nested(source, const ['Sport', 'sport', 'sportInfo']);
    final user = _nested(source, const [
      'User',
      'user',
      'customer',
      'Customer',
    ]);
    final complex =
        _nested(source, const [
          'SportComplex',
          'sportComplex',
          'sport_complex',
          'complex',
        ]) ??
        // `/courts/bookings/my` nests the complex inside the court.
        (court == null
            ? null
            : _nested(court, const ['SportComplex', 'sportComplex', 'complex']));

    return Booking(
      id: JsonReader.integer(source, const ['id', '_id', 'bookingId']) ?? 0,
      reference: JsonReader.string(source, const [
        'passCode',
        'pass_code',
        'bookingCode',
        'bookingReference',
        'reference',
      ]),
      // The customer lives inside a nested user on every shape seen so far, so
      // the flat keys are tried first and the object is the fallback.
      customerName:
          JsonReader.string(source, const [
            'customerName',
            'userName',
            'user_name',
          ]) ??
          (user == null
              ? null
              : JsonReader.string(user, const ['name', 'fullName'])),
      customerPhone:
          JsonReader.string(source, const [
            'customerPhone',
            'phone',
            'phoneNumber',
            'phone_number',
          ]) ??
          (user == null
              ? null
              : JsonReader.string(user, const [
                  'phone_number',
                  'phoneNumber',
                  'phone',
                  'mobile',
                ])),
      customerEmail:
          JsonReader.string(source, const ['customerEmail', 'email']) ??
          (user == null
              ? null
              : JsonReader.string(user, const ['email', 'emailAddress'])),
      userId:
          JsonReader.integer(source, const ['userId', 'user_id']) ??
          (user == null
              ? null
              : JsonReader.integer(user, const ['id', '_id'])),
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
      courtId:
          JsonReader.integer(source, const ['courtId', 'court_id']) ??
          (court == null
              ? null
              : JsonReader.integer(court, const ['id', '_id'])),
      courtName:
          JsonReader.string(source, const ['courtName', 'court_name']) ??
          (court == null
              ? null
              : JsonReader.string(court, const ['name', 'title'])),
      sportComplexId:
          JsonReader.integer(source, const [
            'sportComplexId',
            'sport_complex_id',
            'complexId',
          ]) ??
          (complex == null
              ? null
              : JsonReader.integer(complex, const ['id', '_id'])) ??
          (court == null
              ? null
              : JsonReader.integer(court, const [
                  'sportComplexId',
                  'sport_complex_id',
                ])),
      sportComplexName:
          JsonReader.string(source, const [
            'sportComplexName',
            'complexName',
          ]) ??
          (complex == null
              ? null
              : JsonReader.string(complex, const ['name', 'title'])),
      date: JsonReader.date(source, const ['date', 'bookingDate']),
      startTimeRaw: JsonReader.string(source, const [
        'startTime',
        'start_time',
        'from',
      ]),
      endTimeRaw: JsonReader.string(source, const [
        'endTime',
        'end_time',
        'to',
      ]),
      amount: CourtMapper.number(
        JsonReader.pick(source, const [
          'totalAmount',
          'total_amount',
          'amount',
          'price',
        ]),
      ),
      discountAmount: CourtMapper.number(
        JsonReader.pick(source, const ['discountAmount', 'discount_amount']),
      ),
      couponCode: JsonReader.string(source, const ['couponCode', 'coupon']),
      transactionId: JsonReader.string(source, const [
        'transactionId',
        'transaction_id',
        'paymentId',
      ]),
      bookingSourceRaw: JsonReader.string(source, const [
        'bookingSource',
        'booking_source',
        'source',
      ]),
      bookingStatusRaw: JsonReader.string(source, const [
        'bookingStatus',
        'booking_status',
        'status',
      ]),
      paymentStatusRaw: JsonReader.string(source, const [
        'paymentStatus',
        'payment_status',
      ]),
      notes: JsonReader.string(source, const ['notes', 'note', 'remarks']),
      createdAt: JsonReader.date(source, const ['createdAt', 'created_at']),
      raw: source,
    );
  }

  static List<Booking> listFrom(Object? body) {
    return JsonReader.records(
          body,
          keys: const [
            'bookings',
            'items',
            'data',
            'results',
            'records',
            'current',
          ],
        )
        .map(fromJson)
        .where((booking) => booking.id != 0)
        .toList(growable: false);
  }

  static Booking? maybeFromBody(Object? body) {
    if (body is! Map) return null;
    final booking = fromJson(Map<String, dynamic>.from(body));
    return booking.id == 0 ? null : booking;
  }

  /// `GET /bookings` — the list plus its pagination meta.
  ///
  /// A route that answers with a bare list still works: the result then
  /// describes a single page holding everything it returned, so the pagination
  /// bar stays truthful either way.
  static BookingPageResult pageFrom(
    Object? body, {
    required int requestedPage,
    required int requestedLimit,
  }) {
    final bookings = listFrom(body);

    final meta = body is Map ? Map<String, dynamic>.from(body) : null;
    final envelope = meta == null ? null : _metaEnvelope(meta);

    int? read(List<String> keys) =>
        envelope == null ? null : JsonReader.integer(envelope, keys);

    final page =
        read(const ['currentPage', 'current_page', 'page']) ?? requestedPage;
    final total =
        read(const ['totalItems', 'total_items', 'total', 'count']) ??
        bookings.length;
    final perPage =
        read(const [
          'itemsPerPage',
          'items_per_page',
          'perPage',
          'limit',
          'pageSize',
        ]) ??
        requestedLimit;
    final totalPages =
        read(const ['totalPages', 'total_pages', 'pages', 'lastPage']) ??
        // Derived rather than assumed to be 1: a route that sends a total but
        // no page count would otherwise hide every page after the first.
        (perPage > 0 && total > 0 ? (total / perPage).ceil() : 1);

    return BookingPageResult(
      bookings: bookings,
      page: page,
      totalPages: totalPages < 1 ? 1 : totalPages,
      totalItems: total,
      perPage: perPage < 1 ? requestedLimit : perPage,
    );
  }

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
    for (final key in const ['booking', 'data', 'result']) {
      final inner = json[key];
      if (inner is Map) {
        final unwrapped = Map<String, dynamic>.from(inner);
        for (final nested in const ['booking', 'data']) {
          final deeper = unwrapped[nested];
          if (deeper is Map) return Map<String, dynamic>.from(deeper);
        }
        return unwrapped;
      }
    }
    return json;
  }
}

/// Maps `GET /bookings/stats`.
class BookingStatsMapper {
  const BookingStatsMapper._();

  static BookingStats fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    return BookingStats(
      total: JsonReader.integer(source, const [
        'totalBookings',
        'total_bookings',
        'total',
      ]),
      today: JsonReader.integer(source, const [
        'todayBookings',
        'today_bookings',
        'today',
        'todaysBookings',
      ]),
      confirmed: JsonReader.integer(source, const [
        'confirmedBookings',
        'confirmed_bookings',
        'confirmed',
      ]),
      pending: JsonReader.integer(source, const [
        'pendingBookings',
        'pending_bookings',
        'pending',
      ]),
      cancelled: JsonReader.integer(source, const [
        'cancelledBookings',
        'cancelled_bookings',
        'cancelled',
      ]),
      completed: JsonReader.integer(source, const [
        'completedBookings',
        'completed_bookings',
        'completed',
      ]),
      revenue: CourtMapper.number(
        JsonReader.pick(source, const [
          'totalRevenue',
          'total_revenue',
          'revenue',
          'earnings',
        ]),
      ),
      paid: JsonReader.integer(source, const [
        'paidBookings',
        'paid_bookings',
        'paid',
      ]),
      unpaid: JsonReader.integer(source, const [
        'unpaidBookings',
        'unpaid_bookings',
        'unpaid',
        'pendingPayments',
      ]),
      growthPercent: _double(
        JsonReader.pick(source, const [
          'growth',
          'growthPercentage',
          'growth_percentage',
          'percentageChange',
        ]),
      ),
      daily: _series(source, const [
        'daily',
        'dailyBookings',
        'bookingsByDay',
        'trend',
      ]),
      topSports: _series(source, const [
        'topSports',
        'mostBookedSports',
        'bySport',
        'sportDistribution',
      ]),
      topCourts: _series(source, const [
        'topCourts',
        'mostBookedCourts',
        'byCourt',
      ]),
      peakHours: _series(source, const [
        'peakHours',
        'bookingsByHour',
        'byHour',
        'hourly',
      ]),
    );
  }

  /// A labelled series, from a list of objects or from a `{label: value}` map.
  /// Anything else yields an empty list, and the chart is simply not drawn —
  /// never filled with zeroes.
  static List<BookingPoint> _series(
    Map<String, dynamic> json,
    List<String> keys,
  ) {
    final value = JsonReader.pick(json, keys);
    if (value == null) return const [];

    if (value is Map) {
      final points = <BookingPoint>[];
      value.forEach((key, entry) {
        final number = CourtMapper.number(entry);
        if (number != null) {
          points.add(BookingPoint(label: key.toString(), value: number));
        }
      });
      return points;
    }

    if (value is! Iterable) return const [];

    final points = <BookingPoint>[];
    for (final entry in value) {
      if (entry is! Map) continue;
      final row = Map<String, dynamic>.from(entry);

      final label = JsonReader.string(row, const [
        'label',
        'name',
        'date',
        'day',
        'hour',
        'sport',
        'court',
        'month',
      ]);
      final number = CourtMapper.number(
        JsonReader.pick(row, const [
          'value',
          'count',
          'bookings',
          'total',
          'revenue',
        ]),
      );

      if (label == null || number == null) continue;
      points.add(BookingPoint(label: label, value: number));
    }
    return points;
  }

  static double? _double(Object? value) {
    final number = CourtMapper.number(value);
    return number?.toDouble();
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
