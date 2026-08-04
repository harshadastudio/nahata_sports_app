import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../navigation/admin_destination.dart';
import '../state/admin_shell_controller.dart';
import '../theme/admin_theme.dart';
import 'roles_permissions_page.dart';
import 'users_page.dart';

/// The primary module: Users on one tab, Roles & Permissions on the other.
///
/// Both tabs stay alive behind an [IndexedStack], so switching back does not
/// re-fetch a list the admin has already paged and filtered.
class UsersModulePage extends StatelessWidget {
  const UsersModulePage({super.key, this.showInlineSearch = false});

  final bool showInlineSearch;

  @override
  Widget build(BuildContext context) {
    final shell = context.watch<AdminShellController>();
    final tokens = AdminTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < AdminTokens.mobileMax;

    return ColoredBox(
      color: tokens.canvas,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: EdgeInsets.fromLTRB(
              narrow ? AdminTokens.space4 : AdminTokens.space6,
              AdminTokens.space4,
              narrow ? AdminTokens.space4 : AdminTokens.space6,
              0,
            ),
            // On a phone the two tabs cannot sit side by side at their natural
            // width, so the switcher stretches and each tab takes half.
            child: Align(
              alignment: Alignment.centerLeft,
              child: _TabSwitcher(
                current: shell.usersTab,
                onSelect: shell.openUsersTab,
                stretch: narrow,
              ),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: shell.usersTab.index,
              sizing: StackFit.expand,
              children: [
                UsersPage(showInlineSearch: showInlineSearch),
                const RolesPermissionsPage(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabSwitcher extends StatelessWidget {
  const _TabSwitcher({
    required this.current,
    required this.onSelect,
    this.stretch = false,
  });

  final UsersTab current;
  final ValueChanged<UsersTab> onSelect;

  /// Fill the available width, splitting it between the tabs.
  final bool stretch;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      width: stretch ? double.infinity : null,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
        children: UsersTab.values.map((tab) {
          final selected = tab == current;
          final button = GestureDetector(
            onTap: () => onSelect(tab),
            child: AnimatedContainer(
              duration: AdminTokens.fast,
              curve: AdminTokens.curve,
              padding: const EdgeInsets.symmetric(
                horizontal: AdminTokens.space4,
                vertical: AdminTokens.space2 + 2,
              ),
              decoration: BoxDecoration(
                color: selected ? tokens.surface : Colors.transparent,
                borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: tokens.shadow,
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    tab.icon,
                    size: 16,
                    color: selected ? tokens.accent : tokens.textMuted,
                  ),
                  const SizedBox(width: AdminTokens.space2),
                  Flexible(
                    child: Text(
                      stretch ? tab.shortLabel : tab.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected
                            ? tokens.textPrimary
                            : tokens.textSecondary,
                        fontSize: 13,
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

          return stretch ? Expanded(child: button) : button;
        }).toList(),
      ),
    );
  }
}
