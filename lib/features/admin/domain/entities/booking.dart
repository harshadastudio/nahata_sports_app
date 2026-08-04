import 'court_slot.dart';

/// Where a booking came from.
///
/// Enumerated by the product spec rather than by any endpoint. [slug] is what
/// goes on the wire; a value outside the list still renders through [labelFor],
/// so the list being wrong never hides data.
///
/// `Walk-in` carries a hyphen the other vocabularies do not — [tryParse]
/// ignores separators, so `walkin`, `Walk In` and `WALK_IN` all resolve, but a
/// *write* sends this exact spelling.
enum BookingSource {
  admin('Admin'),
  walkIn('Walk-in'),
  website('Website'),
  mobileApp('Mobile App');

  const BookingSource(this.slug);

  final String slug;

  String get label => slug;

  static BookingSource? tryParse(Object? value) =>
      _match(BookingSource.values, value);

  static String labelFor(String? raw) =>
      tryParse(raw)?.label ?? _titleise(raw);
}

/// Where the booking itself stands.
enum BookingStatus {
  confirmed('Confirmed'),
  pending('Pending'),
  cancelled('Cancelled'),
  completed('Completed');

  const BookingStatus(this.slug);

  final String slug;

  String get label => slug;

  static BookingStatus? tryParse(Object? value) =>
      _match(BookingStatus.values, value);

  static String labelFor(String? raw) =>
      tryParse(raw)?.label ?? _titleise(raw);
}

/// Where the money stands.
enum PaymentStatus {
  paid('Paid'),
  pending('Pending'),
  failed('Failed'),
  refunded('Refunded');

  const PaymentStatus(this.slug);

  final String slug;

  String get label => slug;

  static PaymentStatus? tryParse(Object? value) =>
      _match(PaymentStatus.values, value);

  static String labelFor(String? raw) =>
      tryParse(raw)?.label ?? _titleise(raw);
}

/// Case- and separator-insensitive lookup, so `walk_in` and `Walk-in` agree.
T? _match<T>(List<T> values, Object? raw) {
  if (raw == null) return null;
  final wanted = _normalise(raw.toString());
  if (wanted.isEmpty) return null;

  for (final value in values) {
    final slug = (value as dynamic).slug as String;
    if (_normalise(slug) == wanted) return value;
  }
  return null;
}

String _normalise(String value) =>
    value.trim().toLowerCase().replaceAll(RegExp(r'[\s_\-]+'), '');

