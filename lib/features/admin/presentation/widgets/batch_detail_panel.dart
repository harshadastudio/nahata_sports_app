import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/batch.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'admin_states.dart';
import 'batches_table.dart';
import 'glass_card.dart';
import 'occupancy_ring.dart';

/// The right-side batch detail panel.
///
/// Shows the row already in hand immediately, then fills in from
/// `GET /batches/{id}` and `/{id}/stats` behind a thin progress line. The two
/// reads are tracked separately: a stats failure leaves a note in the
/// Statistics card rather than blanking a drawer whose detail arrived fine.
class BatchDetailPanel extends StatelessWidget {
  const BatchDetailPanel({
    super.key,
    required this.batch,
    required this.state,
    required this.error,
    required this.stats,
    required this.statsState,
    required this.onClose,
    required this.onAction,
    required this.onRetry,
    required this.onRetryStats,
    required this.busy,
    this.showCloseButton = true,
  });

  final AdminBatch batch;
  final ViewState state;
  final String? error;
  final BatchStatistics? stats;
  final ViewState statsState;
  final VoidCallback onClose;
  final void Function(BatchAction action, AdminBatch batch) onAction;
  final VoidCallback onRetry;
  final VoidCallback onRetryStats;
  final bool busy;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(
            AdminTokens.space5,
            AdminTokens.space4,
            AdminTokens.space3,
            AdminTokens.space4,
          ),
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border(bottom: BorderSide(color: tokens.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Batch details',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (showCloseButton)
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Close',
                  color: tokens.textMuted,
                ),
            ],
          ),
        ),
        RefreshLine(visible: state.isLoading),
        Expanded(
          child: state.isFailed
              ? ErrorStateView(
                  compact: true,
                  title: 'Could not load this batch',
                  message: error ?? 'Please try again.',
                  onRetry: onRetry,
                )
              : ListView(
                  padding: const EdgeInsets.all(AdminTokens.space5),
                  children: [
                    _HeroCard(batch: batch, busy: busy),
                    const SizedBox(height: AdminTokens.space4),
                    _StatisticsCard(
                      batch: batch,
                      stats: stats,
                      statsState: statsState,
                      onRetryStats: onRetryStats,
                    ),
                    const SizedBox(height: AdminTokens.space4),
                    _RowsCard(
                      icon: Icons.info_outline_rounded,
                      title: 'General information',
                      rows: [
                        _Row('Sport', AdminFormat.text(batch.sportName)),
                        _Row('Coach', AdminFormat.text(batch.coachName)),
                        _Row(
                          'Sports complex',
                          AdminFormat.text(batch.sportComplexName),
                        ),
                        _Row('Schedule', batch.scheduleLabel),
                        _Row('Days', batch.daysLabel),
                        _Row('Start date', AdminFormat.date(batch.startDate)),
                        _Row('End date', AdminFormat.date(batch.endDate)),
                        _Row('Age group', AdminFormat.text(batch.ageGroup)),
                        _Row('Duration', AdminFormat.text(batch.duration)),
                      ],
                    ),
                    const SizedBox(height: AdminTokens.space4),
                    _RowsCard(
                      icon: Icons.event_seat_outlined,
                      title: 'Students and fees',
                      rows: [
                        _Row(
                          'Maximum students',
                          AdminFormat.number(batch.maxStudents),
                        ),
                        _Row(
                          'Current students',
                          AdminFormat.number(batch.currentStudents),
                        ),
                        _Row(
                          'Available seats',
                          AdminFormat.number(batch.availableSeats),
                        ),
                        _Row('Fees', AdminFormat.currency(batch.fees)),
                      ],
                    ),
                    if (batch.features.isNotEmpty) ...[
                      const SizedBox(height: AdminTokens.space4),
                      _FeaturesCard(features: batch.features),
                    ],
                    if ((batch.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: AdminTokens.space4),
                      _ProseCard(
                        icon: Icons.notes_rounded,
                        title: 'Description',
                        body: batch.description!.trim(),
                      ),
                    ],
                    const SizedBox(height: AdminTokens.space6),
                  ],
                ),
        ),
        Container(
          padding: const EdgeInsets.all(AdminTokens.space4),
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border(top: BorderSide(color: tokens.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onAction(BatchAction.delete, batch),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.danger,
                    side: BorderSide(
                      color: tokens.danger.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => onAction(BatchAction.edit, batch),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit batch'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The photo, the name, the assignment and the occupancy ring.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.batch, required this.busy});

  final AdminBatch batch;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final url = batch.imageUrl;

    return SolidCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AdminTokens.radiusLg),
            ),
            child: SizedBox(
              height: 150,
              child: url == null
                  ? _ImageFallback(batch: batch)
                  : CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _ImageFallback(batch: batch),
                      errorWidget: (_, __, ___) => _ImageFallback(batch: batch),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AdminTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            batch.displayName,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Icon(
                                Icons.stadium_outlined,
                                size: 13,
                                color: tokens.textMuted,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  AdminFormat.text(batch.sportComplexName),
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: tokens.textMuted,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AdminTokens.space3),
                    OccupancyRing(
                      ratio: batch.occupancy,
                      size: 58,
                      caption: batch.maxStudents == null
                          ? null
                          : '${batch.currentStudents ?? 0}/'
                                '${batch.maxStudents}',
                    ),
                  ],
                ),
                const SizedBox(height: AdminTokens.space4),
                Wrap(
                  spacing: AdminTokens.space2,
                  runSpacing: AdminTokens.space2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (busy)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      BatchStatusBadge(batch: batch),
                    BatchDaysChip(batch: batch),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.batch});

  final AdminBatch batch;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final gradient = tokens.avatarGradient('${batch.id}${batch.name ?? ''}');

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Icon(
        Icons.groups_2_rounded,
        size: 40,
        color: Colors.white.withValues(alpha: 0.85),
      ),
    );
  }
}

