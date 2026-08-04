import 'package:flutter/material.dart';

import '../../domain/entities/batch.dart';
import '../state/batches_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'admin_states.dart';
import 'batches_table.dart';
import 'glass_card.dart';
import 'occupancy_ring.dart';

/// `GET /batches/sport/{sportId}` — every batch of one sport, grouped by the
/// complex that runs it.
///
/// A separate route from the paginated list, and unpaginated, so this view
/// shows the sport's whole programme at once rather than a page of it.
class SportBatchesView extends StatelessWidget {
  const SportBatchesView({
    super.key,
    required this.controller,
    required this.onAction,
  });

  final BatchesController controller;
  final void Function(BatchAction action, AdminBatch batch) onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final sportId = controller.groupSportId;

    if (sportId == null) {
      return _Picker(
        icon: Icons.sports_tennis_outlined,
        title: 'Pick a sport',
        message:
            'Choose a sport to see every batch it runs, grouped by the complex '
            'that hosts them.',
        state: controller.sportsState,
        onReload: () => controller.loadSports(refresh: true),
        options: [
          for (final sport in controller.sports)
            (id: sport.id, label: sport.displayName),
        ],
        onSelect: controller.selectGroupSport,
      );
    }

    if (controller.sportGroupState.isLoading) {
      return const SingleChildScrollView(child: TableShimmer(rows: 6));
    }

    if (controller.sportGroupState.isFailed) {
      return ErrorStateView(
        title: 'Could not load this sport',
        message:
            controller.sportGroupError ??
            'The server did not return the batches for this sport.',
        onRetry: controller.loadSportGroup,
      );
    }

    final batches = controller.sportGroup;
    final sportName =
        controller.sportById(sportId)?.displayName ?? 'Sport #$sportId';

    if (batches.isEmpty) {
      return EmptyStateView(
        icon: Icons.event_busy_outlined,
        title: 'No batches for $sportName',
        message: 'This sport has no batches yet.',
        actionLabel: 'Pick another sport',
        onAction: () => controller.selectGroupSport(null),
      );
    }

    // Grouped by complex: the same sport at two venues is two programmes to
    // run, and the API's own ids keep them apart even when the names match.
    final groups = <String, List<AdminBatch>>{};
    for (final batch in batches) {
      final key =
          batch.sportComplexName?.trim().isNotEmpty == true
          ? batch.sportComplexName!.trim()
          : (batch.sportComplexId == null
                ? 'Unassigned'
                : 'Complex #${batch.sportComplexId}');
      groups.putIfAbsent(key, () => <AdminBatch>[]).add(batch);
    }

    final keys = groups.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

    return ListView(
      padding: const EdgeInsets.all(AdminTokens.space4),
      children: [
        _GroupHeader(
          title: sportName,
          subtitle:
              '${batches.length} batch${batches.length == 1 ? '' : 'es'} '
              'across ${keys.length} complex${keys.length == 1 ? '' : 'es'}',
          icon: Icons.sports_tennis_rounded,
          onChange: () => controller.selectGroupSport(null),
        ),
        const SizedBox(height: AdminTokens.space4),
        for (final key in keys) ...[
          _ComplexGroup(
            name: key,
            batches: groups[key]!,
            onAction: onAction,
            isBusy: controller.isRowBusy,
          ),
          const SizedBox(height: AdminTokens.space4),
        ],
        SizedBox(height: AdminTokens.space6, child: ColoredBox(color: tokens.canvas)),
      ],
    );
  }
}

class _ComplexGroup extends StatelessWidget {
  const _ComplexGroup({
    required this.name,
    required this.batches,
    required this.onAction,
    required this.isBusy,
  });

  final String name;
  final List<AdminBatch> batches;
  final void Function(BatchAction action, AdminBatch batch) onAction;
  final bool Function(int id) isBusy;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    final active = batches.where((batch) => batch.isActive).length;
    final students = batches.fold<int?>(null, (total, batch) {
      final current = batch.currentStudents;
      if (current == null) return total;
      return (total ?? 0) + current;
    });

    return SolidCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AdminTokens.space4),
            decoration: BoxDecoration(
              color: tokens.surfaceAlt,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AdminTokens.radiusLg),
              ),
              border: Border(bottom: BorderSide(color: tokens.border)),
            ),
            child: Row(
              children: [
                Icon(Icons.stadium_outlined, size: 17, color: tokens.accent),
                const SizedBox(width: AdminTokens.space2),
                Expanded(
                  child: Text(
                    name,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  '$active of ${batches.length} active · '
                  '${AdminFormat.number(students)} students',
                  style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          ...batches.map(
            (batch) => BatchCard(
              batch: batch,
              busy: isBusy(batch.id),
              onAction: onAction,
            ),
          ),
        ],
      ),
    );
  }
}

/// `GET /batches/coach/{coachId}` — one coach's whole load: how many batches,
/// how many students, and every schedule they work.
class CoachBatchesView extends StatelessWidget {
  const CoachBatchesView({
    super.key,
    required this.controller,
    required this.onAction,
  });

  final BatchesController controller;
  final void Function(BatchAction action, AdminBatch batch) onAction;

