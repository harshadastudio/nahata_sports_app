import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/report.dart';
import '../../domain/repositories/report_repository.dart';
import '../state/reports_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_export.dart';
import '../utils/admin_format.dart';
import '../widgets/admin_dialogs.dart';
import '../widgets/admin_states.dart';
import '../widgets/glass_card.dart';
import '../widgets/report_charts.dart';
import '../widgets/report_tables.dart';
import '../widgets/report_widgets.dart';

/// Reports and analytics: nine tabs over nineteen endpoints, all scoped to one
/// date range.
class ReportsPage extends StatefulWidget {
  const ReportsPage({super.key});

  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final ScrollController _scroll = ScrollController();
  final Map<ReportTable, TextEditingController> _search = {
    for (final table in ReportTable.values) table: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    AdminLog.life('ReportsPage mounted');
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReportsController>().loadCurrent();
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final controller = context.read<ReportsController>();
    final table = ReportsController.tableFor(controller.view);
    if (table == null) return;

    final position = _scroll.position;
    // Fires a screen early, so the next page is usually there by the time the
    // list reaches the bottom. The controller ignores a second call while one
    // is in flight, so a fast flick cannot request the same page twice.
    if (position.pixels >= position.maxScrollExtent - 400) {
      controller.loadMore(table);
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    for (final controller in _search.values) {
      controller.dispose();
    }
    AdminLog.life('ReportsPage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ReportsController>();
    final tokens = AdminTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < AdminTokens.mobileMax;

    // Deferred past this frame: writing to the controller mid-build would mark
    // the TextField dirty while its ancestor is still building.
    final table = ReportsController.tableFor(controller.view);
    if (table != null) {
      final field = _search[table]!;
      final live = controller.searchFor(table);
      if (field.text != live) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || field.text == live) return;
          field.value = TextEditingValue(
            text: live,
            selection: TextSelection.collapsed(offset: live.length),
          );
        });
      }
    }

    return ColoredBox(
      color: tokens.canvas,
      child: RefreshIndicator(
        onRefresh: controller.refresh,
        child: SingleChildScrollView(
          controller: _scroll,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.all(
            isMobile ? AdminTokens.space4 : AdminTokens.space6,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(controller: controller),
              const SizedBox(height: AdminTokens.space4),
              ReportRangeBar(
                range: controller.range,
                preset: controller.preset,
                busy: controller.dashboardIsLoading,
                onPreset: controller.setPreset,
                onPickRange: () => _pickRange(context, controller),
                onRefresh: controller.refresh,
                onExport: null,
              ),
              const SizedBox(height: AdminTokens.space4),
              _ViewSwitcher(controller: controller),
              const SizedBox(height: AdminTokens.space5),
              _Body(
                controller: controller,
                isMobile: isMobile,
                searchControllers: _search,
                onExport: (format, origin) =>
                    _export(context, controller, format, origin),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickRange(
    BuildContext context,
    ReportsController controller,
  ) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 1),
      initialDateRange: DateTimeRange(
        start: controller.range.from,
        end: controller.range.to,
      ),
      helpText: 'Select the report window',
      saveText: 'Apply',
    );
    if (picked == null || !context.mounted) return;

    controller.setRange(
      DateRange(
        from: DateTime(
          picked.start.year,
          picked.start.month,
          picked.start.day,
        ),
        to: DateTime(picked.end.year, picked.end.month, picked.end.day),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Export
  // ---------------------------------------------------------------------------

  Future<void> _export(
    BuildContext context,
    ReportsController controller,
    ExportFormat format,
    Rect? origin,
  ) async {
    final view = controller.view;
    final window =
        '${AdminFormat.date(controller.range.from)} – '
        '${AdminFormat.date(controller.range.to)}';

    try {
      final table = ReportsController.tableFor(view);

      if (table == ReportTable.bookings) {
        const which = ReportTable.bookings;
        await _run(
          context,
          format: format,
          origin: origin,
          name: 'booking-report',
          title: 'Booking report',
          window: window,
          rows: controller.bookings,
          columns: _bookingColumns,
          // Said plainly: an infinite list has only what has been scrolled to.
          scope:
              '${controller.bookings.length} of '
              '${controller.totalCount(which) ?? controller.bookings.length} '
              'bookings loaded',
        );
        return;
      }
      if (table == ReportTable.students) {
        const which = ReportTable.students;
        await _run(
          context,
          format: format,
          origin: origin,
          name: 'student-report',
          title: 'Student report',
          window: window,
          rows: controller.students,
          columns: _studentColumns,
          scope:
              '${controller.students.length} of '
              '${controller.totalCount(which) ?? controller.students.length} '
              'students loaded',
        );
        return;
      }
      if (table == ReportTable.coaches) {
        const which = ReportTable.coaches;
        await _run(
          context,
          format: format,
          origin: origin,
          name: 'coach-report',
          title: 'Coach report',
          window: window,
          rows: controller.coaches,
          columns: _coachColumns,
          scope:
              '${controller.coaches.length} of '
              '${controller.totalCount(which) ?? controller.coaches.length} '
              'coaches loaded',
        );
        return;
      }

      // An analytics tab has figures rather than rows, so the figures are what
      // gets written.
      final figures = _figuresFor(controller, view);
      await _run(
        context,
        format: format,
        origin: origin,
        name: '${view.name}-report',
        title: '${view.label} report',
        window: window,
        rows: figures,
        columns: _figureColumns,
        scope: '${figures.length} figures',
      );
    } catch (error) {
      if (!context.mounted) return;
      AdminFeedback.error(context, _messageOf(error, 'export this report'));
    }
  }

  Future<void> _run<T>(
    BuildContext context, {
    required ExportFormat format,
    required Rect? origin,
    required String name,
    required String title,
    required String window,
    required String scope,
    required List<T> rows,
    required List<ExportColumn<T>> columns,
  }) async {
    if (rows.isEmpty) {
      AdminFeedback.error(context, 'There is nothing to export yet.');
      return;
    }

    await AdminExport.run<T>(
      format: format,
      fileName: AdminExport.buildFileName(name, DateTime.now()),
      title: title,
      subtitle: 'Nahata Sports · $window · $scope',
      sharePositionOrigin: origin,
      columns: columns,
      rows: rows,
    );

    if (!context.mounted) return;
    AdminFeedback.success(context, 'Exported $scope as ${format.label}.');
  }

  static List<ReportFigure> _figuresFor(
    ReportsController controller,
    ReportsView view,
  ) {
    if (view == ReportsView.dashboard) return controller.dashboardCards;

    final kind = switch (view) {
      ReportsView.revenue => ReportKind.revenue,
      ReportsView.bookings => ReportKind.bookings,
      ReportsView.students => ReportKind.retention,
      ReportsView.memberships => ReportKind.memberships,
      ReportsView.users => ReportKind.users,
      ReportsView.coaching => ReportKind.coaching,
      ReportsView.facilities => ReportKind.facilities,
      _ => null,
    };
    if (kind == null) return const [];
    return controller.section(kind).value?.shownFigures ?? const [];
  }

  static final List<ExportColumn<ReportFigure>> _figureColumns = [
    ExportColumn('Figure', (figure) => figure.label),
    ExportColumn('Value', formatFigure, numeric: true),
  ];

  static final List<ExportColumn<BookingReportRow>> _bookingColumns = [
    ExportColumn('Booking ID', (row) => row.displayReference),
    ExportColumn('User', (row) => row.displayUser),
    ExportColumn('Contact', (row) => AdminFormat.text(row.userContact)),
    ExportColumn('Sport', (row) => AdminFormat.text(row.sportName)),
    ExportColumn('Court', (row) => AdminFormat.text(row.courtName)),
    ExportColumn('Date', (row) => AdminFormat.date(row.date)),
    ExportColumn('Slot', (row) => AdminFormat.text(row.slotLabel)),
    ExportColumn(
      'Amount',
      (row) =>
          row.amount == null ? AdminFormat.dash : AdminFormat.currency(row.amount),
      numeric: true,
    ),
    ExportColumn('Status', (row) => AdminFormat.text(row.statusRaw)),
    ExportColumn('Payment', (row) => AdminFormat.text(row.paymentStatusRaw)),
  ];

  static final List<ExportColumn<StudentReportRow>> _studentColumns = [
    ExportColumn('Student', (row) => row.displayName),
    ExportColumn('Contact', (row) => AdminFormat.text(row.contact)),
    ExportColumn('Sport', (row) => AdminFormat.text(row.sportName)),
    ExportColumn('Coach', (row) => AdminFormat.text(row.coachName)),
    ExportColumn('Batch', (row) => AdminFormat.text(row.batchName)),
    ExportColumn('Membership', (row) => AdminFormat.text(row.membership)),
    ExportColumn('Joining date', (row) => AdminFormat.date(row.joinedAt)),
    ExportColumn('Status', (row) => AdminFormat.text(row.statusRaw)),
  ];

  static final List<ExportColumn<CoachReportRow>> _coachColumns = [
    ExportColumn('Coach', (row) => row.displayName),
    ExportColumn('Sport', (row) => AdminFormat.text(row.sportName)),
    ExportColumn('Complex', (row) => AdminFormat.text(row.complexName)),
    ExportColumn(
      'Students',
      (row) => AdminFormat.number(row.studentCount),
      numeric: true,
    ),
    ExportColumn(
      'Revenue',
      (row) => row.revenue == null
          ? AdminFormat.dash
          : AdminFormat.currency(row.revenue),
      numeric: true,
    ),
    ExportColumn(
      'Programs',
      (row) => AdminFormat.number(row.programCount),
      numeric: true,
    ),
    ExportColumn('Status', (row) => AdminFormat.text(row.statusRaw)),
  ];

  static String _messageOf(Object error, String action) {
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.isEmpty ? 'Could not $action.' : text;
  }
}

// -----------------------------------------------------------------------------
// Chrome
// -----------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final ReportsController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Reports & Analytics',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: tokens.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          controller.range.isSingleDay
              ? AdminFormat.date(controller.range.from)
              : '${controller.range.days} days · '
                    '${AdminFormat.date(controller.range.from)} – '
                    '${AdminFormat.date(controller.range.to)}',
          style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
        ),
      ],
    );
  }
}

