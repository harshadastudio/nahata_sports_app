import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/enrollment_trend.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';

/// Students vs enquiries over the months the API returned.
///
/// An area chart rather than bars: the point is the shape of the trend, and two
/// translucent bands read more clearly than four interleaved bar groups when
/// the month count varies.
class EnrollmentTrendChart extends StatelessWidget {
  const EnrollmentTrendChart({super.key, required this.trend});

  final EnrollmentTrend trend;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    final students = tokens.accent;
    final enquiries = tokens.success;

    final points = trend.points;
    final maxY = _headroom(trend.maxValue);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _LegendDot(color: students, label: 'Students'),
            const SizedBox(width: AdminTokens.space4),
            _LegendDot(color: enquiries, label: 'Enquiries'),
            const Spacer(),
            Text(
              '${AdminFormat.number(trend.totalStudents)} · '
              '${AdminFormat.number(trend.totalEnquiries)} total',
              style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
            ),
          ],
        ),
        const SizedBox(height: AdminTokens.space5),
        Expanded(
          child: LineChart(
            // fl_chart animates between data sets on its own; `duration` is
            // what makes the first paint grow in rather than snap.
            duration: AdminTokens.slow,
            curve: AdminTokens.curve,
            LineChartData(
              minY: 0,
              maxY: maxY,
              minX: 0,
              maxX: (points.length - 1).toDouble().clamp(0, double.infinity),
              clipData: const FlClipData.all(),
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                horizontalInterval: maxY / 4,
                getDrawingHorizontalLine: (_) => FlLine(
                  color: tokens.border,
                  strokeWidth: 1,
                  dashArray: const [4, 6],
                ),
              ),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(),
                rightTitles: const AxisTitles(),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    interval: maxY / 4,
                    getTitlesWidget: (value, meta) {
                      // The top gridline label collides with the chart edge.
                      if (value >= meta.max) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text(
                          AdminFormat.compact(value.round()),
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final index = value.round();
                      if (index < 0 || index >= points.length) {
                        return const SizedBox.shrink();
                      }
                      // Thin the labels out when a year of months would
                      // otherwise overlap.
                      final step = (points.length / 6).ceil();
                      if (step > 1 &&
                          index % step != 0 &&
                          index != points.length - 1) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _shortLabel(points[index].label),
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 10.5,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => tokens.isDark
                      ? tokens.surfaceAlt
                      : const Color(0xFF111827),
                  tooltipBorderRadius: BorderRadius.circular(
                    AdminTokens.radiusSm,
                  ),
                  tooltipPadding: const EdgeInsets.symmetric(
                    horizontal: AdminTokens.space3,
                    vertical: AdminTokens.space2,
                  ),
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipItems: (spots) {
                    return spots.map((spot) {
                      final index = spot.x.round();
                      final month = index >= 0 && index < points.length
                          ? points[index].label
                          : '';
                      final isStudents = spot.barIndex == 0;
                      return LineTooltipItem(
                        '${isStudents ? 'Students' : 'Enquiries'}  '
                        '${AdminFormat.number(spot.y.round())}',
                        TextStyle(
                          color: isStudents ? students : enquiries,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                        children: [
                          if (spot.barIndex == 0)
                            TextSpan(
                              text: '\n$month',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                        ],
                      );
                    }).toList();
                  },
                ),
                getTouchedSpotIndicator: (barData, indexes) {
                  return indexes.map((_) {
                    return TouchedSpotIndicatorData(
                      FlLine(color: barData.color ?? students, strokeWidth: 1),
                      FlDotData(
                        getDotPainter: (spot, percent, bar, index) =>
                            FlDotCirclePainter(
                              radius: 4,
                              color: bar.color ?? students,
                              strokeWidth: 2,
                              strokeColor: tokens.surface,
                            ),
                      ),
                    );
                  }).toList();
                },
              ),
              lineBarsData: [
                _series(
                  points.map((p) => p.studentsValue).toList(),
                  students,
                  tokens,
                ),
                _series(
                  points.map((p) => p.enquiriesValue).toList(),
                  enquiries,
                  tokens,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  LineChartBarData _series(List<int> values, Color color, AdminTokens tokens) {
    return LineChartBarData(
      spots: [
        for (var i = 0; i < values.length; i++)
          FlSpot(i.toDouble(), values[i].toDouble()),
      ],
      isCurved: true,
      // Below 1 the curve can overshoot into negative y on a spiky series.
      preventCurveOverShooting: true,
      curveSmoothness: 0.28,
      color: color,
      barWidth: 2.5,
      isStrokeCapRound: true,
      // A dot per month is noise on a long series but useful on a short one.
      dotData: FlDotData(
        show: values.length <= 8,
        getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
          radius: 3,
          color: tokens.surface,
          strokeWidth: 2,
          strokeColor: color,
        ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.28),
            color.withValues(alpha: 0.02),
          ],
        ),
      ),
    );
  }

  /// A round-ish ceiling above the data so the top line is not glued to the
  /// chart edge. An all-zero series still needs a non-zero axis.
  static double _headroom(int max) {
    if (max <= 0) return 4;
    final padded = max * 1.2;
    final magnitude = padded < 10
        ? 1.0
        : (padded < 100 ? 5.0 : (padded < 1000 ? 50.0 : 500.0));
    return (padded / magnitude).ceil() * magnitude;
  }

  /// `January 2026` → `Jan`, but a label that is already short is left alone.
  static String _shortLabel(String label) {
    final trimmed = label.trim();
    if (trimmed.length <= 4) return trimmed;
    final firstWord = trimmed.split(RegExp(r'[\s\-/]')).first;
    return firstWord.length <= 3 ? firstWord : firstWord.substring(0, 3);
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: AdminTokens.space2),
        Text(
          label,
          style: TextStyle(
            color: tokens.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
