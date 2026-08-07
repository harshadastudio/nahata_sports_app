import 'package:flutter/material.dart';

import '../../domain/entities/admin_role.dart';
import '../navigation/admin_destination.dart';
import '../navigation/admin_shell_config.dart';
import '../theme/admin_theme.dart';

/// The left rail.
///
/// One widget serves three layouts: the full 268px sidebar, the 76px collapsed
/// rail, and the same thing inside a Drawer on mobile. [collapsed] is forced
/// false in the drawer, where there is room for labels.
///
/// What it lists comes from [config]: the estate-wide ADMIN grouping by
/// default, or a permission-filtered venue-scoped one for a complex admin.
class AdminSidebar extends StatelessWidget {
  const AdminSidebar({
    super.key,
    required this.current,
    required this.onSelect,
    required this.collapsed,
    this.onToggleCollapse,
    this.showToggle = true,
    this.config = AdminShellConfig.admin,
  });

  final AdminDestination current;
  final ValueChanged<AdminDestination> onSelect;
  final bool collapsed;
  final VoidCallback? onToggleCollapse;
  final bool showToggle;
  final AdminShellConfig config;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final sections = config.visibleSections;

    return AnimatedContainer(
      duration: AdminTokens.normal,
      curve: AdminTokens.curve,
      width: collapsed
          ? AdminTokens.sidebarCollapsedWidth
          : AdminTokens.sidebarWidth,
      decoration: BoxDecoration(
        color: tokens.surface,
        border: Border(right: BorderSide(color: tokens.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Brand(
            collapsed: collapsed,
            title: config.title,
            subtitle: config.subtitle,
          ),
          Divider(height: 1, color: tokens.border),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AdminTokens.space3,
                vertical: AdminTokens.space4,
              ),
              children: [
                for (var i = 0; i < sections.length; i++) ...[
                  if (i > 0) const SizedBox(height: AdminTokens.space4),
                  if (!collapsed) _SectionLabel(sections[i].title),
                  ...sections[i].destinations.map(
                        (destination) => _NavItem(
                          destination: destination,
                          selected: current == destination,
                          collapsed: collapsed,
                          onTap: onSelect,
                        ),
                      ),
                ],
              ],
            ),
          ),
          if (showToggle) ...[
            Divider(height: 1, color: tokens.border),
            _CollapseToggle(collapsed: collapsed, onPressed: onToggleCollapse),
          ],
        ],
      ),
    );
  }

}

class _Brand extends StatelessWidget {
  const _Brand({
    required this.collapsed,
    required this.title,
    required this.subtitle,
  });

  final bool collapsed;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      height: AdminTokens.topBarHeight,
      padding: EdgeInsets.symmetric(
        horizontal: collapsed ? AdminTokens.space4 : AdminTokens.space5,
      ),
      alignment: collapsed ? Alignment.center : Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
              gradient: LinearGradient(
                colors: [tokens.accent, tokens.roleColor(AdminRole.admin)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.sports_tennis_rounded,
              size: 19,
              color: Colors.white,
            ),
          ),
          if (!collapsed) ...[
            const SizedBox(width: AdminTokens.space3),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      height: 1.2,
                    ),
                  ),
                  Text(
                    subtitle,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textMuted,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AdminTokens.space3,
        AdminTokens.space2,
        AdminTokens.space3,
        AdminTokens.space2,
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: tokens.textMuted,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.collapsed,
    required this.onTap,
  });

  final AdminDestination destination;
  final bool selected;
  final bool collapsed;
  final ValueChanged<AdminDestination> onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final destination = widget.destination;
    final selected = widget.selected;

    final foreground = selected
        ? tokens.accent
        : (_hovered ? tokens.textPrimary : tokens.textSecondary);

    final item = AnimatedContainer(
      duration: AdminTokens.fast,
      curve: AdminTokens.curve,
      margin: const EdgeInsets.only(bottom: 2),
      padding: EdgeInsets.symmetric(
        horizontal: widget.collapsed ? 0 : AdminTokens.space3,
        vertical: AdminTokens.space3,
      ),
      decoration: BoxDecoration(
        color: selected
            ? tokens.accentSoft
            : (_hovered ? tokens.surfaceAlt : Colors.transparent),
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
      ),
      child: Row(
        mainAxisAlignment: widget.collapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          // The active marker: a 3px bar that only exists when selected.
          if (!widget.collapsed)
            AnimatedContainer(
              duration: AdminTokens.fast,
              width: 3,
              height: 18,
              margin: const EdgeInsets.only(right: AdminTokens.space3),
              decoration: BoxDecoration(
                color: selected ? tokens.accent : Colors.transparent,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          Icon(
            selected ? destination.activeIcon : destination.icon,
            size: 19,
            color: foreground,
          ),
          if (!widget.collapsed) ...[
            const SizedBox(width: AdminTokens.space3),
            Expanded(
              child: Text(
                destination.compactLabel,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  height: 1.2,
                ),
              ),
            ),
            if (destination.primary && !selected)
              Icon(Icons.star_rounded, size: 14, color: tokens.warning),
            if (!destination.ready) const _SoonPill(),
          ],
        ],
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () => widget.onTap(destination),
        behavior: HitTestBehavior.opaque,
        child: widget.collapsed
            ? Tooltip(message: destination.label, child: item)
            : item,
      ),
    );
  }
}

class _SoonPill extends StatelessWidget {
  const _SoonPill();

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
        border: Border.all(color: tokens.border),
      ),
      child: Text(
        'Soon',
        style: TextStyle(
          color: tokens.textMuted,
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _CollapseToggle extends StatelessWidget {
  const _CollapseToggle({required this.collapsed, this.onPressed});

  final bool collapsed;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Padding(
      padding: const EdgeInsets.all(AdminTokens.space3),
      child: Tooltip(
        message: collapsed ? 'Expand sidebar' : 'Collapse sidebar',
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AdminTokens.space3,
              vertical: AdminTokens.space3,
            ),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  collapsed
                      ? Icons.keyboard_double_arrow_right_rounded
                      : Icons.keyboard_double_arrow_left_rounded,
                  size: 18,
                  color: tokens.textMuted,
                ),
                if (!collapsed) ...[
                  const SizedBox(width: AdminTokens.space3),
                  Text(
                    'Collapse',
                    style: TextStyle(
                      color: tokens.textMuted,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
