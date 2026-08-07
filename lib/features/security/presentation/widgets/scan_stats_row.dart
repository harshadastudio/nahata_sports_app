import 'package:flutter/material.dart';

import '../../../admin/presentation/theme/admin_theme.dart';
import '../../../admin/presentation/widgets/admin_states.dart';
import '../../domain/entities/gate_scan.dart';

/// The six counters `/…/scan-stats` returns, laid out identically for the event
/// and court gates so a guard reads them the same way at either door.
class ScanStatsRow extends StatelessWidget {
  const ScanStatsRow({
    super.key,
    required this.stats,
    required this.loading,
    this.error,
    this.onRetry,
  });

  final ScanStats stats;
  final bool loading;
  final String? error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const _Grid(
        children: [
          ShimmerBox(height: 74),
          ShimmerBox(height: 74),
          ShimmerBox(height: 74),
          ShimmerBox(height: 74),
          ShimmerBox(height: 74),
          ShimmerBox(height: 74),
        ],
      );
    }

    if (error != null) {
      return ErrorStateView(
        compact: true,
        title: 'Statistics unavailable',
        message: error!,
        onRetry: onRetry,
      );
    }

    final tokens = AdminTheme.of(context);

    return _Grid(
      children: [
        _Tile(
          label: 'Total Passes',
          value: stats.totalPasses,
          icon: Icons.confirmation_number_outlined,
          colour: tokens.accent,
        ),
        _Tile(
          label: 'Total Persons',
          value: stats.totalPersons,
          icon: Icons.groups_rounded,
          colour: tokens.accent,
        ),
        _Tile(
          label: 'Inside',
          value: stats.inCount,
          icon: Icons.login_rounded,
          colour: tokens.success,
        ),
        _Tile(
          label: 'Outside',
          value: stats.outCount,
          icon: Icons.logout_rounded,
          colour: tokens.warning,
        ),
        _Tile(
          label: 'Pending Scan',
          value: stats.notScanned,
          icon: Icons.hourglass_top_rounded,
          colour: tokens.textMuted,
        ),
        _Tile(
          label: 'Currently Inside',
          value: stats.currentlyInside,
          icon: Icons.meeting_room_rounded,
          colour: tokens.success,
        ),
      ],
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = switch (width) {
      < AdminTokens.mobileMax => 2,
      < AdminTokens.tabletMax => 3,
      _ => 6,
    };

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AdminTokens.space3;
        final tileWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: children
              .map((child) => SizedBox(width: tileWidth, child: child))
              .toList(),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.label,
    required this.value,
    required this.icon,
    required this.colour,
  });

  final String label;
  final int value;
  final IconData icon;
  final Color colour;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space3),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: colour),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}