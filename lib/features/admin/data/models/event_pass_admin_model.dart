import '../../domain/entities/event_pass.dart';
import 'court_model.dart';
import 'json_reader.dart';

/// Maps `/event-passes` JSON onto [AdminEventPass].
///
/// No response was ever captured for these routes, so the key names come from
/// the storefront's `EventPassModel` — which *was* written against live
/// payloads — widened with the usual snake_case candidates.
class EventPassMapper {
  const EventPassMapper._();

  static AdminEventPass fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    final complex = _nested(source, const [
      'sportComplex',
      'SportComplex',
      'sport_complex',
      'complex',
    ]);

    return AdminEventPass(
      id: JsonReader.integer(source, const ['id', '_id', 'eventPassId']) ?? 0,
      title: JsonReader.string(source, const ['title', 'name', 'eventTitle']),
      description: JsonReader.string(source, const ['description', 'about']),
      image: JsonReader.string(source, const [
        'image',
        'imageUrl',
        'image_url',
        'banner',
        'coverImage',
      ]),
      sportComplexId:
          JsonReader.integer(source, const [
            'sportComplexId',
            'sport_complex_id',
            'complexId',
          ]) ??
          (complex == null
              ? null
              : JsonReader.integer(complex, const ['id', '_id'])),
      sportComplexName:
          JsonReader.string(source, const [
            'sportComplexName',
            'complexName',
            'venueName',
          ]) ??
          (complex == null
              ? null
              : JsonReader.string(complex, const ['name', 'title'])),
      statusRaw: JsonReader.string(source, const ['status', 'eventStatus']),
      slots: _slots(source),
      faqs: _faqs(source),
      createdAt: JsonReader.date(source, const ['createdAt', 'created_at']),
      updatedAt: JsonReader.date(source, const ['updatedAt', 'updated_at']),
      raw: source,
    );
  }

  static EventPassSlot slotFromJson(Map<String, dynamic> json) {
    return EventPassSlot(
      id: JsonReader.integer(json, const ['id', '_id', 'slotId']),
      eventPassId: JsonReader.integer(json, const [
        'eventPassId',
        'event_pass_id',
      ]),
      name: JsonReader.string(json, const ['name', 'slot_name', 'slotName']),
      date: JsonReader.date(json, const ['date', 'pass_date', 'passDate']),
      startTimeRaw: JsonReader.string(json, const ['startTime', 'start_time']),
      endTimeRaw: JsonReader.string(json, const ['endTime', 'end_time']),
      price: CourtMapper.number(
        JsonReader.pick(json, const ['price', 'pass_price', 'passPrice']),
      ),
      capacity: JsonReader.integer(json, const [
        'capacity',
        'maxCapacity',
        'totalSeats',
        'seats',
      ]),
      passType: JsonReader.string(json, const ['passType', 'pass_type']),
      statusRaw: JsonReader.string(json, const ['status']),
      raw: json,
    );
  }

  static const List<String> listKeys = [
    'eventPasses',
    'EventPasses',
    'events',
    'items',
    'data',
    'results',
    'rows',
  ];

  /// The rows the payload carried, before the id filter.
  static List<Map<String, dynamic>> rowsIn(Object? body) =>
      JsonReader.records(body, keys: listKeys);

  static List<AdminEventPass> listFrom(Object? body) {
    return rowsIn(body)
        .map(fromJson)
        .where((event) => event.id != 0)
        .toList(growable: false);
  }

  static AdminEventPass? maybeFromBody(Object? body) {
    if (body is! Map) return null;
    final event = fromJson(Map<String, dynamic>.from(body));
    return event.id == 0 ? null : event;
  }

  /// `GET /event-passes` — rows in `data`, counters in a sibling `pagination`.
  ///
  /// That split is unique to this module; every other paginated route in the
  /// console puts the counters beside the list or in `meta`. Both are still
  /// tried, and a bare list degrades to a single complete page.
  static EventPassPageResult<AdminEventPass> pageFrom(
    Object? body, {
    required int requestedPage,
    required int requestedLimit,
  }) {
    final items = listFrom(body);
    final pagination = paginationOf(body);

    return buildPage<AdminEventPass>(
      items: items,
      pagination: pagination,
      requestedPage: requestedPage,
      requestedLimit: requestedLimit,
    );
  }

  /// The `pagination` block, wherever this route put it.
  static Map<String, dynamic>? paginationOf(Object? body) {
    if (body is! Map) return null;
    final map = Map<String, dynamic>.from(body);

    for (final key in const ['pagination', 'meta', 'pageInfo']) {
      final value = map[key];
      if (value is Map) return Map<String, dynamic>.from(value);
    }

    if (map.containsKey('currentPage') || map.containsKey('totalPages')) {
      return map;
    }

    final data = map['data'];
    if (data is Map) return paginationOf(data);
    return null;
  }

  /// Shared by both paginated event routes.
  static EventPassPageResult<T> buildPage<T>({
    required List<T> items,
    required Map<String, dynamic>? pagination,
    required int requestedPage,
    required int requestedLimit,
  }) {
    int? read(List<String> keys) =>
        pagination == null ? null : JsonReader.integer(pagination, keys);

    final page =
        read(const ['currentPage', 'current_page', 'page']) ?? requestedPage;
    final total =
        read(const ['totalItems', 'total_items', 'total', 'count']) ??
        items.length;
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

    return EventPassPageResult<T>(
      items: items,
      page: page,
      totalPages: totalPages < 1 ? 1 : totalPages,
      totalItems: total,
      perPage: perPage < 1 ? requestedLimit : perPage,
    );
  }

  /// The URL returned by `POST /event-passes/upload-image`.
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
      'secure_url',
      'path',
      'location',
    ];

    final source = Map<String, dynamic>.from(body);
    final direct = JsonReader.string(source, keys);
    if (direct != null) return direct;

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

  static List<EventPassSlot> _slots(Map<String, dynamic> json) {
    for (final key in const [
      'slots',
      'eventPassSlots',
      'EventPassSlots',
      'passes',
    ]) {
      final value = json[key];
      if (value is! List) continue;
      final slots = value
          .whereType<Map>()
          .map((slot) => slotFromJson(Map<String, dynamic>.from(slot)))
          .toList(growable: false);
      if (slots.isNotEmpty) return slots;
    }
    return const [];
  }

  static List<EventFaq> _faqs(Map<String, dynamic> json) {
    for (final key in const ['faqs', 'FAQs', 'eventFaqs', 'EventFaqs']) {
      final value = json[key];
      if (value is! List) continue;

      final faqs = <EventFaq>[];
      for (final entry in value) {
        if (entry is! Map) continue;
        final row = Map<String, dynamic>.from(entry);
        final faq = EventFaq(
          question: JsonReader.string(row, const ['question', 'title', 'q']),
          answer: JsonReader.string(row, const ['answer', 'body', 'a']),
        );
        if (!faq.isEmpty) faqs.add(faq);
      }
      if (faqs.isNotEmpty) return faqs;
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
    for (final key in const ['eventPass', 'event', 'data', 'result']) {
      final inner = json[key];
      if (inner is Map) {
        final unwrapped = Map<String, dynamic>.from(inner);
        for (final nested in const ['eventPass', 'event', 'data']) {
          final deeper = unwrapped[nested];
          if (deeper is Map) return Map<String, dynamic>.from(deeper);
        }
        return unwrapped;
      }
    }
    return json;
  }
}

