import 'package:flutter/material.dart';

import '../../domain/entities/coaching_enquiry.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import 'admin_states.dart';
import 'stat_card.dart';

/// The six counters from `GET /coaching-enquiries/stats`.
///
/// Each state card doubles as the queue's filter — tapping one shows only
/// those enquiries, tapping it again clears the filter. That is why the cards
/// know which filter is active: a card the list is currently filtered by is
/// outlined, so the number and the rows below it never appear to disagree.
class EnquiryStatCards extends StatelessWidget {
  const EnquiryStatCards({
    super.key,
    required this.stats,
    required this.state,
    required this.activeFilter,
    required this.onFilter,
    required this.onClearFilter,
  });

  final CoachingEnquiryStats stats;
  final ViewState state;
  final CoachingEnquiryStatus? activeFilter;
  final ValueChanged<CoachingEnquiryStatus> onFilter;
  final VoidCallback onClearFilter;

  /// One card per documented state, in the order the desk works through them.
  static const List<CoachingEnquiryStatus> _states = [
    CoachingEnquiryStatus.isNew,
    CoachingEnquiryStatus.contacted,
    CoachingEnquiryStatus.interested,
    CoachingEnquiryStatus.joined,
    CoachingEnquiryStatus.closed,
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        // Six cards across on a desktop, dropping to two on a phone — sized by
        // the space available rather than by a breakpoint, so the row never
        // half-wraps.
        final columns = switch (constraints.maxWidth) {
          >= 1250 => 6,
          >= 950 => 3,
          >= 560 => 3,
          _ => 2,
        };

        const spacing = AdminTokens.space4;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        final cards = <Widget>[
          SizedBox(
            width: width,
            child: state.isLoading && stats.isEmpty
                ? const StatCardShimmer()
                : StatCard(
                    label: 'Total enquiries',
                    value: stats.effectiveTotal,
                    icon: Icons.forum_outlined,
                    gradient: const [Color(0xFF1A237E), Color(0xFF5C6BC0)],
                    caption: activeFilter == null
                        ? 'Every enquiry logged'
                        : 'Showing ${activeFilter!.label} only',
                    onTap: activeFilter == null ? null : onClearFilter,
                  ),
          ),
          ..._states.map((status) {
            final selected = activeFilter == status;

            return SizedBox(
              width: width,
              child: state.isLoading && stats.isEmpty
                  ? const StatCardShimmer()
                  : _Selectable(
                      selected: selected,
                      color: tokens.enquiryStatColor(status),
                      child: StatCard(
                        label: status.label,
                        value: stats.countOf(status),
                        icon: tokens.enquiryStatIcon(status),
                        gradient: tokens.enquiryStatGradient(status),
                        caption: selected
                            ? 'Filtering the queue'
                            : 'Tap to filter',
                        progress: stats.shareOf(status),
                        onTap: () => onFilter(status),
                      ),
                    ),
            );
          }),
        ];

        return Wrap(spacing: spacing, runSpacing: spacing, children: cards);
      },
    );
  }
}

/// A ring around the card that is currently filtering the list.
class _Selectable extends StatelessWidget {
  const _Selectable({
    required this.selected,
    required this.color,
    required this.child,
  });

  final bool selected;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: AdminTokens.normal,
      curve: AdminTokens.curve,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AdminTokens.radiusLg + 3),
        border: Border.all(
          color: selected ? color : Colors.transparent,
          width: 2,
        ),
      ),
      padding: const EdgeInsets.all(2),
      child: child,
    );
  }
}

/// Card colours per state, kept beside the cards because they are only about
/// how a card looks — the badge colours live with the badge.
extension _EnquiryStatStyle on AdminTokens {
  Color enquiryStatColor(CoachingEnquiryStatus status) {
    return enquiryStatGradient(status).first;
  }

  IconData enquiryStatIcon(CoachingEnquiryStatus status) {
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
    }
  }

  List<Color> enquiryStatGradient(CoachingEnquiryStatus status) {
    switch (status) {
      case CoachingEnquiryStatus.isNew:
        return const [Color(0xFF2563EB), Color(0xFF60A5FA)];
      case CoachingEnquiryStatus.contacted:
        return const [Color(0xFFD97706), Color(0xFFFBBF24)];
      case CoachingEnquiryStatus.interested:
        return const [Color(0xFF7C3AED), Color(0xFFC4B5FD)];
      case CoachingEnquiryStatus.joined:
        return const [Color(0xFF059669), Color(0xFF6EE7B7)];
      case CoachingEnquiryStatus.closed:
        return const [Color(0xFF475569), Color(0xFF94A3B8)];
    }
  }
}
