import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';

/// How full a batch is, as a ring.
///
/// The colour is the point: green while there is room, amber as it fills, red
/// once it is effectively closed. A batch whose capacity the API never sent has
/// no honest ratio at all, so [ratio] is nullable and the ring renders as a
/// dashed-looking grey track with an em dash rather than an empty circle that
/// reads as 0%.
class OccupancyRing extends StatelessWidget {
  const OccupancyRing({
    super.key,
    required this.ratio,
    this.size = 44,
    this.strokeWidth = 5,
    this.showLabel = true,
    this.caption,
  });

  /// 0–1, or null when it is unknown.
  final double? ratio;

  final double size;
  final double strokeWidth;

  /// The percentage inside the ring. Off for the small table variant, where the
  /// figure sits beside it instead.
  final bool showLabel;

  /// A short line under the percentage, e.g. `12/20`.
  final String? caption;

  /// Green under 70%, amber to 90%, red above — and grey when unknown.
  static Color colorFor(BuildContext context, double? ratio) {
    final tokens = AdminTheme.of(context);
    if (ratio == null) return tokens.textMuted;
    if (ratio >= 0.9) return tokens.danger;
    if (ratio >= 0.7) return tokens.warning;
    return tokens.success;
  }

  /// "Filling up" style wording for tooltips and captions.
  static String describe(double? ratio) {
    if (ratio == null) return 'Capacity not set';
    if (ratio >= 1) return 'Full';
    if (ratio >= 0.9) return 'Almost full';
    if (ratio >= 0.7) return 'Filling up';
    return 'Seats available';
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final color = colorFor(context, ratio);
    final percent = ratio == null ? null : (ratio! * 100).round();

    return Tooltip(
      message: percent == null
          ? OccupancyRing.describe(null)
          : '$percent% · ${OccupancyRing.describe(ratio)}',
      waitDuration: const Duration(milliseconds: 300),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Animated so a status change or a reload reads as movement rather
            // than a jump.
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: ratio ?? 0),
              duration: AdminTokens.slow,
              curve: AdminTokens.curve,
              builder: (context, value, _) {
                return CustomPaint(
                  size: Size.square(size),
                  painter: _RingPainter(
                    ratio: ratio == null ? null : value,
                    color: color,
                    track: tokens.border,
                    strokeWidth: strokeWidth,
                  ),
                );
              },
            ),
            if (showLabel)
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    percent == null ? '—' : '$percent%',
                    style: TextStyle(
                      color: percent == null ? tokens.textMuted : color,
                      fontSize: size * 0.26,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                    ),
                  ),
                  if (caption != null)
                    Text(
                      caption!,
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: size * 0.16,
                        height: 1.2,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.ratio,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  final double? ratio;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = (size.shortestSide - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(centre, radius, trackPaint);

    final value = ratio;
    if (value == null || value <= 0) return;

    final arcPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      // Starts at twelve o'clock rather than three, which is what a progress
      // ring is read as.
      -math.pi / 2,
      2 * math.pi * value.clamp(0.0, 1.0),
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter oldDelegate) =>
      oldDelegate.ratio != ratio ||
      oldDelegate.color != color ||
      oldDelegate.track != track ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// The linear equivalent, for rows where a ring would be too tall.
class OccupancyBar extends StatelessWidget {
  const OccupancyBar({
    super.key,
    required this.ratio,
    this.label,
    this.width = 84,
  });

  final double? ratio;
  final String? label;
  final double width;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final color = OccupancyRing.colorFor(context, ratio);
    final percent = ratio == null ? null : (ratio! * 100).round();

    return Tooltip(
      message: percent == null
          ? OccupancyRing.describe(null)
          : '$percent% · ${OccupancyRing.describe(ratio)}',
      waitDuration: const Duration(milliseconds: 300),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                percent == null ? '—' : '$percent%',
                style: TextStyle(
                  color: percent == null ? tokens.textMuted : color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              if (label != null) ...[
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label!,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tokens.textMuted, fontSize: 11),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            width: width,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: ratio ?? 0),
                duration: AdminTokens.slow,
                curve: AdminTokens.curve,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: ratio == null ? 0 : value,
                  minHeight: 5,
                  backgroundColor: tokens.border,
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
