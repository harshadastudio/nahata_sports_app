import 'package:flutter/material.dart';

import '../../domain/entities/booking.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';

/// The colour a booking status reads in.
Color bookingStatusColor(BuildContext context, BookingStatus? status) {
  final tokens = AdminTheme.of(context);
  return switch (status) {
    BookingStatus.confirmed => tokens.success,
    BookingStatus.pending => tokens.warning,
    BookingStatus.cancelled => tokens.danger,
    BookingStatus.completed => tokens.info,
    null => tokens.textMuted,
  };
}

/// The colour a payment status reads in.
///
/// Refunded is deliberately not green: money going back out is not the same
/// event as money coming in, and an admin scanning the column needs them apart.
Color paymentStatusColor(BuildContext context, PaymentStatus? payment) {
  final tokens = AdminTheme.of(context);
  return switch (payment) {
    PaymentStatus.paid => tokens.success,
    PaymentStatus.pending => tokens.warning,
    PaymentStatus.failed => tokens.danger,
    PaymentStatus.refunded => const Color(0xFF8B5CF6),
    null => tokens.textMuted,
  };
}

/// Confirmed / Pending / Cancelled / Completed.
class BookingStatusChip extends StatelessWidget {
  const BookingStatusChip({
    super.key,
    required this.booking,
    this.dense = false,
  });

  final Booking booking;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final raw = (booking.bookingStatusRaw ?? '').trim();

    if (raw.isEmpty) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    final color = bookingStatusColor(context, booking.status);

    return _Pill(
      label: booking.statusLabel,
      color: color,
      dense: dense,
      icon: switch (booking.status) {
        BookingStatus.confirmed => Icons.check_circle_outline_rounded,
        BookingStatus.pending => Icons.schedule_rounded,
        BookingStatus.cancelled => Icons.cancel_outlined,
        BookingStatus.completed => Icons.task_alt_rounded,
        null => Icons.help_outline_rounded,
      },
    );
  }
}

/// Paid / Pending / Failed / Refunded.
class PaymentStatusChip extends StatelessWidget {
  const PaymentStatusChip({
    super.key,
    required this.booking,
    this.dense = false,
  });

  final Booking booking;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final raw = (booking.paymentStatusRaw ?? '').trim();

    if (raw.isEmpty) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    return _Pill(
      label: booking.paymentLabel,
      color: paymentStatusColor(context, booking.payment),
      dense: dense,
      icon: switch (booking.payment) {
        PaymentStatus.paid => Icons.payments_rounded,
        PaymentStatus.pending => Icons.hourglass_empty_rounded,
        PaymentStatus.failed => Icons.error_outline_rounded,
        PaymentStatus.refunded => Icons.undo_rounded,
        null => Icons.help_outline_rounded,
      },
    );
  }
}

/// Where the booking came from.
class BookingSourceChip extends StatelessWidget {
  const BookingSourceChip({super.key, required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final raw = (booking.bookingSourceRaw ?? '').trim();

    if (raw.isEmpty) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          switch (booking.source) {
            BookingSource.admin => Icons.admin_panel_settings_outlined,
            BookingSource.walkIn => Icons.directions_walk_rounded,
            BookingSource.website => Icons.language_rounded,
            BookingSource.mobileApp => Icons.phone_iphone_rounded,
            null => Icons.help_outline_rounded,
          },
          size: 14,
          color: tokens.textMuted,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            booking.sourceLabel,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
    required this.icon,
    required this.dense,
  });

  final String label;
  final Color color;
  final IconData icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AdminTokens.space2 : AdminTokens.space3,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 12 : 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: dense ? 11 : 12,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The customer's initials on a deterministic gradient — a booking has no photo
/// to fall back to, so this stands in for one.
class CustomerAvatar extends StatelessWidget {
  const CustomerAvatar({super.key, required this.booking, this.size = 38});

  final Booking booking;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final gradient = tokens.avatarGradient(
      '${booking.userId ?? booking.id}${booking.customerName ?? ''}',
    );

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        booking.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
