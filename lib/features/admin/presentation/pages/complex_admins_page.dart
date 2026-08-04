import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/complex_admin.dart';
import '../state/complex_admins_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dialogs.dart';
import '../widgets/admin_states.dart';
import '../widgets/complex_admin_detail_panel.dart';
import '../widgets/complex_admin_form_dialog.dart';
import '../widgets/complex_admins_table.dart';
import '../widgets/glass_card.dart';
import '../widgets/pagination_bar.dart';

/// Complex Admin: the list, its search, and the three write actions.
class ComplexAdminsPage extends StatefulWidget {
  const ComplexAdminsPage({super.key});

  @override
  State<ComplexAdminsPage> createState() => _ComplexAdminsPageState();
}

class _ComplexAdminsPageState extends State<ComplexAdminsPage> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    AdminLog.life('ComplexAdminsPage mounted');
    _search = TextEditingController(
      text: context.read<ComplexAdminsController>().search,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<ComplexAdminsController>();
      if (controller.state.isIdle) controller.load();
      // Warmed here so the Add dialog opens with its dropdown already filled.
      controller.loadComplexes();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    AdminLog.life('ComplexAdminsPage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ComplexAdminsController>();
    final tokens = AdminTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < AdminTokens.mobileMax;
    final isDesktop = width >= AdminTokens.tabletMax;

    // Deferred past this frame: writing to the controller mid-build would mark
    // the TextField dirty while its ancestor is still building.
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

    final list = ColoredBox(
      color: tokens.canvas,
      child: Padding(
        padding: EdgeInsets.all(
          isMobile ? AdminTokens.space4 : AdminTokens.space6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Toolbar(
              controller: controller,
              searchController: _search,
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
                        child: _Body(
                          controller: controller,
                          isMobile: isMobile,
                          onAdd: () => _openForm(context, controller),
                          onAction: (action, admin) =>
                              _handleAction(context, controller, action, admin),
                        ),
                      ),
                      if (controller.page.isNotEmpty ||
                          controller.page.page > 1)
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
      ),
    );

    if (!isDesktop || selected == null) return list;

    return Row(
      children: [
        Expanded(child: list),
        AnimatedContainer(
          duration: AdminTokens.normal,
          curve: AdminTokens.curve,
          width: AdminTokens.detailDrawerWidth,
          decoration: BoxDecoration(
            color: tokens.canvas,
            border: Border(left: BorderSide(color: tokens.border)),
          ),
          child: ComplexAdminDetailPanel(
            admin: selected,
            onClose: controller.clearSelection,
            onAction: (action, admin) =>
                _handleAction(context, controller, action, admin),
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
    ComplexAdminsController controller,
    ComplexAdminAction action,
    ComplexAdmin admin,
  ) async {
    switch (action) {
      case ComplexAdminAction.view:
        controller.select(admin);
        if (MediaQuery.sizeOf(context).width < AdminTokens.tabletMax) {
          await _showDetailSheet(context, controller);
        }
      case ComplexAdminAction.edit:
        await _openForm(context, controller, admin: admin);
      case ComplexAdminAction.delete:
        await _confirmDelete(context, controller, admin);
    }
  }

  Future<void> _showDetailSheet(
    BuildContext context,
    ComplexAdminsController controller,
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
        return ChangeNotifierProvider<ComplexAdminsController>.value(
          value: controller,
          child: Consumer<ComplexAdminsController>(
            builder: (context, live, _) {
              final admin = live.selected;
              if (admin == null) return const SizedBox.shrink();

              return SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.85,
                child: ComplexAdminDetailPanel(
                  admin: admin,
                  onClose: () => Navigator.of(sheetContext).pop(),
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
    ).whenComplete(controller.clearSelection);
  }

  Future<void> _openForm(
    BuildContext context,
    ComplexAdminsController controller, {
    ComplexAdmin? admin,
  }) async {
    // The picker needs its options before the dialog is useful.
    if (controller.complexes.isEmpty && !controller.complexesState.isLoading) {
      await controller.loadComplexes();
    }
    if (!context.mounted) return;

    final saved = await ComplexAdminFormDialog.show(
      context,
      admin: admin,
      complexes: controller.complexes,
      complexesState: controller.complexesState,
      onReloadComplexes: () => controller.loadComplexes(refresh: true),
      onSubmit: (draft) async {
        if (admin == null) {
          await controller.create(draft);
        } else {
          await controller.update(admin.id, draft);
        }
      },
    );

    if (!saved || !context.mounted) return;

    AdminFeedback.success(
      context,
      admin == null
          ? 'Complex admin created and the list has been refreshed.'
          : 'Changes to ${admin.displayName} were saved.',
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    ComplexAdminsController controller,
    ComplexAdmin admin,
  ) async {
    final tokens = AdminTheme.of(context);

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete this complex admin?',
      message:
          'This removes the account and its access to '
          '${admin.sportComplexName ?? 'the assigned complex'}. '
          'This cannot be undone.',
      confirmLabel: 'Delete admin',
      destructive: true,
      detail: SolidCard(
        padding: const EdgeInsets.all(AdminTokens.space3),
        color: tokens.surfaceAlt,
        radius: AdminTokens.radiusMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              admin.displayName,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              admin.venueLabel.isEmpty
                  ? (admin.email ?? admin.id)
                  : '${admin.email ?? admin.id} · ${admin.venueLabel}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tokens.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );

    if (!confirmed || !context.mounted) return;

    try {
      await controller.delete(admin.id);
      if (!context.mounted) return;
      AdminFeedback.success(context, '${admin.displayName} was deleted.');
    } catch (error) {
      if (!context.mounted) return;
      AdminFeedback.error(context, _messageOf(error));
    }
  }

  static String _messageOf(Object error) {
    // ApiException.toString() carries the user-facing message.
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.isEmpty ? 'Could not delete this complex admin.' : text;
  }
}

// -----------------------------------------------------------------------------
// Toolbar
// -----------------------------------------------------------------------------

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.searchController,
    required this.onAdd,
  });

  final ComplexAdminsController controller;
  final TextEditingController searchController;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < AdminTokens.tabletMax;

    final search = SizedBox(
      width: narrow ? double.infinity : 320,
      child: TextField(
        controller: searchController,
        onChanged: controller.onSearchChanged,
        style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search name, email or complex',
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
    );

    final refresh = OutlinedButton.icon(
      onPressed: controller.state.isLoading ? null : controller.refresh,
      icon: controller.state.isLoading
          ? const SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.refresh_rounded, size: 18),
      label: const Text('Refresh'),
    );

    final add = FilledButton.icon(
      onPressed: onAdd,
      icon: const Icon(Icons.add_rounded, size: 19),
      label: const Text('Add Complex Admin'),
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          search,
          const SizedBox(height: AdminTokens.space3),
          Row(
            children: [
              Expanded(child: refresh),
              const SizedBox(width: AdminTokens.space3),
              Expanded(flex: 2, child: add),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        search,
        const Spacer(),
        refresh,
        const SizedBox(width: AdminTokens.space3),
        add,
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Body
// -----------------------------------------------------------------------------

class _Body extends StatelessWidget {
  const _Body({
    required this.controller,
    required this.isMobile,
    required this.onAdd,
    required this.onAction,
  });

  final ComplexAdminsController controller;
  final bool isMobile;
  final VoidCallback onAdd;
  final void Function(ComplexAdminAction action, ComplexAdmin admin) onAction;

  @override
  Widget build(BuildContext context) {
    if (controller.isFirstLoad) {
      return SingleChildScrollView(
        child: TableShimmer(rows: 7, dense: isMobile),
      );
    }

    if (controller.state.isFailed) {
      return ErrorStateView(
        title: 'Could not load complex admins',
        message:
            controller.error ??
            'The server did not return a list. Check your connection and '
                'try again.',
        onRetry: controller.refresh,
      );
    }

    final admins = controller.admins;

    if (admins.isEmpty) {
      return controller.hasFilters
          ? EmptyStateView(
              icon: Icons.search_off_rounded,
              title: 'No complex admins match this search',
              message:
                  'Try a different term, or clear the search to see '
                  'everyone.',
              actionLabel: 'Clear search',
              onAction: controller.clearSearch,
            )
          : EmptyStateView(
              icon: Icons.admin_panel_settings_outlined,
              title: 'No complex admins yet',
              message:
                  'Add one to give a manager control over a single '
                  'sports complex.',
              actionLabel: 'Add Complex Admin',
              onAction: onAdd,
              secondaryLabel: 'Refresh',
              onSecondary: controller.refresh,
            );
    }

    if (isMobile) {
      return ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: admins.length,
        itemBuilder: (context, index) =>
            ComplexAdminCard(admin: admins[index], onAction: onAction),
      );
    }

    return SingleChildScrollView(
      child: ComplexAdminsTable(
        admins: admins,
        onAction: onAction,
        selectedId: controller.selected?.id,
      ),
    );
  }
}
