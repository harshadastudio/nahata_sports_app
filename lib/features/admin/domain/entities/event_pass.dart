import 'admin_role.dart';
import 'admin_sports_complex.dart';
import 'court_slot.dart';

/// One dated session of an event, with its own price and capacity.
///
/// The storefront's `EventPassSlot` is the same row read for booking screens;
/// this one adds [capacity], which the admin create payload carries and the
/// customer model never needed, and parses the price into a number.
class EventPassSlot {
  const EventPassSlot({
    this.id,
    this.eventPassId,
    this.name,
    this.date,
    this.startTimeRaw,
    this.endTimeRaw,
    this.price,
    this.capacity,
    this.passType,
    this.statusRaw,
    this.raw = const {},
  });

  final int? id;
  final int? eventPassId;

  /// Some slots are named ("Morning session"); many are not.
  final String? name;

  final DateTime? date;

  /// `HH:mm` in the documented create payload.
  final String? startTimeRaw;
  final String? endTimeRaw;

  /// A number in the create payload but a decimal string when read back, so it
  /// is parsed either way.
  final num? price;

  final int? capacity;
  final String? passType;
  final String? statusRaw;

  final Map<String, dynamic> raw;

  SlotTime? get startTime => SlotTime.parse(startTimeRaw);
  SlotTime? get endTime => SlotTime.parse(endTimeRaw);

  AdminUserStatus? get status => AdminUserStatus.tryParse(statusRaw);

  /// Absent status means the slot inherits the event's — not that it is off.
  bool get isActive => status == null || status == AdminUserStatus.active;

  String get windowLabel {
    final start = startTime;
    final end = endTime;
    if (start == null && end == null) return '—';
    if (start == null) return 'until ${end!.label}';
    if (end == null) return 'from ${start.label}';
    return '${start.label} – ${end.label}';
  }

  /// The slot's own name, or the date it runs on.
  String get displayName {
    final trimmed = (name ?? '').trim();
    if (trimmed.isNotEmpty) return trimmed;
    final day = date;
    if (day == null) return 'Untitled slot';
    return '${day.day}/${day.month}/${day.year}';
  }

  /// True when the slot's date is today or later. Null-safe: a slot with no
  /// date is treated as upcoming rather than silently expired.
  bool isUpcomingOn(DateTime now) {
    final day = date;
    if (day == null) return true;
    final today = DateTime(now.year, now.month, now.day);
    return !DateTime(day.year, day.month, day.day).isBefore(today);
  }

  @override
  String toString() =>
      'EventPassSlot($id, $date $startTimeRaw–$endTimeRaw, $price, '
      'cap $capacity)';
}

/// One question and answer on an event page.
class EventFaq {
  const EventFaq({this.question, this.answer});

  final String? question;
  final String? answer;

  bool get isEmpty =>
      (question ?? '').trim().isEmpty && (answer ?? '').trim().isEmpty;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'question': (question ?? '').trim(),
    'answer': (answer ?? '').trim(),
  };

  @override
  String toString() => 'EventFaq($question)';
}

/// An event pass (`/event-passes`).
///
/// A second model beside the storefront's `EventPassModel`, which keeps prices
/// and dates as the raw strings its booking screens display — the same split
/// this console already makes for complexes, batches, courts and bookings.
class AdminEventPass {
  const AdminEventPass({
    required this.id,
    this.title,
    this.description,
    this.image,
    this.sportComplexId,
    this.sportComplexName,
    this.statusRaw,
    this.slots = const [],
    this.faqs = const [],
    this.createdAt,
    this.updatedAt,
    this.raw = const {},
  });

  /// The event id, used in every `/event-passes/{id}` call.
  final int id;

  final String? title;
  final String? description;

  /// The documented create payload sends a full Cloudinary URL, so this is
  /// usually absolute; [imageUrl] handles the relative case anyway.
  final String? image;

  final int? sportComplexId;
  final String? sportComplexName;

  final String? statusRaw;

  final List<EventPassSlot> slots;
  final List<EventFaq> faqs;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  final Map<String, dynamic> raw;

  AdminUserStatus? get status => AdminUserStatus.tryParse(statusRaw);
  String get statusLabel => status?.label ?? ((statusRaw ?? '').trim());
  bool get isActive => status == AdminUserStatus.active;

  String get displayTitle {
    final trimmed = (title ?? '').trim();
    return trimmed.isEmpty ? 'Untitled event' : trimmed;
  }

