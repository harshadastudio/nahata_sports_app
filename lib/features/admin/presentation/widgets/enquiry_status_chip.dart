import 'package:flutter/material.dart';

import '../../domain/entities/coaching_enquiry.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';

/// The colour and icon each follow-up state carries, drawn from the console's
/// own semantic tokens so the module reads like the rest of the panel.
extension EnquiryStatusStyle on AdminTokens {
  Color enquiryStatusColor(CoachingEnquiryStatus? status) {
    switch (status) {
      case CoachingEnquiryStatus.isNew:
        // Untouched work — the same blue the console uses for "needs looking
        // at" everywhere else.
        return info;
      case CoachingEnquiryStatus.contacted:
        return warning;
      case CoachingEnquiryStatus.interested:
        return const Color(0xFF8B5CF6);
      case CoachingEnquiryStatus.joined:
        return success;
      case CoachingEnquiryStatus.closed:
        return textMuted;
      case null:
        return textMuted;
    }
  }

  IconData enquiryStatusIcon(CoachingEnquiryStatus? status) {
    switch (status) {
      case CoachingEnquiryStatus.isNew:
        return Icons.fiber_new_rounded;
      case CoachingEnquiryStatus.contacted:
        return Icons.phone_in_talk_outlined;
      case CoachingEnquiryStatus.interested:
        return Icons.favorite_outline_rounded;
      case CoachingEnquiryStatus.joined:
        return Icons.how_to_reg_rounded;
      case CoachingEnquiryStatus.closed:
        return Icons.archive_outlined;
      case null:
        return Icons.help_outline_rounded;
    }
  }
}

/// A dot-and-label pill for an enquiry's state.
class EnquiryStatusChip extends StatelessWidget {
  const EnquiryStatusChip({
    super.key,
    required this.statusRaw,
    this.dense = false,
  });

  final String? statusRaw;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final status = CoachingEnquiryStatus.tryParse(statusRaw);
    final color = tokens.enquiryStatusColor(status);

    final label = CoachingEnquiryStatus.labelFor(statusRaw);

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
          Icon(
            tokens.enquiryStatusIcon(status),
            size: dense ? 11 : 13,
            color: color,
          ),
          const SizedBox(width: AdminTokens.space2),
          Flexible(
            child: Text(
              label.isEmpty ? AdminFormat.dash : label,
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

/// How far through the follow-up an enquiry has come.
///
/// Only the five documented states sit on the track. A Closed enquiry is shown
/// as its own end rather than as "not joined" — it is a legitimate outcome,
/// not a failure — and an unrecognised status renders no track at all rather
/// than implying a position it may not hold.
class EnquiryStatusTimeline extends StatelessWidget {
  const EnquiryStatusTimeline({super.key, required this.statusRaw});

  final String? statusRaw;

  static const List<CoachingEnquiryStatus> _track = [
    CoachingEnquiryStatus.isNew,
    CoachingEnquiryStatus.contacted,
    CoachingEnquiryStatus.interested,
    CoachingEnquiryStatus.joined,
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final status = CoachingEnquiryStatus.tryParse(statusRaw);

    if (status == null) {
      return Text(
        'This enquiry carries a status the console does not recognise '
        '("${(statusRaw ?? '').trim()}"), so its progress is not charted.',
        style: TextStyle(color: tokens.textMuted, fontSize: 11.5, height: 1.45),
      );
    }

    if (status == CoachingEnquiryStatus.closed) {
      final color = tokens.enquiryStatusColor(status);
      return Row(
        children: [
          Icon(tokens.enquiryStatusIcon(status), size: 17, color: color),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              'Closed — no further follow-up is planned.',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      );
    }

    final reached = status.step;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(_track.length, (index) {
        final step = _track[index];
        final done = index <= reached;
        final isLast = index == _track.length - 1;
        final color = done ? tokens.enquiryStatusColor(step) : tokens.textMuted;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 22,
                    height: 22,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done
                          ? color.withValues(alpha: 0.15)
                          : Colors.transparent,
                      border: Border.all(
                        color: done ? color : tokens.border,
                        width: 1.5,
                      ),
                    ),
                    child: done
                        ? Icon(Icons.check_rounded, size: 12, color: color)
                        : null,
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 2),
                        color: index < reached ? color : tokens.border,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: isLast ? 0 : AdminTokens.space4,
                    top: 2,
                  ),
                  child: Text(
                    step.label,
                    style: TextStyle(
                      color: done ? tokens.textPrimary : tokens.textMuted,
                      fontSize: 12.5,
                      fontWeight: index == reached
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
              if (index == reached)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    'Now',
                    style: TextStyle(
                      color: tokens.enquiryStatusColor(step),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
