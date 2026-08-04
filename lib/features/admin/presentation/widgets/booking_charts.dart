import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/booking.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'glass_card.dart';

/// The charts on the Statistics view.
///
/// Each is drawn only when `/bookings/stats` actually sent its series. A chart
/// with no data is *not rendered* rather than shown empty or filled with
/// zeroes — an axis of zeroes reads as "no bookings", which is a different
/// claim from "the endpoint did not send this".
class BookingChartsSection extends StatelessWidget {
  const BookingChartsSection({super.key, required this.stats});

  final BookingStats stats;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    if (!stats.hasCharts) {
      return SolidCard(
        padding: const EdgeInsets.all(AdminTokens.space5),
        child: Row(
          children: [
            Icon(
              Icons.insights_outlined,
              size: 18,
              color: tokens.textMuted,
            ),
            const SizedBox(width: AdminTokens.space3),
            Expanded(
              child: Text(
                'The statistics endpoint returned counters but no series, so '
                'there is nothing to chart. The cards above are the whole of '
                'what it sent.',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 12.5,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final charts = <Widget>[
      if (stats.daily.isNotEmpty)
        _ChartCard(
          title: 'Bookings over time',
          subtitle: 'From the trend series',
          icon: Icons.show_chart_rounded,
          child: BookingLineChart(points: stats.daily, color: tokens.accent),
        ),
      if (stats.peakHours.isNotEmpty)
        _ChartCard(
          title: 'Peak booking hours',
          subtitle: 'Bookings by hour of the day',
          icon: Icons.schedule_rounded,
          child: BookingBarChart(
            points: stats.peakHours,
            color: tokens.warning,
          ),
        ),
      if (stats.topSports.isNotEmpty)
        _ChartCard(
          title: 'Most booked sports',
          subtitle: 'By number of bookings',
          icon: Icons.sports_tennis_rounded,
          child: BookingRankedBars(
            points: stats.topSports,
            color: tokens.success,
          ),
        ),
      if (stats.topCourts.isNotEmpty)
        _ChartCard(
          title: 'Most booked courts',
          subtitle: 'By number of bookings',
          icon: Icons.grid_view_rounded,
          child: BookingRankedBars(
            points: stats.topCourts,
            color: tokens.info,
          ),
        ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1100 ? 2 : 1;
        const gap = AdminTokens.space4;
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: charts
              .map((chart) => SizedBox(width: cardWidth, child: chart))
              .toList(),
        );
      },
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: tokens.accent),
              const SizedBox(width: AdminTokens.space2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space4),
          SizedBox(height: 200, child: child),
        ],
      ),
    );
  }
}

/// A line over a labelled series.
class BookingLineChart extends StatelessWidget {
  const BookingLineChart({
    super.key,
    required this.points,
    required this.color,
  });

  final List<BookingPoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final maxY = _headroom(points);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: tokens.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: maxY / 4,
              getTitlesWidget: (value, _) => Text(
                AdminFormat.compact(value.round()),
                style: TextStyle(color: tokens.textMuted, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              // Every label on a long series would overlap; this thins them to
              // roughly six.
              interval: (points.length / 6).ceilToDouble().clamp(1, 999),
              getTitlesWidget: (value, _) {
                final index = value.round();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _short(points[index].label),
                    style: TextStyle(color: tokens.textMuted, fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var index = 0; index < points.length; index++)
                FlSpot(index.toDouble(), points[index].value.toDouble()),
            ],
            isCurved: true,
            curveSmoothness: 0.28,
            color: color,
            barWidth: 2.5,
            dotData: FlDotData(show: points.length <= 14),
            belowBarData: BarAreaData(
              show: true,
              color: color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical bars, for the hour-of-day distribution.
class BookingBarChart extends StatelessWidget {
  const BookingBarChart({
    super.key,
    required this.points,
    required this.color,
  });

  final List<BookingPoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final maxY = _headroom(points);

    return BarChart(
      BarChartData(
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxY / 4,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: tokens.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          rightTitles: const AxisTitles(),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: maxY / 4,
              getTitlesWidget: (value, _) => Text(
                AdminFormat.compact(value.round()),
                style: TextStyle(color: tokens.textMuted, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: (points.length / 8).ceilToDouble().clamp(1, 999),
              getTitlesWidget: (value, _) {
                final index = value.round();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _short(points[index].label),
                    style: TextStyle(color: tokens.textMuted, fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (var index = 0; index < points.length; index++)
            BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: points[index].value.toDouble(),
                  color: color,
                  width: 10,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(3),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// A ranked list with proportional bars — clearer than a pie for "top N", and
/// it keeps the labels readable.
class BookingRankedBars extends StatelessWidget {
  const BookingRankedBars({
    super.key,
    required this.points,
    required this.color,
  });

  final List<BookingPoint> points;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    final ranked = [...points]
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = ranked.take(6).toList();
    final max = top.isEmpty ? 0 : top.first.value.toDouble();

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: top.length,
      separatorBuilder: (_, __) => const SizedBox(height: AdminTokens.space3),
      itemBuilder: (context, index) {
        final point = top[index];
        final ratio = max <= 0 ? 0.0 : point.value / max;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    point.label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  AdminFormat.number(point.value.round()),
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: tokens.border,
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A little headroom above the tallest point, so the peak is not flush with the
/// top of the chart. Never zero — a flat-zero series would divide by it.
double _headroom(List<BookingPoint> points) {
  var max = 0.0;
  for (final point in points) {
    final value = point.value.toDouble();
    if (value > max) max = value;
  }
  if (max <= 0) return 4;
  return (max * 1.2).ceilToDouble();
}

/// Axis labels have no room for `2026-08-04` — this keeps the informative end.
String _short(String label) {
  final text = label.trim();
  if (text.length <= 6) return text;

  // A date: keep the day and month.
  final iso = RegExp(r'^\d{4}-(\d{2})-(\d{2})').firstMatch(text);
  if (iso != null) return '${iso.group(2)}/${iso.group(1)}';

  return text.substring(0, 6);
}
