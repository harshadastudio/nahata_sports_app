import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/report.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'report_widgets.dart';

/// A line over a report series — the booking-trends shape.
class ReportLineChart extends StatelessWidget {
  const ReportLineChart({super.key, required this.series, this.color});

  final ChartSeries series;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final line = color ?? tokens.accent;
    final points = series.points;
    final maxY = _headroom(series);

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
              reservedSize: 44,
              interval: maxY / 4,
              getTitlesWidget: (value, _) => Text(
                _axisLabel(value, series.format),
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
                    shortLabel(points[index].label),
                    style: TextStyle(color: tokens.textMuted, fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => [
              for (final spot in spots)
                LineTooltipItem(
                  _tooltip(points[spot.spotIndex], series),
                  TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
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
            color: line,
            barWidth: 2.5,
            dotData: FlDotData(show: points.length <= 14),
            belowBarData: BarAreaData(
              show: true,
              color: line.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical bars — revenue by court, peak hours.
class ReportBarChart extends StatelessWidget {
  const ReportBarChart({super.key, required this.series, this.color});

  final ChartSeries series;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final bar = color ?? tokens.accent;
    final points = series.points;
    final maxY = _headroom(series);

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
              reservedSize: 44,
              interval: maxY / 4,
              getTitlesWidget: (value, _) => Text(
                _axisLabel(value, series.format),
                style: TextStyle(color: tokens.textMuted, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: (points.length / 8).ceilToDouble().clamp(1, 999),
              getTitlesWidget: (value, _) {
                final index = value.round();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    shortLabel(points[index].label),
                    style: TextStyle(color: tokens.textMuted, fontSize: 10),
                  ),
                );
              },
            ),
          ),
        ),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipItem: (group, _, rod, __) => BarTooltipItem(
              _tooltip(points[group.x], series),
              TextStyle(
                color: tokens.textPrimary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
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
                  color: bar,
                  width: points.length > 16 ? 6 : 12,
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

/// A doughnut with a legend — court performance.
///
/// Slices under a twentieth of the total are gathered into "Other", because a
/// two-pixel wedge is unreadable and its label overlaps its neighbours.
class ReportPieChart extends StatelessWidget {
  const ReportPieChart({super.key, required this.series});

  final ChartSeries series;

  static const List<Color> _palette = [
    Color(0xFF1A237E),
    Color(0xFF3949AB),
    Color(0xFF10B981),
    Color(0xFF0EA5E9),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFF7986CB),
    Color(0xFFEC4899),
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final total = series.total;
    if (total <= 0) {
      return Center(
        child: Text(
          'Every value in this series is zero.',
          style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
        ),
      );
    }

    final slices = _slices(total);
    final narrow = MediaQuery.sizeOf(context).width < AdminTokens.mobileMax;

    final chart = PieChart(
      PieChartData(
        sectionsSpace: 2,
        centerSpaceRadius: 46,
        sections: [
          for (var index = 0; index < slices.length; index++)
            PieChartSectionData(
              value: slices[index].value.toDouble(),
              color: _palette[index % _palette.length],
              radius: 46,
              title: '${((slices[index].value / total) * 100).round()}%',
              titleStyle: const TextStyle(
                color: Colors.white,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );

    final legend = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < slices.length; index++)
          Padding(
            padding: const EdgeInsets.only(bottom: AdminTokens.space2),
            child: Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _palette[index % _palette.length],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: AdminTokens.space2),
                Expanded(
                  child: Text(
                    slices[index].label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: AdminTokens.space2),
                Text(
                  _valueLabel(slices[index].value, series),
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    if (narrow) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 180, child: chart),
          const SizedBox(height: AdminTokens.space4),
          legend,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(width: 190, height: 190, child: chart),
        const SizedBox(width: AdminTokens.space5),
        Expanded(child: SingleChildScrollView(child: legend)),
      ],
    );
  }

  List<ChartPoint> _slices(num total) {
    final sorted = [...series.points]..sort((a, b) => b.value.compareTo(a.value));
    final kept = <ChartPoint>[];
    num other = 0;

    for (final point in sorted) {
      if (point.value / total >= 0.05 && kept.length < 7) {
        kept.add(point);
      } else {
        other += point.value;
      }
    }
    if (other > 0) kept.add(ChartPoint(label: 'Other', value: other));
    return kept;
  }
}

/// A ranked list with proportional bars — clearer than a pie for "top N", and
/// it degrades gracefully to one row.
class ReportRankedList extends StatelessWidget {
  const ReportRankedList({super.key, required this.series, this.maxRows = 8});

  final ChartSeries series;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final sorted = [...series.points]..sort((a, b) => b.value.compareTo(a.value));
    final shown = sorted.take(maxRows).toList();
    final max = shown.isEmpty ? 0 : shown.first.value;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final point in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: AdminTokens.space3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        point.label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                    Text(
                      _valueLabel(point.value, series),
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
                  child: LinearProgressIndicator(
                    value: max == 0 ? 0 : (point.value / max).toDouble(),
                    minHeight: 6,
                    backgroundColor: tokens.surfaceAlt,
                    valueColor: AlwaysStoppedAnimation<Color>(tokens.accent),
                  ),
                ),
              ],
            ),
          ),
        if (sorted.length > maxRows)
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              // Says what was left out rather than quietly truncating.
              'Showing the top $maxRows of ${sorted.length}.',
              style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
            ),
          ),
      ],
    );
  }
}

/// Rounds the top of the axis up so the tallest point is not flush with it.
double _headroom(ChartSeries series) {
  final max = series.maxValue;
  if (max <= 0) return 4;
  final padded = max * 1.2;
  final magnitude = padded < 10 ? 1 : (padded < 100 ? 10 : 100);
  return (padded / magnitude).ceil() * magnitude.toDouble();
}

String _axisLabel(double value, ReportFormat format) {
  if (format == ReportFormat.currency) {
    return AdminFormat.compact(value.round());
  }
  return AdminFormat.compact(value.round());
}

/// The point, its value, and the second figure when the series knows what that
/// figure means — the captured booking-trends rows carry revenue alongside the
/// booking count.
String _tooltip(ChartPoint point, ChartSeries series) {
  final lines = <String>[
    point.label,
    _valueLabel(point.value, series),
  ];

  final secondary = point.secondary;
  final label = series.secondaryLabel;
  if (secondary != null && label != null) {
    final figure = ReportFigure(
      key: series.key,
      label: label,
      value: secondary,
      format: series.secondaryFormat,
    );
    lines.add('$label: ${formatFigure(figure)}');
  }
  return lines.join('\n');
}

String _valueLabel(num value, ChartSeries series) => formatFigure(
  ReportFigure(
    key: series.key,
    label: series.label,
    value: value,
    format: series.format,
  ),
);

/// `2026-08-05` → `5 Aug`; a long name is cut rather than allowed to overlap.
String shortLabel(String label) {
  final date = DateTime.tryParse(label);
  if (date != null) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]}';
  }
  return label.length <= 6 ? label : '${label.substring(0, 5)}…';
}
