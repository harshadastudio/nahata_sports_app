import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/dashboard_stats.dart';
import '../../domain/entities/enrollment_trend.dart';
import '../../domain/entities/live_enquiry.dart';
import '../../domain/entities/sport_distribution.dart';
import '../navigation/admin_destination.dart';
import '../state/admin_shell_controller.dart';
import '../state/admin_users_controller.dart';
import '../state/dashboard_controller.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import '../widgets/admin_states.dart';
import '../widgets/enrollment_trend_chart.dart';
import '../widgets/glass_card.dart';
import '../widgets/growth_stat_card.dart';
import '../widgets/live_enquiries_card.dart';
import '../widgets/sport_distribution_chart.dart';

/// The dashboard home.
///
/// Layout, widest first:
///
/// ```
///   five stat cards
///   enrollment chart          sport distribution
///   recent live enquiries
/// ```
///
/// Each block owns its loading, empty and error state, so a dead endpoint costs
/// one card rather than the page.
class DashboardHomePage extends StatefulWidget {
  const DashboardHomePage({super.key});

  @override
  State<DashboardHomePage> createState() => _DashboardHomePageState();
}

class _DashboardHomePageState extends State<DashboardHomePage> {
  @override
  void initState() {
    super.initState();
    AdminLog.life('DashboardHomePage mounted');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<DashboardController>();
      if (controller.loadedAt == null && !controller.isLoading) {
        controller.load();
      }
    });
  }

  @override
  void dispose() {
    AdminLog.life('DashboardHomePage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<DashboardController>();
    final tokens = AdminTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;

    final isMobile = width < AdminTokens.mobileMax;
    final isTablet = width < AdminTokens.tabletMax;

    return RefreshIndicator(
      onRefresh: controller.refresh,
      color: tokens.accent,
      child: ListView(
        padding: EdgeInsets.all(
          isMobile ? AdminTokens.space4 : AdminTokens.space6,
        ),
        children: [
          _Header(controller: controller),
          const SizedBox(height: AdminTokens.space5),
          _StatsRow(section: controller.stats, onRetry: controller.loadStats),
          const SizedBox(height: AdminTokens.space5),
          // Desktop puts the chart and the doughnut side by side; anything
          // narrower stacks them.
          if (isTablet) ...[
            _EnrollmentBlock(
              section: controller.trends,
              onRetry: controller.loadTrends,
            ),
            const SizedBox(height: AdminTokens.space5),
            _DistributionBlock(
              section: controller.distribution,
              onRetry: controller.loadDistribution,
              stacked: true,
            ),
          ] else
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    flex: 7,
                    child: _EnrollmentBlock(
                      section: controller.trends,
                      onRetry: controller.loadTrends,
                    ),
                  ),
                  const SizedBox(width: AdminTokens.space5),
                  Expanded(
                    flex: 5,
                    child: _DistributionBlock(
                      section: controller.distribution,
                      onRetry: controller.loadDistribution,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AdminTokens.space5),
          _EnquiriesBlock(
            section: controller.enquiries,
            onRetry: controller.loadEnquiries,
          ),
          const SizedBox(height: AdminTokens.space6),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final DashboardController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < AdminTokens.mobileMax;

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Overview',
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(color: tokens.textPrimary),
        ),
        const SizedBox(height: AdminTokens.space1),
        Text(
          controller.loadedAt == null
              ? 'Loading the latest figures…'
              : 'Updated ${AdminFormat.relative(controller.loadedAt).toLowerCase()}',
          style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
        ),
      ],
    );

    final refresh = OutlinedButton.icon(
      onPressed: controller.isLoading ? null : controller.refresh,
      icon: controller.isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh_rounded, size: 18),
      label: const Text('Refresh'),
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: AdminTokens.space4),
          refresh,
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: title),
        refresh,
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Stats
// -----------------------------------------------------------------------------

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.section, required this.onRetry});

  final Section<DashboardStats> section;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = switch (width) {
      < AdminTokens.mobileMax => 1,
      < AdminTokens.tabletMax => 2,
      < 1500 => 3,
      _ => 5,
    };

    if (section.isBusy && section.data.isEmpty) {
      return _Grid(
        columns: columns,
        children: List.generate(5, (_) => const StatCardShimmer()),
      );
    }

    if (section.isFailed && section.data.isEmpty) {
      return SolidCard(
        padding: const EdgeInsets.symmetric(vertical: AdminTokens.space8),
        child: ErrorStateView(
          compact: true,
          title: 'Statistics unavailable',
          message: section.error ?? 'The server did not return any figures.',
          onRetry: onRetry,
        ),
      );
    }

    if (section.data.isEmpty) {
      return SolidCard(
        padding: const EdgeInsets.symmetric(vertical: AdminTokens.space8),
        child: EmptyStateView(
          icon: Icons.query_stats_rounded,
          title: 'No statistics yet',
          message:
              'Figures appear here as students, bookings and enquiries '
              'come in.',
          actionLabel: 'Reload',
          onAction: onRetry,
        ),
      );
    }

    final stats = section.data;

    return _Grid(
      columns: columns,
      children: [
        GrowthStatCard(
          label: 'Students',
          metric: stats.students,
          icon: Icons.school_rounded,
          gradient: const [Color(0xFF1A237E), Color(0xFF3F51B5)],
          onTap: () => _openUsers(context, AdminRole.user),
        ),
        GrowthStatCard(
          label: 'Coaches',
          metric: stats.coaches,
          icon: Icons.sports_rounded,
          gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
          onTap: () => _openUsers(context, AdminRole.coach),
        ),
        GrowthStatCard(
          label: 'Bookings',
          metric: stats.bookings,
          icon: Icons.event_available_rounded,
          gradient: const [Color(0xFF0EA5E9), Color(0xFF67E8F9)],
        ),
        GrowthStatCard(
          label: 'Enquiries',
          metric: stats.enquiries,
          icon: Icons.forum_rounded,
          gradient: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
        ),
        GrowthStatCard(
          label: 'Contact Requests',
          metric: stats.contactRequests,
          icon: Icons.mark_email_unread_rounded,
          gradient: const [Color(0xFFEC4899), Color(0xFFF9A8D4)],
        ),
      ],
    );
  }

  static void _openUsers(BuildContext context, AdminRole role) {
    AdminLog.ui('Stat card → Users (${role.slug})');
    context.read<AdminUsersController>().setRoleFilter(role);
    context.read<AdminShellController>().go(AdminDestination.users);
  }
}

