/// Models for `GET /courts/bookings/my`.
library;

/// The venue a court belongs to.
class BookedComplex {
  const BookedComplex({this.id, this.name, this.city});

  final int? id;
  final String? name;
  final String? city;

  factory BookedComplex.fromJson(Map<String, dynamic> json) => BookedComplex(
        id: _asInt(json['id']),
        name: _asString(json['name']),
        city: _asString(json['city']),
      );
}

/// The court a booking is for.
class BookedCourt {
  const BookedCourt({
    this.id,
    this.name,
    this.sportId,
    this.sportComplexId,
    this.surfaceType,
    this.hourlyRate,
    this.complex,
  });

  final int? id;
  final String? name;
  final int? sportId;
  final int? sportComplexId;
  final String? surfaceType;
  final String? hourlyRate;
  final BookedComplex? complex;

  factory BookedCourt.fromJson(Map<String, dynamic> json) {
    final complex = json['SportComplex'] ?? json['sportComplex'];
    return BookedCourt(
      id: _asInt(json['id']),
      name: _asString(json['name']),
      sportId: _asInt(json['sportId']),
      sportComplexId: _asInt(json['sportComplexId']),
      surfaceType: _asString(json['surfaceType']),
      hourlyRate: _asString(json['hourlyRate']),
      complex: complex is Map
          ? BookedComplex.fromJson(Map<String, dynamic>.from(complex))
          : null,
    );
  }
}

/// The sport played on the booked court.
class BookedSport {
  const BookedSport({this.id, this.name, this.image});

  final int? id;
  final String? name;
  final String? image;

  factory BookedSport.fromJson(Map<String, dynamic> json) => BookedSport(
        id: _asInt(json['id']),
        name: _asString(json['name']),
        image: _asString(json['image']),
      );
}

/// A court (facility) booking made by the signed-in user.
class CourtBooking {
  const CourtBooking({
    this.id,
    this.date,
    this.startTime,
    this.endTime,
    this.bookingStatus,
    this.paymentStatus,
    this.totalAmount,
    this.bookingSource,
    this.passCode,
    this.qrCode,
    this.maxPersons,
    this.scannedInCount = 0,
    this.scannedOutCount = 0,
    this.scanStatus,
    this.transactionId,
    this.couponCode,
    this.discountAmount,
    this.notes,
    this.createdAt,
    this.court,
    this.sport,
    this.members = const <Map<String, dynamic>>[],
  });

  final int? id;

  /// `yyyy-MM-dd`.
  final String? date;

  /// `HH:mm:ss`.
  final String? startTime;
  final String? endTime;

  /// `Confirmed`, `Pending`, `Cancelled`.
  final String? bookingStatus;

  /// `Paid`, `Pending`.
  final String? paymentStatus;

  final String? totalAmount;
  final String? bookingSource;

  /// e.g. `BOOK-2026-000071` — the value encoded in [qrCode].
  final String? passCode;

  final String? qrCode;
  final int? maxPersons;
  final int scannedInCount;
  final int scannedOutCount;
  final String? scanStatus;
  final String? transactionId;
  final String? couponCode;
  final String? discountAmount;
  final String? notes;
  final DateTime? createdAt;

  final BookedCourt? court;
  final BookedSport? sport;
  final List<Map<String, dynamic>> members;

  double get totalValue => double.tryParse(totalAmount ?? '') ?? 0;

  bool get isPaid => (paymentStatus ?? '').toLowerCase() == 'paid';
  bool get isConfirmed => (bookingStatus ?? '').toLowerCase() == 'confirmed';
  bool get isScanned =>
      (scanStatus ?? 'NotScanned').toLowerCase() != 'notscanned';

  /// Booking date as a date, when it parses.
  DateTime? get dateTime => DateTime.tryParse(date ?? '');

  /// [date] + [startTime] as one local instant.
  DateTime? get startsAt => _at(startTime);

  /// [date] + [endTime] as one local instant. Falls back to the end of the
  /// booked day when the API sends no end time.
  DateTime? get endsAt {
    final day = dateTime;
    if (day == null) return null;
    return _at(endTime) ?? DateTime(day.year, day.month, day.day, 23, 59, 59);
  }

  /// True until the slot's end time passes — a slot that finished earlier
  /// today is already previous, one later today is still upcoming.
  bool get isUpcoming {
    final end = endsAt;
    if (end == null) return false;
    return end.isAfter(DateTime.now());
  }

  /// Sort key: bookings with no usable date fall to the end of either list.
  DateTime get _sortKey => startsAt ?? endsAt ?? DateTime(1970);

