import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/employee.dart';
import '../state/employees_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dialogs.dart';
import '../widgets/admin_states.dart';
import '../widgets/employee_detail_panel.dart';
import '../widgets/employee_filter_sheet.dart';
import '../widgets/employee_form_dialog.dart';
import '../widgets/employee_password_dialogs.dart';
import '../widgets/employees_table.dart';
import '../widgets/glass_card.dart';
import '../widgets/pagination_bar.dart';

/// Employee management: the list, its header, and every write action.
class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    AdminLog.life('EmployeesPage mounted');
    _search = TextEditingController(
      text: context.read<EmployeesController>().search,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<EmployeesController>();
      if (controller.state.isIdle) controller.load();
      // Warmed here so the Add dialog and the complex filter both open ready.
      controller.loadComplexes();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    AdminLog.life('EmployeesPage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EmployeesController>();
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
            _Header(
              controller: controller,
              searchController: _search,
              onAdd: () => _openForm(context, controller),
            ),
            if (controller.activeFilterCount > 0) ...[
              const SizedBox(height: AdminTokens.space3),
              _ActiveFilters(controller: controller),
            ],
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
                          onAction: (action, employee) => _handleAction(
                            context,
                            controller,
                            action,
                            employee,
                          ),
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
          child: EmployeeDetailPanel(
            employee: selected,
            state: controller.detailState,
            error: controller.detailError,
            onClose: controller.closeEmployee,
            onRetry: () => controller.openEmployee(selected),
            onAction: (action, employee) =>
                _handleAction(context, controller, action, employee),
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
    EmployeesController controller,
    EmployeeAction action,
    Employee employee,
  ) async {
    switch (action) {
      case EmployeeAction.view:
        // Not awaited: the panel opens with the row already in hand and fills
        // in when the detail read lands.
        unawaited(controller.openEmployee(employee));
        if (MediaQuery.sizeOf(context).width < AdminTokens.tabletMax) {
          await _showDetailSheet(context, controller);
        }
      case EmployeeAction.edit:
        await _openForm(context, controller, employee: employee);
      case EmployeeAction.delete:
        await _confirmDelete(context, controller, employee);
      case EmployeeAction.viewPassword:
        await EmployeePasswordDialog.show(
          context,
          employee: employee,
          load: () => controller.fetchCredentials(employee.id),
        );
      case EmployeeAction.resetPassword:
        await EmployeeResetPasswordDialog.show(
          context,
          employee: employee,
          onSubmit: (password) =>
              controller.resetPassword(employee.id, password),
        );
    }
  }

  Future<void> _showDetailSheet(
    BuildContext context,
    EmployeesController controller,
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
        return ChangeNotifierProvider<EmployeesController>.value(
          value: controller,
          child: Consumer<EmployeesController>(
            builder: (context, live, _) {
              final employee = live.selected;
              if (employee == null) return const SizedBox.shrink();

              return SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.88,
                child: EmployeeDetailPanel(
                  employee: employee,
                  state: live.detailState,
                  error: live.detailError,
                  onClose: () => Navigator.of(sheetContext).pop(),
                  onRetry: () => live.openEmployee(employee),
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
    ).whenComplete(controller.closeEmployee);
  }

  Future<void> _openForm(
    BuildContext context,
    EmployeesController controller, {
    Employee? employee,
  }) async {
    // The venue picker needs its options before the dialog is useful.
    if (controller.complexes.isEmpty && !controller.complexesState.isLoading) {
      await controller.loadComplexes();
    }
    if (!context.mounted) return;

    final saved = await EmployeeFormDialog.show(
      context,
      employee: employee,
      complexes: controller.complexes,
      complexesState: controller.complexesState,
      onReloadComplexes: () => controller.loadComplexes(refresh: true),
      onSubmit: (draft, {required bool clearAddress}) async {
        if (employee == null) {
          await controller.create(draft);
        } else {
          await controller.update(
            employee.id,
            draft,
            clearAddress: clearAddress,
          );
        }
      },
    );

    if (!saved || !context.mounted) return;

    AdminFeedback.success(
      context,
      employee == null
          ? 'Employee created and the list has been refreshed.'
          : 'Changes to ${employee.displayName} were saved.',
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    EmployeesController controller,
    Employee employee,
  ) async {
    final tokens = AdminTheme.of(context);

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete this employee?',
      message:
          'This removes the staff account and its access to the '
          'platform. This cannot be undone.',
      confirmLabel: 'Delete employee',
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
              employee.displayName,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              [
                if ((employee.employeeCode ?? '').isNotEmpty)
                  employee.employeeCode!,
                if (employee.designationRaw != null) employee.designationLabel,
                if ((employee.sportComplexName ?? '').isNotEmpty)
                  employee.sportComplexName!,
              ].join(' · '),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tokens.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );

    if (!confirmed || !context.mounted) return;

    try {
      await controller.delete(employee.id);
      if (!context.mounted) return;
      AdminFeedback.success(context, '${employee.displayName} was deleted.');
    } catch (error) {
      if (!context.mounted) return;
      // The controller has already put the row back.
      AdminFeedback.error(context, _messageOf(error));
    }
  }

  static String _messageOf(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.isEmpty ? 'Could not delete this employee.' : text;
  }
}

// -----------------------------------------------------------------------------
// Header
// -----------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.searchController,
    required this.onAdd,
  });

  final EmployeesController controller;
  final TextEditingController searchController;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < AdminTokens.tabletMax;

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Employees',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: tokens.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          controller.state.isReady
              ? '${controller.page.total} staff across every complex'
              : 'Staff accounts, departments and shifts',
          style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
        ),
      ],
    );

    final search = SizedBox(
      width: narrow ? double.infinity : 300,
      child: TextField(
        controller: searchController,
        onChanged: controller.onSearchChanged,
        style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search name, email or ID',
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

    final filter = _FilterButton(controller: controller);

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
      label: const Text('Add Employee'),
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: AdminTokens.space4),
          search,
          const SizedBox(height: AdminTokens.space3),
          Row(
            children: [
              Expanded(child: filter),
              const SizedBox(width: AdminTokens.space3),
              Expanded(child: refresh),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          add,
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: title),
            filter,
            const SizedBox(width: AdminTokens.space3),
            refresh,
            const SizedBox(width: AdminTokens.space3),
            add,
          ],
        ),
        const SizedBox(height: AdminTokens.space4),
        Align(alignment: Alignment.centerLeft, child: search),
      ],
    );
  }
}

