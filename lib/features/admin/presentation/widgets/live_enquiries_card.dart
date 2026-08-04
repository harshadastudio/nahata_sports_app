import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/live_enquiry.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';

/// One enquiry row: avatar, identity, sport, when, and its status.
class LiveEnquiryRow extends StatefulWidget {
  const LiveEnquiryRow({
    super.key,
    required this.enquiry,
    required this.isLast,
    this.onTap,
  });

  final LiveEnquiry enquiry;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  State<LiveEnquiryRow> createState() => _LiveEnquiryRowState();
}

class _LiveEnquiryRowState extends State<LiveEnquiryRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final enquiry = widget.enquiry;
    final narrow = MediaQuery.sizeOf(context).width < AdminTokens.mobileMax;

    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AdminTokens.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AdminTokens.space5,
            vertical: AdminTokens.space3 + 1,
          ),
          decoration: BoxDecoration(
            color: _hovered ? tokens.surfaceAlt : Colors.transparent,
            border: widget.isLast
                ? null
                : Border(bottom: BorderSide(color: tokens.border)),
          ),
          child: Row(
            children: [
              EnquiryAvatar(enquiry: enquiry),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                flex: 3,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      enquiry.displayName,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    Text(
                      AdminFormat.text(enquiry.email),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 11.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (!narrow) ...[
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  flex: 2,
                  child: Text(
                    AdminFormat.text(enquiry.sport),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  flex: 2,
                  child: Tooltip(
                    message: AdminFormat.dateTime(enquiry.createdAt),
                    child: Text(
                      _timeAgo(enquiry),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: tokens.textMuted, fontSize: 12),
                    ),
                  ),
                ),
              ],
              const SizedBox(width: AdminTokens.space3),
              EnquiryStatusBadge(enquiry: enquiry),
            ],
          ),
        ),
      ),
    );
  }

  /// The server's own phrasing wins when it sent one.
  static String _timeAgo(LiveEnquiry enquiry) {
    final sent = (enquiry.timeAgoRaw ?? '').trim();
    if (sent.isNotEmpty) return sent;
    return AdminFormat.relative(enquiry.createdAt);
  }
}

/// The enquirer's picture, or initials on a deterministic gradient when the
/// API sent no avatar.
class EnquiryAvatar extends StatelessWidget {
  const EnquiryAvatar({super.key, required this.enquiry, this.size = 36});

  final LiveEnquiry enquiry;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final gradient = tokens.avatarGradient(
      enquiry.id.isEmpty ? enquiry.displayName : enquiry.id,
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
        enquiry.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    if (!enquiry.hasAvatar) return fallback;

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: enquiry.avatarUrl!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

/// Coloured pill for the enquiry's status.
class EnquiryStatusBadge extends StatelessWidget {
  const EnquiryStatusBadge({super.key, required this.enquiry});

  final LiveEnquiry enquiry;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final color = _colorFor(enquiry.status, tokens);

    return Container(
      constraints: const BoxConstraints(maxWidth: 108),
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.space2 + 2,
        vertical: 4,
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
          Flexible(
            child: Text(
              enquiry.statusLabel,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Color _colorFor(LiveEnquiryStatus? status, AdminTokens tokens) {
    switch (status) {
      case LiveEnquiryStatus.pending:
        return tokens.warning;
      case LiveEnquiryStatus.approved:
      case LiveEnquiryStatus.converted:
        return tokens.success;
      case LiveEnquiryStatus.rejected:
        return tokens.danger;
      case LiveEnquiryStatus.contacted:
        return tokens.info;
      case null:
        return tokens.textMuted;
    }
  }
}