/// Maps `/event-passes/bookings/*` JSON onto [EventPassBookingRow].
class EventBookingMapper {
  const EventBookingMapper._();

  static EventPassBookingRow fromJson(Map<String, dynamic> json) {
    final source = _unwrap(json);

    final event = _nested(source, const [
      'eventPass',
      'EventPass',
      'event',
      'Event',
    ]);
    final slot = _nested(source, const [
      'eventPassSlot',
      'EventPassSlot',
      'slot',
      'Slot',
    ]);
    final user = _nested(source, const ['user', 'User', 'customer']);

    return EventPassBookingRow(
      id: JsonReader.integer(source, const ['id', '_id', 'bookingId']) ?? 0,
      eventPassId:
          JsonReader.integer(source, const ['eventPassId', 'event_pass_id']) ??
          (event == null
              ? null
              : JsonReader.integer(event, const ['id', '_id'])),
      eventTitle:
          JsonReader.string(source, const ['eventTitle', 'event_title']) ??
          (event == null
              ? null
              : JsonReader.string(event, const ['title', 'name'])),
      slotId:
          JsonReader.integer(source, const ['slotId', 'slot_id']) ??
          (slot == null
              ? null
              : JsonReader.integer(slot, const ['id', '_id'])),
      slotName: slot == null
          ? null
          : JsonReader.string(slot, const ['name', 'slot_name']),
      slotDate:
          JsonReader.date(source, const ['slotDate', 'date']) ??
          (slot == null
              ? null
              : JsonReader.date(slot, const ['date', 'pass_date'])),
      userId:
          JsonReader.integer(source, const ['userId', 'user_id']) ??
          (user == null
              ? null
              : JsonReader.integer(user, const ['id', '_id'])),
      // The create payload takes a flat name/email/phone, so those are tried
      // before the nested user.
      customerName:
          JsonReader.string(source, const ['name', 'customerName']) ??
          (user == null
              ? null
              : JsonReader.string(user, const ['name', 'fullName'])),
      customerEmail:
          JsonReader.string(source, const ['email', 'customerEmail']) ??
          (user == null
              ? null
              : JsonReader.string(user, const ['email'])),
      customerPhone:
          JsonReader.string(source, const [
            'phone',
            'phoneNumber',
            'customerPhone',
          ]) ??
          (user == null
              ? null
              : JsonReader.string(user, const [
                  'phone_number',
                  'phoneNumber',
                  'phone',
                ])),
      numberOfPasses: JsonReader.integer(source, const [
        'numberOfPasses',
        'number_of_passes',
        'passCount',
        'quantity',
      ]),
      totalAmount: CourtMapper.number(
        JsonReader.pick(source, const ['totalAmount', 'total_amount', 'amount']),
      ),
      discountAmount: CourtMapper.number(
        JsonReader.pick(source, const ['discountAmount', 'discount_amount']),
      ),
      couponCode: JsonReader.string(source, const ['couponCode', 'coupon']),
      paymentStatusRaw: JsonReader.string(source, const [
        'paymentStatus',
        'payment_status',
      ]),
      bookingStatusRaw: JsonReader.string(source, const [
        'bookingStatus',
        'booking_status',
        'status',
      ]),
      scannedInCount: _scannedIn(source),
      createdAt: JsonReader.date(source, const ['createdAt', 'created_at']),
      raw: source,
    );
  }

