import 'package:flutter/material.dart';

import '../../domain/entities/coach.dart';
import '../../domain/entities/court_slot.dart';
import '../state/court_slots_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'admin_states.dart';
import 'glass_card.dart';

/// The colour every availability view shares.
///
/// Green available, red booked, grey blocked — and a fourth, deliberately
/// distinct, for "the payload did not say". Telling an admin a court is free
/// when it is not is the expensive mistake, so unknown never renders as green.
Color availabilityColor(BuildContext context, SlotAvailability availability) {
  final tokens = AdminTheme.of(context);
  return switch (availability) {
    SlotAvailability.available => tokens.success,
    SlotAvailability.booked => tokens.danger,
    SlotAvailability.blocked => tokens.textMuted,
    SlotAvailability.unknown => tokens.border,
  };
}

/// One day's live availability, from `/courts/{id}/available-slots?date=`.
class DayAvailabilityView extends StatelessWidget {
  const DayAvailabilityView({
    super.key,
    required this.controller,
    required this.onPickDate,
  });

  final CourtSlotsController controller;
  final VoidCallback onPickDate;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AdminTokens.space4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AdminFormat.date(controller.selectedDate),
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Live availability for this date',
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: onPickDate,
                icon: const Icon(Icons.calendar_today_rounded, size: 17),
                label: const Text('Change date'),
              ),
            ],
          ),
        ),
        const AvailabilityLegend(),
        const SizedBox(height: AdminTokens.space2),
        Expanded(
          child: Builder(
            builder: (context) {
              if (controller.dayState.isLoading) {
                return const SingleChildScrollView(
                  child: TableShimmer(rows: 6, dense: true),
                );
              }

              if (controller.dayState.isFailed) {
                return ErrorStateView(
                  title: 'Could not load availability',
                  message:
                      controller.dayError ??
                      'The server did not return availability for this date.',
                  onRetry: controller.loadDay,
                );
              }

              final slots = controller.dayAvailability;
              if (slots.isEmpty) {
                return const EmptyStateView(
                  icon: Icons.event_busy_outlined,
                  title: 'No slots available',
                  message:
                      'Nothing is scheduled on this court for the selected '
                      'date.',
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(AdminTokens.space4),
                itemCount: slots.length,
                separatorBuilder: (_, __) =>
                    const SizedBox(height: AdminTokens.space2),
                itemBuilder: (context, index) =>
                    _AvailabilityRow(slot: slots[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AvailabilityRow extends StatelessWidget {
  const _AvailabilityRow({required this.slot});

  final AvailableSlot slot;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final availability = slot.availability;
    final color = availabilityColor(context, availability);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              slot.windowLabel,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (slot.price != null) ...[
            Text(
              AdminFormat.currency(slot.price),
              style: TextStyle(color: tokens.textSecondary, fontSize: 12.5),
            ),
            const SizedBox(width: AdminTokens.space3),
          ],
          Text(
            availability.label,
            style: TextStyle(
              color: availability == SlotAvailability.unknown
                  ? tokens.textMuted
                  : color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

/// The weekly grid: seven day columns, one row per hour.
///
/// Built from seven `/available-slots` reads — the route answers for a single
/// date — so the header says which week it is and the cells say what each hour
/// actually is.
class WeekAvailabilityCalendar extends StatelessWidget {
  const WeekAvailabilityCalendar({super.key, required this.controller});

  final CourtSlotsController controller;

  static const double _hourColumn = 84;
  static const double _dayColumn = 116;
  static const double _rowHeight = 44;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AdminTokens.space4),
          child: Row(
            children: [
              IconButton(
                onPressed: controller.previousWeek,
                icon: const Icon(Icons.chevron_left_rounded),
                tooltip: 'Previous week',
                color: tokens.textSecondary,
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${AdminFormat.date(controller.weekStart)} – '
                      '${AdminFormat.date(controller.weekStart.add(const Duration(days: 6)))}',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Seven daily reads, one per column',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: controller.nextWeek,
                icon: const Icon(Icons.chevron_right_rounded),
                tooltip: 'Next week',
                color: tokens.textSecondary,
              ),
              const SizedBox(width: AdminTokens.space2),
              TextButton(
                onPressed: controller.thisWeek,
                child: const Text('Today'),
              ),
            ],
          ),
        ),
        const AvailabilityLegend(),
        const SizedBox(height: AdminTokens.space2),
        Expanded(
          child: Builder(
            builder: (context) {
              if (controller.weekState.isLoading) {
                return const SingleChildScrollView(
                  child: TableShimmer(rows: 8, dense: true),
                );
              }

              if (controller.weekState.isFailed) {
                return ErrorStateView(
                  title: 'Could not load the week',
                  message: controller.weekError ?? 'Please try again.',
                  onRetry: controller.loadWeek,
                );
              }

              return _Grid(controller: controller);
            },
          ),
        ),
      ],
    );
  }
}

class _Grid extends StatefulWidget {
  const _Grid({required this.controller});

  final CourtSlotsController controller;

  @override
  State<_Grid> createState() => _GridState();
}

class _GridState extends State<_Grid> {
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final controller = widget.controller;
    final hours = controller.gridHours;

    const gridWidth =
        WeekAvailabilityCalendar._hourColumn +
        WeekAvailabilityCalendar._dayColumn * 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (controller.weekError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AdminTokens.space4,
              0,
              AdminTokens.space4,
              AdminTokens.space3,
            ),
            child: Text(
              controller.weekError!,
              style: TextStyle(
                color: tokens.textMuted,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        Expanded(
          child: Scrollbar(
            controller: _horizontal,
            thumbVisibility: true,
            child: SingleChildScrollView(
              controller: _horizontal,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: gridWidth,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _WeekHeader(controller: controller),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: hours.length,
                        itemBuilder: (context, index) => _HourRow(
                          controller: controller,
                          hour: hours[index],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({required this.controller});

  final CourtSlotsController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final today = DateTime.now();

    return Container(
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          const SizedBox(width: WeekAvailabilityCalendar._hourColumn),
          for (final day in Weekday.values)
            SizedBox(
              width: WeekAvailabilityCalendar._dayColumn,
              child: Builder(
                builder: (context) {
                  final date = controller.dateForWeekday(day.dateTimeWeekday);
                  final isToday =
                      date.year == today.year &&
                      date.month == today.month &&
                      date.day == today.day;

                  return Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AdminTokens.space3,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          day.shortLabel,
                          style: TextStyle(
                            color: isToday
                                ? tokens.accent
                                : tokens.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${date.day}/${date.month}',
                          style: TextStyle(
                            color: isToday
                                ? tokens.accent
                                : tokens.textMuted,
                            fontSize: 10.5,
                            fontWeight: isToday
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _HourRow extends StatelessWidget {
  const _HourRow({required this.controller, required this.hour});

  final CourtSlotsController controller;
  final int hour;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final label = SlotTime.fromHour(hour).label;

    return Container(
      height: WeekAvailabilityCalendar._rowHeight,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: WeekAvailabilityCalendar._hourColumn,
            child: Padding(
              padding: const EdgeInsets.only(left: AdminTokens.space4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          for (final day in Weekday.values)
            SizedBox(
              width: WeekAvailabilityCalendar._dayColumn,
              child: _Cell(
                availability: controller.availabilityAt(
                  day.dateTimeWeekday,
                  hour,
                ),
                label: label,
                day: day,
              ),
            ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.availability,
    required this.label,
    required this.day,
  });

  final SlotAvailability availability;
  final String label;
  final Weekday day;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final color = availabilityColor(context, availability);
    final unknown = availability == SlotAvailability.unknown;

    return Padding(
      padding: const EdgeInsets.all(3),
      child: Tooltip(
        message: '${day.label} $label · ${availability.label}',
        waitDuration: const Duration(milliseconds: 400),
        child: Container(
          decoration: BoxDecoration(
            // Unknown is a hairline outline rather than a filled cell, so an
            // hour nothing was said about never reads as a state.
            color: unknown
                ? Colors.transparent
                : color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
            border: Border.all(
              color: unknown
                  ? tokens.border
                  : color.withValues(alpha: 0.5),
            ),
          ),
          alignment: Alignment.center,
          child: unknown
              ? null
              : Icon(
                  switch (availability) {
                    SlotAvailability.available => Icons.check_rounded,
                    SlotAvailability.booked => Icons.person_rounded,
                    SlotAvailability.blocked => Icons.block_rounded,
                    SlotAvailability.unknown => Icons.remove,
                  },
                  size: 14,
                  color: color,
                ),
        ),
      ),
    );
  }
}

/// What the colours mean, said once and shown above every availability view.
class AvailabilityLegend extends StatelessWidget {
  const AvailabilityLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AdminTokens.space4),
      child: Wrap(
        spacing: AdminTokens.space4,
        runSpacing: AdminTokens.space2,
        children: [
          for (final availability in SlotAvailability.values)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: availabilityColor(context, availability),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  availability == SlotAvailability.unknown
                      ? 'Not reported'
                      : availability.label,
                  style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// `GET /courts/availability` — free time across every court at a complex.
///
/// Deliberately shows no court names: the route answers "is anything free",
/// and the spec is explicit that this view must not expose which court.
class CourtAvailabilityList extends StatelessWidget {
  const CourtAvailabilityList({
    super.key,
    required this.windows,
    required this.state,
    required this.error,
    required this.onRetry,
  });

  final List<AvailabilityWindow> windows;
  final ViewState state;
  final String? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    if (state.isLoading) {
      return const SingleChildScrollView(child: TableShimmer(rows: 6));
    }

    if (state.isFailed) {
      return ErrorStateView(
        title: 'Could not load availability',
        message: error ?? 'The server did not return any availability.',
        onRetry: onRetry,
      );
    }

    if (windows.isEmpty) {
      return const EmptyStateView(
        icon: Icons.event_busy_outlined,
        title: 'No slots available',
        message:
            'Nothing is free for the selected complex, sport and date.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AdminTokens.space4),
      itemCount: windows.length,
      separatorBuilder: (_, __) => const SizedBox(height: AdminTokens.space2),
      itemBuilder: (context, index) {
        final window = windows[index];
        final free = window.hasAvailability;
        final color = free ? tokens.success : tokens.textMuted;

        return SolidCard(
          padding: const EdgeInsets.all(AdminTokens.space3),
          child: Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                child: Text(
                  window.windowLabel,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                window.availableCourts == null
                    ? 'Availability not reported'
                    : '${window.availableCourts} '
                          '${window.availableCourts == 1 ? 'court' : 'courts'} '
                          'free'
                          '${window.totalCourts == null ? '' : ' of ${window.totalCourts}'}',
                style: TextStyle(
                  color: window.availableCourts == null
                      ? tokens.textMuted
                      : color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