/// The counters from `/batches/{id}/stats`, led by the occupancy ring the spec
/// asks for.
class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({
    required this.batch,
    required this.stats,
    required this.statsState,
    required this.onRetryStats,
  });

  final AdminBatch batch;
  final BatchStatistics? stats;
  final ViewState statsState;
  final VoidCallback onRetryStats;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    // The stats route is authoritative; the row's own counters are the fallback
    // when it has not answered.
    final maxStudents = stats?.maxStudents ?? batch.maxStudents;
    final currentStudents = stats?.currentStudents ?? batch.currentStudents;
    final enrolled = stats?.enrolledStudents;
    final available = stats?.availableSlots ?? batch.availableSeats;
    final occupancy = stats?.occupancy ?? batch.occupancy;
    final fees = stats?.fees ?? batch.fees;

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_outlined, size: 17, color: tokens.accent),
              const SizedBox(width: AdminTokens.space2),
              Expanded(
                child: Text(
                  'Statistics',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (statsState.isLoading)
                const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (statsState.isFailed)
                TextButton(
                  onPressed: onRetryStats,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Retry stats',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AdminTokens.space4),
          Row(
            children: [
              OccupancyRing(ratio: occupancy, size: 78, strokeWidth: 7),
              const SizedBox(width: AdminTokens.space4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Occupancy',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      OccupancyRing.describe(occupancy),
                      style: TextStyle(
                        color: OccupancyRing.colorFor(context, occupancy),
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${AdminFormat.number(currentStudents)} of '
                      '${AdminFormat.number(maxStudents)} seats taken',
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
                child: _Counter(
                  label: 'Max students',
                  value: AdminFormat.number(maxStudents),
                  icon: Icons.event_seat_outlined,
                  color: tokens.info,
                ),
              ),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                child: _Counter(
                  label: 'Current students',
                  value: AdminFormat.number(currentStudents),
                  icon: Icons.groups_outlined,
                  color: tokens.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          Row(
            children: [
              Expanded(
                child: _Counter(
                  label: 'Enrolled students',
                  value: AdminFormat.number(enrolled),
                  icon: Icons.how_to_reg_outlined,
                  color: tokens.success,
                ),
              ),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                child: _Counter(
                  label: 'Available slots',
                  value: AdminFormat.number(available),
                  icon: Icons.chair_alt_outlined,
                  color: tokens.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          Row(
            children: [
              Expanded(
                child: _Counter(
                  label: 'Fees',
                  value: AdminFormat.currency(fees),
                  icon: Icons.currency_rupee_rounded,
                  color: const Color(0xFF3949AB),
                ),
              ),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                child: _Counter(
                  label: 'Status',
                  value: batch.statusLabel.isEmpty
                      ? AdminFormat.dash
                      : batch.statusLabel,
                  icon: Icons.toggle_on_outlined,
                  color: tokens.statusColor(batch.status),
                ),
              ),
            ],
          ),
          if (statsState.isFailed) ...[
            const SizedBox(height: AdminTokens.space3),
            Text(
              'Statistics are unavailable right now — any figures above come '
              'from the batch record itself.',
              style: TextStyle(
                color: tokens.textMuted,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
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
            // A missing counter reads as an em dash, never as zero.
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 17,
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

class _FeaturesCard extends StatelessWidget {
  const _FeaturesCard({required this.features});

  final List<String> features;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist_rounded, size: 17, color: tokens.accent),
              const SizedBox(width: AdminTokens.space2),
              Text(
                'Features',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          Wrap(
            spacing: AdminTokens.space2,
            runSpacing: AdminTokens.space2,
            children: features
                .map(
                  (feature) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AdminTokens.space3,
                      vertical: AdminTokens.space2,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.accentSoft,
                      borderRadius: BorderRadius.circular(
                        AdminTokens.radiusPill,
                      ),
                    ),
                    child: Text(
                      feature,
                      style: TextStyle(
                        color: tokens.accent,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _RowsCard extends StatelessWidget {
  const _RowsCard({
    required this.icon,
    required this.title,
    this.rows = const [],
  });

  final IconData icon;
  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: tokens.accent),
              const SizedBox(width: AdminTokens.space2),
              Text(
                title,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: AdminTokens.space3),
            ...rows,
          ],
        ],
      ),
    );
  }
}

class _ProseCard extends StatelessWidget {
  const _ProseCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: tokens.accent),
              const SizedBox(width: AdminTokens.space2),
              Text(
                title,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          // Line breaks the admin typed are preserved rather than collapsed.
          Text(
            body,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 12.5,
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: value == AdminFormat.dash
                    ? tokens.textMuted
                    : tokens.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
