import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/admin_role.dart';
import '../../domain/entities/admin_user.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';

/// A user's picture, falling back to initials on a deterministic gradient.
class AdminAvatar extends StatelessWidget {
  const AdminAvatar({super.key, required this.user, this.size = 36});

  final AdminUser user;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final gradient = tokens.avatarGradient(
      user.id.isEmpty ? user.displayName : user.id,
    );

    final fallback = Container(
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
        user.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );

    if (!user.hasAvatar) return fallback;

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: user.avatarUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        // A broken URL silently becomes initials — never a broken-image glyph.
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

/// A dot-and-label pill for account status.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.user, this.dense = false});

  final AdminUser user;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final color = tokens.statusColor(user.status);
    final label = user.statusLabel.isEmpty
        ? AdminFormat.dash
        : user.statusLabel;

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
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AdminTokens.space2),
          // Flexible, so a long status in a narrow table column ellipsises
          // instead of overflowing the row.
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

/// A tinted chip carrying the role, coloured consistently across the panel.
class RoleChip extends StatelessWidget {
  const RoleChip({super.key, required this.roleRaw, this.dense = false});

  final String? roleRaw;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final role = AdminRole.tryParse(roleRaw);
    final color = tokens.roleColor(role);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AdminTokens.space2 : AdminTokens.space3,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
      ),
      child: Text(
        AdminRole.labelFor(roleRaw),
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: dense ? 11 : 12,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Membership tier chip. The value is whatever the API sent — the panel never
/// invents a tier name.
class MembershipChip extends StatelessWidget {
  const MembershipChip({
    super.key,
    required this.membership,
    this.dense = false,
  });

  final String? membership;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final label = (membership ?? '').trim();

    if (label.isEmpty) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 13),
      );
    }

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
    );
  }
}

/// A tick / cross pill for the two verification flags.
class VerificationBadge extends StatelessWidget {
  const VerificationBadge({
    super.key,
    required this.label,
    required this.verified,
  });

  final String label;
  final bool? verified;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    // Unknown is its own state — an unsent flag must not read as "unverified".
    final Color color;
    final IconData icon;
    final String suffix;
    switch (verified) {
      case true:
        color = tokens.success;
        icon = Icons.verified_rounded;
        suffix = 'Verified';
      case false:
        color = tokens.warning;
        icon = Icons.error_outline_rounded;
        suffix = 'Not verified';
      case null:
        color = tokens.textMuted;
        icon = Icons.help_outline_rounded;
        suffix = AdminFormat.dash;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.space3,
        vertical: AdminTokens.space2,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(width: AdminTokens.space2),
          Text(
            '$label · $suffix',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