  String get initials {
    final parts = displayTitle
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  bool get hasImage => (image ?? '').trim().isNotEmpty;
  String? get imageUrl => resolveMediaUrl(image);

  int get slotCount => slots.length;

  /// Seats across every slot, or null when not one slot declared a capacity —
  /// a zero there would claim a sold-out event the API never described.
  int? get totalCapacity {
    var total = 0;
    var known = false;
    for (final slot in slots) {
      final capacity = slot.capacity;
      if (capacity == null) continue;
      known = true;
      total += capacity;
    }
    return known ? total : null;
  }

  /// The cheapest and dearest slot prices, when any slot carries one.
  (num, num)? get priceRange {
    num? low;
    num? high;
    for (final slot in slots) {
      final price = slot.price;
      if (price == null) continue;
      if (low == null || price < low) low = price;
      if (high == null || price > high) high = price;
    }
    if (low == null || high == null) return null;
    return (low, high);
  }

  /// The first date the event runs, for the table's Starts column.
  DateTime? get firstDate {
    DateTime? earliest;
    for (final slot in slots) {
      final date = slot.date;
      if (date == null) continue;
      if (earliest == null || date.isBefore(earliest)) earliest = date;
    }
    return earliest;
  }

  DateTime? get lastDate {
    DateTime? latest;
    for (final slot in slots) {
      final date = slot.date;
      if (date == null) continue;
      if (latest == null || date.isAfter(latest)) latest = date;
    }
    return latest;
  }

  /// Slots still to run. An event whose every slot is in the past is finished
  /// whatever its status says.
  int upcomingSlotCount(DateTime now) =>
      slots.where((slot) => slot.isUpcomingOn(now)).length;

  bool hasFinished(DateTime now) =>
      slots.isNotEmpty && upcomingSlotCount(now) == 0;

  /// Text a local search should match: the title and the venue.
  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return displayTitle.toLowerCase().contains(needle) ||
        (sportComplexName ?? '').toLowerCase().contains(needle);
  }

  /// Merges a detail read over the list row, keeping anything detail omitted.
  AdminEventPass mergedWith(AdminEventPass other) {
    return AdminEventPass(
      id: other.id == 0 ? id : other.id,
      title: other.title ?? title,
      description: other.description ?? description,
      image: other.image ?? image,
      sportComplexId: other.sportComplexId ?? sportComplexId,
      sportComplexName: other.sportComplexName ?? sportComplexName,
      statusRaw: other.statusRaw ?? statusRaw,
      slots: other.slots.isEmpty ? slots : other.slots,
      faqs: other.faqs.isEmpty ? faqs : other.faqs,
      createdAt: other.createdAt ?? createdAt,
      updatedAt: other.updatedAt ?? updatedAt,
      raw: {...raw, ...other.raw},
    );
  }

  /// Returns a copy with the status changed — used by the optimistic write.
  AdminEventPass copyWith({String? statusRaw}) {
    return AdminEventPass(
      id: id,
      title: title,
      description: description,
      image: image,
      sportComplexId: sportComplexId,
      sportComplexName: sportComplexName,
      statusRaw: statusRaw ?? this.statusRaw,
      slots: slots,
      faqs: faqs,
      createdAt: createdAt,
      updatedAt: updatedAt,
      raw: raw,
    );
  }

  @override
  String toString() =>
      'AdminEventPass($id, $title, complex: $sportComplexId, $statusRaw, '
      '${slots.length} slots)';
}

/// One row of `GET /event-passes/bookings/all`.
///
/// Read from the storefront's booking shape, which is the only one captured:
/// the booking carries the event and slot it belongs to plus the individual
/// passes issued for it.
class EventPassBookingRow {
  const EventPassBookingRow({
    required this.id,
    this.eventPassId,
    this.eventTitle,
    this.slotId,
    this.slotName,
    this.slotDate,
    this.userId,
    this.customerName,
    this.customerEmail,
    this.customerPhone,
    this.numberOfPasses,
    this.totalAmount,
    this.discountAmount,
    this.couponCode,
    this.paymentStatusRaw,
    this.bookingStatusRaw,
    this.scannedInCount,
    this.createdAt,
    this.raw = const {},
  });

  final int id;

  final int? eventPassId;
  final String? eventTitle;

  final int? slotId;
  final String? slotName;
  final DateTime? slotDate;

  final int? userId;
  final String? customerName;
  final String? customerEmail;
  final String? customerPhone;

  final int? numberOfPasses;
  final num? totalAmount;
  final num? discountAmount;
  final String? couponCode;

  final String? paymentStatusRaw;
  final String? bookingStatusRaw;

  /// How many of the issued passes have been scanned in, when the payload
  /// carries the individual passes.
  final int? scannedInCount;

  final DateTime? createdAt;

  final Map<String, dynamic> raw;

  String get displayCustomer {
    final trimmed = (customerName ?? '').trim();
    return trimmed.isEmpty ? 'Unnamed customer' : trimmed;
  }

