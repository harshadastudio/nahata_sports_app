import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../providers/profile_provider.dart';
import '../../core/admin_log.dart';
import '../navigation/admin_destination.dart';
import '../theme/admin_theme.dart';

/// The bar above the content area.
///
/// Search is handed up rather than owned here: on the Users module it drives
/// the server-side query, everywhere else it is disabled with a tooltip saying
/// so, which is more honest than a box that silently does nothing.
class AdminTopBar extends StatelessWidget {
  const AdminTopBar({
    super.key,
    required this.destination,
    required this.isDark,
    required this.onToggleTheme,
    required this.onLogout,
    required this.onNotifications,
    this.notificationCount = 0,
    this.searchController,
    this.onSearchChanged,
    this.onClearSearch,
    this.searchEnabled = false,
    this.searchHint = 'Search',
    this.onMenu,
    this.compact = false,
  });

  final AdminDestination destination;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onLogout;
  final VoidCallback onNotifications;
  final int notificationCount;

  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onClearSearch;
  final bool searchEnabled;
  final String searchHint;

  /// Opens the drawer on layouts with no permanent sidebar.
  final VoidCallback? onMenu;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      height: AdminTokens.topBarHeight,
      padding: const EdgeInsets.symmetric(horizontal: AdminTokens.space5),
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          if (onMenu != null) ...[
            IconButton(
              onPressed: onMenu,
              icon: const Icon(Icons.menu_rounded),
              tooltip: 'Menu',
              color: tokens.textSecondary,
            ),
            const SizedBox(width: AdminTokens.space2),
          ],
          Expanded(
            flex: compact ? 1 : 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  compact ? destination.compactLabel : destination.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: compact ? 15 : 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    height: 1.2,
                  ),
                ),
                if (!compact)
                  Text(
                    destination.subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textMuted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
              ],
            ),
          ),
          if (!compact) ...[
            const SizedBox(width: AdminTokens.space8),
            Expanded(
              child: _SearchField(
                controller: searchController,
                onChanged: onSearchChanged,
                onClear: onClearSearch,
                enabled: searchEnabled,
                hint: searchHint,
              ),
            ),
            const SizedBox(width: AdminTokens.space5),
          ] else
            const Spacer(),
          _NotificationBell(
            count: notificationCount,
            onPressed: onNotifications,
          ),
          const SizedBox(width: AdminTokens.space1),
          _ThemeToggle(isDark: isDark, onPressed: onToggleTheme),
          const SizedBox(width: AdminTokens.space3),
          _ProfileMenu(onLogout: onLogout, compact: compact),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
    required this.enabled,
    required this.hint,
  });

  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onClear;
  final bool enabled;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final hasText = (controller?.text ?? '').isNotEmpty;

    final field = ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 460),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        enabled: enabled,
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: enabled ? tokens.textMuted : tokens.border,
          ),
          suffixIcon: hasText && enabled
              ? IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  tooltip: 'Clear',
                  color: tokens.textMuted,
                )
              : null,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AdminTokens.space4,
            vertical: AdminTokens.space3,
          ),
        ),
      ),
    );

    if (enabled) return field;

    return Tooltip(
      message: 'Search is available in Users, Roles & Permissions',
      child: field,
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({required this.count, required this.onPressed});

  final int count;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Tooltip(
      message: count > 0 ? '$count unread notifications' : 'Notifications',
      child: IconButton(
        onPressed: onPressed,
        color: tokens.textSecondary,
        icon: Stack(
          clipBehavior: Clip.none,
          children: [
            const Icon(Icons.notifications_none_rounded, size: 22),
            if (count > 0)
              Positioned(
                right: -3,
                top: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
                  constraints: const BoxConstraints(minWidth: 16),
                  decoration: BoxDecoration(
                    color: tokens.danger,
                    borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
                    border: Border.all(color: tokens.surface, width: 1.5),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle({required this.isDark, required this.onPressed});

  final bool isDark;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Tooltip(
      message: isDark ? 'Switch to light' : 'Switch to dark',
      child: IconButton(
        onPressed: onPressed,
        color: tokens.textSecondary,
        icon: AnimatedSwitcher(
          duration: AdminTokens.normal,
          transitionBuilder: (child, animation) => RotationTransition(
            turns: Tween<double>(begin: 0.6, end: 1).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Icon(
            isDark ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
            key: ValueKey<bool>(isDark),
            size: 21,
          ),
        ),
      ),
    );
  }
}

/// The signed-in admin, read from the app's existing [ProfileProvider] — the
/// dashboard does not keep a second copy of who is logged in.
class _ProfileMenu extends StatelessWidget {
  const _ProfileMenu({required this.onLogout, required this.compact});

  final VoidCallback onLogout;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final profile = context.watch<ProfileProvider>();

    final name = profile.name.isEmpty ? 'Administrator' : profile.name;
    final role = profile.role.isEmpty ? 'Admin' : profile.role;

    return PopupMenuButton<String>(
      tooltip: 'Account',
      offset: const Offset(0, 48),
      onSelected: (value) {
        AdminLog.ui('Profile menu → $value');
        if (value == 'logout') onLogout();
      },
      itemBuilder: (context) => [
        PopupMenuItem<String>(
          enabled: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (profile.email.isNotEmpty)
                Text(
                  profile.email,
                  style: TextStyle(color: tokens.textMuted, fontSize: 12),
                ),
            ],
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          value: 'logout',
          child: Row(
            children: [
              Icon(Icons.logout_rounded, size: 18, color: tokens.danger),
              const SizedBox(width: AdminTokens.space3),
              Text(
                'Log out',
                style: TextStyle(
                  color: tokens.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AdminTokens.space2,
          vertical: AdminTokens.space2,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
          border: Border.all(color: tokens.border),
          color: tokens.surfaceAlt,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 14,
              backgroundColor: tokens.accent,
              backgroundImage: profile.imageUrl == null
                  ? null
                  : NetworkImage(profile.imageUrl!),
              child: profile.imageUrl != null
                  ? null
                  : Text(
                      profile.initial,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
            if (!compact) ...[
              const SizedBox(width: AdminTokens.space2),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    Text(
                      role,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 10.5,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AdminTokens.space1),
              Icon(
                Icons.expand_more_rounded,
                size: 16,
                color: tokens.textMuted,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
