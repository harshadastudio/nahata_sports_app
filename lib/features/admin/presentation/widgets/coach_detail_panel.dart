import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/coach.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'admin_states.dart';
import 'coaches_table.dart';
import 'glass_card.dart';

/// The right-side coach detail panel.
///
/// Shows the row already in hand immediately, then fills in from
/// `GET /coaches/{id}` and `/{id}/stats` behind a thin progress line. Both
/// reads are non-blocking on purpose: `/{id}` is not part of the documented
/// module, so its failure leaves a note above the profile rather than blanking
/// a drawer that already has every column the table showed, and a stats failure
/// leaves its own note inside the Statistics card.
class CoachDetailPanel extends StatelessWidget {
  const CoachDetailPanel({
    super.key,
    required this.coach,
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

  final Coach coach;
  final ViewState state;

  /// Set when `GET /coaches/{id}` failed — shown as a note, not an error page.
  final String? error;

  final CoachStats? stats;
  final ViewState statsState;
  final VoidCallback onClose;
  final void Function(CoachAction action, Coach coach) onAction;
  final VoidCallback onRetry;
  final VoidCallback onRetryStats;
  final bool busy;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final availability = coach.availability;

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
                  'Coach details',
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
          child: ListView(
            padding: const EdgeInsets.all(AdminTokens.space5),
            children: [
              if (error != null) ...[
                _PartialNote(message: error!, onRetry: onRetry),
                const SizedBox(height: AdminTokens.space4),
              ],
              _ProfileCard(coach: coach, busy: busy),
              const SizedBox(height: AdminTokens.space4),
              _StatisticsCard(
                stats: stats,
                statsState: statsState,
                onRetryStats: onRetryStats,
              ),
              const SizedBox(height: AdminTokens.space4),
              _SportsCard(coach: coach),
              const SizedBox(height: AdminTokens.space4),
              _RowsCard(
                icon: Icons.workspace_premium_outlined,
                title: 'Professional information',
                rows: [
                  _Row('Experience', AdminFormat.text(coach.experience)),
                  _Row('Certification', AdminFormat.text(coach.certification)),
                  _Row('Qualification', AdminFormat.text(coach.qualifications)),
                  _Row(
                    'Specialization',
                    AdminFormat.text(coach.specialization),
                  ),
                  _Row('Price', AdminFormat.currency(coach.price)),
                ],
              ),
              const SizedBox(height: AdminTokens.space4),
              _AvailabilityCard(availability: availability),
              if ((coach.bio ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: AdminTokens.space4),
                _ProseCard(
                  icon: Icons.notes_rounded,
                  title: 'Biography',
                  body: coach.bio!.trim(),
                ),
              ],
              const SizedBox(height: AdminTokens.space4),
              _CredentialsCard(coach: coach, onAction: onAction),
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
                  onPressed: () => onAction(CoachAction.delete, coach),
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
                  onPressed: () => onAction(CoachAction.edit, coach),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit coach'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The `/coaches/{id}` read failed — the drawer keeps the list row and says so.
class _PartialNote extends StatelessWidget {
  const _PartialNote({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space3),
      decoration: BoxDecoration(
        color: tokens.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: tokens.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 17, color: tokens.warning),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              'Showing what the list returned — the full record could not be '
              'loaded. $message',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('Retry', style: TextStyle(fontSize: 11.5)),
          ),
        ],
      ),
    );
  }
}

/// Profile: photo, name, contact details and status.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.coach, required this.busy});

