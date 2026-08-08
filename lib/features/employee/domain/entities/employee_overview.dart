import 'employee_booking.dart';
import 'employee_formats.dart';

/// The headline numbers on the employee dashboard, from `GET /reports/overview`.
///
/// The route is complex-scoped for an EMPLOYEE (`resolveComplexId` reads the
/// caller's `sportComplexId`), so every figure here already describes the
/// employee's own venue — no filter is sent and none would be honoured.
///
/// The website's employee dashboard shows only three of these. The phone shows
/// more because the route already returns them: an employee opening the app at
/// the desk wants the day's shape, not a subset of it.
class EmployeeStats {
  const EmployeeStats({
    this.todayBookings = 0,
    this.upcomingBookings = 0,
    this.totalBookings = 0,
    this.totalRevenue = 0,
    this.totalStudents = 0,
    this.activeEnrollments = 0,
    this.totalCoaches = 0,
    this.totalCourts = 0,
    this.revenueTrend,
    this.bookingsTrend,
  });

  /// Slots booked for today.
  final int todayBookings;

  /// Slots booked for the next seven days — deliberately excludes today.
  final int upcomingBookings;

  final int totalBookings;

  /// Summed from the records that hold the money (paid court bookings,
  /// confirmed event passes, collected coaching fees) — **not** the `Payments`
  /// table, which is empty in production.
  final num totalRevenue;

  final int totalStudents;
  final int activeEnrollments;
  final int totalCoaches;
  final int totalCourts;

  /// Percentage change against the equally long window before this one. Null
  /// when the backend had no baseline to compare against — showing `+100%` for
  /// "there was nothing before" would be a lie.
  final double? revenueTrend;
  final double? bookingsTrend;

  static const EmployeeStats empty = EmployeeStats();

  String get revenueLabel => formatRupees(totalRevenue);

  @override
  String toString() => 'EmployeeStats(today: $todayBookings, '
      'upcoming: $upcomingBookings, revenue: $totalRevenue)';
}

/// The dashboard's "Recent Bookings" strip — the five newest rows of
/// `GET /bookings?page=1&limit=5&sortBy=createdAt&sortOrder=DESC`.
///
/// A thin view over [EmployeeBooking] rather than a second type: it is the same
/// row, just rendered smaller, and duplicating the parser would mean two places
/// to fix when the booking shape moves.
typedef EmployeeRecentBooking = EmployeeBooking;
