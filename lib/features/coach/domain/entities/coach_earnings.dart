/// Entities behind the coach dashboard's My Earnings card.
///
/// Source: `GET /coach/dashboard/earnings?startDate=&endDate=`.
library;

/// One batch's contribution to the earnings figures.
class CoachEarningsBatch {
  const CoachEarningsBatch({
    required this.batchId,
    this.batchName = '',
    this.sportName,
    this.complexName,
    this.earnings = 0,
    this.collected = 0,
    this.nahataEarnings = 0,
    this.payments = 0,
  });

  final int batchId;
  final String batchName;
  final String? sportName;
  final String? complexName;

  /// The coach's own share for this batch.
  final num earnings;

  /// Total collected across every payment on this batch.
  final num collected;

  final num nahataEarnings;
  final int payments;

  String get displayName => batchName.trim().isEmpty ? 'Batch' : batchName;

  @override
  String toString() => 'CoachEarningsBatch($batchId, $batchName, $earnings)';
}

/// One month's contribution to the earnings figures.
class CoachEarningsMonth {
  const CoachEarningsMonth({
    required this.month,
    this.label = '',
    this.earnings = 0,
    this.collected = 0,
    this.nahataEarnings = 0,
    this.payments = 0,
  });

  /// `yyyy-MM`.
  final String month;
  final String label;
  final num earnings;
  final num collected;
  final num nahataEarnings;
  final int payments;

  String get displayLabel => label.trim().isEmpty ? month : label;

  @override
  String toString() => 'CoachEarningsMonth($month, $earnings)';
}

/// The whole My Earnings card.
class CoachEarnings {
  const CoachEarnings({
    this.coachId,
    this.totalEarnings = 0,
    this.earnedFromPayments = 0,
    this.reversedByRefunds = 0,
    this.totalCollected = 0,
    this.nahataShare = 0,
    this.paymentCount = 0,
    this.byBatch = const [],
    this.byMonth = const [],
    this.startDate,
    this.endDate,
    this.allTime = true,
  });

  final int? coachId;

  /// Your share, net of refunds. Drives the headline figure.
  final num totalEarnings;

  final num earnedFromPayments;

  /// Negative when refunds took money back out of what was earned.
  final num reversedByRefunds;

  /// `totalEarnings + nahataShare === totalCollected`.
  final num totalCollected;

  final num nahataShare;
  final int paymentCount;

  final List<CoachEarningsBatch> byBatch;
  final List<CoachEarningsMonth> byMonth;

  final String? startDate;
  final String? endDate;
  final bool allTime;

  static const CoachEarnings empty = CoachEarnings();

  bool get isEmpty => totalCollected == 0 && paymentCount == 0;

  /// `YOUR SHARE % = totalEarnings / totalCollected * 100`.
  String get sharePercentLabel {
    if (totalCollected <= 0) return '0%';
    final pct = (totalEarnings / totalCollected) * 100;
    return '${pct.round()}%';
  }

  @override
  String toString() =>
      'CoachEarnings(total: $totalEarnings, collected: $totalCollected, '
      'nahata: $nahataShare, payments: $paymentCount)';
}

/// The client-side range chips on the My Earnings card.
enum CoachEarningsRange { allTime, days30, days90, thisYear }

extension CoachEarningsRangeLabel on CoachEarningsRange {
  String get label {
    switch (this) {
      case CoachEarningsRange.allTime:
        return 'All time';
      case CoachEarningsRange.days30:
        return '30 days';
      case CoachEarningsRange.days90:
        return '90 days';
      case CoachEarningsRange.thisYear:
        return 'This year';
    }
  }
}
