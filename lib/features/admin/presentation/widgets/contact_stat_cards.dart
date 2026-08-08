import 'package:flutter/material.dart';

import '../../domain/entities/contact_inquiry.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import 'admin_states.dart';
import 'contact_status_chip.dart';
import 'stat_card.dart';

/// The four counters from `data.statusCounts`.
///
/// These come **from the payload**, never from counting the rows on screen:
/// the endpoint answers ten rows at a time, so a count derived here would say
/// "1 replied on this page" while claiming to say "1 replied".
///
/// Each state card doubles as a filter. Because the endpoint has no confirmed
/// status parameter, that filter narrows **the loaded page** — [pageScoped]
/// makes the card say so, so the number on the card and the rows beneath it are
/// never read as disagreeing.
class ContactStatCards extends StatelessWidget {
  const ContactStatCards({
    super.key,
    required this.counts,
    required this.state,
    required this.activeFilter,
    required this.onFilter,
    required this.onClearFilter,
    this.pageScoped = true,
  });

  final ContactStatusCounts counts;
  final ViewState state;
  final ContactInquiryStatus? activeFilter;
  final ValueChanged<ContactInquiryStatus> onFilter;
  final VoidCallback onClearFilter;
  final bool pageScoped;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final loading = state.isLoading && counts.isEmpty;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Sized by the space available rather than by a breakpoint, so the row
        // never half-wraps.
        final columns = switch (constraints.maxWidth) {
          >= 1000 => 4,
          >= 620 => 4,
          _ => 2,
        };

        const spacing = AdminTokens.space4;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;

        final cards = <Widget>[
          SizedBox(
            width: width,
            child: loading
                ? const StatCardShimmer()
                : StatCard(
                    label: 'Total enquiries',
                    value: counts.effectiveTotal,
                    icon: Icons.forum_outlined,
                    gradient: const [Color(0xFF1A237E), Color(0xFF5C6BC0)],
                    caption: activeFilter == null
                        ? 'Across every page'
                        : 'Showing ${activeFilter!.label} only',
                    onTap: activeFilter == null ? null : onClearFilter,
                  ),
          ),
          ...ContactInquiryStatus.values.map((status) {
            final selected = activeFilter == status;

            return SizedBox(
              width: width,
              child: loading
                  ? const StatCardShimmer()
                  : _Selectable(
                      selected: selected,
                      color: tokens.contactStatusColor(status),
                      child: StatCard(
                        label: status.label,
                        value: counts.countOf(status),
                        icon: tokens.contactStatusIcon(status),
                        gradient: tokens.contactStatusGradient(status),
                        caption: selected
                            ? (pageScoped
                                  ? 'Filtering this page'
                                  : 'Filtering the queue')
                            : 'Tap to filter',
                        progress: counts.shareOf(status),
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