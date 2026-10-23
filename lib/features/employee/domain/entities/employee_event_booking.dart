import 'employee_formats.dart';

/// One booking made against an event, from `GET /event-passes/bookings/all`.
///
/// The route is complex-scoped **because the rows carry guest names and email
/// addresses** — an employee sees the bookings for their own complex's events
/// and no one else's.
///
/// A booking is not a pass: it is the purchase, and it holds one or more
/// [passes], each with its own QR code and its own id. Emailing "the booking"
/// means calling `POST /event-passes/individual-passes/{passId}/send-email`
/// once per pass, which is what [EmployeeEventBooking.passes] is for.
class EmployeeEventBooking {
  const EmployeeEventBooking({
    required this.id,
    this.bookingNumber = '',
    this.eventId,
    this.eventTitle = '',
    this.slotName = '',
    this.slotDate,
    this.customerName = '',
    this.email = '',
    this.phone = '',
    this.quantity = 1,
    this.totalAmount = 0,
    this.paymentStatus = 'Pending',
    this.bookingStatus = 'Confirmed',
    this.passes = const [],
    this.createdAt,
  });

  final int id;
  final String bookingNumber;

  final int? eventId;
  final String eventTitle;
  final String slotName;
  final DateTime? slotDate;

  final String customerName;
  final String email;
  final String phone;

  final int quantity;
  final num totalAmount;

  /// `Paid` | `Pending` | `Failed` | `Refunded`.
  final String paymentStatus;

  /// `Confirmed` | `Cancelled`.
  final String bookingStatus;

  /// The individual passes issued against this booking, from the row's own
  /// `individualPasses[]`. The list route carries them, so the detail sheet
  /// does not fetch anything — there is no per-booking passes route.
  final List<EmployeeIndividualPass> passes;

  final DateTime? createdAt;

  String get displayName =>
      customerName.trim().isEmpty ? 'Guest #$id' : customerName.trim();

  String get initial =>
      displayName.trim().isEmpty ? '?' : displayName.trim()[0].toUpperCase();

  String get displayReference =>
      bookingNumber.trim().isEmpty ? 'Booking #$id' : bookingNumber.trim();

  String get displayEventTitle =>
      eventTitle.trim().isEmpty ? 'Event' : eventTitle.trim();

  bool get isPaid => paymentStatus.toLowerCase() == 'paid';
  bool get isCancelled => bookingStatus.toLowerCase() == 'cancelled';

  String get amountLabel => formatRupees(totalAmount);

  String get bookedAtLabel => formatDateTime(createdAt);

  /// `Morning Batch · 10 Sep 2026`, or whichever half actually arrived.
  String get slotLabel => [
        if (slotName.trim().isNotEmpty) slotName.trim(),
        if (slotDate != null) formatDay(slotDate),
      ].join(' · ');

  /// How many passes are known. Falls back to [quantity] on the list route,
  /// where the passes themselves have not been fetched.
  int get passCount => passes.isEmpty ? quantity : passes.length;

  EmployeeEventBooking copyWith({List<EmployeeIndividualPass>? passes}) {
    return EmployeeEventBooking(
      id: id,
      bookingNumber: bookingNumber,
      eventId: eventId,
      eventTitle: eventTitle,
      slotName: slotName,
      slotDate: slotDate,
      customerName: customerName,
      email: email,
      phone: phone,
      quantity: quantity,
      totalAmount: totalAmount,
      paymentStatus: paymentStatus,
      bookingStatus: bookingStatus,
      passes: passes ?? this.passes,
      createdAt: createdAt,
    );
  }

  @override
  String toString() =>
      'EmployeeEventBooking($id, $displayReference, $passCount passes)';
}

/// One admission pass on a booking — the thing that actually carries a QR code
/// and can be emailed on its own.
class EmployeeIndividualPass {
  const EmployeeIndividualPass({
    required this.id,
    this.passCode = '',
    this.holderName = '',
    this.email,
    this.status = 'Active',
    this.scanStatus = 'NotScanned',
    this.qrCode,
    this.scannedAt,
  });

  final int id;
  final String passCode;

  /// The person this pass admits, which on a group booking is not the buyer.
  final String holderName;

  final String? email;

  /// `Active` | `Used` | `Cancelled` — the pass's own lifecycle, which is not
  /// where it is. [scanStatus] is the gate's answer.
  final String status;

  /// `NotScanned` | `In` | `Out` — how far the pass has got through the gate.
  /// This is the authoritative field; [scannedAt] only says when.
  final String scanStatus;

  /// The QR payload the pass carries, when the row reported one. Emailing the
  /// pass renders it server-side, so this is not needed to send one.
  final String? qrCode;

  final DateTime? scannedAt;

  String get displayName =>
      holderName.trim().isEmpty ? 'Pass #$id' : holderName.trim();

  String get displayCode =>
      passCode.trim().isEmpty ? '#$id' : passCode.trim();

  bool get isCheckedIn => scanStatus.toLowerCase() == 'in';
  bool get isCheckedOut => scanStatus.toLowerCase() == 'out';

  /// Whether the pass has been through the gate at all.
  bool get isUsed =>
      isCheckedIn ||
      isCheckedOut ||
      scannedAt != null ||
      status.toLowerCase() == 'used';

  /// `Checked in`, `Checked out 4:10 PM`, or `Not scanned`. The status leads
  /// because a pass can be scanned without the row carrying a timestamp.
  String get scannedLabel {
    final when = scannedAt == null ? '' : ' ${formatDateTime(scannedAt)}';
    if (isCheckedOut) return 'Checked out$when';
    if (isCheckedIn) return 'Checked in$when';
    if (scannedAt != null) return 'Scanned$when';
    return 'Not scanned';
  }

  @override
  String toString() =>
      'EmployeeIndividualPass($id, $displayCode, $scanStatus)';
}

/// The body of `POST /event-passes/individual-passes/{passId}/send-email`.
class EmployeeEventPassEmailDraft {
  const EmployeeEventPassEmailDraft({
    required this.email,
    this.recipientName,
  });

  final String email;

  /// Optional server-side — it only personalises the mail.
  final String? recipientName;

  bool get isValid {
    final text = email.trim();
    if (text.isEmpty) return false;
    return RegExp(r'^[^@\s]+@[^@\s.]+\.[^@\s]+$').hasMatch(text);
  }

  Map<String, dynamic> toJson() {
    final name = recipientName?.trim();
    return <String, dynamic>{
      'email': email.trim(),
      if (name != null && name.isNotEmpty) 'recipientName': name,
    };
  }
}
