import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/role_permissions.dart';
import '../state/admin_roles_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dialogs.dart';
import '../widgets/admin_states.dart';
import '../widgets/glass_card.dart';

/// Roles & Permissions.
///
/// Left: the six roles. Right: that role's permission catalogue as toggle
/// cards, grouped by module. Save is disabled until a toggle actually differs
/// from what the server last confirmed.
class RolesPermissionsPage extends StatefulWidget {
  const RolesPermissionsPage({super.key});

  @override
  State<RolesPermissionsPage> createState() => _RolesPermissionsPageState();
}

class _RolesPermissionsPageState extends State<RolesPermissionsPage> {
  @override
  void initState() {
    super.initState();
    AdminLog.life('RolesPermissionsPage mounted');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<AdminRolesController>();
      if (controller.state.isIdle) controller.load();
    });
  }

  @override
  void dispose() {
    AdminLog.life('RolesPermissionsPage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AdminRolesController>();
    final width = MediaQuery.sizeOf(context).width;
    final stacked = width < AdminTokens.tabletMax;

    final rolePicker = _RolePicker(
      selected: controller.role,
      horizontal: stacked,
      onSelect: (role) => controller.selectRole(role),
    );

    final detail = _PermissionsPanel(
      controller: controller,
      onSave: () => _save(context, controller),
    );

    return Padding(
      padding: EdgeInsets.all(
        stacked ? AdminTokens.space4 : AdminTokens.space6,
      ),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                rolePicker,
                const SizedBox(height: AdminTokens.space4),
                Expanded(child: detail),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 260, child: rolePicker),
                const SizedBox(width: AdminTokens.space5),
                Expanded(child: detail),
              ],
            ),
    );
  }

  Future<void> _save(
    BuildContext context,
    AdminRolesController controller,
  ) async {
    final saved = await controller.save();
    if (!context.mounted) return;

    if (saved) {
      AdminFeedback.success(
        context,
        'Permissions for ${controller.role.label} were updated.',
      );
    } else {
      AdminFeedback.error(
        context,
        controller.saveError ?? 'Could not save these permissions.',
      );
    }
  }
}

// -----------------------------------------------------------------------------
// Role picker
// -----------------------------------------------------------------------------

class _RolePicker extends StatelessWidget {
  const _RolePicker({
    required this.selected,
    required this.onSelect,
    required this.horizontal,
  });

  final AdminRole selected;
  final ValueChanged<AdminRole> onSelect;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    if (horizontal) {
      return SizedBox(
        height: 44,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: AdminRole.permissionManaged.length,
          separatorBuilder: (_, __) =>
              const SizedBox(width: AdminTokens.space2),
          itemBuilder: (context, index) {
            final role = AdminRole.permissionManaged[index];
            return _RolePill(
              role: role,
              selected: role == selected,
              onTap: () => onSelect(role),
            );
          },
        ),
      );
    }

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AdminTokens.space2,
              AdminTokens.space2,
              AdminTokens.space2,
              AdminTokens.space3,
            ),
            child: Text(
              'ROLES',
              style: TextStyle(
                color: tokens.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
          ...AdminRole.permissionManaged.map(
            (role) => _RoleTile(
              role: role,
              selected: role == selected,
              onTap: () => onSelect(role),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AdminTokens.space2,
              AdminTokens.space3,
              AdminTokens.space2,
              AdminTokens.space2,
            ),
            child: Text(
              // Said plainly, so a missing role reads as a backend rule rather
              // than a bug in this screen.
              'Admin and Complex Admin are not managed here — the permissions '
              'endpoint accepts these four roles only.',
              style: TextStyle(
                color: tokens.textMuted,
                fontSize: 11,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoleTile extends StatefulWidget {
  const _RoleTile({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final AdminRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  State<_RoleTile> createState() => _RoleTileState();
}

class _RoleTileState extends State<_RoleTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final color = tokens.roleColor(widget.role);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AdminTokens.fast,
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(
            horizontal: AdminTokens.space3,
            vertical: AdminTokens.space3,
          ),
          decoration: BoxDecoration(
            color: widget.selected
                ? color.withValues(alpha: 0.1)
                : (_hovered ? tokens.surfaceAlt : Colors.transparent),
            borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
            border: Border.all(
              color: widget.selected
                  ? color.withValues(alpha: 0.35)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                child: Text(
                  widget.role.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: widget.selected ? color : tokens.textSecondary,
                    fontSize: 13.5,
                    fontWeight: widget.selected
                        ? FontWeight.w700
                        : FontWeight.w500,
                  ),
                ),
              ),
              if (widget.selected)
                Icon(Icons.chevron_right_rounded, size: 17, color: color),
            ],
          ),
        ),
      ),
    );
  }
}

