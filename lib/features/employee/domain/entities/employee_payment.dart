import 'employee_formats.dart';

/// One row of the unified payment ledger, from `GET /payments/all`.
///
/// The route merges three sources that live in different tables — court
/// bookings, event-pass bookings and coaching fees — into one list, so [id] is
/// a composite string (`BOOKING_12`, `EVENT_4`, `FEE_31`) and [sourceId] is the
/// numeric id **within that source**. Two rows can share a `sourceId` and still
/// be different payments; always key off [id].
///
/// It is not the `Payments` table: nothing in the app writes rows there, so the
/// backend aggregates from the records that actually hold the money.
class EmployeePayment {
  const EmployeePayment({
    required this.id,
    this.sourceId,
    this.type = '',
    this.typeLabel = '',
    this.transactionId,
    this.razorpayPaymentId,
    this.razorpayOrderId,
    this.userName = '',
    this.userEmail = '',
    this.userPhone = '',
    this.amount = 0,
    this.paymentMode = '',
    this.status = '',
    this.description = '',
    this.venue = '',
    this.createdAt,
    this.date,
  });

  /// Composite and source-prefixed — `FEE_31`, not `31`.
  final String id;

  /// The row's id inside its own table. Only meaningful together with [type].
  final int? sourceId;

  /// `facility` | `event` | `coaching`.
  final String type;

  /// The human label the backend already picked — `Court Booking`,
  /// `Event Pass`, `Coaching Fee`.
  final String typeLabel;

  final String? transactionId;
  final String? razorpayPaymentId;
  final String? razorpayOrderId;

  final String userName;
  final String userEmail;
  final String userPhone;

  final num amount;

  /// `Cash`, `UPI`, `Razorpay`, … Whatever was recorded at collection.
  final String paymentMode;

  /// Normalised across the three sources to `Paid` | `Pending` | `Failed` |
  /// `Refunded`.
  final String status;

  final String description;
  final String venue;

  final DateTime? createdAt;

  /// The date the payment is *for* (the booking's date, the enrollment date),
  /// which is not always the date it was recorded on.
  final String? date;

  String get displayName => userName.trim().isEmpty ? 'Unknown' : userName.trim();

  String get initial =>
      displayName.trim().isEmpty ? '?' : displayName.trim()[0].toUpperCase();

  String get amountLabel => formatRupees(amount);

  bool get isPaid => status.toLowerCase() == 'paid';

  @override
  String toString() => 'EmployeePayment($id, $status, $amount)';
}

/// The summary strip above the ledger. Sent alongside the rows on every page,
/// and describes the **whole filtered set**, not just the page in hand.
class EmployeePaymentStats {
  const EmployeePaymentStats({
    this.totalRevenue = 0,
    this.successCount = 0,
    this.pendingCount = 0,
    this.failedCount = 0,
    this.totalCount = 0,
  });

  final num totalRevenue;
  final int successCount;
  final int pendingCount;
  final int failedCount;
  final int totalCount;

  static const EmployeePaymentStats empty = EmployeePaymentStats();

  String get revenueLabel => formatRupees(totalRevenue);

  @override
  String toString() =>
      'EmployeePaymentStats(revenue: $totalRevenue, ok: $successCount)';
}

/// A page of the ledger plus the stats that came with it.
///
/// Kept as one object because the two always arrive in the same response and
/// splitting them would mean two round trips or a stats value that lags the
/// rows it sits above.
class EmployeePaymentsPage {
  const EmployeePaymentsPage({
    required this.payments,
    required this.stats,
    this.page = 1,
    this.limit = 20,
    this.total = 0,
    this.totalPages = 0,
  });

  final List<EmployeePayment> payments;
  final EmployeePaymentStats stats;
  final int page;
  final int limit;
  final int total;
  final int totalPages;

  int get effectiveTotalPages {
    if (totalPages > 0) return totalPages;
    if (total > 0 && limit > 0) return (total / limit).ceil();
    return payments.isEmpty ? 0 : page;
  }

  bool get hasNext => page < effectiveTotalPages;

  static const EmployeePaymentsPage empty = EmployeePaymentsPage(
    payments: [],
    stats: EmployeePaymentStats.empty,
  );

  @override
  String toString() =>
      'EmployeePaymentsPage(${payments.length} rows, page $page/$effectiveTotalPages)';
}
