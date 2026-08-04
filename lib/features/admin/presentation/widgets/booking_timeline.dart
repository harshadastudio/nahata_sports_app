import 'package:flutter/material.dart';

import '../../domain/entities/booking.dart';
import '../state/bookings_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'admin_states.dart';
import 'booking_chips.dart';
import 'bookings_table.dart';
import 'glass_card.dart';
import 'stat_card.dart';

/// Today's board: four counters and a vertical timeline of the day.
///
/// Reads `/bookings/current`, which is the only route that answers "what is
/// happening now" — the list route would need a date filter and a sort to say
/// the same thing, and would still not know the time.
class BookingTimelineView extends StatelessWidget {
  const BookingTimelineView({
    super.key,
    required this.controller,
    required this.onAction,
    this.now,
  });

  final BookingsController controller;
  final void Function(BookingAction action, Booking booking) onAction;

  /// Injectable so a test can pin "now".
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final moment = now ?? DateTime.now();

    if (controller.currentState.isLoading) {
      return const SingleChildScrollView(child: TableShimmer(rows: 6));
    }

    if (controller.currentState.isFailed) {
      return ErrorStateView(
        title: "Could not load today's bookings",
        message:
            controller.currentError ??
            'The server did not return the current bookings.',
        onRetry: controller.loadCurrent,
      );
    }

    final ordered = controller.orderedCurrent();

    if (ordered.isEmpty) {
      return EmptyStateView(
        icon: Icons.event_busy_outlined,
        title: 'No bookings found',
        message: 'Nothing is booked for today yet.',
        actionLabel: 'Refresh',
        onAction: controller.loadCurrent,
      );
    }

    final upcoming = controller.currentIn(BookingPhase.upcoming, now: moment);
    final ongoing = controller.currentIn(BookingPhase.ongoing, now: moment);
    final finished = controller.currentIn(BookingPhase.finished, now: moment);

    return ListView(
      padding: const EdgeInsets.all(AdminTokens.space4),
      children: [
        _Counters(
          total: ordered.length,
          ongoing: ongoing.length,
          upcoming: upcoming.length,
          finished: finished.length,
        ),
        const SizedBox(height: AdminTokens.space5),
        for (var index = 0; index < ordered.length; index++)
          _TimelineEntry(
            booking: ordered[index],
            phase: ordered[index].phaseAt(moment),
            isFirst: index == 0,
            isLast: index == ordered.length - 1,
            onAction: onAction,
          ),
      ],
    );
  }
}

class _Counters extends StatelessWidget {
  const _Counters({
    required this.total,
    required this.ongoing,
    required this.upcoming,
    required this.finished,
  });

  final int total;
  final int ongoing;
  final int upcoming;
  final int finished;

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      StatCard(
        label: 'Active today',
        value: total,
        icon: Icons.today_rounded,
        gradient: const [Color(0xFF1A237E), Color(0xFF3F51B5)],
      ),
      StatCard(
        label: 'Ongoing now',
        value: ongoing,
        icon: Icons.play_circle_outline_rounded,
        gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
      ),
      StatCard(
        label: 'Upcoming',
        value: upcoming,
        icon: Icons.schedule_rounded,
        gradient: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
      ),
      StatCard(
        label: 'Completed today',
        value: finished,
        icon: Icons.task_alt_rounded,
        gradient: const [Color(0xFF0EA5E9), Color(0xFF67E8F9)],
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 900 ? 4 : 2;
        const gap = AdminTokens.space4;
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards
              .map((card) => SizedBox(width: cardWidth, child: card))
              .toList(),
        );
      },
    );
  }
}

/// One stop on the timeline: the time on the left, a rail, and the booking.
class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({
    required this.booking,
    required this.phase,
    required this.isFirst,
    required this.isLast,
    required this.onAction,
  });

  final Booking booking;
  final BookingPhase? phase;
  final bool isFirst;
  final bool isLast;
  final void Function(BookingAction action, Booking booking) onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    final color = switch (phase) {
      BookingPhase.ongoing => tokens.success,
      BookingPhase.upcoming => tokens.accent,
      BookingPhase.finished => tokens.textMuted,
      null => tokens.textMuted,
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 76,
            child: Padding(
              padding: const EdgeInsets.only(top: AdminTokens.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    booking.startTime?.label ?? '—',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    booking.durationLabel,
                    textAlign: TextAlign.right,
                    style: TextStyle(color: tokens.textMuted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          // The rail: a line through the whole entry with a node at the time.
          SizedBox(
            width: 32,
            child: Column(
              children: [
                Expanded(
                  flex: 0,
                  child: SizedBox(
                    height: AdminTokens.space3 + 2,
                    child: Center(
                      child: Container(
                        width: 2,
                        color: isFirst ? Colors.transparent : tokens.border,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: phase == BookingPhase.ongoing
                        ? color
                        : tokens.surface,
                    border: Border.all(color: color, width: 2.5),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 2,
                      color: isLast ? Colors.transparent : tokens.border,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AdminTokens.space3),
              child: SolidCard(
                padding: const EdgeInsets.all(AdminTokens.space3),
                child: InkWell(
                  onTap: () => onAction(BookingAction.view, booking),
                  child: Row(
                    children: [
                      CustomerAvatar(booking: booking, size: 34),
                      const SizedBox(width: AdminTokens.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              booking.displayCustomer,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                AdminFormat.text(booking.courtName),
                                AdminFormat.text(booking.sportName),
                              ]
                                  .where((part) => part != AdminFormat.dash)
                                  .join(' · '),
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AdminTokens.space3),
                      Wrap(
                        spacing: AdminTokens.space2,
                        runSpacing: AdminTokens.space2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (phase == BookingPhase.ongoing)
                            _NowBadge(color: color),
                          BookingStatusChip(booking: booking, dense: true),
                          PaymentStatusChip(booking: booking, dense: true),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NowBadge extends StatelessWidget {
  const _NowBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.space2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
      ),
      child: const Text(
        'NOW',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
