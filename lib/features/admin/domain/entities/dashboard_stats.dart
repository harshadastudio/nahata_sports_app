/// One counter on the dashboard home, with its month-over-month movement.
///
/// Every figure is nullable: a card whose numbers the server did not send shows
/// an em dash rather than a fabricated zero, and the trend row disappears
/// entirely when there is no movement to report.
class StatMetric {
  const StatMetric({
    this.total,
    this.thisMonth,
    this.lastMonth,
    this.growth,
    this.isPositive,
  });

  final int? total;
  final int? thisMonth;
  final int? lastMonth;

  /// Percentage change as sent by the server (`12.5` meaning 12.5%).
  final double? growth;

  /// The server's own verdict on the direction. Falls back to the sign of
  /// [growth] when it is not sent — see [trendIsPositive].
  final bool? isPositive;

  static const StatMetric empty = StatMetric();

  bool get isEmpty =>
      total == null && thisMonth == null && lastMonth == null && growth == null;

  bool get isNotEmpty => !isEmpty;

  /// True when the trend should read green/up.
  ///
  /// `isPositive` wins when the API sends it, because a fall in (say)
  /// cancellations may well be the good direction and only the backend knows
  /// that. Otherwise the sign of the growth figure decides.
  bool get trendIsPositive => isPositive ?? ((growth ?? 0) >= 0);

  /// True when there is a movement worth drawing an arrow for.
  bool get hasTrend =>
      growth != null || (thisMonth != null && lastMonth != null);

  /// The growth to display: the server's figure, or one derived from the two
  /// month counts when it did not send a percentage.
  double? get effectiveGrowth {
    if (growth != null) return growth;

    final current = thisMonth;
    final previous = lastMonth;
    if (current == null || previous == null) return null;

    // A month that starts from zero has no defined percentage — showing
    // "+∞%" or a bogus 100% would be worse than showing nothing.
    if (previous == 0) return null;

    return ((current - previous) / previous) * 100;
  }

  @override
  String toString() =>
      'StatMetric(total: $total, thisMonth: $thisMonth, '
      'lastMonth: $lastMonth, growth: $growth, isPositive: $isPositive)';
}

/// The five counters behind `GET /dashboard/stats`.
class DashboardStats {
  const DashboardStats({
    this.students = StatMetric.empty,
    this.coaches = StatMetric.empty,
    this.bookings = StatMetric.empty,
    this.enquiries = StatMetric.empty,
    this.contactRequests = StatMetric.empty,
    this.raw = const {},
  });

  final StatMetric students;
  final StatMetric coaches;
  final StatMetric bookings;
  final StatMetric enquiries;
  final StatMetric contactRequests;

  /// The untouched payload, so a counter this entity does not model is still
  /// reachable by a later module.
  final Map<String, dynamic> raw;

  static const DashboardStats empty = DashboardStats();

  bool get isEmpty =>
      students.isEmpty &&
      coaches.isEmpty &&
      bookings.isEmpty &&
      enquiries.isEmpty &&
      contactRequests.isEmpty;

  bool get isNotEmpty => !isEmpty;

  @override
  String toString() =>
      'DashboardStats(students: ${students.total}, '
      'coaches: ${coaches.total}, bookings: ${bookings.total}, '
      'enquiries: ${enquiries.total}, contact: ${contactRequests.total})';
}
