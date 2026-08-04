import '../entities/paged.dart';
import '../entities/report.dart';

/// Which analytics section a caller wants.
///
/// One enum rather than thirteen methods: every analytics route takes the same
/// window and answers the same shape (figures plus optional series), and the
/// mapper knows which documented figures belong to which.
enum ReportKind {
  overview,
  revenue,
  bookings,
  retention,
  memberships,
  users,
  coaching,
  facilities,
}

/// Which standalone chart a caller wants.
enum ReportChart { bookingTrends, revenueByCourt, peakHours, courtPerformance }

/// Which tabular report a caller wants.
enum ReportTable { bookings, students, coaches }

/// Which set of filter options a caller wants.
enum ReportFilterSet { bookings, students, retention, coaches }

/// Reports and analytics.
///
/// **No response was captured for any of these nineteen routes.** The module
/// documents the figures each screen must display, so the mappers read those
/// through ordered candidate keys and keep anything else the payload carried.
abstract class ReportRepository {
  /// `GET /reports/{kind}?from=&to=`
  Future<ReportSection> fetchSection(ReportKind kind, DateRange range);

  /// `GET /reports/charts/{chart}?from=&to=`
  Future<ChartSeries> fetchChart(ReportChart chart, DateRange range);

  /// `GET /reports/bookings/all?page=&limit=&from=&to=`
  Future<Paged<BookingReportRow>> fetchBookingRows(
    DateRange range, {
    int page,
    int limit,
    ReportFilters filters,
  });

  /// `GET /reports/students/all?page=&limit=&from=&to=`
  Future<Paged<StudentReportRow>> fetchStudentRows(
    DateRange range, {
    int page,
    int limit,
    ReportFilters filters,
  });

  /// `GET /reports/coaches/all?page=&limit=&from=&to=`
  Future<Paged<CoachReportRow>> fetchCoachRows(
    DateRange range, {
    int page,
    int limit,
    ReportFilters filters,
  });

  /// `GET /reports/{table}/filter-options`
  Future<ReportFilterOptions> fetchFilterOptions(ReportFilterSet set);
}