  DateTime? _at(String? time) {
    final day = dateTime;
    if (day == null) return null;

    final parts = (time ?? '').split(':');
    if (parts.length < 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;

    final second = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
    return DateTime(day.year, day.month, day.day, hour, minute, second);
  }

  /// Slots still to come — today's later slots first, then tomorrow onwards.
  static List<CourtBooking> upcomingFrom(List<CourtBooking> bookings) {
    final list = bookings.where((b) => b.isUpcoming).toList();
    list.sort((a, b) => a._sortKey.compareTo(b._sortKey));
    return list;
  }

  /// Slots already finished — the most recent first.
  static List<CourtBooking> previousFrom(List<CourtBooking> bookings) {
    final list = bookings.where((b) => !b.isUpcoming).toList();
    list.sort((a, b) => b._sortKey.compareTo(a._sortKey));
    return list;
  }

  factory CourtBooking.fromJson(Map<String, dynamic> json) {
    final court = json['court'];
    final sport = json['sport'];
    final members = json['members'];

    return CourtBooking(
      id: _asInt(json['id']),
      date: _asString(json['date']),
      startTime: _asString(json['startTime']),
      endTime: _asString(json['endTime']),
      bookingStatus: _asString(json['bookingStatus']),
      paymentStatus: _asString(json['paymentStatus']),
      totalAmount: _asString(json['totalAmount']),
      bookingSource: _asString(json['bookingSource']),
      passCode: _asString(json['passCode']),
      qrCode: _asString(json['qrCode']),
      maxPersons: _asInt(json['maxPersons']),
      scannedInCount: _asInt(json['scannedInCount']) ?? 0,
      scannedOutCount: _asInt(json['scannedOutCount']) ?? 0,
      scanStatus: _asString(json['scanStatus']),
      transactionId: _asString(json['transactionId']),
      couponCode: _asString(json['couponCode']),
      discountAmount: _asString(json['discountAmount']),
      notes: _asString(json['notes']),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      court: court is Map
          ? BookedCourt.fromJson(Map<String, dynamic>.from(court))
          : null,
      sport: sport is Map
          ? BookedSport.fromJson(Map<String, dynamic>.from(sport))
          : null,
      members: members is List
          ? members
              .whereType<Map>()
              .map((m) => Map<String, dynamic>.from(m))
              .toList(growable: false)
          : const <Map<String, dynamic>>[],
    );
  }

  static List<CourtBooking> listFrom(Object? data) {
    if (data is! List) return const <CourtBooking>[];
    return data
        .whereType<Map>()
        .map((e) => CourtBooking.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  /// Flat shape the pass card reads.
  Map<String, dynamic> toPassMap() => <String, dynamic>{
        'booking_id': id?.toString() ?? '',
        'qr_code': qrCode ?? '',
        'pass_code': passCode ?? '',
        'sport_name': sport?.name ?? '',
        'court_name': court?.name ?? '',
        'venue_name': court?.complex?.name ?? '',
        'pass_date': date ?? '',
        'start_time': startTime ?? '',
        'end_time': endTime ?? '',
        'status': bookingStatus ?? '',
        'payment_status': paymentStatus ?? '',
        'total_amount': totalAmount ?? '0',
        'max_persons': (maxPersons ?? 1).toString(),
      };

  /// `5:00 AM - 6:00 AM`, or just the start when there is no end time.
  String get slotLabel {
    final from = _clock(startTime);
    final to = _clock(endTime);
    if (from.isEmpty) return to;
    return to.isEmpty ? from : '$from - $to';
  }

  /// Flat shape the My Bookings card reads.
  Map<String, dynamic> toBookingMap() => <String, dynamic>{
        'booking_id': id?.toString() ?? '',
        'court_name': court?.name ?? '',
        'venue_name': court?.complex?.name ?? '',
        'sport_name': sport?.name ?? '',
        'selected_date': date ?? '',
        'amount': totalAmount ?? '0',
        'qr_code': qrCode ?? '',
        'pass_code': passCode ?? '',
        'status': bookingStatus ?? '',
        'payment_status': paymentStatus ?? '',
        'slots': <Map<String, dynamic>>[
          if (slotLabel.isNotEmpty) {'time': slotLabel},
        ],
      };

  /// `05:00:00` → `5:00 AM`.
  static String _clock(String? time) {
    final parts = (time ?? '').split(':');
    if (parts.length < 2) return '';

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return '';

    final suffix = hour < 12 ? 'AM' : 'PM';
    final display = hour % 12 == 0 ? 12 : hour % 12;
    return '$display:${minute.toString().padLeft(2, '0')} $suffix';
  }
}

/// One page of `GET /courts/bookings/my`.
class CourtBookingPage {
  const CourtBookingPage({
    this.bookings = const <CourtBooking>[],
    this.currentPage = 1,
    this.totalPages = 1,
    this.totalItems = 0,
  });

  final List<CourtBooking> bookings;
  final int currentPage;
  final int totalPages;
  final int totalItems;

  bool get hasMore => currentPage < totalPages;

  factory CourtBookingPage.fromJson({
    Object? data,
    Map<String, dynamic>? pagination,
  }) {
    final page = pagination ?? const <String, dynamic>{};
    return CourtBookingPage(
      bookings: CourtBooking.listFrom(data),
      currentPage: _asInt(page['currentPage']) ?? 1,
      totalPages: _asInt(page['totalPages']) ?? 1,
      totalItems: _asInt(page['totalItems']) ?? 0,
    );
  }
}

int? _asInt(Object? value) =>
    value is int ? value : int.tryParse(value?.toString() ?? '');

String? _asString(Object? value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty || text == 'null') ? null : text;
}