String _titleise(String? raw) {
  final text = (raw ?? '').trim();
  if (text.isEmpty) return '—';
  return text
      .split(RegExp(r'[_\-\s]+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word[0].toUpperCase() + word.substring(1).toLowerCase())
      .join(' ');
}

/// A court booking, as the admin console needs it (`/bookings`).
///
/// A second model beside the storefront's `CourtBooking`, which keeps the
/// amount, the date and the times as the raw strings its screens display. The
/// shapes of those strings are known from live `/courts/bookings/my` payloads:
/// `date` is `yyyy-MM-dd` and the times are `HH:mm:ss`.
///
/// Every field except [id] is nullable so a thinner list payload is never
/// padded with invented values; the UI renders "—" for anything absent.
class Booking {
  const Booking({
    required this.id,
    this.reference,
    this.customerName,
    this.customerPhone,
    this.customerEmail,
    this.userId,
    this.sportId,
    this.sportName,
    this.courtId,
    this.courtName,
    this.sportComplexId,
    this.sportComplexName,
    this.date,
    this.startTimeRaw,
    this.endTimeRaw,
    this.amount,
    this.discountAmount,
    this.couponCode,
    this.transactionId,
    this.bookingSourceRaw,
    this.bookingStatusRaw,
    this.paymentStatusRaw,
    this.notes,
    this.createdAt,
    this.raw = const {},
  });

  /// The booking id, used in every `/bookings/{id}` call.
  final int id;

  /// The human-facing code, e.g. `BOOK-2026-000071`. Distinct from [id], which
  /// is what every URL uses — never swap them.
  final String? reference;

  final String? customerName;
  final String? customerPhone;
  final String? customerEmail;
  final int? userId;

  final int? sportId;
  final String? sportName;

  final int? courtId;
  final String? courtName;

  final int? sportComplexId;
  final String? sportComplexName;

  final DateTime? date;

  /// `HH:mm:ss` on the wire. Read [startTime] for the parsed form.
  final String? startTimeRaw;
  final String? endTimeRaw;

  /// A decimal string on the wire (`"800.00"`), parsed here so the table can
  /// sort and total it.
  final num? amount;
  final num? discountAmount;
  final String? couponCode;

  final String? transactionId;

  final String? bookingSourceRaw;
  final String? bookingStatusRaw;
  final String? paymentStatusRaw;

  final String? notes;
  final DateTime? createdAt;

  final Map<String, dynamic> raw;

  SlotTime? get startTime => SlotTime.parse(startTimeRaw);
  SlotTime? get endTime => SlotTime.parse(endTimeRaw);

  BookingStatus? get status => BookingStatus.tryParse(bookingStatusRaw);
  String get statusLabel => BookingStatus.labelFor(bookingStatusRaw);

  PaymentStatus? get payment => PaymentStatus.tryParse(paymentStatusRaw);
  String get paymentLabel => PaymentStatus.labelFor(paymentStatusRaw);

  BookingSource? get source => BookingSource.tryParse(bookingSourceRaw);
  String get sourceLabel => BookingSource.labelFor(bookingSourceRaw);

  bool get isPaid => payment == PaymentStatus.paid;
  bool get isCancelled => status == BookingStatus.cancelled;

  /// What to show as the booking's name in a list: the reference when there is
  /// one, and the id when there is not.
  String get displayReference {
    final trimmed = (reference ?? '').trim();
    return trimmed.isEmpty ? '#$id' : trimmed;
  }

  String get displayCustomer {
    final trimmed = (customerName ?? '').trim();
    return trimmed.isEmpty ? 'Unnamed customer' : trimmed;
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

  /// `7:00 AM – 8:00 AM`, or an em dash when the times are unreadable.
  String get windowLabel {
    final start = startTime;
    final end = endTime;
    if (start == null && end == null) return '—';
    if (start == null) return 'until ${end!.label}';
    if (end == null) return 'from ${start.label}';
    return '${start.label} – ${end.label}';
  }

  /// Minutes booked, or null when either end is unreadable.
  int? get durationMinutes {
    final start = startTime;
    final end = endTime;
    if (start == null || end == null) return null;
    return start.minutesUntil(end);
  }

  /// `1 hr`, `90 min`, or an em dash.
  String get durationLabel {
    final minutes = durationMinutes;
    if (minutes == null) return '—';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '$rest min';
    if (rest == 0) return '$hours hr';
    return '$hours hr $rest min';
  }

  /// True when [date] is the same calendar day as [now].
  bool isOn(DateTime now) {
    final day = date;
    if (day == null) return false;
    return day.year == now.year &&
        day.month == now.month &&
        day.day == now.day;
  }

  /// Where the booking sits against the clock — the three groups the "today"
  /// view separates. Null when the booking has no readable time.
  BookingPhase? phaseAt(DateTime now) {
    final start = startTime;
    if (start == null || date == null) return null;

    if (!isOn(now)) {
      return date!.isAfter(DateTime(now.year, now.month, now.day))
          ? BookingPhase.upcoming
          : BookingPhase.finished;
    }

    final minutesNow = now.hour * 60 + now.minute;
    final from = start.minutesFromMidnight;
    final to = endTime?.minutesFromMidnight ?? (from + 60);

    if (minutesNow < from) return BookingPhase.upcoming;
    if (minutesNow < to) return BookingPhase.ongoing;
    return BookingPhase.finished;
  }

  /// Text a local search should match, per the spec: reference, name, phone.
  bool matches(String query) {
    final needle = query.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return displayReference.toLowerCase().contains(needle) ||
        '$id'.contains(needle) ||
        (customerName ?? '').toLowerCase().contains(needle) ||
        (customerPhone ?? '').toLowerCase().contains(needle);
  }

  /// Merges a detail read over the list row, keeping anything detail omitted.
  Booking mergedWith(Booking other) {
    return Booking(
      id: other.id == 0 ? id : other.id,
      reference: other.reference ?? reference,
      customerName: other.customerName ?? customerName,
      customerPhone: other.customerPhone ?? customerPhone,
      customerEmail: other.customerEmail ?? customerEmail,
      userId: other.userId ?? userId,
      sportId: other.sportId ?? sportId,
      sportName: other.sportName ?? sportName,
      courtId: other.courtId ?? courtId,
      courtName: other.courtName ?? courtName,
      sportComplexId: other.sportComplexId ?? sportComplexId,
      sportComplexName: other.sportComplexName ?? sportComplexName,
      date: other.date ?? date,
      startTimeRaw: other.startTimeRaw ?? startTimeRaw,
      endTimeRaw: other.endTimeRaw ?? endTimeRaw,
      amount: other.amount ?? amount,
      discountAmount: other.discountAmount ?? discountAmount,
      couponCode: other.couponCode ?? couponCode,
      transactionId: other.transactionId ?? transactionId,
      bookingSourceRaw: other.bookingSourceRaw ?? bookingSourceRaw,
      bookingStatusRaw: other.bookingStatusRaw ?? bookingStatusRaw,
      paymentStatusRaw: other.paymentStatusRaw ?? paymentStatusRaw,
      notes: other.notes ?? notes,
      createdAt: other.createdAt ?? createdAt,
      raw: {...raw, ...other.raw},
    );
  }

  /// Returns a copy with one field changed — used by the optimistic status
  /// writes, which must not wait for a list reload to repaint.
  Booking copyWith({String? bookingStatusRaw, String? paymentStatusRaw}) {
    return Booking(
      id: id,
      reference: reference,
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
      userId: userId,
      sportId: sportId,
      sportName: sportName,
      courtId: courtId,
      courtName: courtName,
      sportComplexId: sportComplexId,
      sportComplexName: sportComplexName,
      date: date,
      startTimeRaw: startTimeRaw,
      endTimeRaw: endTimeRaw,
      amount: amount,
      discountAmount: discountAmount,
      couponCode: couponCode,
      transactionId: transactionId,
      bookingSourceRaw: bookingSourceRaw,
      bookingStatusRaw: bookingStatusRaw ?? this.bookingStatusRaw,
      paymentStatusRaw: paymentStatusRaw ?? this.paymentStatusRaw,
      notes: notes,
      createdAt: createdAt,
      raw: raw,
    );
  }

  /// True when this booking and [other] hold the same court at an overlapping
  /// time on the same date. Cancelled bookings never clash — the court is free.
  bool clashesWith(Booking other) {
    if (isCancelled || other.isCancelled) return false;
    if (courtId == null || other.courtId == null) return false;
    if (courtId != other.courtId) return false;
    if (date == null || other.date == null) return false;
    if (!_sameDay(date!, other.date!)) return false;

    final start = startTime;
    final end = endTime;
    final otherStart = other.startTime;
    final otherEnd = other.endTime;
    if (start == null || end == null) return false;
    if (otherStart == null || otherEnd == null) return false;

    final a = start.minutesFromMidnight;
    final c = otherStart.minutesFromMidnight;
    // A window that wraps past midnight is treated as running to end of day;
    // the backend owns the real calendar.
    final b = end.minutesFromMidnight > a
        ? end.minutesFromMidnight
        : SlotTime.minutesPerDay;
    final d = otherEnd.minutesFromMidnight > c
        ? otherEnd.minutesFromMidnight
        : SlotTime.minutesPerDay;

    // Touching windows do not clash: 08–09 and 09–10 are back-to-back slots.
    return a < d && c < b;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  String toString() =>
      'Booking($id, $reference, court: $courtId, $date $startTimeRaw, '
      '$bookingStatusRaw/$paymentStatusRaw)';
}

/// Where a booking sits against the clock.
enum BookingPhase {
  upcoming('Upcoming'),
  ongoing('Ongoing'),
  finished('Completed');

  const BookingPhase(this.label);

  final String label;
}

/// `GET /bookings/stats`.
///
/// Every counter is nullable: a card shows an em dash for one the endpoint did
/// not send rather than a zero it cannot vouch for.
class BookingStats {
  const BookingStats({
    this.total,
    this.today,
    this.confirmed,
    this.pending,
    this.cancelled,
    this.completed,
    this.revenue,
    this.paid,
    this.unpaid,
    this.growthPercent,
    this.daily = const [],
    this.topSports = const [],
    this.topCourts = const [],
    this.peakHours = const [],
  });

  final int? total;
  final int? today;
  final int? confirmed;
  final int? pending;
  final int? cancelled;
  final int? completed;
  final num? revenue;
  final int? paid;
  final int? unpaid;

  /// Month-on-month growth, when the route sends one.
  final double? growthPercent;

  /// Optional series the charts draw. Empty when the route did not send them —
  /// a chart is simply not rendered rather than being filled with zeroes.
  final List<BookingPoint> daily;
  final List<BookingPoint> topSports;
  final List<BookingPoint> topCourts;
  final List<BookingPoint> peakHours;

  bool get isEmpty =>
      total == null &&
      today == null &&
      confirmed == null &&
      pending == null &&
      cancelled == null &&
      completed == null &&
      revenue == null;

  bool get hasCharts =>
      daily.isNotEmpty ||
      topSports.isNotEmpty ||
      topCourts.isNotEmpty ||
      peakHours.isNotEmpty;

  @override
  String toString() =>
      'BookingStats(total: $total, today: $today, revenue: $revenue)';
}

/// One labelled figure in a stats series.
class BookingPoint {
  const BookingPoint({required this.label, required this.value});

  final String label;
  final num value;

  @override
  String toString() => '$label: $value';
}

/// One page of `GET /bookings`.
class BookingPageResult {
  const BookingPageResult({
    this.bookings = const [],
    this.page = 1,
    this.totalPages = 1,
    this.totalItems = 0,
    this.perPage = 20,
  });

  final List<Booking> bookings;
  final int page;
  final int totalPages;
  final int totalItems;
  final int perPage;

  bool get hasMore => page < totalPages;

  @override
  String toString() =>
      'BookingPageResult(page $page/$totalPages, ${bookings.length} of '
      '$totalItems)';
}

/// The write payload for create and update.
class BookingDraft {
  const BookingDraft({
    this.userId,
    this.sportId,
    this.courtId,
    this.sportComplexId,
    this.date,
    this.startTime,
    this.endTime,
    this.amount,
    this.source,
    this.status,
    this.payment,
    this.transactionId,
    this.notes,
  });

  final int? userId;
  final int? sportId;
  final int? courtId;
  final int? sportComplexId;

  final DateTime? date;
  final SlotTime? startTime;
  final SlotTime? endTime;

  final num? amount;
  final BookingSource? source;
  final BookingStatus? status;
  final PaymentStatus? payment;
  final String? transactionId;
  final String? notes;

  /// `yyyy-MM-dd`, the shape every date this API returns is in.
  static String? formatDate(DateTime? value) {
    if (value == null) return null;
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  /// `HH:mm:ss` — the shape live booking payloads use, unlike the slots module
  /// which stores `HH:mm`.
  static String? formatTime(SlotTime? value) =>
      value == null ? null : '${value.wire}:00';

  /// `POST /bookings`
  Map<String, dynamic> toCreateJson() {
    return <String, dynamic>{
      'userId': userId,
      'sportId': sportId,
      'courtId': courtId,
      if (sportComplexId != null) 'sportComplexId': sportComplexId,
      'date': formatDate(date),
      'startTime': formatTime(startTime),
      'endTime': formatTime(endTime),
      'totalAmount': amount,
      'bookingSource': (source ?? BookingSource.admin).slug,
      'bookingStatus': (status ?? BookingStatus.confirmed).slug,
      'paymentStatus': (payment ?? PaymentStatus.pending).slug,
      'transactionId': (transactionId ?? '').trim(),
      'notes': (notes ?? '').trim(),
    };
  }

  /// `PUT /bookings/{bookingId}`.
  ///
  /// Only the five fields the route documents as editable — the date, the two
  /// times, the two statuses and the notes. The customer, sport and court are
  /// deliberately absent: the edit dialog renders those read-only for the same
  /// reason.
  ///
  /// A field the form never set is omitted; notes deliberately blanked are sent
  /// empty, or a note could never be cleared once written.
  Map<String, dynamic> toUpdateJson() {
    final body = <String, dynamic>{};

    final day = formatDate(date);
    if (day != null) body['date'] = day;

    final from = formatTime(startTime);
    if (from != null) body['startTime'] = from;

    final to = formatTime(endTime);
    if (to != null) body['endTime'] = to;

    if (status != null) body['bookingStatus'] = status!.slug;
    if (payment != null) body['paymentStatus'] = payment!.slug;
    if (notes != null) body['notes'] = notes!.trim();

    return body;
  }
}
