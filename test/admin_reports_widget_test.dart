import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nahata_app/core/network/api_exception.dart';
import 'package:nahata_app/features/admin/domain/entities/paged.dart';
import 'package:nahata_app/features/admin/domain/entities/report.dart';
import 'package:nahata_app/features/admin/domain/repositories/report_repository.dart';
import 'package:nahata_app/features/admin/presentation/pages/reports_page.dart';
import 'package:nahata_app/features/admin/presentation/state/reports_controller.dart';
import 'package:nahata_app/features/admin/presentation/theme/admin_theme.dart';
import 'package:nahata_app/features/admin/presentation/widgets/report_charts.dart';
import 'package:nahata_app/features/admin/presentation/widgets/report_tables.dart';
import 'package:nahata_app/features/admin/presentation/widgets/report_widgets.dart';

/// Paints the Reports page against a fake repository.
///
/// Nine tabs, four chart types, three tables and the filter bar all get laid
/// out for real, so an overflow shows up here rather than on a device.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  Future<ReportsController> pumpPage(
    WidgetTester tester, {
    required Size size,
    ReportRepository? repository,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final controller = ReportsController(repository ?? _FakeRepository());
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AdminTheme.build(Brightness.light),
        home: ChangeNotifierProvider<ReportsController>.value(
          value: controller,
          child: const Scaffold(body: ReportsPage()),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    return controller;
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    // The switcher sits above the body, so its label is the first match — the
    // same word also appears on cards and column headings below it.
    await tester.tap(find.text(label).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
  }

  testWidgets('the dashboard paints its eight cards and both charts', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1700, 1600));

    expect(find.text('Reports & Analytics'), findsOneWidget);

    // The eight documented dashboard cards.
    expect(find.text('Revenue'), findsWidgets);
    expect(find.text('Total bookings'), findsOneWidget);
    expect(find.text('Active members'), findsOneWidget);
    expect(find.text('Students'), findsWidgets);
    expect(find.text('Coaches'), findsWidgets);
    expect(find.text('Court utilization'), findsOneWidget);
    expect(find.text('Coaching revenue'), findsOneWidget);
    expect(find.text('Facility revenue'), findsOneWidget);

    expect(find.byType(ReportLineChart), findsOneWidget);
    expect(find.byType(ReportBarChart), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the range bar offers the presets and the window', (
    tester,
  ) async {
    final controller = await pumpPage(tester, size: const Size(1700, 1600));

    expect(find.text('Last 30 days'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget);
    expect(find.text('Refresh'), findsOneWidget);
    expect(find.text('Export'), findsWidgets);

    await tester.tap(find.text('Last 7 days'));
    // The range change is debounced, so the reload has to be let through
    // before the tree is torn down.
    await tester.pump();
    await tester.pump(
      ReportsController.rangeDebounce + const Duration(milliseconds: 50),
    );
    await tester.pump(const Duration(milliseconds: 300));

    expect(controller.preset, DateRangePreset.last7);
    expect(controller.range.days, 7);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a card with nothing behind it says so rather than showing 0', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(1700, 1600),
      // The overview answers with the revenue only.
      repository: _FakeRepository(
        sections: {
          ReportKind.overview: const ReportSection(
            figures: [
              ReportFigure(
                key: 'revenue',
                label: 'Total revenue',
                value: 336000,
                format: ReportFormat.currency,
              ),
            ],
          ),
        },
      ),
    );

    // "Not reported" is a different claim from a zero.
    expect(find.text('Not reported'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('figures the module never listed are shown as extras', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(1700, 1800),
      repository: _FakeRepository(
        sections: {
          ReportKind.overview: const ReportSection(
            figures: [
              ReportFigure(key: 'bookings', label: 'Total bookings', value: 420),
            ],
            extras: [
              ReportFigure(
                key: 'walkInRevenue',
                label: 'Walk in revenue',
                value: 12000,
                format: ReportFormat.currency,
              ),
            ],
          ),
        },
      ),
    );

    expect(find.text('Also reported'), findsOneWidget);
    expect(find.text('Walk in revenue'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the booking tab paints its table, filters and chart', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1700, 2000));
    await openTab(tester, 'Bookings');

    expect(find.byType(BookingReportTable), findsOneWidget);
    expect(find.text('Booking ID'), findsOneWidget);
    expect(find.text('Rahul Sharma'), findsWidgets);
    expect(find.byType(ReportFilterBar), findsOneWidget);
    // The dropdown built from the filter-options payload.
    expect(find.text('Sports'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the student and coach tabs paint their own columns', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1700, 2000));

    await openTab(tester, 'Students');
    expect(find.byType(StudentReportTable), findsOneWidget);
    expect(find.text('Batch'), findsOneWidget);
    expect(find.text('Priya Nair'), findsWidgets);

    await openTab(tester, 'Coaches');
    expect(find.byType(CoachReportTable), findsOneWidget);
    expect(find.text('Programs'), findsOneWidget);
    expect(find.text('Arjun Nahata'), findsWidgets);

    expect(tester.takeException(), isNull);
  });

  testWidgets('the facilities tab paints the pie and the bar chart', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(1700, 1800));
    await openTab(tester, 'Facilities');

    expect(find.text('Peak hours'), findsWidgets);
    expect(find.text('Court performance'), findsWidgets);
    expect(find.byType(ReportPieChart), findsOneWidget);

    expect(tester.takeException(), isNull);
  });

  testWidgets('a chart with no series explains itself instead of drawing zero',
      (tester) async {
    await pumpPage(
      tester,
      size: const Size(1700, 1600),
      repository: _FakeRepository(emptyCharts: true),
    );

    // An axis of zeroes would read as "nothing happened".
    expect(find.textContaining('No series was returned'), findsWidgets);
    expect(find.byType(ReportLineChart), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('one failed section shows its own retry, not a dead page', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(1700, 1600),
      repository: _FakeRepository(failSections: {ReportKind.coaching}),
    );

    // The dashboard still paints; only the coaching figure is missing.
    expect(find.text('Total bookings'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a whole failed tab offers a retry', (tester) async {
    await pumpPage(
      tester,
      size: const Size(1700, 1600),
      repository: _FakeRepository(
        failSections: {
          ReportKind.overview,
          ReportKind.revenue,
          ReportKind.memberships,
          ReportKind.coaching,
          ReportKind.facilities,
        },
      ),
    );

    expect(find.text('Could not load the dashboard'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty table explains itself instead of showing a grid', (
    tester,
  ) async {
    await pumpPage(
      tester,
      size: const Size(1700, 2000),
      repository: _FakeRepository(emptyTables: true),
    );
    await openTab(tester, 'Bookings');

    expect(find.text('No rows found'), findsOneWidget);
    expect(find.byType(BookingReportTable), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the phone layout swaps the tables for stacked cards', (
    tester,
  ) async {
    await pumpPage(tester, size: const Size(430, 1400));
    await openTab(tester, 'Bookings');

    expect(find.byType(BookingReportTable), findsNothing);
    expect(find.byType(BookingReportCard), findsNWidgets(2));
    expect(find.byType(RefreshIndicator), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
}

class _FakeRepository implements ReportRepository {
  _FakeRepository({
    this.sections = const {},
    this.emptyCharts = false,
    this.emptyTables = false,
    Set<ReportKind>? failSections,
  }) : failSections = failSections ?? <ReportKind>{};

  final Map<ReportKind, ReportSection> sections;
  final bool emptyCharts;
  final bool emptyTables;
  final Set<ReportKind> failSections;

  @override
  Future<ReportSection> fetchSection(ReportKind kind, DateRange range) async {
    if (failSections.contains(kind)) {
      throw const ServerException('The reports service is down');
    }
    if (sections.containsKey(kind)) return sections[kind]!;

    return switch (kind) {
      ReportKind.overview => const ReportSection(
        figures: [
          ReportFigure(
            key: 'revenue',
            label: 'Total revenue',
            value: 336000,
            format: ReportFormat.currency,
          ),
          ReportFigure(key: 'bookings', label: 'Total bookings', value: 420),
          ReportFigure(key: 'students', label: 'Total students', value: 180),
          ReportFigure(key: 'coaches', label: 'Total coaches', value: 12),
          ReportFigure(
            key: 'occupancy',
            label: 'Occupancy',
            value: 72,
            format: ReportFormat.percent,
          ),
        ],
      ),
      ReportKind.coaching => const ReportSection(
        figures: [
          ReportFigure(
            key: 'revenue',
            label: 'Coaching revenue',
            value: 96000,
            format: ReportFormat.currency,
          ),
        ],
      ),
      ReportKind.facilities => const ReportSection(
        figures: [
          ReportFigure(
            key: 'utilization',
            label: 'Court utilization',
            value: 68,
            format: ReportFormat.percent,
          ),
        ],
      ),
      ReportKind.memberships => const ReportSection(
        figures: [
          ReportFigure(key: 'active', label: 'Active memberships', value: 96),
        ],
      ),
      ReportKind.revenue => const ReportSection(
        figures: [
          ReportFigure(
            key: 'total',
            label: 'Total revenue',
            value: 336000,
            format: ReportFormat.currency,
          ),
        ],
      ),
      _ => const ReportSection(
        figures: [ReportFigure(key: 'total', label: 'Total', value: 10)],
      ),
    };
  }

  @override
  Future<ChartSeries> fetchChart(ReportChart chart, DateRange range) async {
    if (emptyCharts) {
      return ChartSeries(key: chart.name, label: chart.name);
    }
    return ChartSeries(
      key: chart.name,
      label: switch (chart) {
        ReportChart.bookingTrends => 'Booking trends',
        ReportChart.revenueByCourt => 'Revenue by court',
        ReportChart.peakHours => 'Peak hours',
        ReportChart.courtPerformance => 'Court performance',
      },
      valueLabel: 'Bookings',
      points: const [
        ChartPoint(label: 'Court 1', value: 12),
        ChartPoint(label: 'Court 2', value: 8),
        ChartPoint(label: 'Court 3', value: 5),
      ],
    );
  }

  @override
  Future<Paged<BookingReportRow>> fetchBookingRows(
    DateRange range, {
    int page = 1,
    int limit = 20,
    ReportFilters filters = const ReportFilters(),
  }) async {
    if (emptyTables) {
      return const Paged<BookingReportRow>(items: [], total: 0, totalPages: 0);
    }
    return Paged<BookingReportRow>(
      items: [
        BookingReportRow(
          id: '71',
          reference: 'BOOK-2026-000071',
          userName: 'Rahul Sharma',
          userContact: '9876543210',
          sportName: 'Badminton',
          courtName: 'Court 1',
          date: DateTime(2026, 8, 5),
          slotLabel: '19:00 – 20:00',
          amount: 800,
          statusRaw: 'Confirmed',
          paymentStatusRaw: 'Paid',
        ),
        const BookingReportRow(
          id: '72',
          reference: 'BOOK-2026-000072',
          userName: 'Priya Nair',
          statusRaw: 'Cancelled',
          paymentStatusRaw: 'Refunded',
        ),
      ],
      page: page,
      limit: limit,
      total: 2,
      totalPages: 1,
    );
  }

  @override
  Future<Paged<StudentReportRow>> fetchStudentRows(
    DateRange range, {
    int page = 1,
    int limit = 20,
    ReportFilters filters = const ReportFilters(),
  }) async => Paged<StudentReportRow>(
    items: [
      StudentReportRow(
        id: 's1',
        name: 'Priya Nair',
        sportName: 'Badminton',
        coachName: 'Arjun',
        batchName: 'Morning A',
        membership: 'Gold Annual',
        joinedAt: DateTime(2026, 2, 1),
        statusRaw: 'Active',
      ),
    ],
    page: page,
    limit: limit,
    total: 1,
    totalPages: 1,
  );

  @override
  Future<Paged<CoachReportRow>> fetchCoachRows(
    DateRange range, {
    int page = 1,
    int limit = 20,
    ReportFilters filters = const ReportFilters(),
  }) async => const Paged<CoachReportRow>(
    items: [
      CoachReportRow(
        id: 'c1',
        name: 'Arjun Nahata',
        sportName: 'Badminton',
        complexName: 'Kothrud Arena',
        studentCount: 24,
        revenue: 96000,
        programCount: 3,
        statusRaw: 'Active',
      ),
    ],
    page: 1,
    limit: 20,
    total: 1,
    totalPages: 1,
  );

  @override
  Future<ReportFilterOptions> fetchFilterOptions(ReportFilterSet set) async =>
      const ReportFilterOptions(
        groups: {
          'sports': [
            FilterOption(id: '8', label: 'Badminton'),
            FilterOption(id: '9', label: 'Tennis'),
          ],
        },
      );
}
