import 'package:flutter/material.dart';

import '../../domain/entities/membership.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';

/// The colour a membership status reads in.
Color membershipStatusColor(BuildContext context, MembershipStatus? status) {
  final tokens = AdminTheme.of(context);
  return switch (status) {
    MembershipStatus.active => tokens.success,
    MembershipStatus.inactive => tokens.textMuted,
    MembershipStatus.expired => tokens.warning,
    MembershipStatus.cancelled => tokens.danger,
    null => tokens.textMuted,
  };
}

IconData membershipStatusIcon(MembershipStatus? status) => switch (status) {
  MembershipStatus.active => Icons.verified_rounded,
  MembershipStatus.inactive => Icons.pause_circle_outline_rounded,
  MembershipStatus.expired => Icons.event_busy_rounded,
  MembershipStatus.cancelled => Icons.cancel_outlined,
  null => Icons.help_outline_rounded,
};

/// Active / Inactive / Expired / Cancelled.
///
/// A status the vocabulary does not know still renders, in the neutral colour —
/// a row must never vanish because the backend grew a fifth value.
class MembershipStatusChip extends StatelessWidget {
  const MembershipStatusChip({
    super.key,
    required this.membership,
    this.dense = false,
  });

  final Membership membership;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final raw = (membership.statusRaw ?? '').trim();

    if (raw.isEmpty) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    return StatusPill(
      label: membership.statusLabel,
      color: membershipStatusColor(context, membership.status),
      icon: membershipStatusIcon(membership.status),
      dense: dense,
    );
  }
}

/// The shared pill both membership chips are drawn with.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    required this.icon,
    this.dense = false,
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
