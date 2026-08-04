import 'package:flutter/material.dart';

import '../../domain/entities/membership.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'membership_status_chip.dart';

/// The colour a membership payment status reads in.
///
/// Refunded is deliberately not green: money going back out is not the same
/// event as money coming in, and an admin scanning the column needs them apart.
Color membershipPaymentColor(
  BuildContext context,
  MembershipPaymentStatus? payment,
) {
  final tokens = AdminTheme.of(context);
  return switch (payment) {
    MembershipPaymentStatus.paid => tokens.success,
    MembershipPaymentStatus.pending => tokens.warning,
    MembershipPaymentStatus.failed => tokens.danger,
    MembershipPaymentStatus.refunded => tokens.info,
    null => tokens.textMuted,
  };
}

IconData membershipPaymentIcon(MembershipPaymentStatus? payment) =>
    switch (payment) {
      MembershipPaymentStatus.paid => Icons.payments_rounded,
      MembershipPaymentStatus.pending => Icons.hourglass_empty_rounded,
      MembershipPaymentStatus.failed => Icons.error_outline_rounded,
      MembershipPaymentStatus.refunded => Icons.undo_rounded,
      null => Icons.help_outline_rounded,
    };

/// Paid / Pending / Failed / Refunded.
class MembershipPaymentChip extends StatelessWidget {
  const MembershipPaymentChip({
    super.key,
    required this.membership,
    this.dense = false,
  });

  final Membership membership;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final raw = (membership.paymentStatusRaw ?? '').trim();

    if (raw.isEmpty) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    return StatusPill(
      label: membership.paymentLabel,
      color: membershipPaymentColor(context, membership.paymentStatus),
      icon: membershipPaymentIcon(membership.paymentStatus),
      dense: dense,
    );
  }
}