class _RolePill extends StatelessWidget {
  const _RolePill({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final AdminRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final color = tokens.roleColor(role);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AdminTokens.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AdminTokens.space4,
          vertical: AdminTokens.space3,
        ),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.12) : tokens.surface,
          borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
          border: Border.all(color: selected ? color : tokens.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: AdminTokens.space2),
            Text(
              role.label,
              style: TextStyle(
                color: selected ? color : tokens.textSecondary,
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Permissions panel
// -----------------------------------------------------------------------------

class _PermissionsPanel extends StatelessWidget {
  const _PermissionsPanel({required this.controller, required this.onSave});

  final AdminRolesController controller;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PanelHeader(controller: controller),
            RefreshLine(visible: controller.state.isLoading),
            Expanded(child: _PanelBody(controller: controller)),
            if (controller.state.isReady)
              Container(
                padding: const EdgeInsets.all(AdminTokens.space4),
                decoration: BoxDecoration(
                  color: tokens.surfaceAlt,
                  border: Border(top: BorderSide(color: tokens.border)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: AdminTokens.fast,
                        child: controller.isDirty
                            ? Row(
                                key: const ValueKey('dirty'),
                                children: [
                                  Icon(
                                    Icons.edit_note_rounded,
                                    size: 17,
                                    color: tokens.warning,
                                  ),
                                  const SizedBox(width: AdminTokens.space2),
                                  Flexible(
                                    child: Text(
                                      'Unsaved changes',
                                      style: TextStyle(
                                        color: tokens.warning,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : Text(
                                key: const ValueKey('clean'),
                                'All changes saved',
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 12.5,
                                ),
                              ),
                      ),
                    ),
                    TextButton(
                      // Disabled until there is something to discard.
                      onPressed: controller.isDirty && !controller.isSaving
                          ? controller.discard
                          : null,
                      child: const Text('Discard'),
                    ),
                    const SizedBox(width: AdminTokens.space3),
                    FilledButton.icon(
                      onPressed: controller.isDirty && !controller.isSaving
                          ? onSave
                          : null,
                      icon: controller.isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Save changes'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PanelHeader extends StatelessWidget {
  const _PanelHeader({required this.controller});

  final AdminRolesController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final color = tokens.roleColor(controller.role);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space5),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
              color: color.withValues(alpha: 0.12),
            ),
            child: Icon(Icons.key_rounded, size: 20, color: color),
          ),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  controller.role.label,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  controller.state.isReady
                      ? '${controller.grantedCount} of ${controller.totalCount} '
                            'permissions granted'
                      : 'Loading permissions…',
                  style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: controller.state.isLoading ? null : controller.refresh,
            icon: const Icon(Icons.refresh_rounded, size: 19),
            tooltip: 'Reload permissions',
            color: tokens.textMuted,
          ),
        ],
      ),
    );
  }
}

class _PanelBody extends StatelessWidget {
  const _PanelBody({required this.controller});

  final AdminRolesController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.state.isLoading && controller.permissions == null) {
      return const _PermissionsShimmer();
    }

    if (controller.state.isFailed) {
      return ErrorStateView(
        title: 'Could not load permissions',
        message:
            controller.error ??
            'The server did not return a permission list for this role.',
        onRetry: controller.refresh,
      );
    }

