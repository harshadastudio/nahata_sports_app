import 'package:flutter/material.dart';

import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'glass_card.dart';

/// The gradient counter cards on the dashboard home.
///
/// The number counts up on first appearance — an animation that reads as
/// "this just loaded" rather than decoration. A null [value] means the API did
/// not send that counter, and the card shows an em dash instead of a zero.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.gradient,
    this.caption,
    this.progress,
    this.onTap,
  });

  final String label;
  final int? value;
  final IconData icon;
  final List<Color> gradient;

  /// Small line under the number.
  final String? caption;

  /// 0–1 meter under the caption, when the figure has a meaningful share.
  final double? progress;

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
                // A soft wash of the card's own gradient in the top-right.
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
                    const SizedBox(height: AdminTokens.space5),
                    _CountUp(value: value),
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
                    if (caption != null) ...[
                      const SizedBox(height: AdminTokens.space3),
                      Text(
                        caption!,
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 11.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                    if (progress != null) ...[
                      const SizedBox(height: AdminTokens.space3),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(
                          AdminTokens.radiusPill,
                        ),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0, end: progress!),
                          duration: AdminTokens.slow,
                          curve: AdminTokens.curve,
                          builder: (context, value, _) =>
                              LinearProgressIndicator(
                                value: value,
                                minHeight: 5,
                                backgroundColor: tokens.surfaceAlt,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  gradient.first,
                                ),
                              ),
                        ),
                      ),
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

/// Animates 0 → [value] once. A null value skips the animation entirely.
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

    if (value == null) {
      return Text(AdminFormat.dash, style: style);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: value!.toDouble()),
      duration: AdminTokens.slow,
      curve: AdminTokens.curve,
      builder: (context, animated, _) =>
          Text(AdminFormat.number(animated.round()), style: style),
    );
  }
}
