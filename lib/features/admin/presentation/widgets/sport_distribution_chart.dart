import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/sport_distribution.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';

/// The sport doughnut, with the total in the hole and a legend beside it.
///
/// Slice colours come from the API whenever it sends one; the fallback palette
/// is only used for slices with no colour, so a backend that themes its sports
/// always wins.
class SportDistributionChart extends StatefulWidget {
  const SportDistributionChart({
    super.key,
    required this.distribution,
    this.stacked = false,
  });

  final SportDistribution distribution;

  /// Legend below the chart instead of beside it, for narrow layouts.
  final bool stacked;

  @override
  State<SportDistributionChart> createState() => _SportDistributionChartState();
}

class _SportDistributionChartState extends State<SportDistributionChart> {
  /// Index of the slice under the pointer, or -1. Drives the pop-out.
  int _touched = -1;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final slices = widget.distribution.slices;

    final chart = AspectRatio(
      aspectRatio: 1,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            duration: AdminTokens.normal,
            curve: AdminTokens.curve,
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: double.infinity,
              startDegreeOffset: -90,
              pieTouchData: PieTouchData(
                enabled: true,
                touchCallback: (event, response) {
                  final index =
                      response?.touchedSection?.touchedSectionIndex ?? -1;
                  // `interestedForInteractions` is false on exit events, which
                  // is what clears the pop-out when the pointer leaves.
                  final next = event.isInterestedForInteractions ? index : -1;
                  if (next == _touched) return;
                  setState(() => _touched = next);
                },
              ),
              sections: [
                for (var i = 0; i < slices.length; i++)
                  _section(i, slices[i], tokens),
              ],
            ),
          ),
          IgnorePointer(child: _Centre(distribution: widget.distribution)),
        ],
      ),
    );

    final legend = _Legend(
      distribution: widget.distribution,
      touched: _touched,
      onHover: (index) {
        if (index == _touched) return;
        setState(() => _touched = index);
      },
      colorOf: (index) => _colorFor(index, slices[index], tokens),
    );

    if (widget.stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: chart,
            ),
          ),
          const SizedBox(height: AdminTokens.space5),
          legend,
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Flexible(
          flex: 4,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 200),
            child: chart,
          ),
        ),
        const SizedBox(width: AdminTokens.space5),
        Expanded(flex: 5, child: legend),
      ],
    );
  }

  PieChartSectionData _section(
    int index,
    SportSlice slice,
    AdminTokens tokens,
  ) {
    final touched = index == _touched;
    final share = widget.distribution.percentageOf(slice);

    return PieChartSectionData(
      value: slice.value.toDouble(),
      color: _colorFor(index, slice, tokens),
      radius: touched ? 30 : 24,
      // A label inside a 24px band is unreadable; the legend carries the
      // numbers, and the touched slice gets its share in the centre instead.
      showTitle: touched && share >= 8,
      title: AdminFormat.share(share),
      titleStyle: const TextStyle(
        color: Colors.white,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
      ),
      borderSide: BorderSide(color: tokens.surface, width: 1.5),
    );
  }

  /// The API's colour, or a stable one from the theme palette.
  Color _colorFor(int index, SportSlice slice, AdminTokens tokens) {
    return slice.color ?? _palette(tokens)[index % _palette(tokens).length];
  }

  static List<Color> _palette(AdminTokens tokens) => [
    tokens.accent,
    const Color(0xFF10B981),
    const Color(0xFFF59E0B),
    const Color(0xFF0EA5E9),
    const Color(0xFFEC4899),
    const Color(0xFF8B5CF6),
    const Color(0xFF14B8A6),
    const Color(0xFFF97316),
  ];
}

class _Centre extends StatelessWidget {
  const _Centre({required this.distribution});

  final SportDistribution distribution;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween<double>(
            begin: 0,
            end: distribution.totalSports.toDouble(),
          ),
          duration: AdminTokens.slow,
          curve: AdminTokens.curve,
          builder: (context, value, _) => Text(
            '${value.round()}',
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 30,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
              height: 1.1,
            ),
          ),
        ),
        Text(
          distribution.totalSports == 1 ? 'Sport' : 'Sports',
          style: TextStyle(
            color: tokens.textMuted,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({
    required this.distribution,
    required this.touched,
    required this.onHover,
    required this.colorOf,
  });

  final SportDistribution distribution;
  final int touched;
  final ValueChanged<int> onHover;
  final Color Function(int index) colorOf;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final slices = distribution.slices;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < slices.length; i++)
          MouseRegion(
            onEnter: (_) => onHover(i),
            onExit: (_) => onHover(-1),
            child: AnimatedContainer(
              duration: AdminTokens.fast,
              margin: const EdgeInsets.only(bottom: 2),
              padding: const EdgeInsets.symmetric(
                horizontal: AdminTokens.space2,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: i == touched ? tokens.surfaceAlt : Colors.transparent,
                borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
              ),
              child: Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: colorOf(i),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: AdminTokens.space3),
                  Expanded(
                    child: Text(
                      slices[i].sport,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12.5,
                        fontWeight: i == touched
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  const SizedBox(width: AdminTokens.space2),
                  Text(
                    AdminFormat.number(slices[i].count),
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: AdminTokens.space2),
                  SizedBox(
                    width: 44,
                    child: Text(
                      AdminFormat.share(distribution.percentageOf(slices[i])),
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
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
