import 'package:flutter/material.dart';

import '../../domain/entities/booking.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'admin_states.dart';
import 'booking_chips.dart';
import 'bookings_table.dart';
import 'glass_card.dart';

/// The right-side booking detail panel.
class BookingDetailPanel extends StatelessWidget {
  const BookingDetailPanel({
    super.key,
    required this.booking,
    required this.state,
    required this.error,
    required this.onClose,
    required this.onAction,
    required this.onRetry,
    this.showCloseButton = true,
  });

  final Booking booking;
  final ViewState state;
  final String? error;
  final VoidCallback onClose;
  final void Function(BookingAction action, Booking booking) onAction;
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
                  'Booking details',
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
                  title: 'Could not load this booking',
                  message: error ?? 'Please try again.',
                  onRetry: onRetry,
                )
              : ListView(
                  padding: const EdgeInsets.all(AdminTokens.space5),
                  children: [
                    _HeroCard(booking: booking),
                    const SizedBox(height: AdminTokens.space4),
                    _RowsCard(
                      icon: Icons.person_outline_rounded,
                      title: 'Customer',
                      rows: [
                        _Row('Name', AdminFormat.text(booking.customerName)),
                        _Row('Phone', AdminFormat.text(booking.customerPhone)),
                        _Row('Email', AdminFormat.text(booking.customerEmail)),
                      ],
                    ),
                    const SizedBox(height: AdminTokens.space4),
                    _RowsCard(
                      icon: Icons.confirmation_number_outlined,
                      title: 'Booking',
                      rows: [
                        _Row('Booking ID', booking.displayReference),
                        _Row('Sport', AdminFormat.text(booking.sportName)),
                        _Row('Court', AdminFormat.text(booking.courtName)),
                        _Row(
                          'Sports complex',
                          AdminFormat.text(booking.sportComplexName),
                        ),
                        _Row('Source', booking.sourceLabel),
                        _Row('Created', AdminFormat.dateTime(booking.createdAt)),
                      ],
                    ),
                    const SizedBox(height: AdminTokens.space4),
                    _RowsCard(
                      icon: Icons.schedule_rounded,
                      title: 'Schedule',
                      rows: [
                        _Row('Date', AdminFormat.date(booking.date)),
                        _Row(
                          'Start time',
                          booking.startTime?.label ?? AdminFormat.dash,
                        ),
                        _Row(
                          'End time',
                          booking.endTime?.label ?? AdminFormat.dash,
                        ),
                        _Row('Duration', booking.durationLabel),
                      ],
                    ),
                    const SizedBox(height: AdminTokens.space4),
                    _PaymentCard(booking: booking),
                    if ((booking.notes ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: AdminTokens.space4),
                      _ProseCard(
                        icon: Icons.sticky_note_2_outlined,
                        title: 'Notes',
                        body: booking.notes!.trim(),
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
                  onPressed: () => onAction(BookingAction.delete, booking),
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
                  onPressed: () => onAction(BookingAction.edit, booking),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit booking'),
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
  const _HeroCard({required this.booking});

  final Booking booking;

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
              CustomerAvatar(booking: booking, size: 48),
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
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      booking.displayReference,
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
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
              BookingStatusChip(booking: booking),
              PaymentStatusChip(booking: booking),
            ],
          ),
          const SizedBox(height: AdminTokens.space4),
          Row(
            children: [
              Icon(
                Icons.event_rounded,
                size: 14,
                color: tokens.textMuted,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${AdminFormat.date(booking.date)} · '
                  '${booking.windowLabel}',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentCard extends StatelessWidget {
  const _PaymentCard({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final discount = booking.discountAmount;

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.payments_outlined, size: 17, color: tokens.accent),
              const SizedBox(width: AdminTokens.space2),
              Expanded(
                child: Text(
                  'Payment',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              PaymentStatusChip(booking: booking, dense: true),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          Text(
            AdminFormat.currency(booking.amount),
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: AdminTokens.space3),
          // Only rendered when there is one — an em-dash discount row is noise.
          if (discount != null && discount > 0)
            _Row('Discount', AdminFormat.currency(discount)),
          if ((booking.couponCode ?? '').trim().isNotEmpty)
            _Row('Coupon', booking.couponCode!),
          _Row('Transaction ID', AdminFormat.text(booking.transactionId)),
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