  String get displayEvent {
    final trimmed = (eventTitle ?? '').trim();
    if (trimmed.isNotEmpty) return trimmed;
    return eventPassId == null ? '—' : 'Event #$eventPassId';
  }

  String get initials {
    final parts = displayCustomer
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return displayCustomer.toLowerCase().contains(needle) ||
        displayEvent.toLowerCase().contains(needle) ||
        (customerPhone ?? '').toLowerCase().contains(needle) ||
        (customerEmail ?? '').toLowerCase().contains(needle) ||
        '$id'.contains(needle);
  }

  @override
  String toString() =>
      'EventPassBookingRow($id, event: $eventPassId, $numberOfPasses passes, '
      '$totalAmount)';
}

/// One page of `GET /event-passes` or `/event-passes/bookings/all`.
///
/// The list route puts the rows in `data` and the counters in a sibling
/// `pagination` object — a shape unique to this module.
class EventPassPageResult<T> {
  const EventPassPageResult({
    this.items = const [],
    this.page = 1,
    this.totalPages = 1,
    this.totalItems = 0,
    this.perPage = 20,
  });

  final List<T> items;
  final int page;
  final int totalPages;
  final int totalItems;
  final int perPage;

  bool get hasMore => page < totalPages;

  @override
  String toString() =>
      'EventPassPageResult(page $page/$totalPages, ${items.length} of '
      '$totalItems)';
}

/// The write payload for creating and updating an event pass.
class EventPassDraft {
  const EventPassDraft({
    this.sportComplexId,
    this.title,
    this.description,
    this.image,
    this.status,
    this.faqs,
    this.slots,
  });

  final int? sportComplexId;
  final String? title;
  final String? description;
  final String? image;
  final AdminUserStatus? status;

  final List<EventFaq>? faqs;
  final List<EventPassSlot>? slots;

  /// `yyyy-MM-dd`, as the documented payload sends it.
  static String? formatDate(DateTime? value) {
    if (value == null) return null;
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  /// `POST /event-passes` — the documented shape, including the nested slot and
  /// FAQ arrays that are created with the event rather than separately.
  Map<String, dynamic> toCreateJson() {
    return <String, dynamic>{
      'sportComplexId': sportComplexId,
      'title': (title ?? '').trim(),
      'description': (description ?? '').trim(),
      'image': (image ?? '').trim(),
      'status': (status ?? AdminUserStatus.active).slug,
      'faqs': [
        for (final faq in faqs ?? const <EventFaq>[])
          if (!faq.isEmpty) faq.toJson(),
      ],
      'slots': [
        for (final slot in slots ?? const <EventPassSlot>[])
          <String, dynamic>{
            'date': formatDate(slot.date),
            // `HH:mm`, exactly as the documented payload shows — note this
            // differs from the bookings module, which stores `HH:mm:ss`.
            'startTime': slot.startTime?.wire,
            'endTime': slot.endTime?.wire,
            'price': slot.price,
            'capacity': slot.capacity,
            if ((slot.name ?? '').trim().isNotEmpty) 'name': slot.name!.trim(),
          },
      ],
    };
  }

  /// `PUT /event-passes/{eventPassId}`.
  ///
  /// The collection only *exemplifies* `title` and `status`; it does not list
  /// the editable fields. Description and image are sent when the form set
  /// them, since a partial update is what the example implies — but the slots
  /// and FAQs are deliberately **not**, because replacing those arrays on an
  /// event that already has bookings against its slots is not something an
  /// unspecified route should be trusted with.
  Map<String, dynamic> toUpdateJson() {
    final body = <String, dynamic>{};

    void put(String key, Object? value) {
      if (value == null) return;
      body[key] = value is String ? value.trim() : value;
    }

    put('title', title);
    put('description', description);
    put('image', image);
    put('status', status?.slug);

    return body;
  }
}

/// The write payload for `POST /event-passes/bookings/create`.
class EventBookingDraft {
  const EventBookingDraft({
    this.eventPassId,
    this.slotId,
    this.name,
    this.email,
    this.phone,
    this.numberOfPasses,
    this.couponCode,
  });

  final int? eventPassId;
  final int? slotId;
  final String? name;
  final String? email;
  final String? phone;
  final int? numberOfPasses;

  /// Documented as explicitly nullable, so an absent coupon is sent as null
  /// rather than as an empty string.
  final String? couponCode;

  Map<String, dynamic> toJson() {
    final coupon = (couponCode ?? '').trim();

    return <String, dynamic>{
      'eventPassId': eventPassId,
      'slotId': slotId,
      'name': (name ?? '').trim(),
      'email': (email ?? '').trim(),
      'phone': (phone ?? '').trim(),
      'numberOfPasses': numberOfPasses ?? 1,
      'couponCode': coupon.isEmpty ? null : coupon,
    };
  }
}
