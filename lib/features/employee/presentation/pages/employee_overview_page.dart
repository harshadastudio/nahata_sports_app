import 'package:flutter/material.dart';

import '../../data/repositories/employee_dashboard_repository_impl.dart';
import '../../domain/entities/employee_booking.dart';
import '../../domain/entities/employee_formats.dart';
import '../state/employee_overview_controller.dart';
import '../state/employee_view_state.dart';
import '../theme/employee_theme.dart';
import '../widgets/employee_states.dart';
import '../widgets/employee_stat_tile.dart';

/// Dashboard Overview — the numbers, then the newest bookings.
///
/// Everything here is scoped to the employee's own complex by the API, so no
/// venue filter appears and none is sent.
class EmployeeOverviewPage extends StatefulWidget {
  const EmployeeOverviewPage({super.key, this.onOpenBookings});

  /// Lets the "View all" link reach the full bookings screen rather than
  /// dead-ending, when the overview was opened from the menu.
  final VoidCallback? onOpenBookings;

  @override
  State<EmployeeOverviewPage> createState() => _EmployeeOverviewPageState();
}

class _EmployeeOverviewPageState extends State<EmployeeOverviewPage> {
  late final EmployeeOverviewController _controller =
      EmployeeOverviewController(EmployeeDashboardRepositoryImpl());

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: EmployeeTokens.canvas,
      appBar: AppBar(
        backgroundColor: EmployeeTokens.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Refresh',
              onPressed: _controller.refreshing ? null : _controller.refresh,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) =>
                EmployeeRefreshLine(visible: _controller.refreshing),
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => RefreshIndicator(
          color: EmployeeTokens.brand,
          onRefresh: _controller.refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(
              EmployeeTokens.space4,
              EmployeeTokens.space4,
              EmployeeTokens.space4,
              EmployeeTokens.space8,
            ),
            children: [
              const EmployeeScopeNotice(
                message: 'Every figure below covers your own sports complex.',
              ),
              const SizedBox(height: EmployeeTokens.space4),
              _statsSection(),
              EmployeeSectionHeader(
                title: 'Recent bookings',
                trailing: widget.onOpenBookings == null
                    ? null
                    : TextButton(
                        onPressed: widget.onOpenBookings,
                        style: TextButton.styleFrom(
                          foregroundColor: EmployeeTokens.brand,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'View all',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
              _recentSection(),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Stats
  // ───────────────────────────────────────────────────────────────────────────

  Widget _statsSection() {
    if (_controller.isInitialLoad) {
      return const EmployeeStatsShimmer(tiles: 6);
    }

    if (_controller.statsState.isFailed) {
      return EmployeeCard(
        child: EmployeeErrorView(
          compact: true,
          message: _controller.statsError ?? 'Could not load your numbers.',
          onRetry: _controller.refresh,
        ),
      );
    }

    final stats = _controller.stats;

    return EmployeeTileGrid(
      children: [
        EmployeeStatTile(
          label: "Today's bookings",
          value: '${stats.todayBookings}',
          icon: Icons.today_rounded,
          color: EmployeeTokens.info,
          trend: stats.bookingsTrend,
          onTap: widget.onOpenBookings,
        ),
        EmployeeStatTile(
          label: 'Total revenue',
          value: stats.revenueLabel,
          icon: Icons.currency_rupee_rounded,
          color: EmployeeTokens.accent,
          trend: stats.revenueTrend,
        ),
        EmployeeStatTile(
          // The API counts the next seven days here, deliberately excluding
          // today — the two tiles do not overlap.
          label: 'Upcoming (7 days)',
          value: '${stats.upcomingBookings}',
          icon: Icons.event_available_rounded,
          color: EmployeeTokens.purple,
        ),
        EmployeeStatTile(
          label: 'Total bookings',
          value: '${stats.totalBookings}',
          icon: Icons.receipt_long_rounded,
          color: EmployeeTokens.brand,
        ),
        EmployeeStatTile(
          label: 'Active enrollments',
          value: '${stats.activeEnrollments}',
          icon: Icons.school_outlined,
          color: EmployeeTokens.success,
        ),
        EmployeeStatTile(
          label: 'Courts',
          value: '${stats.totalCourts}',
          icon: Icons.stadium_outlined,
          color: EmployeeTokens.warning,
        ),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Recent bookings
  // ───────────────────────────────────────────────────────────────────────────

  Widget _recentSection() {
    if (_controller.bookingsState.isLoading &&
        _controller.recentBookings.isEmpty) {
      return const EmployeeListShimmer(rows: 3);
    }

    if (_controller.bookingsState.isFailed) {
      return EmployeeCard(
        child: EmployeeErrorView(
          compact: true,
          message: _controller.bookingsError ?? 'Could not load bookings.',
          onRetry: _controller.refresh,
        ),
      );
    }

    if (_controller.recentBookings.isEmpty) {
      return const EmployeeCard(
        child: EmployeeEmptyView(
          compact: true,
          icon: Icons.event_busy_rounded,
          title: 'No bookings yet',
          message: 'New bookings will appear here as they come in.',
        ),
      );
    }

    return Column(
      children: [
        for (final booking in _controller.recentBookings)
          _recentTile(booking),
      ],
    );
  }

  Widget _recentTile(EmployeeBooking booking) {
    return EmployeeCard(
      margin: const EdgeInsets.only(bottom: EmployeeTokens.space3),
      accentColor: EmployeeTokens.statusColor(booking.bookingStatus),
      onTap: widget.onOpenBookings,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EmployeeAvatar(initial: booking.initial, radius: 19),
          const SizedBox(width: EmployeeTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: EmployeeTokens.textDark,
                  ),
                ),
                const SizedBox(height: 3),
                Wrap(
                  spacing: EmployeeTokens.space3,
                  runSpacing: 2,
                  children: [
                    if (booking.sportName.isNotEmpty)
                      _meta(Icons.emoji_events_outlined, booking.sportName),
                    _meta(Icons.schedule_rounded, booking.timeLabel),
                    _meta(
                      Icons.currency_rupee_rounded,
                      booking.amountLabel.replaceFirst('₹', ''),
                      color: EmployeeTokens.success,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: EmployeeTokens.space2),
          Text(
            formatRelative(booking.createdAt),
            style: const TextStyle(
              fontSize: 10.5,
              color: EmployeeTokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text, {Color? color}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color ?? EmployeeTokens.textMuted),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 11.5,
            color: color ?? EmployeeTokens.textBody,
          ),
        ),
      ],
    );
  }
}
