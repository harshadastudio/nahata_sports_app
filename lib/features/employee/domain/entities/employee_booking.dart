import 'employee_formats.dart';

/// A court booking, from `GET /bookings`.
///
/// The list is complex-scoped for an EMPLOYEE, so every row belongs to their
/// own venue. `bookingSource` says where it came in from — `Website`, `App`, or
/// a partner feed such as `KheloMore` / `Huddle` — which matters because
/// partner rows all share one user account.
class EmployeeBooking {
  const EmployeeBooking({
    required this.id,
    this.customerName,
    this.userName = '',
    this.userEmail = '',
    this.userPhone = '',
    this.sportId,
    this.sportName = '',
    this.courtId,
    this.courtName = '',
    this.venueName = '',
    this.date,
    this.startTime,
    this.endTime,
    this.source = '',
    this.paymentStatus = '',
    this.bookingStatus = '',
    this.totalAmount = 0,
    this.transactionId,
    this.passCode,
    this.qrCode,
    this.maxPersons,
    this.notes,
    this.movedFromCourtId,
    this.moveReason,
    this.createdAt,
  });

  final int id;

  /// Set per booking by staff. Preferred over the account name because partner
  /// bookings all hang off one shared account — renaming the account would
  /// rename every one of that partner's bookings at once.
  final String? customerName;

  final String userName;
  final String userEmail;
  final String userPhone;

  final int? sportId;
  final String sportName;
  final int? courtId;
  final String courtName;
  final String venueName;

  /// `DATEONLY`, so no time component: `2026-08-07`.
  final DateTime? date;

  /// `HH:mm:ss` as sent by the API.
  final String? startTime;
  final String? endTime;

  final String source;
  final String paymentStatus;
  final String bookingStatus;
  final num totalAmount;

  final String? transactionId;
  final String? passCode;
  final String? qrCode;
  final int? maxPersons;
  final String? notes;

  /// Set when the slot was auto-reassigned to another court.
  final int? movedFromCourtId;
  final String? moveReason;

  final DateTime? createdAt;

  /// The name to show: the per-booking one when staff set it, else the account.
  String get displayName {
    final custom = customerName?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    final account = userName.trim();
    return account.isEmpty ? 'Guest' : account;
  }

  String get initial =>
      displayName.trim().isEmpty ? '?' : displayName.trim()[0].toUpperCase();

  bool get wasReassigned => movedFromCourtId != null;
  bool get hasPass => (qrCode ?? '').isNotEmpty || (passCode ?? '').isNotEmpty;

  bool get isPaid => paymentStatus.toLowerCase() == 'paid';
  bool get isCancelled => bookingStatus.toLowerCase() == 'cancelled';

  String get amountLabel => formatRupees(totalAmount);

  /// `9:00 AM – 10:00 AM`, or an em dash when the API sent no times.
  String get timeLabel {
    final from = formatClock(startTime);
    final to = formatClock(endTime);
    if (from == null && to == null) return '—';
    if (to == null) return from!;
    if (from == null) return to;
    return '$from – $to';
  }

  /// `07 Aug 2026`.
  String get dateLabel => formatDay(date);

  /// The reference the drawer shows, matching the website's `#NSC-000123`.
  String get reference => '#NSC-${id.toString().padLeft(6, '0')}';

  @override
  String toString() => 'EmployeeBooking($id, $displayName, $bookingStatus)';
}
