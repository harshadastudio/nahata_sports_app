import 'package:flutter/material.dart';

import '../../../../core/services/permission_service.dart';
import '../../../../core/storage/profile_cache.dart';
import '../../core/coach_log.dart';
import '../../data/repositories/coach_dashboard_repository_impl.dart';
import '../../domain/entities/coach_enquiry.dart';
import '../../domain/entities/coach_overview.dart';
import '../../domain/repositories/coach_dashboard_repository.dart';
import '../state/coach_overview_controller.dart';
import '../state/coach_view_state.dart';
import '../theme/coach_theme.dart';
import '../widgets/coach_enquiry_form_sheet.dart';
import '../widgets/coach_stat_tile.dart';
import '../widgets/coach_states.dart';

/// The coach's Dashboard Overview.
///
/// Mirrors the website's `CoachDashboard.tsx` section for section: the welcome
/// banner with Refresh and Send Enquiry, the stat grid, today's schedule, top
/// performers, and the enquiry queue.
///
/// The four sections load independently, so one failing endpoint degrades to
/// an inline retry inside its own card rather than taking the page down.
class CoachOverviewPage extends StatefulWidget {
  const CoachOverviewPage({super.key, this.repository, this.onOpenEnquiries});

  /// Injectable for tests; defaults to the live repository.
  final CoachDashboardRepository? repository;

  /// Tapping "View all" on the enquiry card. Left null when the overview is
  /// shown outside the coach shell, in which case the link is hidden.
  final VoidCallback? onOpenEnquiries;

  @override
  State<CoachOverviewPage> createState() => _CoachOverviewPageState();
}

class _CoachOverviewPageState extends State<CoachOverviewPage> {
  late final CoachDashboardRepository _repository =
      widget.repository ?? CoachDashboardRepositoryImpl();
  late final CoachOverviewController _controller =
      CoachOverviewController(_repository);

