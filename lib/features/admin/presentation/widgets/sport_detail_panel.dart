import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/sport.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'admin_states.dart';
import 'glass_card.dart';
import 'sports_table.dart';

/// The right-side sport detail panel.
///
/// Shows the row already in hand immediately, then fills in from
/// `GET /sports/{id}` and `/{id}/stats` behind a thin progress line. The two
/// reads are tracked separately: a stats failure leaves a note in the
/// Statistics card rather than blanking a drawer whose detail arrived fine.
class SportDetailPanel extends StatelessWidget {
  const SportDetailPanel({
    super.key,
    required this.sport,
    required this.state,
    required this.error,
    required this.stats,
    required this.statsState,
    required this.onClose,
    required this.onAction,
    required this.onRetry,
    required this.onRetryStats,
    required this.onToggleVisibility,
    required this.busy,
    this.showCloseButton = true,
  });

  final Sport sport;
  final ViewState state;
  final String? error;
  final SportStats? stats;
  final ViewState statsState;
  final VoidCallback onClose;
  final void Function(SportAction action, Sport sport) onAction;
  final VoidCallback onRetry;
  final VoidCallback onRetryStats;
  final void Function(Sport sport, bool showOnFrontend) onToggleVisibility;
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
                  'Sport details',
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
                  title: 'Could not load this sport',
                  message: error ?? 'Please try again.',
                  onRetry: onRetry,
                )
              : ListView(
                  padding: const EdgeInsets.all(AdminTokens.space5),
                  children: [
                    _HeroCard(
                      sport: sport,
                      busy: busy,
                      onToggleVisibility: onToggleVisibility,
                    ),
                    const SizedBox(height: AdminTokens.space4),
                    _StatisticsCard(
                      sport: sport,
                      stats: stats,
                      statsState: statsState,
                      onRetryStats: onRetryStats,
                    ),
                    const SizedBox(height: AdminTokens.space4),
                    _RowsCard(
                      icon: Icons.fitness_center_rounded,
                      title: 'Training details',
                      rows: [
                        _Row('Minimum age', _age(sport.minAge)),
                        _Row('Maximum age', _age(sport.maxAge)),
                        _Row(
                          'Session duration',
                          AdminFormat.text(sport.duration),
                        ),
                        _Row(
                          'Allowed members',
                          AdminFormat.number(sport.allowedMembers),
                        ),
                      ],
                    ),
                    if ((sport.equipmentRequired ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: AdminTokens.space4),
                      _ProseCard(
                        icon: Icons.sports_handball_outlined,
                        title: 'Equipment required',
                        body: sport.equipmentRequired!.trim(),
                      ),
                    ],
                    if ((sport.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: AdminTokens.space4),
                      _ProseCard(
                        icon: Icons.notes_rounded,
                        title: 'Description',
                        body: sport.description!.trim(),
                      ),
                    ],
                    if ((sport.achievements ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: AdminTokens.space4),
                      _ProseCard(
                        icon: Icons.emoji_events_outlined,
                        title: 'Achievements',
                        body: sport.achievements!.trim(),
                      ),
                    ],
                    if ((sport.completeInformation ?? '')
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: AdminTokens.space4),
                      _ProseCard(
                        icon: Icons.menu_book_outlined,
                        title: 'Complete information',
                        body: sport.completeInformation!.trim(),
                      ),
                    ],
                    if (sport.programNames.isNotEmpty) ...[
                      const SizedBox(height: AdminTokens.space4),
                      _ProgramsCard(sport: sport),
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
                  onPressed: () => onAction(SportAction.delete, sport),
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
                  onPressed: () => onAction(SportAction.edit, sport),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit sport'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _age(int? value) => value == null ? AdminFormat.dash : '$value';
}

/// Basic information: the photo, the name, the complex, and the two state
/// controls.
class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.sport,
    required this.busy,
    required this.onToggleVisibility,
  });

  final Sport sport;
  final bool busy;
  final void Function(Sport sport, bool showOnFrontend) onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final url = sport.imageUrl;

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
                  ? _ImageFallback(sport: sport)
                  : CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _ImageFallback(sport: sport),
                      errorWidget: (_, __, ___) => _ImageFallback(sport: sport),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AdminTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sport.displayName,
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
                        AdminFormat.text(sport.sportComplexName),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AdminTokens.space4),
                Wrap(
                  spacing: AdminTokens.space2,
                  runSpacing: AdminTokens.space2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SportStatusBadge(sport: sport),
                    SportCategoryChip(sport: sport, dense: false),
                  ],
                ),
                const SizedBox(height: AdminTokens.space4),
                Row(
                  children: [
                    Text(
                      'Show on frontend',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    SportVisibilitySwitch(
                      sport: sport,
                      busy: busy,
                      showLabel: false,
                      onChanged: (value) => onToggleVisibility(sport, value),
                    ),
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
  const _ImageFallback({required this.sport});

  final Sport sport;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final gradient = tokens.avatarGradient('${sport.id}${sport.name ?? ''}');

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
        Icons.sports_tennis_rounded,
        size: 40,
        color: Colors.white.withValues(alpha: 0.85),
      ),
    );
  }
}

/// The four counters from `/sports/{id}/stats`.
class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({
    required this.sport,
    required this.stats,
    required this.statsState,
    required this.onRetryStats,
  });

  final Sport sport;
  final SportStats? stats;
  final ViewState statsState;
  final VoidCallback onRetryStats;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    // The stats route is authoritative; the list row's own counters are the
    // fallback when it has not answered.
    final totalPrograms = stats?.totalPrograms ?? sport.programCount;
    final activePrograms = stats?.activePrograms;
    final totalCourts = stats?.totalCourts ?? sport.courtCount;
    final totalStudents = stats?.totalStudents;

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
          const SizedBox(height: AdminTokens.space3),
          Row(
            children: [
              Expanded(
                child: _Counter(
                  label: 'Total programs',
                  value: totalPrograms,
                  icon: Icons.school_outlined,
                  color: tokens.info,
                ),
              ),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                child: _Counter(
                  label: 'Active programs',
                  value: activePrograms,
                  icon: Icons.play_circle_outline_rounded,
                  color: tokens.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          Row(
            children: [
              Expanded(
                child: _Counter(
                  label: 'Total courts',
                  value: totalCourts,
                  icon: Icons.grid_view_rounded,
                  color: tokens.accent,
                ),
              ),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                child: _Counter(
                  label: 'Total students',
                  value: totalStudents,
                  icon: Icons.groups_outlined,
                  color: tokens.warning,
                ),
              ),
            ],
          ),
          if (statsState.isFailed) ...[
            const SizedBox(height: AdminTokens.space3),
            Text(
              'Statistics are unavailable right now — any figures above come '
              'from the sport record itself.',
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
  final int? value;
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
            AdminFormat.number(value),
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

/// The programme names the list payload carried, as chips.
class _ProgramsCard extends StatelessWidget {
  const _ProgramsCard({required this.sport});

  final Sport sport;

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
              Icon(Icons.school_outlined, size: 17, color: tokens.accent),
              const SizedBox(width: AdminTokens.space2),
              Text(
                'Programs',
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
            children: sport.programNames
                .map(
                  (program) => Container(
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
                      program,
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

/// A card for one of the long free-text fields.
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
