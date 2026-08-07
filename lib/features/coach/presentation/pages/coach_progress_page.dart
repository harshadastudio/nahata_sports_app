import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/coach_log.dart';
import '../../data/repositories/coach_dashboard_repository_impl.dart';
import '../../domain/entities/coach_option.dart';
import '../../domain/entities/coach_progress.dart';
import '../../domain/repositories/coach_dashboard_repository.dart';
import '../state/coach_progress_controller.dart';
import '../state/coach_view_state.dart';
import '../theme/coach_theme.dart';
import '../widgets/coach_progress_form_sheet.dart';
import '../widgets/coach_states.dart';

/// Student Progress — the assessment log, and recording new ones.
///
/// Each row is a **dated assessment**, not a student's current standing: the
/// same student appears once per assessment, and the improvement figure is the
/// change since their previous one for the same sport.
class CoachProgressPage extends StatefulWidget {
  const CoachProgressPage({super.key, this.repository});

  final CoachDashboardRepository? repository;

  @override
  State<CoachProgressPage> createState() => _CoachProgressPageState();
}

class _CoachProgressPageState extends State<CoachProgressPage> {
  late final CoachProgressController _controller = CoachProgressController(
    widget.repository ?? CoachDashboardRepositoryImpl(),
  );

  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _scroll.addListener(_onScroll);
    _controller.load();
    _controller.loadOptions();
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

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _record({CoachProgress? existing}) async {
    CoachLog.ui(existing == null
        ? 'Record assessment tapped'
        : 'Edit assessment ${existing.id}');

    final saved = await showCoachProgressFormSheet(
      context: context,
      students: _controller.students,
      sports: _controller.sports,
      existing: existing,
      onSubmit: (draft) => existing == null
          ? _controller.create(draft)
          : _controller.update(existing.id, draft),
    );

    if (!mounted || !saved) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(existing == null ? 'Assessment recorded' : 'Assessment updated'),
        backgroundColor: CoachTokens.success,
      ),
    );
  }

  Future<void> _delete(CoachProgress record) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CoachTokens.radiusMd),
        ),
        title: const Text(
          'Delete assessment?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          "${record.displayName}'s ${record.scoreLabel} assessment will be "
          'removed. This also changes the improvement figure on their next '
          'one.',
          style: const TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: CoachTokens.textMuted),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: CoachTokens.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _controller.delete(record.id);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Assessment deleted'),
          backgroundColor: CoachTokens.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Could not delete that assessment.',
          ),
          backgroundColor: CoachTokens.danger,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoachTokens.canvas,
      appBar: AppBar(
        backgroundColor: CoachTokens.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Student Progress',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: CoachRefreshLine(visible: _controller.refreshing),
        ),
      ),
      // Hidden rather than disabled when there is nobody to assess — the
      // backend requires both a student and a sport, so the form could not
      // succeed anyway.
      floatingActionButton: _controller.canRecord
          ? FloatingActionButton.extended(
              onPressed: () => _record(),
              backgroundColor: CoachTokens.brand,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Record'),
            )
          : null,
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
    // Nothing to filter by until the pickers land, and a failed picker load
    // must not leave two dead dropdowns on screen.
    if (!_controller.optionsState.isReady) return const SizedBox.shrink();

    return Container(
      color: CoachTokens.surface,
      padding: const EdgeInsets.fromLTRB(
        CoachTokens.space4,
        CoachTokens.space3,
        CoachTokens.space4,
        CoachTokens.space3,
      ),
      child: Row(
        children: [
          Expanded(
            child: _picker(
              label: 'Student',
              icon: Icons.person_outline_rounded,
              value: _controller.student,
              options: _controller.students,
              onChanged: _controller.setStudent,
            ),
          ),
          const SizedBox(width: CoachTokens.space3),
          Expanded(
            child: _picker(
              label: 'Sport',
              icon: Icons.sports_tennis_outlined,
              value: _controller.sport,
              options: _controller.sports,
              onChanged: _controller.setSport,
            ),
          ),
        ],
      ),
    );
  }

  Widget _picker({
    required String label,
    required IconData icon,
    required CoachOption? value,
    required List<CoachOption> options,
    required ValueChanged<CoachOption?> onChanged,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
          borderSide: BorderSide(color: color, width: width),
        );

    return DropdownButtonFormField<CoachOption>(
      initialValue: value,
      isExpanded: true,
      style: const TextStyle(fontSize: 13.5, color: CoachTokens.textDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(
          fontSize: 12.5,
          color: CoachTokens.textMuted,
        ),
        prefixIcon: Icon(icon, size: 18, color: CoachTokens.textMuted),
        filled: true,
        fillColor: CoachTokens.canvas,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: CoachTokens.space2,
          vertical: CoachTokens.space3 + 2,
        ),
        border: border(CoachTokens.border),
        enabledBorder: border(CoachTokens.border),
        focusedBorder: border(CoachTokens.brand, 1.4),
      ),
      items: [
        const DropdownMenuItem<CoachOption>(value: null, child: Text('All')),
        ...options.map(
          (o) => DropdownMenuItem(
            value: o,
            child: Text(o.displayName, overflow: TextOverflow.ellipsis),
          ),
        ),
      ],
      onChanged: onChanged,
    );
  }

  Widget _list() {
    if (_controller.state.isLoading && _controller.records.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(CoachTokens.space4),
        children: const [CoachListShimmer()],
      );
    }

    if (_controller.state.isFailed && _controller.records.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: CoachTokens.space8),
          CoachErrorView(
            message: _controller.error ?? 'Could not load assessments.',
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
          if (_controller.isFiltered)
            CoachEmptyView(
              icon: Icons.search_off_rounded,
              title: 'No matching assessments',
              message: 'Nothing recorded for that student and sport yet.',
              actionLabel: 'Clear filters',
              onAction: _controller.clearFilters,
            )
          else if (_controller.canRecord)
            CoachEmptyView(
              icon: Icons.trending_up_rounded,
              title: 'No assessments yet',
              message:
                  "Record one and it starts tracking each student's progress "
                  'over time.',
              actionLabel: 'Record assessment',
              onAction: () => _record(),
            )
          else
            const CoachEmptyView(
              icon: Icons.trending_up_rounded,
              title: 'Nobody to assess yet',
              message:
                  'Assessments need a student and a sport from your own '
                  'batches. Ask an admin to assign you a batch.',
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
        // Room for the FAB.
        CoachTokens.space8 + 56,
      ),
      itemCount: _controller.records.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) return _summary();
        if (index == _controller.records.length + 1) return _footer();
        return _recordCard(_controller.records[index - 1]);
      },
    );
  }

  Widget _summary() {
    final average = _controller.averageScore;

    return Padding(
      padding: const EdgeInsets.only(bottom: CoachTokens.space3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_controller.records.length} of ${_controller.total} '
              'assessment${_controller.total == 1 ? '' : 's'}'
              '${average == null ? '' : '  ·  avg ${average.round()}%'}',
              style: const TextStyle(
                fontSize: 12,
                color: CoachTokens.textMuted,
              ),
            ),
          ),
          if (_controller.improvedCount > 0)
            Padding(
              padding: const EdgeInsets.only(left: CoachTokens.space2),
              child: CoachStatusChip(
                label: '${_controller.improvedCount} up',
                color: CoachTokens.success,
                icon: Icons.arrow_upward_rounded,
              ),
            ),
          if (_controller.declinedCount > 0)
            Padding(
              padding: const EdgeInsets.only(left: CoachTokens.space2),
              child: CoachStatusChip(
                label: '${_controller.declinedCount} down',
                color: CoachTokens.danger,
                icon: Icons.arrow_downward_rounded,
              ),
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

  Widget _recordCard(CoachProgress record) {
    final score = record.currentScore.round();
    final tone = score >= 80
        ? CoachTokens.success
        : score >= 60
            ? CoachTokens.info
            : score >= 40
                ? CoachTokens.warning
                : CoachTokens.danger;

    return CoachCard(
      margin: const EdgeInsets.only(bottom: CoachTokens.space3),
      accentColor: tone,
      onTap: () => _record(existing: record),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoachAvatar(initial: record.initial, radius: 19, color: tone),
              const SizedBox(width: CoachTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.displayName,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: CoachTokens.textDark,
                      ),
                    ),
                    if (record.contextLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        record.contextLabel,
                        maxLines: 1,
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
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    record.scoreLabel,
                    style: TextStyle(
                      fontSize: 19,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: tone,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _improvement(record),
                ],
              ),
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 19,
                  color: CoachTokens.textMuted,
                ),
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  if (value == 'edit') _record(existing: record);
                  if (value == 'delete') _delete(record);
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          const SizedBox(height: CoachTokens.space3),
          Wrap(
            spacing: CoachTokens.space2,
            runSpacing: CoachTokens.space2,
            children: [
              if (record.skillLabel.isNotEmpty)
                CoachStatusChip(
                  label: record.skillLabel,
                  color: CoachTokens.purple,
                ),
              if (record.lastUpdated != null)
                CoachStatusChip(
                  label: _formatDate(record.lastUpdated!),
                  color: CoachTokens.textMuted,
                  icon: Icons.event_outlined,
                ),
            ],
          ),
          if ((record.notes ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: CoachTokens.space3),
            Text(
              record.notes!.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: CoachTokens.textBody,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _improvement(CoachProgress record) {
    // A first assessment has nothing to compare against — saying so is more
    // honest than showing "0", which would read as "no progress".
    if (record.isFirstAssessment) {
      return const Text(
        'First',
        style: TextStyle(fontSize: 11, color: CoachTokens.textMuted),
      );
    }

    final tone = record.improved
        ? CoachTokens.success
        : record.declined
            ? CoachTokens.danger
            : CoachTokens.textMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          record.improved
              ? Icons.arrow_upward_rounded
              : record.declined
                  ? Icons.arrow_downward_rounded
                  : Icons.remove_rounded,
          size: 12,
          color: tone,
        ),
        const SizedBox(width: 2),
        Text(
          record.improvementLabel ?? '0',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: tone,
          ),
        ),
      ],
    );
  }

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')} '
      '${_months[date.month - 1]} ${date.year}';
}