  /// The venue from the cached `/auth/profile`. Not a typed field on
  /// `ProfileModel`, so it arrives in `extras` verbatim.
  String? _venue;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _controller.load();
    _loadVenue();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _loadVenue() async {
    final profile = await ProfileCache.instance.read();
    final complex = profile?.extras['sportComplex'];
    final name = complex is Map ? complex['name']?.toString() : null;

    if (!mounted || name == null || name.isEmpty) return;
    setState(() => _venue = name);
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _sendEnquiry() async {
    CoachLog.ui('Send Enquiry tapped');

    final sent = await showCoachEnquiryFormSheet(
      context: context,
      repository: _repository,
      onSubmit: _controller.submitEnquiry,
    );

    if (!mounted || !sent) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enquiry sent to admin'),
        backgroundColor: CoachTokens.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoachTokens.canvas,
      appBar: AppBar(
        backgroundColor: CoachTokens.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Coach Dashboard',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _controller.refreshing ? null : _controller.refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: CoachRefreshLine(visible: _controller.refreshing),
        ),
      ),
      body: RefreshIndicator(
        color: CoachTokens.brand,
        onRefresh: _controller.refresh,
        child: _body(),
      ),
    );
  }

  Widget _body() {
    // A missing Coach row breaks every section identically, so it is explained
    // once instead of four times.
    if (_controller.profileMissing) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: CoachTokens.space8),
        children: [
          CoachEmptyView(
            icon: Icons.link_off_rounded,
            title: 'Your coach profile is not linked',
            message:
                'This account is signed in as a coach, but it is not attached '
                'to a coach record yet. Ask an admin to link it, then pull to '
                'refresh.',
            actionLabel: 'Try again',
            onAction: _controller.refresh,
          ),
        ],
      );
    }

    if (_controller.isFirstLoad) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(CoachTokens.space4),
        children: const [
          CoachStatsShimmer(),
          SizedBox(height: CoachTokens.space6),
          CoachListShimmer(rows: 3),
        ],
      );
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        CoachTokens.space4,
        CoachTokens.space4,
        CoachTokens.space4,
        CoachTokens.space8,
      ),
      children: [
        _banner(),
        const SizedBox(height: CoachTokens.space5),
        _statsSection(),
        const CoachSectionHeader(title: "Today's Schedule"),
        _scheduleSection(),
        if (PermissionService.instance
            .hasPermission(CoachPermissions.performance)) ...[
          const CoachSectionHeader(title: 'Top Performers'),
          _performersSection(),
        ],
        if (PermissionService.instance
            .hasPermission(CoachPermissions.coachingEnquiries)) ...[
          CoachSectionHeader(
            title: 'My Coaching Enquiries',
            trailing: _controller.enquiryTotal > 0
                ? Text(
                    'Total: ${_controller.enquiryTotal}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: CoachTokens.textMuted,
                    ),
                  )
                : null,
          ),
          _enquiriesSection(),
        ],
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Banner
  // ---------------------------------------------------------------------------

  Widget _banner() {
    return Container(
      padding: const EdgeInsets.all(CoachTokens.space5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [CoachTokens.brand, Color(0xFF2B3FC4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(CoachTokens.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Manage students, attendance\nand track performance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 17,
              height: 1.35,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_venue != null) ...[
            const SizedBox(height: CoachTokens.space2),
            Row(
              children: [
                const Icon(
                  Icons.place_outlined,
                  size: 15,
                  color: Colors.white70,
                ),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    _venue!,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (PermissionService.instance
              .hasPermission(CoachPermissions.coachingEnquiries)) ...[
            const SizedBox(height: CoachTokens.space4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _sendEnquiry,
                icon: const Icon(Icons.add_rounded, size: 19),
                label: const Text('Send Enquiry'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: CoachTokens.brand,
                  padding: const EdgeInsets.symmetric(
                    vertical: CoachTokens.space3 + 2,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Stats
  // ---------------------------------------------------------------------------

  Widget _statsSection() {
    if (_controller.statsState.isLoading && _controller.stats.isEmpty) {
      return const CoachStatsShimmer();
    }

    if (_controller.statsState.isFailed) {
      return CoachCard(
        child: CoachErrorView(
          compact: true,
          message: _controller.statsError ?? 'Could not load your numbers.',
          onRetry: _controller.refresh,
        ),
      );
    }

    final stats = _controller.stats;

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: CoachTokens.space3,
      crossAxisSpacing: CoachTokens.space3,
      childAspectRatio: 1.45,
      children: [
        CoachStatTile(
          label: 'My students',
          value: '${stats.totalStudents}',
          icon: Icons.people_alt_outlined,
          color: CoachTokens.info,
        ),
        CoachStatTile(
          label: 'Present today',
          value: stats.attendanceLabel,
          icon: Icons.how_to_reg_outlined,
          color: CoachTokens.success,
        ),
        CoachStatTile(
          // Named the way the API computes it — Active batches, not sessions
          // timetabled for today. See [CoachDashboardStats.sessionsToday].
          label: 'Active sessions',
          value: '${stats.sessionsToday}',
          icon: Icons.event_available_outlined,
          color: CoachTokens.accent,
        ),
        CoachStatTile(
          label: 'Total batches',
          value: '${stats.totalBatches}',
          icon: Icons.groups_2_outlined,
          color: CoachTokens.brand,
        ),
        CoachStatTile(
          label: 'Avg performance',
          value: stats.performanceLabel,
          icon: Icons.trending_up_rounded,
          color: CoachTokens.purple,
        ),
        CoachStatTile(
          label: 'Active enquiries',
          value: '${stats.activeEnquiries}',
          icon: Icons.question_answer_outlined,
          color: CoachTokens.warning,
          onTap: widget.onOpenEnquiries,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Today's schedule
  // ---------------------------------------------------------------------------

  Widget _scheduleSection() {
    if (_controller.scheduleState.isLoading && _controller.schedule.isEmpty) {
      return const CoachListShimmer(rows: 2);
    }

    if (_controller.scheduleState.isFailed) {
      return CoachCard(
        child: CoachErrorView(
          compact: true,
          message: _controller.scheduleError ?? "Could not load today's sessions.",
          onRetry: _controller.refresh,
        ),
      );
    }

    if (_controller.schedule.isEmpty) {
      return const CoachCard(
        child: CoachEmptyView(
          compact: true,
          icon: Icons.event_busy_outlined,
          title: 'Nothing scheduled',
          message: 'You have no active sessions right now.',
        ),
      );
    }

    return Column(
      children: _controller.schedule.map(_sessionCard).toList(),
    );
  }

  Widget _sessionCard(CoachSession session) {
    return CoachCard(
      margin: const EdgeInsets.only(bottom: CoachTokens.space3),
      accentColor: CoachTokens.statusColor(session.statusLabel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  session.displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: CoachTokens.textDark,
                  ),
                ),
              ),
              const SizedBox(width: CoachTokens.space2),
              CoachStatusChip(label: session.statusLabel),
            ],
          ),
          if ((session.sportName ?? '').isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              session.sportName!,
              style: const TextStyle(
                fontSize: 12.5,
                color: CoachTokens.textBody,
              ),
            ),
          ],
          const SizedBox(height: CoachTokens.space3),
          Wrap(
            spacing: CoachTokens.space4,
            runSpacing: CoachTokens.space2,
            children: [
              if (session.timeLabel.isNotEmpty)
                _meta(Icons.schedule_rounded, session.timeLabel),
              _meta(Icons.people_outline_rounded, session.studentLabel),
              if (session.hasCourt)
                _meta(Icons.place_outlined, session.court!),
            ],
          ),
        ],
      ),
    );
  }

  Widget _meta(IconData icon, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.5, color: CoachTokens.textMuted),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              color: CoachTokens.textBody,
            ),
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // Top performers
  // ---------------------------------------------------------------------------

  Widget _performersSection() {
    if (_controller.performersState.isLoading &&
        _controller.performers.isEmpty) {
      return const CoachListShimmer(rows: 2);
    }

    if (_controller.performersState.isFailed) {
      return CoachCard(
        child: CoachErrorView(
          compact: true,
          message: _controller.performersError ??
              'Could not load your top performers.',
          onRetry: _controller.refresh,
        ),
      );
    }

    if (_controller.performers.isEmpty) {
      return const CoachCard(
        child: CoachEmptyView(
          compact: true,
          icon: Icons.emoji_events_outlined,
          title: 'No assessments yet',
          message:
              'Record a student assessment and your top performers appear here.',
        ),
      );
    }

    return Column(
      children: _controller.performers
          .asMap()
          .entries
          .map((e) => _performerCard(e.value, e.key + 1))
          .toList(),
    );
  }

  Widget _performerCard(CoachTopPerformer performer, int rank) {
    final tone = CoachTokens.performanceColor(performer.colorKey);

    return CoachCard(
      margin: const EdgeInsets.only(bottom: CoachTokens.space3),
      child: Row(
        children: [
          CoachAvatar(initial: performer.initial, color: tone),
          const SizedBox(width: CoachTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$rank. ${performer.displayName}',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    color: CoachTokens.textDark,
                  ),
                ),
                if (performer.subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    performer.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: CoachTokens.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: CoachTokens.space2),
          Text(
            performer.scoreLabel,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: tone,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Enquiries
  // ---------------------------------------------------------------------------

  Widget _enquiriesSection() {
    if (_controller.enquiriesState.isLoading && _controller.enquiries.isEmpty) {
      return const CoachListShimmer(rows: 2);
    }

    if (_controller.enquiriesState.isFailed) {
      return CoachCard(
        child: CoachErrorView(
          compact: true,
          message: _controller.enquiriesError ?? 'Could not load your enquiries.',
          onRetry: _controller.refresh,
        ),
      );
    }

    if (_controller.enquiries.isEmpty) {
      return CoachCard(
        child: CoachEmptyView(
          compact: true,
          icon: Icons.forum_outlined,
          title: 'No enquiries yet',
          message: 'Enquiries you file for prospective students show up here.',
          actionLabel: 'Send enquiry',
          onAction: _sendEnquiry,
        ),
      );
    }

    return Column(
      children: [
        ..._controller.enquiries.map(_enquiryCard),
        if (widget.onOpenEnquiries != null &&
            _controller.enquiryTotal > _controller.enquiries.length)
          Align(
            alignment: Alignment.center,
            child: TextButton(
              onPressed: widget.onOpenEnquiries,
              style: TextButton.styleFrom(
                foregroundColor: CoachTokens.brand,
              ),
              child: Text('View all ${_controller.enquiryTotal} enquiries'),
            ),
          ),
      ],
    );
  }

  Widget _enquiryCard(CoachEnquiry enquiry) {
    return CoachCard(
      margin: const EdgeInsets.only(bottom: CoachTokens.space3),
      accentColor: CoachTokens.statusColor(enquiry.statusLabel),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  enquiry.displayName,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: CoachTokens.textDark,
                  ),
                ),
              ),
              const SizedBox(width: CoachTokens.space2),
              CoachStatusChip(label: enquiry.statusLabel),
            ],
          ),
          if (enquiry.contactLabel.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              enquiry.contactLabel,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                color: CoachTokens.textBody,
              ),
            ),
          ],
          if (enquiry.contextLabel.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              enquiry.contextLabel,
              style: const TextStyle(
                fontSize: 12,
                color: CoachTokens.textMuted,
              ),
            ),
          ],
          if (enquiry.referenceNumber != null) ...[
            const SizedBox(height: CoachTokens.space2),
            Text(
              enquiry.referenceNumber!,
              style: const TextStyle(
                fontSize: 10.5,
                letterSpacing: 0.4,
                color: CoachTokens.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