  @override
  Widget build(BuildContext context) {
    final coachId = controller.groupCoachId;

    if (coachId == null) {
      return _Picker(
        icon: Icons.sports_outlined,
        title: 'Pick a coach',
        message:
            'Choose a coach to see their batches, their total student load and '
            'the schedules they work.',
        state: controller.coachesState,
        onReload: () => controller.loadCoaches(refresh: true),
        options: [
          for (final coach in controller.coaches)
            (id: coach.id, label: coach.displayName),
        ],
        onSelect: controller.selectGroupCoach,
      );
    }

    if (controller.coachGroupState.isLoading) {
      return const SingleChildScrollView(child: TableShimmer(rows: 6));
    }

    if (controller.coachGroupState.isFailed) {
      return ErrorStateView(
        title: 'Could not load this coach',
        message:
            controller.coachGroupError ??
            'The server did not return the batches for this coach.',
        onRetry: controller.loadCoachGroup,
      );
    }

    final load = controller.coachGroup;
    final coachName =
        load?.coachName ??
        controller.coachById(coachId)?.displayName ??
        'Coach #$coachId';

    if (load == null || load.batches.isEmpty) {
      return EmptyStateView(
        icon: Icons.event_busy_outlined,
        title: 'No batches for $coachName',
        message: 'This coach is not assigned to any batch yet.',
        actionLabel: 'Pick another coach',
        onAction: () => controller.selectGroupCoach(null),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AdminTokens.space4),
      children: [
        _GroupHeader(
          title: coachName,
          subtitle:
              '${load.totalBatches} batch'
              '${load.totalBatches == 1 ? '' : 'es'} · '
              '${load.activeBatches} active',
          icon: Icons.sports_rounded,
          onChange: () => controller.selectGroupCoach(null),
        ),
        const SizedBox(height: AdminTokens.space4),
        _CoachLoadCard(load: load),
        const SizedBox(height: AdminTokens.space4),
        ...load.batches.map(
          (batch) => Padding(
            padding: const EdgeInsets.only(bottom: AdminTokens.space3),
            child: SolidCard(
              padding: EdgeInsets.zero,
              child: BatchCard(
                batch: batch,
                busy: controller.isRowBusy(batch.id),
                onAction: onAction,
              ),
            ),
          ),
        ),
        const SizedBox(height: AdminTokens.space6),
      ],
    );
  }
}

/// The coach's totals, plus every distinct schedule window they work.
class _CoachLoadCard extends StatelessWidget {
  const _CoachLoadCard({required this.load});

  final CoachBatchLoad load;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final schedules = load.schedules;

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              OccupancyRing(
                ratio: load.occupancy,
                size: 68,
                strokeWidth: 6,
                caption: load.maxStudents == null
                    ? null
                    : '${load.currentStudents ?? 0}/${load.maxStudents}',
              ),
              const SizedBox(width: AdminTokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Overall load',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      OccupancyRing.describe(load.occupancy),
                      style: TextStyle(
                        color: OccupancyRing.colorFor(context, load.occupancy),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Across ${load.totalBatches} batch'
                      '${load.totalBatches == 1 ? '' : 'es'}',
                      style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space4),
          Row(
            children: [
              Expanded(
                child: _Stat(
                  label: 'Total batches',
                  value: '${load.totalBatches}',
                  icon: Icons.groups_2_outlined,
                  color: tokens.accent,
                ),
              ),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                child: _Stat(
                  label: 'Current students',
                  value: AdminFormat.number(load.currentStudents),
                  icon: Icons.groups_outlined,
                  color: tokens.success,
                ),
              ),
            ],
          ),
          if (schedules.isNotEmpty) ...[
            const SizedBox(height: AdminTokens.space4),
            Text(
              'SCHEDULES',
              style: TextStyle(
                color: tokens.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AdminTokens.space2),
            Wrap(
              spacing: AdminTokens.space2,
              runSpacing: AdminTokens.space2,
              children: schedules
                  .map(
                    (schedule) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AdminTokens.space3,
                        vertical: AdminTokens.space2,
                      ),
                      decoration: BoxDecoration(
                        color: tokens.info.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(
                          AdminTokens.radiusPill,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.schedule_rounded,
                            size: 12,
                            color: tokens.info,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            schedule,
                            style: TextStyle(
                              color: tokens.info,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: AdminTokens.space2),
          Text(
            value,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 19,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

/// The header both grouped views share: what is being shown, and a way out.
class _GroupHeader extends StatelessWidget {
  const _GroupHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onChange,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
            color: tokens.accentSoft,
          ),
          child: Icon(icon, size: 20, color: tokens.accent),
        ),
        const SizedBox(width: AdminTokens.space3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                subtitle,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
              ),
            ],
          ),
        ),
        OutlinedButton.icon(
          onPressed: onChange,
          icon: const Icon(Icons.swap_horiz_rounded, size: 17),
          label: const Text('Change'),
        ),
      ],
    );
  }
}

/// The "nothing picked yet" state both grouped views start in.
class _Picker extends StatelessWidget {
  const _Picker({
    required this.icon,
    required this.title,
    required this.message,
    required this.state,
    required this.onReload,
    required this.options,
    required this.onSelect,
  });

  final IconData icon;
  final String title;
  final String message;
  final ViewState state;
  final VoidCallback onReload;
  final List<({int id, String label})> options;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    if (state.isLoading && options.isEmpty) {
      return const SingleChildScrollView(child: TableShimmer(rows: 4));
    }

    if (options.isEmpty) {
      return ErrorStateView(
        title: 'Nothing to choose from',
        message:
            'The list this view needs could not be loaded. Try again in a '
            'moment.',
        onRetry: onReload,
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AdminTokens.space6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tokens.accentSoft,
            ),
            child: Icon(icon, size: 26, color: tokens.accent),
          ),
          const SizedBox(height: AdminTokens.space4),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AdminTokens.space2),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: tokens.textMuted,
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: AdminTokens.space5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: AdminTokens.space2,
              runSpacing: AdminTokens.space2,
              children: options
                  .map(
                    (option) => OutlinedButton(
                      onPressed: () => onSelect(option.id),
                      child: Text(option.label),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