  final Coach coach;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final url = coach.imageUrl;

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
                  ? _ImageFallback(coach: coach)
                  : CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _ImageFallback(coach: coach),
                      errorWidget: (_, __, ___) => _ImageFallback(coach: coach),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AdminTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  coach.displayName,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: AdminTokens.space3),
                _IconLine(
                  icon: Icons.mail_outline_rounded,
                  value: AdminFormat.text(coach.email),
                ),
                const SizedBox(height: 4),
                _IconLine(
                  icon: Icons.phone_outlined,
                  value: AdminFormat.text(coach.phone),
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
                      CoachStatusBadge(coach: coach),
                    if ((coach.categoryRaw ?? '').trim().isNotEmpty)
                      CoachCategoryChip(coach: coach, dense: false),
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

class _IconLine extends StatelessWidget {
  const _IconLine({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Row(
      children: [
        Icon(icon, size: 13, color: tokens.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: value == AdminFormat.dash
                  ? tokens.textMuted
                  : tokens.textSecondary,
              fontSize: 12.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.coach});

  final Coach coach;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final gradient = tokens.avatarGradient('${coach.id}${coach.name ?? ''}');

    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        coach.initials,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: 40,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Sports information: the assignment, plus every assigned sport as a chip.
class _SportsCard extends StatelessWidget {
  const _SportsCard({required this.coach});

  final Coach coach;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final sports = coach.allSportNames;

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sports_tennis_outlined,
                size: 17,
                color: tokens.accent,
              ),
              const SizedBox(width: AdminTokens.space2),
              Text(
                'Sports information',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          _Row('Primary sport', AdminFormat.text(coach.sportName)),
          _Row('Category', coach.categoryLabel),
          _Row('Sports complex', AdminFormat.text(coach.sportComplexName)),
          _Row('Ground', AdminFormat.text(coach.ground)),
          // Only rendered when the payload listed more than the primary sport,
          // so a single-sport coach does not get a chip row repeating the line
          // directly above it.
          if (sports.length > 1) ...[
            const SizedBox(height: AdminTokens.space3),
            Wrap(
              spacing: AdminTokens.space2,
              runSpacing: AdminTokens.space2,
              children: sports
                  .map(
                    (sport) => Container(
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
                        sport,
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
        ],
      ),
    );
  }
}

/// The schedule, as day chips when it can be read and as written when it cannot.
class _AvailabilityCard extends StatelessWidget {
  const _AvailabilityCard({required this.availability});

  final CoachAvailability availability;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final today = Weekday.of(DateTime.now());

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_month_outlined,
                size: 17,
                color: tokens.accent,
              ),
              const SizedBox(width: AdminTokens.space2),
              Expanded(
                child: Text(
                  'Availability',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                availability.summaryLabel,
                style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          if (availability.isEmpty)
            Text(
              'No schedule recorded for this coach.',
              style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
            )
          else if (availability.isCustom)
            Text(
              availability.raw,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 12.5,
                height: 1.55,
                fontWeight: FontWeight.w500,
              ),
            )
          else
            Wrap(
              spacing: AdminTokens.space2,
              runSpacing: AdminTokens.space2,
              children: Weekday.values.map((day) {
                final on = availability.days.contains(day);
                final isToday = day == today;
                final color = on ? tokens.success : tokens.textMuted;

                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AdminTokens.space3,
                    vertical: AdminTokens.space2,
                  ),
                  decoration: BoxDecoration(
                    color: on
                        ? color.withValues(alpha: 0.12)
                        : tokens.surfaceAlt,
                    borderRadius: BorderRadius.circular(
                      AdminTokens.radiusPill,
                    ),
                    // Today is outlined whether or not the coach works it, so
                    // the card answers "are they in today?" at a glance.
                    border: Border.all(
                      color: isToday
                          ? color.withValues(alpha: on ? 0.6 : 0.35)
                          : Colors.transparent,
                    ),
                  ),
                  child: Text(
                    day.shortLabel,
                    style: TextStyle(
                      color: color,
                      fontSize: 11.5,
                      fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

/// The counters from `/coaches/{id}/stats`.
class _StatisticsCard extends StatelessWidget {
  const _StatisticsCard({
    required this.stats,
    required this.statsState,
    required this.onRetryStats,
  });

  final CoachStats? stats;
  final ViewState statsState;
  final VoidCallback onRetryStats;

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
                  value: stats?.totalPrograms,
                  icon: Icons.school_outlined,
                  color: tokens.info,
                ),
              ),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                child: _Counter(
                  label: 'Active programs',
                  value: stats?.activePrograms,
                  icon: Icons.play_circle_outline_rounded,
                  color: tokens.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          _Counter(
            label: 'Total students',
            value: stats?.totalStudents,
            icon: Icons.groups_outlined,
            color: tokens.warning,
          ),
          if (statsState.isFailed) ...[
            const SizedBox(height: AdminTokens.space3),
            Text(
              'Statistics are unavailable right now.',
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

/// The two credential actions, kept out of the footer so a destructive Delete
/// and a routine password read are never adjacent.
class _CredentialsCard extends StatelessWidget {
  const _CredentialsCard({required this.coach, required this.onAction});

  final Coach coach;
  final void Function(CoachAction action, Coach coach) onAction;

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
              Icon(Icons.key_outlined, size: 17, color: tokens.accent),
              const SizedBox(width: AdminTokens.space2),
              Text(
                'Sign-in',
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
            spacing: AdminTokens.space3,
            runSpacing: AdminTokens.space2,
            children: [
              OutlinedButton.icon(
                onPressed: () => onAction(CoachAction.viewPassword, coach),
                icon: const Icon(Icons.visibility_outlined, size: 17),
                label: const Text('View password'),
              ),
              OutlinedButton.icon(
                onPressed: () => onAction(CoachAction.resetPassword, coach),
                icon: const Icon(Icons.lock_reset_rounded, size: 17),
                label: const Text('Reset password'),
              ),
            ],
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