class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({required this.controller});

  final ReportsController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < AdminTokens.mobileMax;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: ReportsView.values.map((view) {
            final selected = controller.view == view;

            return GestureDetector(
              onTap: () => controller.setView(view),
              child: AnimatedContainer(
                duration: AdminTokens.fast,
                padding: const EdgeInsets.symmetric(
                  horizontal: AdminTokens.space4,
                  vertical: AdminTokens.space2 + 2,
                ),
                decoration: BoxDecoration(
                  color: selected ? tokens.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
                  boxShadow: selected ? tokens.softShadow : null,
                ),
                child: Text(
                  narrow ? view.shortLabel : view.label,
                  style: TextStyle(
                    color: selected ? tokens.accent : tokens.textSecondary,
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// CSV / Excel / PDF.
class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.onExport});

  final void Function(ExportFormat format, Rect? origin) onExport;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return PopupMenuButton<ExportFormat>(
      tooltip: 'Export',
      position: PopupMenuPosition.under,
      onSelected: (format) {
        // The share sheet is a popover on iPad and has to be anchored to the
        // control that opened it, so the button's own rect goes along.
        final box = context.findRenderObject() as RenderBox?;
        final origin = box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size;
        onExport(format, origin);
      },
      itemBuilder: (context) => [
        for (final format in ExportFormat.values)
          PopupMenuItem<ExportFormat>(
            value: format,
            height: 40,
            child: Row(
              children: [
                Icon(
                  switch (format) {
                    ExportFormat.csv => Icons.description_outlined,
                    ExportFormat.excel => Icons.table_chart_outlined,
                    ExportFormat.pdf => Icons.picture_as_pdf_outlined,
                  },
                  size: 17,
                  color: tokens.textPrimary,
                ),
                const SizedBox(width: AdminTokens.space3),
                Text(
                  format.label,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: OutlinedButton.icon(
        // The menu owns the tap; the button is the affordance.
        onPressed: null,
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          side: BorderSide(color: tokens.borderStrong),
          disabledForegroundColor: tokens.textPrimary,
        ),
        icon: const Icon(Icons.ios_share_rounded, size: 17),
        label: const Text('Export'),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Body
// -----------------------------------------------------------------------------

class _Body extends StatelessWidget {
  const _Body({
    required this.controller,
    required this.isMobile,
    required this.searchControllers,
    required this.onExport,
  });

  final ReportsController controller;
  final bool isMobile;
  final Map<ReportTable, TextEditingController> searchControllers;
  final void Function(ExportFormat format, Rect? origin) onExport;

  @override
  Widget build(BuildContext context) {
    switch (controller.view) {
      case ReportsView.dashboard:
        return _Dashboard(
          controller: controller,
          isMobile: isMobile,
          onExport: onExport,
        );
      case ReportsView.revenue:
        return _AnalyticsView(
          controller: controller,
          kind: ReportKind.revenue,
          title: 'Revenue analytics',
          charts: const [ReportChart.revenueByCourt],
          isMobile: isMobile,
          onExport: onExport,
        );
      case ReportsView.bookings:
        return _TableView(
          controller: controller,
          table: ReportTable.bookings,
          kind: ReportKind.bookings,
          filterSet: ReportFilterSet.bookings,
          chart: ReportChart.bookingTrends,
          title: 'Booking analytics',
          searchHint: 'Search by booking, user, sport or court',
          searchController: searchControllers[ReportTable.bookings]!,
          isMobile: isMobile,
          onExport: onExport,
        );
      case ReportsView.students:
        return _TableView(
          controller: controller,
          table: ReportTable.students,
          kind: ReportKind.retention,
          filterSet: ReportFilterSet.students,
          chart: null,
          title: 'New students & retention',
          searchHint: 'Search by student, batch or coach',
          searchController: searchControllers[ReportTable.students]!,
          isMobile: isMobile,
          onExport: onExport,
        );
      case ReportsView.coaches:
        return _TableView(
          controller: controller,
          table: ReportTable.coaches,
          kind: null,
          filterSet: ReportFilterSet.coaches,
          chart: null,
          title: 'Coach report',
          searchHint: 'Search by coach, sport or complex',
          searchController: searchControllers[ReportTable.coaches]!,
          isMobile: isMobile,
          onExport: onExport,
        );
      case ReportsView.memberships:
        return _AnalyticsView(
          controller: controller,
          kind: ReportKind.memberships,
          title: 'Membership analytics',
          charts: const [],
          isMobile: isMobile,
          onExport: onExport,
        );
      case ReportsView.users:
        return _AnalyticsView(
          controller: controller,
          kind: ReportKind.users,
          title: 'User analytics',
          charts: const [],
          isMobile: isMobile,
          onExport: onExport,
        );
      case ReportsView.coaching:
        return _AnalyticsView(
          controller: controller,
          kind: ReportKind.coaching,
          title: 'Coaching analytics',
          charts: const [],
          isMobile: isMobile,
          onExport: onExport,
        );
      case ReportsView.facilities:
        return _AnalyticsView(
          controller: controller,
          kind: ReportKind.facilities,
          title: 'Facility analytics',
          charts: const [
            ReportChart.peakHours,
            ReportChart.courtPerformance,
          ],
          isMobile: isMobile,
          onExport: onExport,
        );
    }
  }
}

/// The eight dashboard cards, then the two charts the module puts on it.
class _Dashboard extends StatelessWidget {
  const _Dashboard({
    required this.controller,
    required this.isMobile,
    required this.onExport,
  });

  final ReportsController controller;
  final bool isMobile;
  final void Function(ExportFormat format, Rect? origin) onExport;

  static const Map<String, IconData> _icons = {
    'revenue': Icons.account_balance_wallet_rounded,
    'bookings': Icons.event_available_rounded,
    'members': Icons.card_membership_rounded,
    'students': Icons.school_rounded,
    'coaches': Icons.sports_rounded,
    'utilization': Icons.donut_large_rounded,
    'coachingRevenue': Icons.sports_tennis_rounded,
    'facilityRevenue': Icons.stadium_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final overview = controller.section(ReportKind.overview);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _SectionTitle(
                title: 'Dashboard',
                subtitle: 'Every card is read from its own endpoint',
              ),
            ),
            _ExportButton(onExport: onExport),
          ],
        ),
        const SizedBox(height: AdminTokens.space4),
        if (controller.dashboardFailed && !controller.dashboardIsLoading)
          SolidCard(
            child: ErrorStateView(
              compact: true,
              title: 'Could not load the dashboard',
              message:
                  overview.error ??
                  'None of the analytics endpoints answered for this window.',
              onRetry: controller.refresh,
            ),
          )
        else
          ReportFigureGrid(
            figures: controller.dashboardCards,
            loading: controller.dashboardIsLoading,
            icons: _icons,
          ),
        const SizedBox(height: AdminTokens.space5),
        _ChartCard(
          controller: controller,
          chart: ReportChart.bookingTrends,
          title: 'Booking trends',
          builder: (series) => ReportLineChart(series: series),
        ),
        const SizedBox(height: AdminTokens.space4),
        _ChartCard(
          controller: controller,
          chart: ReportChart.revenueByCourt,
          title: 'Revenue by court',
          builder: (series) => isMobile
              ? ReportRankedList(series: series)
              : ReportBarChart(series: series),
        ),
        const SizedBox(height: AdminTokens.space5),
        _ExtraFigures(section: overview.value),
      ],
    );
  }
}

/// A figures-and-charts tab.
class _AnalyticsView extends StatelessWidget {
  const _AnalyticsView({
    required this.controller,
    required this.kind,
    required this.title,
    required this.charts,
    required this.isMobile,
    required this.onExport,
  });

  final ReportsController controller;
  final ReportKind kind;
  final String title;
  final List<ReportChart> charts;
  final bool isMobile;
  final void Function(ExportFormat format, Rect? origin) onExport;

  @override
  Widget build(BuildContext context) {
    final slice = controller.section(kind);
    final section = slice.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: _SectionTitle(title: title)),
            _ExportButton(onExport: onExport),
          ],
        ),
        const SizedBox(height: AdminTokens.space4),
        if (slice.state.isFailed)
          SolidCard(
            child: ErrorStateView(
              compact: true,
              title: 'Could not load $title',
              message: slice.error ?? 'Please try again.',
              onRetry: () => controller.retrySection(kind),
            ),
          )
        else if (!slice.isFirstLoad && (section?.isEmpty ?? true))
          SolidCard(
            child: EmptyStateView(
              icon: Icons.query_stats_rounded,
              title: 'Nothing reported',
              // Two different claims, and this says only what is known.
              message:
                  'The endpoint answered, but carried no figures for this '
                  'date range.',
              actionLabel: 'Retry',
              onAction: () => controller.retrySection(kind),
            ),
          )
        else
          ReportFigureGrid(
            figures: section?.shownFigures ?? const [],
            loading: slice.isFirstLoad,
          ),
        // Series the section itself carried.
        for (final series in section?.shownCharts ?? const <ChartSeries>[]) ...[
          const SizedBox(height: AdminTokens.space4),
          ReportSectionCard(
            title: series.label,
            state: slice.state,
            error: slice.error,
            onRetry: () => controller.retrySection(kind),
            height: 240,
            child: _seriesChart(series, isMobile),
          ),
        ],
        // The standalone chart endpoints this tab owns.
        for (final chart in charts) ...[
          const SizedBox(height: AdminTokens.space4),
          _ChartCard(
            controller: controller,
            chart: chart,
            title: _chartTitle(chart),
            builder: (series) => _standaloneChart(chart, series, isMobile),
          ),
        ],
      ],
    );
  }

  static Widget _seriesChart(ChartSeries series, bool isMobile) {
    // A short, named series reads better as a ranked list than as an axis with
    // three ticks; a long, dated one is a line.
    if (series.points.length > 12) return ReportLineChart(series: series);
    if (isMobile) return ReportRankedList(series: series);
    return ReportBarChart(series: series);
  }

  static Widget _standaloneChart(
    ReportChart chart,
    ChartSeries series,
    bool isMobile,
  ) {
    switch (chart) {
      case ReportChart.bookingTrends:
        return ReportLineChart(series: series);
      case ReportChart.courtPerformance:
        return ReportPieChart(series: series);
      case ReportChart.revenueByCourt:
      case ReportChart.peakHours:
        return isMobile
            ? ReportRankedList(series: series)
            : ReportBarChart(series: series);
    }
  }

  static String _chartTitle(ReportChart chart) => switch (chart) {
    ReportChart.bookingTrends => 'Booking trends',
    ReportChart.revenueByCourt => 'Revenue by court',
    ReportChart.peakHours => 'Peak hours',
    ReportChart.courtPerformance => 'Court performance',
  };
}

