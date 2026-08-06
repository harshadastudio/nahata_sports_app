import 'package:flutter/material.dart';

import '../../domain/entities/admin_role.dart';
import '../../domain/entities/coupon.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';

/// The coupon's live state, which is not the same as its status column.
///
/// An Active coupon that expired yesterday or has been redeemed to its limit
/// is still Active in the database and useless in the shop — the list has to
/// say which, or an admin will keep wondering why customers cannot use it.
class CouponStateChip extends StatelessWidget {
  const CouponStateChip({
    super.key,
    required this.coupon,
    this.dense = false,
    this.now,
  });

  final AdminCoupon coupon;
  final bool dense;

  /// Injectable for tests; defaults to the current time.
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final moment = now ?? DateTime.now();

    final (Color color, IconData icon, String label) = _read(tokens, moment);

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
          Icon(icon, size: dense ? 11 : 13, color: color),
          const SizedBox(width: AdminTokens.space2),
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

  (Color, IconData, String) _read(AdminTokens tokens, DateTime moment) {
    final status = coupon.status;

    if (status == AdminUserStatus.inactive ||
        status == AdminUserStatus.suspended) {
      return (
        tokens.textMuted,
        Icons.pause_circle_outline_rounded,
        coupon.statusLabel,
      );
    }

    if (coupon.hasExpiredOn(moment)) {
      return (tokens.danger, Icons.event_busy_rounded, 'Expired');
    }
    if (coupon.isExhausted) {
      return (tokens.warning, Icons.block_rounded, 'Used up');
    }
    if (!coupon.hasStartedOn(moment)) {
      return (tokens.info, Icons.schedule_rounded, 'Scheduled');
    }
    if (status == AdminUserStatus.active) {
      return (tokens.success, Icons.check_circle_outline_rounded, 'Active');
    }

    // An unrecognised status is shown as the server wrote it.
    final label = coupon.statusLabel;
    return (
      tokens.textMuted,
      Icons.help_outline_rounded,
      label.isEmpty ? AdminFormat.dash : label,
    );
  }
}

/// The discount itself — the number an admin scans the list for.
class CouponDiscountChip extends StatelessWidget {
  const CouponDiscountChip({
    super.key,
    required this.coupon,
    this.dense = false,
  });

  final AdminCoupon coupon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final label = coupon.discountLabel;

    if (label.isEmpty) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AdminTokens.space2 : AdminTokens.space3,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: tokens.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: tokens.accent,
          fontSize: dense ? 11.5 : 12.5,
          fontWeight: FontWeight.w700,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Where the coupon can be redeemed — the value the `x-client-platform` header
/// is checked against on the server.
class CouponPlatformChip extends StatelessWidget {
  const CouponPlatformChip({
    super.key,
    required this.coupon,
    this.dense = false,
  });

  final AdminCoupon coupon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (IconData icon, String label) = switch (coupon.platform) {
      CouponPlatform.app => (Icons.phone_iphone_rounded, 'App'),
      CouponPlatform.web => (Icons.language_rounded, 'Web'),
      CouponPlatform.all => (Icons.all_inclusive_rounded, 'All'),
      null => (
        Icons.help_outline_rounded,
        coupon.platformLabel.isEmpty ? AdminFormat.dash : coupon.platformLabel,
      ),
    };

    return _OutlineChip(icon: icon, label: label, dense: dense);
  }
}

/// Court or Event — the coupon's single scope.
class CouponScopeChip extends StatelessWidget {
  const CouponScopeChip({super.key, required this.coupon, this.dense = false});

  final AdminCoupon coupon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    final (
      IconData icon,
      String label,
      Color color,
    ) = switch (coupon.appliesTo) {
      CouponAppliesTo.court => (
        Icons.sports_tennis_rounded,
        'Court',
        tokens.info,
      ),
      CouponAppliesTo.event => (
        Icons.confirmation_number_outlined,
        'Event',
        const Color(0xFF8B5CF6),
      ),
      null => (
        Icons.help_outline_rounded,
        coupon.appliesToLabel.isEmpty
            ? AdminFormat.dash
            : coupon.appliesToLabel,
        tokens.textMuted,
      ),
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AdminTokens.space2 : AdminTokens.space3,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 11 : 13, color: color),
          const SizedBox(width: AdminTokens.space2),
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

/// How much of the coupon is left, when it is limited at all.
class CouponUsageLabel extends StatelessWidget {
  const CouponUsageLabel({super.key, required this.coupon});

  final AdminCoupon coupon;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final limit = coupon.usageLimit;

    if (limit == null || limit <= 0) {
      return Text(
        'Unlimited',
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    final used = coupon.usedCount ?? 0;
    final exhausted = coupon.isExhausted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$used / $limit',
          style: TextStyle(
            color: exhausted ? tokens.warning : tokens.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
          child: SizedBox(
            width: 64,
            height: 4,
            child: LinearProgressIndicator(
              value: (used / limit).clamp(0, 1).toDouble(),
              backgroundColor: tokens.surfaceAlt,
              valueColor: AlwaysStoppedAnimation<Color>(
                exhausted ? tokens.warning : tokens.accent,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OutlineChip extends StatelessWidget {
  const _OutlineChip({
    required this.icon,
    required this.label,
    required this.dense,
  });

  final IconData icon;
  final String label;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AdminTokens.space2 : AdminTokens.space3,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
        border: Border.all(color: tokens.borderStrong),
        color: tokens.surfaceAlt,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: dense ? 11 : 13, color: tokens.textSecondary),
          const SizedBox(width: AdminTokens.space2),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.textSecondary,
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
