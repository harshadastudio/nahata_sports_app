import 'package:flutter/material.dart';

import '../../domain/entities/paged.dart';
import '../state/admin_users_controller.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';

/// Footer controls for a server-paginated table: the range summary, the page
/// buttons and the rows-per-page selector.
///
/// The row type is irrelevant here — only the page counters are read — so this
/// takes `Paged<Object?>` and serves every table in the console.
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.page,
    required this.limit,
    required this.busy,
    required this.onPage,
    required this.onLimit,
  });

  final Paged<Object?> page;
  final int limit;
  final bool busy;
  final ValueChanged<int> onPage;
  final ValueChanged<int> onLimit;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < AdminTokens.mobileMax;

    final summary = Text(
      page.isEmpty
          ? 'No results'
          : 'Showing ${AdminFormat.number(page.firstIndex)}–'
                '${AdminFormat.number(page.lastIndex)} of '
                '${AdminFormat.number(page.total)}',
      style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
    );

    final perPage = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Rows', style: TextStyle(color: tokens.textMuted, fontSize: 12.5)),
        const SizedBox(width: AdminTokens.space2),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: AdminTokens.space3),
          decoration: BoxDecoration(
            color: tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
            border: Border.all(color: tokens.border),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int>(
              value: AdminUsersController.pageSizes.contains(limit)
                  ? limit
                  : AdminUsersController.pageSizes.first,
              isDense: true,
              borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
              dropdownColor: tokens.surface,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
              icon: Icon(
                Icons.expand_more_rounded,
                size: 16,
                color: tokens.textMuted,
              ),
              onChanged: busy
                  ? null
                  : (value) {
                      if (value != null) onLimit(value);
                    },
              items: AdminUsersController.pageSizes
                  .map(
                    (size) => DropdownMenuItem<int>(
                      value: size,
                      child: Text('$size'),
                    ),
                  )
                  .toList(),
            ),
          ),
        ),
      ],
    );

    final controls = _PageButtons(
      page: page,
      busy: busy,
      onPage: onPage,
      compact: narrow,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.space5,
        vertical: AdminTokens.space3,
      ),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: tokens.border)),
      ),
      child: narrow
          ? Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(child: summary),
                    perPage,
                  ],
                ),
                const SizedBox(height: AdminTokens.space3),
                controls,
              ],
            )
          : Row(
              children: [
                summary,
                const Spacer(),
                controls,
                const SizedBox(width: AdminTokens.space5),
                perPage,
              ],
            ),
    );
  }
}

class _PageButtons extends StatelessWidget {
  const _PageButtons({
    required this.page,
    required this.busy,
    required this.onPage,
    required this.compact,
  });

  final Paged<Object?> page;
  final bool busy;
  final ValueChanged<int> onPage;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final total = page.effectiveTotalPages;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        _ArrowButton(
          icon: Icons.chevron_left_rounded,
          tooltip: 'Previous page',
          enabled: page.hasPrevious && !busy,
          onPressed: () => onPage(page.page - 1),
        ),
        const SizedBox(width: AdminTokens.space2),
        if (compact || total <= 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AdminTokens.space3),
            child: Text(
              'Page ${page.page} of ${total == 0 ? 1 : total}',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
        else
          ..._windowFor(page.page, total).map((entry) {
            if (entry == null) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '…',
                  style: TextStyle(color: tokens.textMuted, fontSize: 13),
                ),
              );
            }
            return _PageChip(
              number: entry,
              selected: entry == page.page,
              enabled: !busy,
              onPressed: () => onPage(entry),
            );
          }),
        const SizedBox(width: AdminTokens.space2),
        _ArrowButton(
          icon: Icons.chevron_right_rounded,
          tooltip: 'Next page',
          enabled: page.hasNext && !busy,
          onPressed: () => onPage(page.page + 1),
        ),
      ],
    );
  }

  /// First, last, and the pages either side of the current one; `null` marks a
  /// gap. Keeps the control a fixed width no matter how many pages exist.
  static List<int?> _windowFor(int current, int total) {
    if (total <= 7) {
      return List<int?>.generate(total, (index) => index + 1);
    }

    final pages = <int?>{1};
    for (var page = current - 1; page <= current + 1; page++) {
      if (page > 1 && page < total) pages.add(page);
    }
    pages.add(total);

    final sorted = pages.whereType<int>().toList()..sort();
    final result = <int?>[];
    int? previous;
    for (final page in sorted) {
      if (previous != null && page - previous > 1) result.add(null);
      result.add(page);
      previous = page;
    }
    return result;
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
          child: Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
              border: Border.all(
                color: enabled ? tokens.borderStrong : tokens.border,
              ),
            ),
            child: Icon(
              icon,
              size: 18,
              color: enabled ? tokens.textSecondary : tokens.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _PageChip extends StatelessWidget {
  const _PageChip({
    required this.number,
    required this.selected,
    required this.enabled,
    required this.onPressed,
  });

  final int number;
  final bool selected;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled && !selected ? onPressed : null,
          borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
          child: AnimatedContainer(
            duration: AdminTokens.fast,
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? tokens.accent : Colors.transparent,
              borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
              border: Border.all(
                color: selected ? tokens.accent : tokens.border,
              ),
            ),
            child: Text(
              '$number',
              style: TextStyle(
                color: selected ? Colors.white : tokens.textSecondary,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
