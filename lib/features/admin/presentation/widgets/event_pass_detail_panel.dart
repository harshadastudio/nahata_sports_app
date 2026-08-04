import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/event_pass.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'admin_states.dart';
import 'event_passes_table.dart';
import 'glass_card.dart';

/// The right-side event detail panel.
class EventPassDetailPanel extends StatelessWidget {
  const EventPassDetailPanel({
    super.key,
    required this.event,
    required this.state,
    required this.error,
    required this.onClose,
    required this.onAction,
    required this.onRetry,
    this.showCloseButton = true,
  });

  final AdminEventPass event;
  final ViewState state;
  final String? error;
  final VoidCallback onClose;
  final void Function(EventAction action, AdminEventPass event) onAction;
  final VoidCallback onRetry;
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
                  'Event details',
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
                  title: 'Could not load this event',
                  message: error ?? 'Please try again.',
                  onRetry: onRetry,
                )
              : ListView(
                  padding: const EdgeInsets.all(AdminTokens.space5),
                  children: [
                    _HeroCard(event: event),
                    const SizedBox(height: AdminTokens.space4),
                    _SlotsCard(event: event),
                    if ((event.description ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: AdminTokens.space4),
                      _ProseCard(
                        icon: Icons.notes_rounded,
                        title: 'Description',
                        body: event.description!.trim(),
                      ),
                    ],
                    if (event.faqs.isNotEmpty) ...[
                      const SizedBox(height: AdminTokens.space4),
                      _FaqsCard(event: event),
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
                  onPressed: () => onAction(EventAction.delete, event),
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
                  onPressed: () => onAction(EventAction.edit, event),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit event'),
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
  const _HeroCard({required this.event});

  final AdminEventPass event;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final url = event.imageUrl;

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
                  ? _ImageFallback(event: event)
                  : CachedNetworkImage(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _ImageFallback(event: event),
                      errorWidget: (_, __, ___) => _ImageFallback(event: event),
                    ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AdminTokens.space4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.displayTitle,
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
                        AdminFormat.text(event.sportComplexName),
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
                    EventStatusBadge(event: event),
                    EventSlotsBadge(event: event),
                  ],
                ),
                const SizedBox(height: AdminTokens.space4),
                Row(
                  children: [
                    Expanded(
                      child: _Figure(
                        label: 'Total capacity',
                        value: AdminFormat.number(event.totalCapacity),
                      ),
                    ),
                    Expanded(
                      child: _Figure(
                        label: 'Runs from',
                        value: AdminFormat.date(event.firstDate),
                      ),
                    ),
                    Expanded(
                      child: _Figure(
                        label: 'Until',
                        value: AdminFormat.date(event.lastDate),
                      ),
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

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: tokens.textMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _ImageFallback extends StatelessWidget {
  const _ImageFallback({required this.event});

  final AdminEventPass event;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final gradient = tokens.avatarGradient('${event.id}${event.title ?? ''}');

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
        Icons.confirmation_number_rounded,
        size: 40,
        color: Colors.white.withValues(alpha: 0.85),
      ),
    );
  }
}

class _SlotsCard extends StatelessWidget {
  const _SlotsCard({required this.event});

  final AdminEventPass event;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final now = DateTime.now();

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_note_rounded, size: 17, color: tokens.accent),
              const SizedBox(width: AdminTokens.space2),
              Expanded(
                child: Text(
                  'Slots',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${event.upcomingSlotCount(now)} upcoming of '
                '${event.slotCount}',
                style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          if (event.slots.isEmpty)
            Text(
              'This event has no slots, so nothing can be booked against it.',
              style: TextStyle(
                color: tokens.textMuted,
                fontSize: 12.5,
                height: 1.45,
              ),
            )
          else
            for (final slot in event.slots)
              Padding(
                padding: const EdgeInsets.only(bottom: AdminTokens.space2),
                child: _SlotRow(slot: slot, now: now),
              ),
        ],
      ),
    );
  }
}

class _SlotRow extends StatelessWidget {
  const _SlotRow({required this.slot, required this.now});

  final EventPassSlot slot;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final upcoming = slot.isUpcomingOn(now);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space3),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              // A past slot is muted rather than hidden: it still explains the
              // bookings sitting against it.
              color: upcoming ? tokens.success : tokens.textMuted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AdminFormat.date(slot.date),
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  slot.windowLabel,
                  style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AdminFormat.currency(slot.price),
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                slot.capacity == null
                    ? AdminFormat.dash
                    : '${slot.capacity} seats',
                style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FaqsCard extends StatelessWidget {
  const _FaqsCard({required this.event});

  final AdminEventPass event;

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
              Icon(Icons.help_outline_rounded, size: 17, color: tokens.accent),
              const SizedBox(width: AdminTokens.space2),
              Text(
                'FAQs',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          for (final faq in event.faqs)
            Padding(
              padding: const EdgeInsets.only(bottom: AdminTokens.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AdminFormat.text(faq.question),
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    AdminFormat.text(faq.answer),
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 12,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
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
