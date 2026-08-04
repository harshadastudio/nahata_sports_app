import 'package:flutter/material.dart';

import '../../domain/entities/dashboard_stats.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'glass_card.dart';

/// A dashboard-home counter with its month-over-month movement.
///
/// Reuses the phase-1 card look (gradient icon tile, corner wash, count-up)
/// and adds the trend row underneath, so the two generations of card sit
/// together without a visible seam.
class GrowthStatCard extends StatelessWidget {
  const GrowthStatCard({
    super.key,
    required this.label,
    required this.metric,
    required this.icon,
    required this.gradient,
    this.onTap,
  });

  final String label;
  final StatMetric metric;
  final IconData icon;
  final List<Color> gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return HoverLift(
      onTap: onTap,
      builder: (context, hovered) {
        return AnimatedContainer(
          duration: AdminTokens.normal,
          curve: AdminTokens.curve,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
            boxShadow: hovered ? tokens.liftedShadow : tokens.softShadow,
          ),
          child: SolidCard(
            padding: const EdgeInsets.all(AdminTokens.space5),
            child: Stack(
              children: [
                Positioned(
                  right: -30,
                  top: -34,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: AdminTokens.normal,
                      opacity: hovered ? 0.28 : 0.16,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: gradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              AdminTokens.radiusMd,
                            ),
                            gradient: LinearGradient(
                              colors: gradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: gradient.first.withValues(alpha: 0.35),
                                blurRadius: 14,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: Colors.white, size: 21),
                        ),
                        const Spacer(),
                        if (metric.hasTrend) _TrendPill(metric: metric),
                      ],
                    ),
                    const SizedBox(height: AdminTokens.space5),
                    _CountUp(value: metric.total),
                    const SizedBox(height: AdminTokens.space1),
                    Text(
                      label,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: AdminTokens.space4),
                    Divider(height: 1, color: tokens.border),
                    const SizedBox(height: AdminTokens.space3),
                    Row(
                      children: [
                        Expanded(
                          child: _MonthCell(
                            label: 'This month',
                            value: metric.thisMonth,
                            emphasised: true,
                          ),
                        ),
                        Container(width: 1, height: 26, color: tokens.border),
                        Expanded(
                          child: _MonthCell(
                            label: 'Last month',
                            value: metric.lastMonth,
                          ),
                        ),
                      ],
                    ),
                    if (metric.hasTrend) ...[
                      const SizedBox(height: AdminTokens.space3),
                      _TrendText(metric: metric, label: label),
                    ],
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The green/red arrow chip in the card's top-right.
class _TrendPill extends StatelessWidget {
  const _TrendPill({required this.metric});

  final StatMetric metric;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final positive = metric.trendIsPositive;
    final color = positive ? tokens.success : tokens.danger;
    final growth = metric.effectiveGrowth;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.space2 + 2,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            positive
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              // No percentage when last month was zero — there is no honest
              // one to show, so only the direction is reported.
              growth == null
                  ? (positive ? 'Up' : 'Down')
                  : AdminFormat.growth(growth),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The sentence under the two month figures.
class _TrendText extends StatelessWidget {
  const _TrendText({required this.metric, required this.label});

  final StatMetric metric;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final positive = metric.trendIsPositive;
    final color = positive ? tokens.success : tokens.danger;
    final growth = metric.effectiveGrowth;

    final String message;
    if (growth != null) {
      message =
          '${AdminFormat.growth(growth, signed: false)} '
          '${positive ? 'up' : 'down'} vs last month';
    } else if (metric.lastMonth == 0 && (metric.thisMonth ?? 0) > 0) {
      // The honest reading of 0 → n: new activity, no percentage.
      message = 'New activity this month';
    } else {
      message = positive ? 'Trending up' : 'Trending down';
    }

    return Row(
      children: [
        Icon(
          positive ? Icons.trending_up_rounded : Icons.trending_down_rounded,
          size: 14,
          color: color,
        ),
        const SizedBox(width: AdminTokens.space2),
        Expanded(
          child: Text(
            message,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 11.5,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.label,
    required this.value,
    this.emphasised = false,
  });

  final String label;
  final int? value;
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: tokens.textMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          AdminFormat.number(value),
          style: TextStyle(
            color: emphasised ? tokens.textPrimary : tokens.textSecondary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      ],
    );
  }
}

class _CountUp extends StatelessWidget {
  const _CountUp({required this.value});

  final int? value;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final style = TextStyle(
      color: tokens.textPrimary,
      fontSize: 28,
      fontWeight: FontWeight.w800,
      letterSpacing: -1,
      height: 1.1,
    );

    if (value == null) return Text(AdminFormat.dash, style: style);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value!.toDouble()),
      duration: AdminTokens.slow,
      curve: AdminTokens.curve,
      builder: (context, animated, _) =>
          Text(AdminFormat.number(animated.round()), style: style),
    );
  }
}