/// A tab with figures, an optional chart, filters and a paginated table.
class _TableView extends StatelessWidget {
  const _TableView({
    required this.controller,
    required this.table,
    required this.kind,
    required this.filterSet,
    required this.chart,
    required this.title,
    required this.searchHint,
    required this.searchController,
    required this.isMobile,
    required this.onExport,
  });

  final ReportsController controller;
  final ReportTable table;
  final ReportKind? kind;
  final ReportFilterSet filterSet;
  final ReportChart? chart;
  final String title;
  final String searchHint;
  final TextEditingController searchController;
  final bool isMobile;
  final void Function(ExportFormat format, Rect? origin) onExport;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final slice = controller.sliceOf(table);
    final options = controller.filterOptions(filterSet);
    final loaded = controller.loadedCount(table);
    final total = controller.totalCount(table);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _SectionTitle(
                title: title,
                subtitle: total == null
                    ? null
                    : '$loaded of $total loaded',
              ),
            ),
            _ExportButton(onExport: onExport),
          ],
        ),
        const SizedBox(height: AdminTokens.space4),

        // The analytics figures that belong beside this table.
        if (kind != null) ...[
          Builder(
            builder: (context) {
              final section = controller.section(kind!);
              if (section.state.isFailed) {
                return SolidCard(
                  child: ErrorStateView(
                    compact: true,
                    title: 'Could not load the summary',
                    message: section.error ?? 'Please try again.',
                    onRetry: () => controller.retrySection(kind!),
                  ),
                );
              }
              return ReportFigureGrid(
                figures: section.value?.shownFigures ?? const [],
                loading: section.isFirstLoad,
              );
            },
          ),
          const SizedBox(height: AdminTokens.space4),
          for (final series
              in controller.section(kind!).value?.shownCharts ??
                  const <ChartSeries>[]) ...[
            ReportSectionCard(
              title: series.label,
              state: controller.section(kind!).state,
              error: controller.section(kind!).error,
              onRetry: () => controller.retrySection(kind!),
              height: 240,
              child: series.points.length > 12
                  ? ReportLineChart(series: series)
                  : (isMobile
                        ? ReportRankedList(series: series)
                        : ReportBarChart(series: series)),
            ),
            const SizedBox(height: AdminTokens.space4),
          ],
        ],

        if (chart != null) ...[
          _ChartCard(
            controller: controller,
            chart: chart!,
            title: 'Booking trends',
            builder: (series) => ReportLineChart(series: series),
          ),
          const SizedBox(height: AdminTokens.space4),
        ],

        SolidCard(
          padding: const EdgeInsets.all(AdminTokens.space4),
          child: ReportFilterBar(
            options: options.value,
            optionsState: options.state,
            filters: controller.filtersFor(table),
            searchController: searchController,
            searchHint: searchHint,
            onSearchChanged: (value) =>
                controller.onSearchChanged(table, value),
            onClearSearch: () => controller.clearSearch(table),
            onFilterChanged: (key, value) =>
                controller.setFilter(table, key, value),
            onClearFilters: () => controller.clearFilters(table),
            onReloadOptions: () => controller.reloadFilterOptions(filterSet),
          ),
        ),
        const SizedBox(height: AdminTokens.space4),

        SolidCard(
          padding: EdgeInsets.zero,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                RefreshLine(visible: slice.isRefreshing),
                _TableBody(
                  controller: controller,
                  table: table,
                  isMobile: isMobile,
                ),
                if (controller.isLoadingMore(table))
                  const Padding(
                    padding: EdgeInsets.all(AdminTokens.space4),
                    child: Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                else if (!controller.hasMore(table) && loaded > 0)
                  Padding(
                    padding: const EdgeInsets.all(AdminTokens.space4),
                    child: Center(
                      child: Text(
                        'That is every row for this window.',
                        style: TextStyle(color: tokens.textMuted, fontSize: 12),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TableBody extends StatelessWidget {
  const _TableBody({
    required this.controller,
    required this.table,
    required this.isMobile,
  });

  final ReportsController controller;
  final ReportTable table;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final slice = controller.sliceOf(table);

    if (slice.isFirstLoad || slice.state.isIdle) {
      return TableShimmer(rows: isMobile ? 5 : 8, dense: isMobile);
    }

    if (slice.state.isFailed) {
      return SizedBox(
        height: 320,
        child: ErrorStateView(
          title: 'Could not load this report',
          message: slice.error ?? 'Please try again.',
          onRetry: () => controller.retryTable(table),
        ),
      );
    }

    final empty = controller.loadedCount(table) == 0;
    if (empty) {
      final filtered = !controller.filtersFor(table).isEmpty;
      return SizedBox(
        height: 320,
        child: filtered
            ? EmptyStateView(
                icon: Icons.search_off_rounded,
                title: 'No rows found',
                message:
                    'Nothing matches these filters in this date range. Try a '
                    'wider window, or clear the filters.',
                actionLabel: 'Clear filters',
                onAction: () => controller.clearFilters(table),
              )
            : EmptyStateView(
                icon: Icons.table_chart_outlined,
                title: 'No rows found',
                message: 'Nothing was recorded in this date range.',
                actionLabel: 'Refresh',
                onAction: () => controller.retryTable(table),
              ),
      );
    }

    switch (table) {
      case ReportTable.bookings:
        final rows = controller.bookings;
        return isMobile
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final row in rows) BookingReportCard(row: row),
                ],
              )
            : BookingReportTable(rows: rows);
      case ReportTable.students:
        final rows = controller.students;
        return isMobile
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final row in rows) StudentReportCard(row: row),
                ],
              )
            : StudentReportTable(rows: rows);
      case ReportTable.coaches:
        final rows = controller.coaches;
        return isMobile
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final row in rows) CoachReportCard(row: row),
                ],
              )
            : CoachReportTable(rows: rows);
    }
  }
}

