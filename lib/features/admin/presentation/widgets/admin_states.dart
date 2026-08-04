import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/admin_theme.dart';
import 'glass_card.dart';

/// One shimmering placeholder block.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height = 14,
    this.radius = AdminTokens.radiusSm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    return Shimmer.fromColors(
      baseColor: tokens.isDark ? tokens.surfaceAlt : const Color(0xFFE9ECF3),
      highlightColor: tokens.isDark ? tokens.border : const Color(0xFFF7F8FC),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Skeleton rows shaped like the users table, so the layout does not jump when
/// the real data lands.
class TableShimmer extends StatelessWidget {
  const TableShimmer({super.key, this.rows = 8, this.dense = false});

  final int rows;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      children: List.generate(rows, (index) {
        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: AdminTokens.space5,
            vertical: dense ? AdminTokens.space3 : AdminTokens.space4,
          ),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: tokens.border)),
          ),
          child: Row(
            children: [
              const ShimmerBox(width: 36, height: 36, radius: 18),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(width: 120 + (index % 3) * 24, height: 12),
                    const SizedBox(height: 6),
                    const ShimmerBox(width: 90, height: 10),
                  ],
                ),
              ),
              if (!dense) ...[
                const Expanded(
                  flex: 2,
                  child: ShimmerBox(width: 80, height: 12),
                ),
                const SizedBox(width: AdminTokens.space4),
                const Expanded(
                  child: ShimmerBox(width: 60, height: 20, radius: 999),
                ),
                const SizedBox(width: AdminTokens.space4),
                const Expanded(
                  child: ShimmerBox(width: 60, height: 20, radius: 999),
                ),
              ] else
                const ShimmerBox(width: 64, height: 20, radius: 999),
            ],
          ),
        );
      }),
    );
  }
}

/// Skeleton stat cards for the dashboard home.
class StatCardShimmer extends StatelessWidget {
  const StatCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: const [
          ShimmerBox(width: 44, height: 44, radius: AdminTokens.radiusMd),
          SizedBox(height: AdminTokens.space5),
          ShimmerBox(width: 90, height: 26),
          SizedBox(height: AdminTokens.space3),
          ShimmerBox(width: 120, height: 12),
        ],
      ),
    );
  }
}

/// The illustration-free empty state used across the panel.
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    // Scrollable so the state still fits when it is dropped into a short,
    // fixed-height slot — a dashboard card body, for instance.
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AdminTokens.space6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        tokens.accent.withValues(alpha: 0.16),
                        tokens.accent.withValues(alpha: 0.04),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(icon, size: 32, color: tokens.accent),
                ),
                const SizedBox(height: AdminTokens.space5),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AdminTokens.space2),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
                if (onAction != null || onSecondary != null) ...[
                  const SizedBox(height: AdminTokens.space5),
                  Wrap(
                    spacing: AdminTokens.space3,
                    runSpacing: AdminTokens.space3,
                    alignment: WrapAlignment.center,
                    children: [
                      if (onAction != null && actionLabel != null)
                        FilledButton(
                          onPressed: onAction,
                          child: Text(actionLabel!),
                        ),
                      if (onSecondary != null && secondaryLabel != null)
                        OutlinedButton(
                          onPressed: onSecondary,
                          child: Text(secondaryLabel!),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The failure state. Shows the server's own message when there is one — an
/// admin diagnosing a 403 needs the real reason, not "oops".
class ErrorStateView extends StatelessWidget {
  const ErrorStateView({
    super.key,
    required this.message,
    this.title = 'Something went wrong',
    this.onRetry,
    this.retryLabel = 'Try again',
    this.compact = false,
  });

  final String message;
  final String title;
  final VoidCallback? onRetry;
  final String retryLabel;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    // Scrollable for the same reason as [EmptyStateView]: a chart card's body
    // is a fixed height, and an error there must not overflow it.
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AdminTokens.space6),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: compact ? 52 : 72,
                  height: compact ? 52 : 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tokens.danger.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.cloud_off_rounded,
                    size: compact ? 24 : 32,
                    color: tokens.danger,
                  ),
                ),
                const SizedBox(height: AdminTokens.space4),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: tokens.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AdminTokens.space2),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
                if (onRetry != null) ...[
                  const SizedBox(height: AdminTokens.space5),
                  FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(retryLabel),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin progress line pinned to the top of a section while it refreshes in
/// place — the existing content stays readable underneath.
class RefreshLine extends StatelessWidget {
  const RefreshLine({super.key, required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AdminTokens.fast,
      child: visible
          ? const SizedBox(
              height: 2,
              child: LinearProgressIndicator(minHeight: 2),
            )
          : const SizedBox(height: 2),
    );
  }
}
