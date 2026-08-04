import 'package:flutter/material.dart';

import '../../domain/entities/booking.dart';
import '../../domain/entities/coach.dart';
import '../state/bookings_controller.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'booking_chips.dart';
import 'bookings_table.dart';
import 'glass_card.dart';

/// A month grid of bookings, with the picked day's list beneath it.
///
/// Drawn from the rows already loaded rather than a request per day: there is
/// no month endpoint, and firing thirty reads to fill a calendar would be worse
/// than saying plainly how much is in hand — which the header does.
class BookingCalendarView extends StatelessWidget {
  const BookingCalendarView({
    super.key,
    required this.controller,
    required this.onAction,
  });

  final BookingsController controller;
  final void Function(BookingAction action, Booking booking) onAction;

  static const List<String> _monthNames = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final month = controller.calendarMonth;
    final selected = controller.calendarSelectedDay;

    final monthRows = _bookingsInMonth(month);

    return ListView(
      padding: const EdgeInsets.all(AdminTokens.space4),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: controller.previousMonth,
              icon: const Icon(Icons.chevron_left_rounded),
              tooltip: 'Previous month',
              color: tokens.textSecondary,
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_monthNames[month.month - 1]} ${month.year}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    // Said plainly: the grid can only show what is loaded.
                    controller.isCatalogueMode
                        ? '${monthRows.length} of '
                              '${controller.visibleRows.length} loaded '
                              'bookings fall in this month'
                        : '${monthRows.length} of the '
                              '${controller.rows.length} bookings on this page '
                              'fall in this month',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: controller.nextMonth,
              icon: const Icon(Icons.chevron_right_rounded),
              tooltip: 'Next month',
              color: tokens.textSecondary,
            ),
          ],
        ),
        const SizedBox(height: AdminTokens.space3),
        _MonthGrid(controller: controller),
        const SizedBox(height: AdminTokens.space5),
        if (selected == null)
          Padding(
            padding: const EdgeInsets.all(AdminTokens.space4),
            child: Text(
              'Pick a day to see its bookings.',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
            ),
          )
        else
          _DayBookings(
            day: selected,
            bookings: controller.bookingsOn(selected),
            onAction: onAction,
          ),
      ],
    );
  }

  List<Booking> _bookingsInMonth(DateTime month) {
    final rows = controller.isCatalogueMode
        ? controller.visibleRows
        : controller.rows;
    return rows
        .where(
          (booking) =>
              booking.date != null &&
              booking.date!.year == month.year &&
              booking.date!.month == month.month,
        )
        .toList(growable: false);
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({required this.controller});

  final BookingsController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final month = controller.calendarMonth;
    final today = DateTime.now();

    final firstOfMonth = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    // Monday-first, matching the rest of the console's week views.
    final leading = firstOfMonth.weekday - 1;
    final cells = leading + daysInMonth;
    final rows = (cells / 7).ceil();

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space3),
      child: Column(
        children: [
          Row(
            children: [
              for (final day in Weekday.values)
                Expanded(
                  child: Center(
                    child: Text(
                      day.shortLabel,
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AdminTokens.space2),
          for (var row = 0; row < rows; row++)
            Row(
              children: [
                for (var column = 0; column < 7; column++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final dayNumber = row * 7 + column - leading + 1;
                        if (dayNumber < 1 || dayNumber > daysInMonth) {
                          return const SizedBox(height: 62);
                        }

                        final date = DateTime(
                          month.year,
                          month.month,
                          dayNumber,
                        );
                        final bookings = controller.bookingsOn(date);
                        final isToday =
                            date.year == today.year &&
                            date.month == today.month &&
                            date.day == today.day;
                        final isSelected =
                            controller.calendarSelectedDay == date;

                        return _DayCell(
                          day: dayNumber,
                          count: bookings.length,
                          isToday: isToday,
                          isSelected: isSelected,
                          onTap: () => controller.selectDay(
                            isSelected ? null : date,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.count,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  final int day;
  final int count;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final busy = count > 0;

    return Padding(
      padding: const EdgeInsets.all(2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: isSelected
                ? tokens.accentSoft
                : (busy
                      ? tokens.accent.withValues(alpha: 0.07)
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
            border: Border.all(
              color: isSelected
                  ? tokens.accent
                  : (isToday ? tokens.borderStrong : tokens.border),
              width: isSelected || isToday ? 1.4 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$day',
                style: TextStyle(
                  color: isSelected || isToday
                      ? tokens.accent
                      : tokens.textPrimary,
                  fontSize: 13,
                  fontWeight: isToday || isSelected
                      ? FontWeight.w800
                      : FontWeight.w600,
                ),
              ),
              const SizedBox(height: 3),
              // A day with nothing loaded shows no badge at all, rather than a
              // zero that would read as "closed".
              if (busy)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.accent,
                    borderRadius: BorderRadius.circular(
                      AdminTokens.radiusPill,
                    ),
                  ),
                  child: Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                )
              else
                const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayBookings extends StatelessWidget {
  const _DayBookings({
    required this.day,
    required this.bookings,
    required this.onAction,
  });

  final DateTime day;
  final List<Booking> bookings;
  final void Function(BookingAction action, Booking booking) onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    final ordered = [...bookings]..sort((a, b) {
      final first = a.startTime?.minutesFromMidnight ?? 0;
      final second = b.startTime?.minutesFromMidnight ?? 0;
      return first.compareTo(second);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(
              Icons.event_note_rounded,
              size: 17,
              color: tokens.accent,
            ),
            const SizedBox(width: AdminTokens.space2),
            Expanded(
              child: Text(
                AdminFormat.date(day),
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${ordered.length} '
              '${ordered.length == 1 ? 'booking' : 'bookings'}',
              style: TextStyle(color: tokens.textMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: AdminTokens.space3),
        if (ordered.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AdminTokens.space4),
            child: Text(
              'No bookings found for this day among the loaded rows.',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
            ),
          )
        else
          for (final booking in ordered)
            Padding(
              padding: const EdgeInsets.only(bottom: AdminTokens.space2),
              child: SolidCard(
                padding: const EdgeInsets.all(AdminTokens.space3),
                child: InkWell(
                  onTap: () => onAction(BookingAction.view, booking),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 84,
                        child: Text(
                          booking.startTime?.label ?? '—',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          [
                            booking.displayCustomer,
                            AdminFormat.text(booking.courtName),
                          ].where((p) => p != AdminFormat.dash).join(' · '),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: AdminTokens.space3),
                      BookingStatusChip(booking: booking, dense: true),
                    ],
                  ),
                ),
              ),
            ),
      ],
    );
  }
}
