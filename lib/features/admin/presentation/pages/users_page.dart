import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/admin_user.dart';
import '../state/admin_users_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dialogs.dart';
import '../widgets/admin_states.dart';
import '../widgets/glass_card.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/user_detail_drawer.dart';
import '../widgets/user_form_dialog.dart';
import '../widgets/users_table.dart';

/// Users management: the table, its filters, and the four write actions.
///
/// The search box lives in the top app bar on wide layouts (it drives this
/// controller) and moves into the toolbar when the bar is compact.
class UsersPage extends StatefulWidget {
  const UsersPage({super.key, this.showInlineSearch = false});

  /// True when the top bar is too narrow to host the search field.
  final bool showInlineSearch;

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    AdminLog.life('UsersPage mounted');
    _search = TextEditingController(
      text: context.read<AdminUsersController>().search,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<AdminUsersController>();
      if (controller.state.isIdle) controller.load();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    AdminLog.life('UsersPage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AdminUsersController>();
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < AdminTokens.mobileMax;
    final isDesktop = width >= AdminTokens.tabletMax;

    // Keep the inline field in step with programmatic clears. Deferred past
    // the current frame so writing to the controller cannot mark the TextField
    // dirty while this subtree is still building.
    if (_search.text != controller.search) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _search.text == controller.search) return;
        _search.value = TextEditingValue(
          text: controller.search,
          selection: TextSelection.collapsed(offset: controller.search.length),
        );
      });
    }

    final selected = controller.selected;

    final table = Padding(
      padding: EdgeInsets.all(
        isMobile ? AdminTokens.space4 : AdminTokens.space6,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Toolbar(
            controller: controller,
            searchController: _search,
            showSearch: widget.showInlineSearch,
            onAdd: () => _openForm(context, controller),
          ),
          const SizedBox(height: AdminTokens.space4),
          Expanded(
            child: SolidCard(
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    RefreshLine(visible: controller.isRefreshing),
                    Expanded(
                      child: _TableBody(
                        controller: controller,
                        isMobile: isMobile,
                        onAdd: () => _openForm(context, controller),
                        onAction: (action, user) =>
                            _handleAction(context, controller, action, user),
                      ),
                    ),
                    if (controller.page.isNotEmpty || controller.page.page > 1)
                      PaginationBar(
                        page: controller.page,
                        limit: controller.limit,
                        busy: controller.state.isLoading,
                        onPage: controller.goToPage,
                        onLimit: controller.setLimit,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );

    // On desktop the detail panel sits beside the table; anywhere narrower it
    // is presented as a modal sheet from `_handleAction`.
    if (!isDesktop || selected == null) return table;

    return Row(
      children: [
        Expanded(child: table),
        AnimatedContainer(
          duration: AdminTokens.normal,
          curve: AdminTokens.curve,
          width: AdminTokens.detailDrawerWidth,
          decoration: BoxDecoration(
            color: AdminTheme.of(context).canvas,
            border: Border(
              left: BorderSide(color: AdminTheme.of(context).border),
            ),
          ),
          child: UserDetailPanel(
            user: selected,
            state: controller.detailState,
            error: controller.detailError,
            onClose: controller.closeUser,
            onRetry: () => controller.openUser(selected),
            onAction: (action, user) =>
                _handleAction(context, controller, action, user),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _handleAction(
    BuildContext context,
    AdminUsersController controller,
    UserRowAction action,
    AdminUser user,
  ) async {
    switch (action) {
      case UserRowAction.view:
        // Not awaited: the panel opens straight away showing the row we already
        // have, and fills in when `GET /admin/users/{id}` lands.
        unawaited(controller.openUser(user));
        // Wide layouts already show the panel inline beside the table.
        if (MediaQuery.sizeOf(context).width < AdminTokens.tabletMax) {
          await _showDetailSheet(context, controller);
        }
      case UserRowAction.edit:
        await _openForm(context, controller, user: user);
      case UserRowAction.delete:
        await _confirmDelete(context, controller, user);
    }
  }

  Future<void> _showDetailSheet(
    BuildContext context,
    AdminUsersController controller,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminTheme.of(context).canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AdminTokens.radiusXl),
        ),
      ),
      builder: (sheetContext) {
        // Rebuilds with the controller so the sheet fills in when the detail
        // request lands.
        return ChangeNotifierProvider<AdminUsersController>.value(
          value: controller,
          child: Consumer<AdminUsersController>(
            builder: (context, live, _) {
              final user = live.selected;
              if (user == null) return const SizedBox.shrink();

              return SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.88,
                child: UserDetailPanel(
                  user: user,
                  state: live.detailState,
                  error: live.detailError,
                  onClose: () => Navigator.of(sheetContext).pop(),
                  onRetry: () => live.openUser(user),
                  onAction: (action, target) async {
                    Navigator.of(sheetContext).pop();
                    if (!context.mounted) return;
                    await _handleAction(context, live, action, target);
                  },
                ),
              );
            },
          ),
        );
      },
    ).whenComplete(controller.closeUser);
  }

  Future<void> _openForm(
    BuildContext context,
    AdminUsersController controller, {
    AdminUser? user,
  }) async {
    final saved = await UserFormDialog.show(
      context,
      user: user,
      knownMemberships: controller.knownMemberships,
      knownDepartments: controller.knownDepartments,
      knownSports: controller.knownSports,
      knownLocations: controller.knownLocations,
      onSubmit: (draft) async {
        if (user == null) {
          await controller.createUser(draft);
        } else {
          await controller.updateUser(user.id, draft);
        }
      },
    );

    if (!saved || !context.mounted) return;

    AdminFeedback.success(
      context,
      user == null
          ? 'User created and the list has been refreshed.'
          : 'Changes to ${user.displayName} were saved.',
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    AdminUsersController controller,
    AdminUser user,
  ) async {
    final tokens = AdminTheme.of(context);

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete this user?',
      message:
          'This removes the account and its access to the platform. '
          'This cannot be undone.',
      confirmLabel: 'Delete user',
      destructive: true,
      detail: SolidCard(
        padding: const EdgeInsets.all(AdminTokens.space3),
        color: tokens.surfaceAlt,
        radius: AdminTokens.radiusMd,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    user.displayName,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${user.roleLabel} · ${user.email ?? user.id}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tokens.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );

    if (!confirmed || !context.mounted) return;

    try {
      await controller.deleteUser(user.id);
      if (!context.mounted) return;
      AdminFeedback.success(context, '${user.displayName} was deleted.');
    } catch (error) {
      if (!context.mounted) return;
      AdminFeedback.error(
        context,
        error is Exception ? _messageOf(error) : 'Could not delete this user.',
      );
    }
  }

  static String _messageOf(Object error) {
    // ApiException carries a user-facing `message`; anything else falls back.
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.isEmpty ? 'Could not delete this user.' : text;
  }
}

// -----------------------------------------------------------------------------
// Toolbar
// -----------------------------------------------------------------------------

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.searchController,
    required this.showSearch,
    required this.onAdd,
  });

  final AdminUsersController controller;
  final TextEditingController searchController;
  final bool showSearch;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < AdminTokens.tabletMax;

    final filters = <Widget>[
      if (showSearch)
        SizedBox(
          width: narrow ? double.infinity : 280,
          child: TextField(
            controller: searchController,
            onChanged: controller.onSearchChanged,
            style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search name, email or phone',
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 18,
                color: tokens.textMuted,
              ),
              suffixIcon: controller.search.isEmpty
                  ? null
                  : IconButton(
                      onPressed: controller.clearSearch,
                      icon: const Icon(Icons.close_rounded, size: 16),
                      color: tokens.textMuted,
                      tooltip: 'Clear',
                    ),
            ),
          ),
        ),
      _FilterDropdown<AdminRole>(
        label: 'All roles',
        icon: Icons.shield_outlined,
        value: controller.roleFilter,
        onChanged: controller.setRoleFilter,
        items: AdminRole.values
            .map(
              (role) => DropdownMenuItem<AdminRole>(
                value: role,
                child: Text(role.label),
              ),
            )
            .toList(),
      ),
      _FilterDropdown<AdminUserStatus>(
        label: 'All statuses',
        icon: Icons.toggle_on_outlined,
        value: controller.statusFilter,
        onChanged: controller.setStatusFilter,
        items: AdminUserStatus.values
            .map(
              (status) => DropdownMenuItem<AdminUserStatus>(
                value: status,
                child: Text(status.label),
              ),
            )
            .toList(),
      ),
      if (controller.hasFilters)
        TextButton.icon(
          onPressed: controller.clearFilters,
          icon: const Icon(Icons.filter_alt_off_outlined, size: 17),
          label: const Text('Clear filters'),
        ),
    ];

    final actions = <Widget>[
      OutlinedButton.icon(
        onPressed: controller.state.isLoading ? null : controller.refresh,
        icon: controller.state.isLoading
            ? const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.refresh_rounded, size: 18),
        label: const Text('Refresh'),
      ),
      FilledButton.icon(
        onPressed: onAdd,
        icon: const Icon(Icons.add_rounded, size: 19),
        label: const Text('Add user'),
      ),
    ];

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: AdminTokens.space3,
            runSpacing: AdminTokens.space3,
            children: filters,
          ),
          const SizedBox(height: AdminTokens.space3),
          Row(
            children: [
              Expanded(child: actions.first),
              const SizedBox(width: AdminTokens.space3),
              Expanded(child: actions.last),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: AdminTokens.space3,
            runSpacing: AdminTokens.space3,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: filters,
          ),
        ),
        const SizedBox(width: AdminTokens.space4),
        actions.first,
        const SizedBox(width: AdminTokens.space3),
        actions.last,
      ],
    );
  }
}

