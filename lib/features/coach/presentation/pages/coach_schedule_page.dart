import 'package:flutter/material.dart';

import '../../data/repositories/coach_dashboard_repository_impl.dart';
import '../../domain/entities/coach_batch.dart';
import '../../domain/repositories/coach_dashboard_repository.dart';
import '../state/coach_schedule_controller.dart';
import '../state/coach_view_state.dart';
import '../theme/coach_theme.dart';
import '../widgets/coach_states.dart';

/// My Schedule — the coach's batches with their days, timings and capacity.
///
/// The backend has no per-session table, so this is batches rather than a
/// calendar: the day and time are whatever free text the admin typed on the
/// batch, and the court is always the `"TBD"` placeholder.
class CoachSchedulePage extends StatefulWidget {
  const CoachSchedulePage({super.key, this.repository});

  final CoachDashboardRepository? repository;

  @override
  State<CoachSchedulePage> createState() => _CoachSchedulePageState();
}

class _CoachSchedulePageState extends State<CoachSchedulePage> {
  late final CoachScheduleController _controller = CoachScheduleController(
    widget.repository ?? CoachDashboardRepositoryImpl(),
  );

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _scroll.addListener(_onScroll);
    _controller.load();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final remaining = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 400) _controller.loadMore();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
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
          'My Schedule',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: CoachRefreshLine(visible: _controller.refreshing),
        ),
      ),
      body: Column(
        children: [
          _filters(),
          Expanded(
            child: RefreshIndicator(
              color: CoachTokens.brand,
              onRefresh: _controller.refresh,
              child: _list(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    return Container(
      color: CoachTokens.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: CoachTokens.space4,
        vertical: CoachTokens.space2,
      ),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            for (final status in CoachScheduleController.statusFilters)
              Padding(
                padding: const EdgeInsets.only(right: CoachTokens.space2),
                child: FilterChip(
                  label: Text(status),
                  selected: _controller.status == status,
                  onSelected: (_) => _controller.setStatus(status),
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _controller.status == status
                        ? CoachTokens.brand
                        : CoachTokens.textBody,
                  ),
                  backgroundColor: CoachTokens.canvas,
                  selectedColor: CoachTokens.brandSoft,
                  side: BorderSide(
                    color: _controller.status == status
                        ? CoachTokens.brand
                        : CoachTokens.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CoachTokens.radiusPill),
                  ),
                ),
              ),
            if (_controller.isFiltered)
              TextButton.icon(
                onPressed: _controller.clearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                label: const Text('Clear'),
                style: TextButton.styleFrom(
                  foregroundColor: CoachTokens.textMuted,
                  textStyle: const TextStyle(fontSize: 12.5),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _list() {
    if (_controller.state.isLoading && _controller.batches.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(CoachTokens.space4),
        children: const [CoachListShimmer(rows: 4)],
      );
    }

    if (_controller.state.isFailed && _controller.batches.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: CoachTokens.space8),
          CoachErrorView(
            message: _controller.error ?? 'Could not load your schedule.',
            onRetry: _controller.load,
          ),
        ],
      );
    }

    if (_controller.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: CoachTokens.space8),
          _controller.isFiltered
              ? CoachEmptyView(
                  icon: Icons.search_off_rounded,
                  title: 'No matching batches',
                  message: 'No batch of yours has that status.',
                  actionLabel: 'Clear filters',
                  onAction: _controller.clearFilters,
                )
              : const CoachEmptyView(
                  icon: Icons.event_note_outlined,
                  title: 'No batches assigned',
                  message:
                      'Batches you run will show up here with their days and '
                      'timings. Ask an admin to assign you one.',
                ),
        ],
      );
    }

    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        CoachTokens.space4,
        CoachTokens.space3,
        CoachTokens.space4,
        CoachTokens.space8,
      ),
      itemCount: _controller.batches.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) return _summary();
        if (index == _controller.batches.length + 1) return _footer();
        return _batchCard(_controller.batches[index - 1]);
      },
    );
  }

  Widget _summary() {
    return Padding(
      padding: const EdgeInsets.only(bottom: CoachTokens.space3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_controller.total} batch'
              '${_controller.total == 1 ? '' : 'es'}'
              '  ·  ${_controller.totalStudents} student'
              '${_controller.totalStudents == 1 ? '' : 's'}',
              style: const TextStyle(
                fontSize: 12,
                color: CoachTokens.textMuted,
              ),
            ),
          ),
          if (_controller.activeCount > 0)
            CoachStatusChip(
              label: '${_controller.activeCount} active',
              color: CoachTokens.success,
            ),
        ],
      ),
    );
  }

  Widget _footer() {
    if (_controller.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: CoachTokens.space5),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: CoachTokens.brand,
            ),
          ),
        ),
      );
    }

    if (_controller.error != null && _controller.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: CoachTokens.space4),
        child: Center(
          child: TextButton.icon(
            onPressed: _controller.loadMore,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Load more'),
            style: TextButton.styleFrom(foregroundColor: CoachTokens.brand),
          ),
        ),
      );
    }

    return const SizedBox(height: CoachTokens.space4);
  }

  Widget _batchCard(CoachBatch batch) {
    final ratio = batch.fillRatio;
    final tone = CoachTokens.statusColor(batch.statusLabel);

    return CoachCard(
      margin: const EdgeInsets.only(bottom: CoachTokens.space3),
      accentColor: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      batch.displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: CoachTokens.textDark,
                      ),
                    ),
                    if ((batch.sportName ?? '').isNotEmpty &&
                        batch.sportName!.toUpperCase() != 'N/A') ...[
                      const SizedBox(height: 2),
                      Text(
                        batch.sportName!,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: CoachTokens.textBody,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: CoachTokens.space2),
              CoachStatusChip(label: batch.statusLabel, color: tone),
            ],
          ),
          if (batch.timingLabel.isNotEmpty) ...[
            const SizedBox(height: CoachTokens.space3),
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 15,
                  color: CoachTokens.textMuted,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    batch.timingLabel,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: CoachTokens.textBody,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: CoachTokens.space3),
          Row(
            children: [
              const Icon(
                Icons.people_outline_rounded,
                size: 15,
                color: CoachTokens.textMuted,
              ),
              const SizedBox(width: 6),
              Text(
                batch.capacityLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: batch.isFull
                      ? CoachTokens.warning
                      : CoachTokens.textBody,
                ),
              ),
              if (batch.isFull) ...[
                const SizedBox(width: CoachTokens.space2),
                const CoachStatusChip(
                  label: 'Full',
                  color: CoachTokens.warning,
                ),
              ],
              const Spacer(),
              if (batch.fees > 0)
                Text(
                  '₹${batch.fees.round()}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: CoachTokens.textDark,
                  ),
                ),
            ],
          ),
          // Only drawn for a capped batch — a bar with no denominator would be
          // meaningless.
          if (ratio != null) ...[
            const SizedBox(height: CoachTokens.space2 + 2),
            ClipRRect(
              borderRadius: BorderRadius.circular(CoachTokens.radiusPill),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 5,
                backgroundColor: CoachTokens.canvas,
                valueColor: AlwaysStoppedAnimation(
                  batch.isFull ? CoachTokens.warning : CoachTokens.brand,
                ),
              ),
            ),
          ],
          if (batch.startDate != null || batch.endDate != null) ...[
            const SizedBox(height: CoachTokens.space3),
            Text(
              _runLabel(batch),
              style: const TextStyle(
                fontSize: 11.5,
                color: CoachTokens.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _runLabel(CoachBatch batch) {
    final from = batch.startDate;
    final to = batch.endDate;

    if (from != null && to != null) {
      return '${_formatDate(from)} → ${_formatDate(to)}';
    }
    if (from != null) return 'From ${_formatDate(from)}';
    return 'Until ${_formatDate(to!)}';
  }

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// `06 Aug 2026`. Formatted by hand rather than through `intl` so the coach
  /// screens do not depend on a locale being initialised.
  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')} '
      '${_months[date.month - 1]} ${date.year}';
}