// -----------------------------------------------------------------------------
// Charts
// -----------------------------------------------------------------------------

class _EnrollmentBlock extends StatelessWidget {
  const _EnrollmentBlock({required this.section, required this.onRetry});

  final Section<EnrollmentTrend> section;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _ChartPanel(
      title: 'Enrollment trends',
      subtitle: 'Students and enquiries by month',
      icon: Icons.show_chart_rounded,
      loading: section.isBusy && section.data.isEmpty,
      error: section.isFailed && section.data.isEmpty ? section.error : null,
      onRetry: onRetry,
      refreshing: section.isLoading && section.data.isNotEmpty,
      isEmpty: section.data.isEmpty || section.data.isAllZero,
      emptyTitle: 'No enrollment data yet',
      emptyMessage:
          'Once students and enquiries start coming in, their '
          'monthly trend appears here.',
      height: 300,
      child: EnrollmentTrendChart(trend: section.data),
    );
  }
}

class _DistributionBlock extends StatelessWidget {
  const _DistributionBlock({
    required this.section,
    required this.onRetry,
    this.stacked = false,
  });

  final Section<SportDistribution> section;
  final VoidCallback onRetry;
  final bool stacked;

  @override
  Widget build(BuildContext context) {
    return _ChartPanel(
      title: 'Sport distribution',
      subtitle: 'Where students are enrolled',
      icon: Icons.donut_large_rounded,
      loading: section.isBusy && section.data.isEmpty,
      error: section.isFailed && section.data.isEmpty ? section.error : null,
      onRetry: onRetry,
      refreshing: section.isLoading && section.data.isNotEmpty,
      isEmpty: section.data.isEmpty || section.data.isAllZero,
      emptyTitle: 'No sports to show',
      emptyMessage:
          'The distribution fills in as students enroll across '
          'sports.',
      height: 300,
      scrollable: stacked,
      child: SportDistributionChart(
        distribution: section.data,
        stacked: stacked,
      ),
    );
  }
}