/// One standalone chart endpoint, with its own loading, empty and error states.
class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.controller,
    required this.chart,
    required this.title,
    required this.builder,
  });

  final ReportsController controller;
  final ReportChart chart;
  final String title;
  final Widget Function(ChartSeries series) builder;

  @override
  Widget build(BuildContext context) {
    final slice = controller.chart(chart);
    final series = slice.value;
    final empty = series == null || series.isEmpty;

    return ReportSectionCard(
      title: title,
      subtitle: series?.valueLabel,
      state: slice.state,
      error: slice.error,
      onRetry: () => controller.retryChart(chart),
      isEmpty: empty,
      // An axis of zeroes would read as "nothing happened", which is a
      // different claim from "the endpoint sent no series".
      emptyMessage: 'No series was returned for this date range.',
      height: empty ? null : 240,
      child: empty ? const SizedBox.shrink() : builder(series),
    );
  }
}

/// Figures the module never listed but the endpoint sent anyway.
class _ExtraFigures extends StatelessWidget {
  const _ExtraFigures({required this.section});

  final ReportSection? section;

  @override
  Widget build(BuildContext context) {
    final extras = section?.extras ?? const <ReportFigure>[];
    if (extras.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: 'Also reported',
          subtitle: 'Figures this endpoint returned beyond the documented set',
        ),
        const SizedBox(height: AdminTokens.space4),
        ReportFigureGrid(figures: extras, loading: false),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: TextStyle(color: tokens.textMuted, fontSize: 12),
          ),
        ],
      ],
    );
  }
}
