import 'package:flutter/material.dart';

import '../../../admin/domain/entities/report.dart';
import '../../../admin/presentation/theme/admin_theme.dart';
import '../../../admin/presentation/widgets/admin_states.dart';
import '../../../admin/presentation/widgets/report_charts.dart';

/// A titled panel around one chart, matching the dashboard home's chart cards.
///
/// It owns the three states a chart can be in — loading, empty and drawn — so
/// no caller has to repeat them, and an empty series never renders as an
/// axis with nothing on it.
class SecurityChartPanel extends StatelessWidget {
  const SecurityChartPanel({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.series,
    required this.loading,
    required this.emptyMessage,
    required this.child,
    this.height = 260,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final ChartSeries series;
  final bool loading;
  final String emptyMessage;

  /// The chart itself, built by the caller so each panel can pick its own type.
  final Widget child;

  final double height;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
                color: tokens.accentSoft,
              ),
              child: Icon(icon, size: 18, color: tokens.accent),
            ),
            const SizedBox(width: AdminTokens.space3),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: AdminTokens.space4),
        SizedBox(height: height, child: _body(context)),
      ],
    );
  }

  Widget _body(BuildContext context) {
    if (loading) {
      return const Center(
        child: ShimmerBox(height: 180, width: double.infinity),
      );
    }

    if (series.isEmpty) {
      return EmptyStateView(
        icon: Icons.show_chart_rounded,
        title: 'Nothing to chart yet',
        message: emptyMessage,
      );
    }

    return child;
  }
}

/// Pie: Pending / Inside / Completed / Expired.
class VisitorStatusPie extends StatelessWidget {
  const VisitorStatusPie({
    super.key,
    required this.series,
    required this.loading,
  });

  final ChartSeries series;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SecurityChartPanel(
      title: 'Visitor Status',
      subtitle: 'How the passes in this period ended up',
      icon: Icons.donut_large_rounded,
      series: series,
      loading: loading,
      emptyMessage: 'Statuses appear once passes have been issued.',
      height: 280,
      child: ReportPieChart(series: series),
    );
  }
}

/// Line: entries per hour across the day.
class HourlyVisitorTrend extends StatelessWidget {
  const HourlyVisitorTrend({
    super.key,
    required this.series,
    required this.loading,
  });

  final ChartSeries series;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SecurityChartPanel(
      title: 'Hourly Visitor Trend',
      subtitle: 'Gate entries by hour',
      icon: Icons.timeline_rounded,
      series: series,
      loading: loading,
      emptyMessage: 'The curve fills in as visitors are checked in.',
      child: ReportLineChart(series: series),
    );
  }
}

/// Bar: passes per day over the last seven days.
class DailyVisitorBars extends StatelessWidget {
  const DailyVisitorBars({
    super.key,
    required this.series,
    required this.loading,
  });

  final ChartSeries series;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SecurityChartPanel(
      title: 'Daily Visitors',
      subtitle: 'Last 7 days',
      icon: Icons.bar_chart_rounded,
      series: series,
      loading: loading,
      emptyMessage: 'Daily totals appear once passes have been issued.',
      child: ReportBarChart(series: series),
    );
  }
}