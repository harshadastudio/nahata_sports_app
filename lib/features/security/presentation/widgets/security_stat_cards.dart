import 'package:flutter/material.dart';

import '../../../admin/domain/entities/visitor_pass.dart';
import '../../../admin/presentation/theme/admin_theme.dart';
import '../../../admin/presentation/widgets/admin_states.dart';
import '../../../admin/presentation/widgets/glass_card.dart';
import '../../../admin/presentation/widgets/growth_stat_card.dart';
import '../../../admin/presentation/widgets/stat_card.dart';
import '../../domain/entities/security_dashboard_data.dart';

/// The seven figures across the top of the dashboard.
///
/// Tapping one filters the activity table to it — a count is more useful when
/// it leads somewhere, and it saves the desk a trip through the filter sheet.
class SecurityStatCards extends StatelessWidget {
  const SecurityStatCards({
    super.key,
    required this.data,
    required this.loading,
    required this.onFilter,
  });

  final SecurityDashboardData data;
  final bool loading;

  /// Null clears the status filter (the "all passes" cards).
  final ValueChanged<VisitorPassStatus?> onFilter;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = switch (width) {
      < AdminTokens.mobileMax => 1,
      < AdminTokens.tabletMax => 2,
      < 1500 => 3,
      _ => 4,
    };

    if (loading) {
      return _Grid(
        columns: columns,
        children: List.generate(7, (_) => const StatCardShimmer()),
      );
    }

    final windowLabel = data.window?.label.toLowerCase() ?? 'today';

    return _Grid(
      columns: columns,
      children: [
        GrowthStatCard(
          label: 'Total Visitors ${_titleCase(windowLabel)}',
          metric: data.visitorsMetric,
          icon: Icons.groups_rounded,
          gradient: const [Color(0xFF1A237E), Color(0xFF3F51B5)],
          onTap: () => onFilter(null),
        ),
        StatCard(
          label: 'Currently Inside',
          value: data.inside,
          icon: Icons.meeting_room_rounded,
          gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
          caption: data.inside == 0
              ? 'Nobody in the building'
              : 'On site right now',
          onTap: () => onFilter(VisitorPassStatus.checkedIn),
        ),
        StatCard(
          label: 'Checked Out',
          value: data.checkedOut,
          icon: Icons.logout_rounded,
          gradient: const [Color(0xFF0EA5E9), Color(0xFF67E8F9)],
          caption: 'Visits completed $windowLabel',
          onTap: () => onFilter(VisitorPassStatus.checkedOut),
        ),
        StatCard(
          label: 'Pending Visitors',
          value: data.pending,
          icon: Icons.hourglass_top_rounded,
          gradient: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
          caption: 'Pass issued, not scanned in',
          onTap: () => onFilter(VisitorPassStatus.pending),
        ),
        StatCard(
          label: 'Total Visitor Passes',
          value: data.totalPasses,
          icon: Icons.badge_rounded,
          gradient: const [Color(0xFF6366F1), Color(0xFF818CF8)],
          caption: 'Issued $windowLabel',
          onTap: () => onFilter(null),
        ),
        StatCard(
          label: 'Active Passes',
          value: data.active,
          icon: Icons.verified_rounded,
          gradient: const [Color(0xFF14B8A6), Color(0xFF5EEAD4)],
          caption: 'Still usable',
          // Active spans pending and inside, so it cannot map to one status.
          onTap: () => onFilter(null),
        ),
        StatCard(
          label: 'Expired Passes',
          value: data.expired,
          icon: Icons.block_rounded,
          gradient: const [Color(0xFFEF4444), Color(0xFFF87171)],
          caption: 'Checked out or expired',
          onTap: () => onFilter(VisitorPassStatus.expired),
        ),
      ],
    );
  }

  static String _titleCase(String value) =>
      value.isEmpty ? value : value[0].toUpperCase() + value.substring(1);
}

/// A banner shown when the sweep hit its page cap, so a partial figure is never
/// presented as the complete one.
class SecurityTruncationNotice extends StatelessWidget {
  const SecurityTruncationNotice({super.key, required this.maxPasses});

  final int maxPasses;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      color: tokens.warning.withValues(alpha: 0.08),
      borderColor: tokens.warning.withValues(alpha: 0.35),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: tokens.warning),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              'These figures cover the $maxPasses most recent passes. There are '
              'older passes in this period that are not included.',
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
}

/// Equal-width cards that wrap — the same grid the admin dashboard home uses.
class _Grid extends StatelessWidget {
  const _Grid({required this.columns, required this.children});

  final int columns;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AdminTokens.space4;
        final width = (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(),
        );
      },
    );
  }
}