/// A dropdown whose null value means "no filter".
class _FilterDropdown<T> extends StatelessWidget {
  const _FilterDropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.onChanged,
    required this.items,
  });

  final String label;
  final IconData icon;
  final T? value;
  final ValueChanged<T?> onChanged;
  final List<DropdownMenuItem<T>> items;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final active = value != null;

    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: AdminTokens.space3),
      decoration: BoxDecoration(
        color: active ? tokens.accentSoft : tokens.surface,
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: active ? tokens.accent : tokens.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: value,
          isDense: true,
          borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
          dropdownColor: tokens.surface,
          hint: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: tokens.textMuted),
              const SizedBox(width: AdminTokens.space2),
              Text(
                label,
                style: TextStyle(color: tokens.textSecondary, fontSize: 13),
              ),
            ],
          ),
          icon: Icon(
            Icons.expand_more_rounded,
            size: 17,
            color: active ? tokens.accent : tokens.textMuted,
          ),
          style: TextStyle(
            color: active ? tokens.accent : tokens.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          onChanged: onChanged,
          items: [
            DropdownMenuItem<T?>(
              value: null,
              child: Text(label, style: TextStyle(color: tokens.textSecondary)),
            ),
            ...items.map(
              (item) =>
                  DropdownMenuItem<T?>(value: item.value, child: item.child),
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Table body: shimmer / error / empty / rows
// -----------------------------------------------------------------------------

class _TableBody extends StatelessWidget {
  const _TableBody({
    required this.controller,
    required this.isMobile,
    required this.onAdd,
    required this.onAction,
  });

  final AdminUsersController controller;
  final bool isMobile;
  final VoidCallback onAdd;
  final void Function(UserRowAction action, AdminUser user) onAction;

  @override
  Widget build(BuildContext context) {
    if (controller.isFirstLoad) {
      return SingleChildScrollView(
        child: TableShimmer(rows: 8, dense: isMobile),
      );
    }

    if (controller.state.isFailed) {
      return ErrorStateView(
        title: 'Could not load users',
        message:
            controller.error ??
            'The server did not return a user list. Check your connection '
                'and try again.',
        onRetry: controller.refresh,
      );
    }

    final users = controller.users;

    if (users.isEmpty) {
      return controller.hasFilters
          ? EmptyStateView(
              icon: Icons.search_off_rounded,
              title: 'No users match these filters',
              message:
                  'Try a different search term, or clear the filters to '
                  'see every account.',
              actionLabel: 'Clear filters',
              onAction: controller.clearFilters,
            )
          : EmptyStateView(
              icon: Icons.group_add_outlined,
              title: 'No users yet',
              message:
                  'Create the first account to start managing access to '
                  'the platform.',
              actionLabel: 'Add user',
              onAction: onAdd,
              secondaryLabel: 'Refresh',
              onSecondary: controller.refresh,
            );
    }

    if (isMobile) {
      return ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: users.length,
        itemBuilder: (context, index) =>
            UserCard(user: users[index], onAction: onAction),
      );
    }

    return SingleChildScrollView(
      child: UsersTable(
        users: users,
        sort: controller.sort,
        descending: controller.descending,
        onSort: controller.toggleSort,
        onAction: onAction,
        selectedId: controller.selected?.id,
      ),
    );
  }
}