/// Opens the filter sheet, with a badge counting the filters in force.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.controller});

  final EmployeesController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final count = controller.activeFilterCount;
    final active = count > 0;

    return OutlinedButton.icon(
      onPressed: () => EmployeeFilterSheet.show(context, controller),
      style: OutlinedButton.styleFrom(
        foregroundColor: active ? tokens.accent : tokens.textPrimary,
        side: BorderSide(color: active ? tokens.accent : tokens.borderStrong),
        backgroundColor: active ? tokens.accentSoft : null,
      ),
      icon: const Icon(Icons.filter_alt_outlined, size: 18),
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Filter'),
          if (active) ...[
            const SizedBox(width: AdminTokens.space2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: tokens.accent,
                borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The filters currently in force, each removable in one tap.
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.controller});

  final EmployeesController controller;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (controller.statusFilter != null)
        _RemovableChip(
          label: controller.statusFilter!.label,
          onRemove: () => controller.setStatusFilter(null),
        ),
      if (controller.departmentFilter != null)
        _RemovableChip(
          label: controller.departmentFilter!.label,
          onRemove: () => controller.setDepartmentFilter(null),
        ),
      if (controller.shiftFilter != null)
        _RemovableChip(
          label: controller.shiftFilter!.label,
          onRemove: () => controller.setShiftFilter(null),
        ),
      if (controller.complexFilter != null)
        _RemovableChip(
          // Falls back to the id if the venue list has not landed yet.
          label:
              controller.filteredComplex?.name ??
              'Complex #${controller.complexFilter}',
          onRemove: () => controller.setComplexFilter(null),
        ),
    ];

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: AdminTokens.space2,
        runSpacing: AdminTokens.space2,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ...chips,
          TextButton.icon(
            onPressed: controller.clearFilters,
            icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
            label: const Text('Clear all'),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: AdminTokens.space2,
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  const _RemovableChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.only(
        left: AdminTokens.space3,
        right: 4,
        top: 4,
        bottom: 4,
      ),
      decoration: BoxDecoration(
        color: tokens.accentSoft,
        borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
        border: Border.all(color: tokens.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: tokens.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          InkWell(
            onTap: onRemove,
            borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 14, color: tokens.accent),
            ),
          ),
        ],
      ),
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

  final EmployeesController controller;
  final bool isMobile;
  final VoidCallback onAdd;
  final void Function(EmployeeAction action, Employee employee) onAction;

  @override
  Widget build(BuildContext context) {
    if (controller.isFirstLoad) {
      return SingleChildScrollView(
        child: TableShimmer(rows: 8, dense: isMobile),
      );
    }

    if (controller.state.isFailed) {
      return ErrorStateView(
        title: 'Could not load employees',
        message:
            controller.error ??
            'The server did not return a staff list. Check your connection '
                'and try again.',
        onRetry: controller.refresh,
      );
    }

    final employees = controller.employees;

    if (employees.isEmpty) {
      return controller.hasFilters
          ? EmptyStateView(
              icon: Icons.search_off_rounded,
              title: 'No employees match these filters',
              message:
                  'Try a different search term, or clear the filters to '
                  'see all staff.',
              actionLabel: 'Clear filters',
              onAction: controller.clearFilters,
            )
          : EmptyStateView(
              icon: Icons.badge_outlined,
              title: 'No employees yet',
              message:
                  'Add the first staff member to start managing '
                  'departments, shifts and access.',
              actionLabel: 'Add Employee',
              onAction: onAdd,
              secondaryLabel: 'Refresh',
              onSecondary: controller.refresh,
            );
    }

    if (isMobile) {
      return ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: employees.length,
        itemBuilder: (context, index) =>
            EmployeeCard(employee: employees[index], onAction: onAction),
      );
    }

    return SingleChildScrollView(
      child: EmployeesTable(
        employees: employees,
        sort: controller.sort,
        descending: controller.descending,
        onSort: controller.toggleSort,
        onAction: onAction,
        selectedId: controller.selected?.id,
      ),
    );
  }
}