    final permissions = controller.permissions;
    if (permissions == null || permissions.catalogue.isEmpty) {
      return EmptyStateView(
        icon: Icons.lock_open_rounded,
        title: 'No permissions defined',
        message:
            'The backend has not published a permission catalogue for '
            '${controller.role.label}. Once it does, the toggles appear here.',
        actionLabel: 'Reload',
        onAction: controller.refresh,
      );
    }

    final groups = permissions.grouped;
    final groupNames = groups.keys.toList()..sort();

    return ListView.separated(
      padding: const EdgeInsets.all(AdminTokens.space5),
      itemCount: groupNames.length,
      separatorBuilder: (_, __) => const SizedBox(height: AdminTokens.space4),
      itemBuilder: (context, index) {
        final name = groupNames[index];
        final slugs = groups[name]!;
        return _PermissionGroup(
          name: name,
          slugs: slugs,
          permissions: permissions,
          onToggle: controller.toggle,
          onToggleAll: (value) => controller.toggleGroup(name, value),
        );
      },
    );
  }
}

class _PermissionGroup extends StatelessWidget {
  const _PermissionGroup({
    required this.name,
    required this.slugs,
    required this.permissions,
    required this.onToggle,
    required this.onToggleAll,
  });

  final String name;
  final List<String> slugs;
  final RolePermissions permissions;
  final void Function(String slug, bool value) onToggle;
  final ValueChanged<bool> onToggleAll;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final grantedInGroup = slugs.where(permissions.isGranted).length;
    final allGranted = grantedInGroup == slugs.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              name,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: AdminTokens.space2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: tokens.surfaceAlt,
                borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
                border: Border.all(color: tokens.border),
              ),
              child: Text(
                '$grantedInGroup/${slugs.length}',
                style: TextStyle(
                  color: tokens.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Spacer(),
            TextButton(
              onPressed: () => onToggleAll(!allGranted),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: AdminTokens.space2,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                allGranted ? 'Revoke all' : 'Grant all',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        const SizedBox(height: AdminTokens.space3),
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = AdminTokens.space3;
            final columns = constraints.maxWidth > 900
                ? 3
                : (constraints.maxWidth > 560 ? 2 : 1);
            final width =
                (constraints.maxWidth - (gap * (columns - 1))) / columns;

            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: slugs
                  .map(
                    (slug) => SizedBox(
                      width: width,
                      child: _PermissionToggle(
                        slug: slug,
                        granted: permissions.isGranted(slug),
                        onChanged: (value) => onToggle(slug, value),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }
}

class _PermissionToggle extends StatelessWidget {
  const _PermissionToggle({
    required this.slug,
    required this.granted,
    required this.onChanged,
  });

  final String slug;
  final bool granted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return HoverLift(
      onTap: () => onChanged(!granted),
      builder: (context, hovered) {
        return AnimatedContainer(
          duration: AdminTokens.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AdminTokens.space3,
            vertical: AdminTokens.space3,
          ),
          decoration: BoxDecoration(
            color: granted ? tokens.accentSoft : tokens.surface,
            borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
            border: Border.all(
              color: granted
                  ? tokens.accent.withValues(alpha: 0.4)
                  : (hovered ? tokens.borderStrong : tokens.border),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      RolePermissions.labelFor(slug),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: granted ? tokens.accent : tokens.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      slug,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 10.5,
                        fontFamily: 'monospace',
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AdminTokens.space2),
              Transform.scale(
                scale: 0.78,
                child: Switch(value: granted, onChanged: onChanged),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PermissionsShimmer extends StatelessWidget {
  const _PermissionsShimmer();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AdminTokens.space5),
      children: List.generate(3, (group) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AdminTokens.space6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const ShimmerBox(width: 130, height: 14),
              const SizedBox(height: AdminTokens.space3),
              Wrap(
                spacing: AdminTokens.space3,
                runSpacing: AdminTokens.space3,
                children: List.generate(
                  4,
                  (_) => const ShimmerBox(
                    width: 240,
                    height: 54,
                    radius: AdminTokens.radiusMd,
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
