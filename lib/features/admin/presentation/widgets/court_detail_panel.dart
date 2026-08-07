import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/court.dart';
import '../state/view_state.dart';
import '../navigation/admin_module.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'admin_states.dart';
import 'courts_table.dart';
import 'glass_card.dart';

/// The right-side court detail panel.
///
/// Shows the row already in hand immediately, then fills in from
/// `GET /courts/{id}` behind a thin progress line.
class CourtDetailPanel extends StatelessWidget {
  const CourtDetailPanel({
    super.key,
    required this.court,
    required this.state,
    required this.error,
    required this.onClose,
    required this.onAction,
    required this.onRetry,
    required this.onToggleVisibility,
    required this.busy,
    this.showCloseButton = true,
  });

  final Court court;
  final ViewState state;
  final String? error;
  final VoidCallback onClose;
  final void Function(CourtAction action, Court court) onAction;
  final VoidCallback onRetry;
  final void Function(Court court, bool showOnFrontend) onToggleVisibility;
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
                  'Court details',
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
                  title: 'Could not load this court',
                  message: error ?? 'Please try again.',
                  onRetry: onRetry,
                )
              : ListView(
                  padding: const EdgeInsets.all(AdminTokens.space5),
                  children: [
                    _HeroCard(
                      court: court,
                      busy: busy,
                      onToggleVisibility: onToggleVisibility,
                    ),
                    const SizedBox(height: AdminTokens.space4),
                    _RowsCard(
                      icon: Icons.info_outline_rounded,
                      title: 'General information',
                      rows: [
                        _Row('Sport', AdminFormat.text(court.sportName)),
                        _Row(
                          'Sports complex',
                          AdminFormat.text(court.sportComplexName),
                        ),
                      ],
                    ),
                    const SizedBox(height: AdminTokens.space4),
                    _RowsCard(
                      icon: Icons.straighten_rounded,
                      title: 'Court details',
                      rows: [
                        _Row('Capacity', AdminFormat.number(court.capacity)),
                        _Row(
                          'Surface type',
                          AdminFormat.text(court.surfaceType),
                        ),
                        _Row(
                          'Lighting',
                          court.lightingAvailable == null
                              ? AdminFormat.dash
                              : (court.lightingAvailable!
                                    ? 'Available'
                                    : 'Not available'),
                        ),
                        _Row(
                          'Equipment',
                          AdminFormat.text(court.equipmentAvailable),
                        ),
                        _Row(
                          'Hourly rate',
                          AdminFormat.currency(court.hourlyRate),
                        ),
                      ],
                    ),
                    if ((court.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: AdminTokens.space4),
                      _ProseCard(
                        icon: Icons.notes_rounded,
                        title: 'Description',
                        body: court.description!.trim(),
                      ),
                    ],
                    const SizedBox(height: AdminTokens.space4),
                    _SlotsCard(court: court, onAction: onAction),
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
              if (AdminAccess.canDelete(AdminModules.courts))
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onAction(CourtAction.delete, court),
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
              if (AdminAccess.canEdit(AdminModules.courts))
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed: () => onAction(CourtAction.edit, court),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit court'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.court,
    required this.busy,
    required this.onToggleVisibility,
  });

  final Court court;
  final bool busy;
  final void Function(Court court, bool showOnFrontend) onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final url = court.imageUrl;

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
                  ? _ImageFallback(court: court)
                  : CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _ImageFallback(court: court),
                      errorWidget: (_, __, ___) => _ImageFallback(court: court),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AdminTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  court.displayName,
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
                        AdminFormat.text(court.sportComplexName),
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
                    CourtStatusBadge(court: court),
                    SurfaceChip(court: court),
                    LightingChip(court: court),
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
                    CourtVisibilitySwitch(
                      court: court,
                      busy: busy,
                      showLabel: false,
                      onChanged: (value) => onToggleVisibility(court, value),
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
  const _ImageFallback({required this.court});

  final Court court;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final gradient = tokens.avatarGradient('${court.id}${court.name ?? ''}');

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
        Icons.grid_view_rounded,
        size: 40,
        color: Colors.white.withValues(alpha: 0.85),
      ),
    );
  }
}

/// The way into the slot schedule, plus whatever counters the list carried.
class _SlotsCard extends StatelessWidget {
  const _SlotsCard({required this.court, required this.onAction});

  final Court court;
  final void Function(CourtAction action, Court court) onAction;

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
              Icon(Icons.schedule_rounded, size: 17, color: tokens.accent),
              const SizedBox(width: AdminTokens.space2),
              Text(
                'Slots',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          // Only rendered when the list payload actually carried counters —
          // this panel does not fetch the schedule to fill a card.
          if (court.slotCount != null || court.availableSlotCount != null) ...[
            _Row('Total slots', AdminFormat.number(court.slotCount)),
            _Row(
              'Available slots',
              AdminFormat.number(court.availableSlotCount),
            ),
            const SizedBox(height: AdminTokens.space3),
          ],
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => onAction(CourtAction.manageSlots, court),
              icon: const Icon(Icons.event_note_rounded, size: 17),
              label: const Text('Manage slots'),
            ),
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