/// The shared frame for both charts: header, states, and a fixed body height so
/// the two panels line up when side by side.
class _ChartPanel extends StatelessWidget {
  const _ChartPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.isEmpty,
    required this.emptyTitle,
    required this.emptyMessage,
    required this.height,
    this.refreshing = false,
    this.scrollable = false,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  final bool loading;
  final String? error;
  final VoidCallback onRetry;
  final bool refreshing;

  final bool isEmpty;
  final String emptyTitle;
  final String emptyMessage;

  final double height;

  /// Stacked layouts grow past [height]; a fixed box would clip the legend.
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    final Widget body;
    if (loading) {
      body = _ChartShimmer(height: height);
    } else if (error != null) {
      body = SizedBox(
        height: height,
        child: ErrorStateView(
          compact: true,
          title: 'Could not load this chart',
          message: error!,
          onRetry: onRetry,
        ),
      );
    } else if (isEmpty) {
      body = SizedBox(
        height: height,
        child: EmptyStateView(
          icon: icon,
          title: emptyTitle,
          message: emptyMessage,
          actionLabel: 'Reload',
          onAction: onRetry,
        ),
      );
    } else if (scrollable) {
      body = child;
    } else {
      body = SizedBox(height: height, child: child);
    }

    return SolidCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AdminTokens.space5,
              AdminTokens.space5,
              AdminTokens.space5,
              AdminTokens.space3,
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: tokens.accent),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                if (refreshing)
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AdminTokens.space5,
              0,
              AdminTokens.space5,
              AdminTokens.space5,
            ),
            child: body,
          ),
        ],
      ),
    );
  }
}

class _ChartShimmer extends StatelessWidget {
  const _ChartShimmer({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              ShimmerBox(width: 74, height: 12),
              SizedBox(width: AdminTokens.space4),
              ShimmerBox(width: 74, height: 12),
            ],
          ),
          const SizedBox(height: AdminTokens.space5),
          const Expanded(
            child: ShimmerBox(
              height: double.infinity,
              radius: AdminTokens.radiusMd,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Live enquiries
// -----------------------------------------------------------------------------

class _EnquiriesBlock extends StatelessWidget {
  const _EnquiriesBlock({required this.section, required this.onRetry});

  final Section<List<LiveEnquiry>> section;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final enquiries = section.data;

    final Widget body;
    if (section.isBusy && enquiries.isEmpty) {
      body = const TableShimmer(rows: 4, dense: true);
    } else if (section.isFailed && enquiries.isEmpty) {
      body = SizedBox(
        height: 220,
        child: ErrorStateView(
          compact: true,
          title: 'Could not load enquiries',
          message: section.error ?? 'Please try again.',
          onRetry: onRetry,
        ),
      );
    } else if (enquiries.isEmpty) {
      body = SizedBox(
        height: 220,
        child: EmptyStateView(
          icon: Icons.forum_outlined,
          title: 'No recent enquiries',
          message:
              'New enquiries from the website and app land here as they '
              'arrive.',
          actionLabel: 'Reload',
          onAction: onRetry,
        ),
      );
    } else {
      body = Column(
        children: [
          for (var i = 0; i < enquiries.length; i++)
            LiveEnquiryRow(
              key: ValueKey<String>(enquiries[i].id),
              enquiry: enquiries[i],
              isLast: i == enquiries.length - 1,
            ),
        ],
      );
    }

    return SolidCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AdminTokens.space5,
                AdminTokens.space5,
                AdminTokens.space4,
                AdminTokens.space4,
              ),
              child: Row(
                children: [
                  Icon(Icons.bolt_rounded, size: 18, color: tokens.accent),
                  const SizedBox(width: AdminTokens.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Recent enquiries',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          'The latest leads across every sport',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (section.isLoading && enquiries.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(right: AdminTokens.space3),
                      child: SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: () {
                      // Enquiries live in the Coaching module, which is not
                      // built yet — say so rather than navigate nowhere.
                      AdminLog.ui('View all enquiries tapped');
                      ScaffoldMessenger.maybeOf(context)
                        ?..hideCurrentSnackBar()
                        ..showSnackBar(
                          const SnackBar(
                            content: Text(
                              'The full enquiries list arrives with the '
                              'Programs module.',
                            ),
                          ),
                        );
                    },
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                    iconAlignment: IconAlignment.end,
                    label: const Text('View all'),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: tokens.border),
            body,
          ],
        ),
      ),
    );
  }
}

/// Responsive equal-width grid, matching the phase-1 dashboard's card grid.
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
