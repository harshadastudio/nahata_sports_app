import 'package:flutter/material.dart';

import '../../../admin/presentation/theme/admin_theme.dart';
import '../../../admin/presentation/widgets/admin_states.dart';
import '../../../admin/presentation/widgets/glass_card.dart';
import '../../../admin/presentation/widgets/stat_card.dart';
import '../state/security_guard_controller.dart';

/// The eight live counters.
///
/// Three of them are labelled "on this device" on purpose. The event, court and
/// coaching backends expose no "scans today" endpoint — only per-event and
/// per-court stats — so the only honest count is what this gate has scanned.
/// Saying so is better than a number that looks venue-wide and is not.
class GuardStatGrid extends StatelessWidget {
  const GuardStatGrid({
    super.key,
    required this.counters,
    required this.loading,
    this.onOpenVisitors,
  });

  final GuardCounters counters;
  final bool loading;
  final VoidCallback? onOpenVisitors;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = switch (width) {
      < AdminTokens.mobileMax => 2,
      < AdminTokens.tabletMax => 3,
      < 1500 => 4,
      _ => 4,
    };

    if (loading) {
      return _Grid(
        columns: columns,
        children: List.generate(8, (_) => const StatCardShimmer()),
      );
    }

    return _Grid(
      columns: columns,
      children: [
        StatCard(
          label: 'Visitor Passes Today',
          value: counters.visitorPassesToday,
          icon: Icons.badge_rounded,
          gradient: const [Color(0xFF1A237E), Color(0xFF3F51B5)],
          caption: 'Issued today',
          onTap: onOpenVisitors,
        ),
        StatCard(
          label: 'Visitors Inside',
          value: counters.visitorsInside,
          icon: Icons.meeting_room_rounded,
          gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
          caption: 'On site right now',
          onTap: onOpenVisitors,
        ),
        StatCard(
          label: 'Visitors Checked Out',
          value: counters.visitorsCheckedOut,
          icon: Icons.logout_rounded,
          gradient: const [Color(0xFF0EA5E9), Color(0xFF67E8F9)],
          caption: 'Visits completed today',
          onTap: onOpenVisitors,
        ),
        StatCard(
          label: 'Event Pass Entries',
          value: counters.eventEntries,
          icon: Icons.confirmation_number_rounded,
          gradient: const [Color(0xFF8B5CF6), Color(0xFFC4B5FD)],
          caption: 'Scanned on this device',
        ),
        StatCard(
          label: 'Court Booking Entries',
          value: counters.courtEntries,
          icon: Icons.sports_tennis_rounded,
          gradient: const [Color(0xFF14B8A6), Color(0xFF5EEAD4)],
          caption: 'Scanned on this device',
        ),
        StatCard(
          label: 'Coaching Pass Scans',
          value: counters.coachingScans,
          icon: Icons.school_rounded,
          gradient: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
          caption: 'Scanned on this device',
        ),
        StatCard(
          label: 'Total Scans Today',
          value: counters.totalScans,
          icon: Icons.qr_code_scanner_rounded,
          gradient: const [Color(0xFF6366F1), Color(0xFF818CF8)],
          caption: 'All gates, this device',
        ),
        StatCard(
          label: 'Invalid QR Attempts',
          value: counters.invalidAttempts,
          icon: Icons.gpp_bad_rounded,
          gradient: const [Color(0xFFEF4444), Color(0xFFF87171)],
          caption: 'Refused or failed today',
        ),
      ],
    );
  }
}

/// The one-line explanation of where the device-scoped figures come from.
class GuardCounterNote extends StatelessWidget {
  const GuardCounterNote({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space3),
      color: tokens.surfaceAlt,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 16, color: tokens.textMuted),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              'Visitor figures come from the server and cover the whole venue. '
              'Event, court and coaching counts are what this device has '
              'scanned today — those gates report per-event and per-court '
              'statistics, not a daily total.',
              style: TextStyle(
                color: tokens.textMuted,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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