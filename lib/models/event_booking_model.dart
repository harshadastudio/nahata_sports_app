/// Models for `GET /event-passes/bookings/my`.
library;

/// One pass inside a booking — each has its own code and scan state.
class EventIndividualPass {
  const EventIndividualPass({
    this.id,
    this.passCode,
    this.qrCode,
    this.maxPersons,
    this.scannedInCount = 0,
    this.scannedOutCount = 0,
    this.scanStatus,
    this.holderName,
    this.holderEmail,
    this.isValid = true,
    this.members = const <Map<String, dynamic>>[],
  });

  final int? id;

  /// e.g. `EVTPASS-2026-000027`.
  final String? passCode;

  final String? qrCode;
  final int? maxPersons;
  final int scannedInCount;
  final int scannedOutCount;

  /// `NotScanned`, `ScannedIn`, …
  final String? scanStatus;

  final String? holderName;
  final String? holderEmail;
  final bool isValid;
  final List<Map<String, dynamic>> members;

  bool get isScanned => (scanStatus ?? 'NotScanned').toLowerCase() != 'notscanned';

  factory EventIndividualPass.fromJson(Map<String, dynamic> json) =>
      EventIndividualPass(
        id: _asInt(json['id']),
        passCode: _asString(json['passCode'] ?? json['pass_code']),
        qrCode: _asString(json['qrCode'] ?? json['qr_code']),
        maxPersons: _asInt(json['maxPersons']),
        scannedInCount: _asInt(json['scannedInCount']) ?? 0,
        scannedOutCount: _asInt(json['scannedOutCount']) ?? 0,
        scanStatus: _asString(json['scanStatus']),
        holderName: _asString(json['holderName']),
        holderEmail: _asString(json['holderEmail']),
        isValid: json['isValid'] != false,
        members: (json['members'] is List)
            ? (json['members'] as List)
                .whereType<Map>()
                .map((m) => Map<String, dynamic>.from(m))
                .toList(growable: false)
            : const <Map<String, dynamic>>[],
      );
}

/// The event a booking belongs to, as embedded in the booking.
class BookedEvent {
  const BookedEvent({this.id, this.title, this.image});

  final int? id;
  final String? title;
  final String? image;

  factory BookedEvent.fromJson(Map<String, dynamic> json) => BookedEvent(
        id: _asInt(json['id']),
        title: _asString(json['title']),
        image: _asString(json['image']),
      );
}

/// The slot a booking is for, as embedded in the booking.
class BookedSlot {
  const BookedSlot({
    this.id,
    this.name,
    this.date,
    this.passType,
    this.price,
    this.startTime,
    this.endTime,
  });

  final int? id;
  final String? name;
  final String? date;
  final String? passType;
  final String? price;
  final String? startTime;
  final String? endTime;

  double get priceValue => double.tryParse(price ?? '') ?? 0;

  factory BookedSlot.fromJson(Map<String, dynamic> json) => BookedSlot(
        id: _asInt(json['id']),
        name: _asString(json['name']),
        date: _asString(json['date']),
        passType: _asString(json['passType'] ?? json['pass_type']),
        price: _asString(json['price']),
        startTime: _asString(json['startTime'] ?? json['start_time']),
        endTime: _asString(json['endTime'] ?? json['end_time']),
      );
}

/// A booking made by the signed-in user.
class EventPassBooking {
  const EventPassBooking({
    this.id,
    this.eventPassId,
    this.slotId,
    this.userId,
    this.name,
    this.email,
    this.numberOfPasses = 1,
    this.totalAmount,
    this.couponCode,
    this.discountAmount,
    this.originalAmount,
    this.status,
    this.qrCode,
    this.razorpayOrderId,
    this.razorpayPaymentId,
    this.createdAt,
    this.event,
    this.slot,
    this.individualPasses = const <EventIndividualPass>[],
  });

  final int? id;
  final int? eventPassId;
  final int? slotId;
  final int? userId;
  final String? name;
  final String? email;
  final int numberOfPasses;

  /// Decimal strings, e.g. `"200.00"`.
  final String? totalAmount;
  final String? couponCode;
  final String? discountAmount;
  final String? originalAmount;

  /// `Pending`, `Confirmed`, …
  final String? status;

  final String? qrCode;
  final String? razorpayOrderId;
  final String? razorpayPaymentId;
  final DateTime? createdAt;

  final BookedEvent? event;
  final BookedSlot? slot;
  final List<EventIndividualPass> individualPasses;

  double get totalValue => double.tryParse(totalAmount ?? '') ?? 0;
  double get discountValue => double.tryParse(discountAmount ?? '') ?? 0;

  bool get isPaid => (status ?? '').toLowerCase() != 'pending';

  /// The booking QR, falling back to the first individual pass's.
  String get displayQrCode {
    final own = qrCode;
    if (own != null && own.isNotEmpty) return own;
    for (final pass in individualPasses) {
      final code = pass.qrCode;
      if (code != null && code.isNotEmpty) return code;
    }
    return '';
  }

  String? get passCode => individualPasses
      .map((p) => p.passCode)
      .firstWhere((c) => c != null && c.isNotEmpty, orElse: () => null);

  factory EventPassBooking.fromJson(Map<String, dynamic> json) {
    final event = json['event'];
    final slot = json['slot'];
    final passes = json['individualPasses'];

    return EventPassBooking(
      id: _asInt(json['id']),
      eventPassId: _asInt(json['eventPassId']),
      slotId: _asInt(json['slotId']),
      userId: _asInt(json['userId']),
      name: _asString(json['name']),
      email: _asString(json['email']),
      numberOfPasses: _asInt(json['numberOfPasses']) ?? 1,
      totalAmount: _asString(json['totalAmount']),
      couponCode: _asString(json['couponCode']),
      discountAmount: _asString(json['discountAmount']),
      originalAmount: _asString(json['originalAmount']),
      status: _asString(json['status']),
      qrCode: _asString(json['qrCode']),
      razorpayOrderId: _asString(json['razorpayOrderId']),
      razorpayPaymentId: _asString(json['razorpayPaymentId']),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      event: event is Map
          ? BookedEvent.fromJson(Map<String, dynamic>.from(event))
          : null,
      slot: slot is Map
          ? BookedSlot.fromJson(Map<String, dynamic>.from(slot))
          : null,
      individualPasses: passes is List
          ? passes
              .whereType<Map>()
              .map((p) =>
                  EventIndividualPass.fromJson(Map<String, dynamic>.from(p)))
              .toList(growable: false)
          : const <EventIndividualPass>[],
    );
  }

  static List<EventPassBooking> listFrom(Object? data) {
    if (data is! List) return const <EventPassBooking>[];
    return data
        .whereType<Map>()
        .map((e) => EventPassBooking.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  /// Flat shape the existing pass screen reads, so its UI needs no changes.
  Map<String, dynamic> toViewPassMap() => <String, dynamic>{
        'booking_id': id?.toString() ?? '',
        'qr_code': displayQrCode,
        'pass_code': passCode ?? '',
        'tournament_title': event?.title ?? '',
        'slot_name': slot?.name ?? '',
        'pass_date': slot?.date ?? '',
        'start_time': slot?.startTime ?? '',
        'end_time': slot?.endTime ?? '',
        'pass_type': slot?.passType ?? '',
        'members_count': numberOfPasses.toString(),
        'pass_price': slot?.price ?? '0',
        'event_image': event?.image ?? '',
        'status': status ?? '',
      };
}

int? _asInt(Object? value) =>
    value is int ? value : int.tryParse(value?.toString() ?? '');

String? _asString(Object? value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty || text == 'null') ? null : text;
}
