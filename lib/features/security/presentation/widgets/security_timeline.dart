import 'package:flutter/material.dart';

import '../../../admin/presentation/theme/admin_theme.dart';
import '../../domain/entities/security_dashboard_data.dart';

/// Today's movements through the gate, newest first.
///
/// Entries and exits are one stream rather than two columns: what the desk
/// wants to know is what just happened, not which of two lists it happened in.
class SecurityTimeline extends StatelessWidget {
  const SecurityTimeline({
    super.key,
    required this.events,
    this.limit = 12,
    this.onSelect,
  });

  final List<SecurityTimelineEvent> events;

  /// The panel shows the most recent [limit]; the activity table holds the rest.
  final int limit;

  final void Function(SecurityTimelineEvent event)? onSelect;

  @override
  Widget build(BuildContext context) {
    final shown = events.length > limit ? events.sublist(0, limit) : events;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < shown.length; i++)
          _Entry(
            event: shown[i],
            isLast: i == shown.length - 1,
            onTap: onSelect == null ? null : () => onSelect!(shown[i]),
          ),
        if (events.length > limit)
          Padding(
            padding: const EdgeInsets.only(top: AdminTokens.space3),
            child: Text(
              '+ ${events.length - limit} more movements today',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AdminTheme.of(context).textMuted,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}

class _Entry extends StatelessWidget {
  const _Entry({required this.event, required this.isLast, this.onTap});

  final SecurityTimelineEvent event;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final colour = event.isEntry ? tokens.success : tokens.warning;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 52,
              child: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  event.timeLabel,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ),
            // The rail: a dot for this event and a line down to the next one.
            Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colour,
                    border: Border.all(
                      color: colour.withValues(alpha: 0.25),
                      width: 3,
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      color: tokens.border,
                    ),
                  ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: AdminTokens.space3,
                  bottom: isLast ? 0 : AdminTokens.space4,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          event.isEntry
                              ? Icons.login_rounded
                              : Icons.logout_rounded,
                          size: 14,
                          color: colour,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            event.title,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.25,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      [
                        if ((event.pass.visitPurpose ?? '').trim().isNotEmpty)
                          event.pass.visitPurpose!.trim(),
                        if ((event.pass.passCode ?? '').trim().isNotEmpty)
                          event.pass.passCode!.trim(),
                      ].join(' · '),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}