  /// The list, wherever this route put it.
  ///
  /// No response was captured, so the Sequelize association names are tried
  /// alongside the plain ones — a booking list keyed `EventPassBookings` would
  /// otherwise read as "no bookings", which is a different claim.
  static const List<String> listKeys = [
    'bookings',
    'eventBookings',
    'EventBookings',
    'eventPassBookings',
    'EventPassBookings',
    'passBookings',
    'items',
    'data',
    'results',
    'records',
    'rows',
  ];

  /// The rows the payload carried, before the id filter — used to tell an
  /// empty list apart from a list this mapper could not read.
  static List<Map<String, dynamic>> rowsIn(Object? body) =>
      JsonReader.records(body, keys: listKeys);

  static List<EventPassBookingRow> listFrom(Object? body) {
    return rowsIn(body)
        .map(fromJson)
        .where((booking) => booking.id != 0)
        .toList(growable: false);
  }

  static EventPassBookingRow? maybeFromBody(Object? body) {
    if (body is! Map) return null;
    final booking = fromJson(Map<String, dynamic>.from(body));
    return booking.id == 0 ? null : booking;
  }

  static EventPassPageResult<EventPassBookingRow> pageFrom(
    Object? body, {
    required int requestedPage,
    required int requestedLimit,
  }) {
    return EventPassMapper.buildPage<EventPassBookingRow>(
      items: listFrom(body),
      pagination: EventPassMapper.paginationOf(body),
      requestedPage: requestedPage,
      requestedLimit: requestedLimit,
    );
  }

  /// How many issued passes have been scanned in.
  ///
  /// Either a counter on the booking, or counted from the individual passes —
  /// null when neither is present, so "0 scanned" is never claimed of a payload
  /// that did not say.
  static int? _scannedIn(Map<String, dynamic> json) {
    final direct = JsonReader.integer(json, const [
      'scannedInCount',
      'scanned_in_count',
      'checkedIn',
    ]);
    if (direct != null) return direct;

    for (final key in const [
      'individualPasses',
      'passes',
      'IndividualPasses',
    ]) {
      final value = json[key];
      if (value is! List) continue;

      var scanned = 0;
      var known = false;
      for (final entry in value) {
        if (entry is! Map) continue;
        final row = Map<String, dynamic>.from(entry);
        final count = JsonReader.integer(row, const [
          'scannedInCount',
          'scanned_in_count',
        ]);
        if (count == null) continue;
        known = true;
        if (count > 0) scanned++;
      }
      if (known) return scanned;
    }
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
    for (final key in const ['booking', 'eventBooking', 'data', 'result']) {
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
