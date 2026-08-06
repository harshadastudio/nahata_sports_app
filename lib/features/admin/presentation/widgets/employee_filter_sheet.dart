import 'package:flutter/material.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/employee_vocabulary.dart';
import '../state/employees_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';

/// The four employee filters, in a sheet behind the header's Filter button.
///
/// A sheet rather than four inline dropdowns: status, department, shift and
/// complex would not fit the toolbar beside search and the action buttons, and
/// hiding them behind one button keeps the header identical in shape to the
/// other modules'.
class EmployeeFilterSheet extends StatelessWidget {
  const EmployeeFilterSheet({super.key, required this.controller});

  static Future<void> show(
    BuildContext context,
    EmployeesController controller,
  ) {
    AdminLog.ui('Employee filter sheet opened');
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminTheme.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AdminTokens.radiusXl),
        ),
      ),
      builder: (_) => EmployeeFilterSheet(controller: controller),
    ).whenComplete(() => AdminLog.ui('Employee filter sheet closed'));
  }

  final EmployeesController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    // Listens so a selection updates the sheet's own chips immediately.
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AdminTokens.space5,
              AdminTokens.space4,
              AdminTokens.space5,
              AdminTokens.space5,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.filter_alt_outlined,
                      size: 18,
                      color: tokens.accent,
                    ),
                    const SizedBox(width: AdminTokens.space3),
                    Expanded(
                      child: Text(
                        'Filter employees',
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (controller.activeFilterCount > 0)
                      TextButton.icon(
                        onPressed: () {
                          controller.clearFilters();
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(
                          Icons.filter_alt_off_outlined,
                          size: 16,
                        ),
                        label: const Text('Clear all'),
                      ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                      color: tokens.textMuted,
                      tooltip: 'Close',
                    ),
                  ],
                ),
                const SizedBox(height: AdminTokens.space4),
                _Group<AdminUserStatus>(
                  label: 'Status',
                  // Only the two the spec lists — Suspended is not an employee
                  // state in this module.
                  options: const [
                    AdminUserStatus.active,
                    AdminUserStatus.inactive,
                  ],
                  selected: controller.statusFilter,
                  labelOf: (status) => status.label,
                  onSelect: controller.setStatusFilter,
                ),
                const SizedBox(height: AdminTokens.space5),
                _Group<Department>(
                  label: 'Department',
                  options: Department.values,
                  selected: controller.departmentFilter,
                  labelOf: (department) => department.label,
                  onSelect: controller.setDepartmentFilter,
                ),
                const SizedBox(height: AdminTokens.space5),
                _Group<Shift>(
                  label: 'Shift',
                  options: Shift.values,
                  selected: controller.shiftFilter,
                  labelOf: (shift) => shift.label,
                  onSelect: controller.setShiftFilter,
                ),
                const SizedBox(height: AdminTokens.space5),
                _ComplexGroup(controller: controller),
                const SizedBox(height: AdminTokens.space6),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One filter row: a label and a wrap of single-select chips.
class _Group<T> extends StatelessWidget {
  const _Group({
    required this.label,
    required this.options,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
  });

  final String label;
  final List<T> options;
  final T? selected;
  final String Function(T value) labelOf;
  final ValueChanged<T?> onSelect;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: tokens.textMuted,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AdminTokens.space3),
        Wrap(
          spacing: AdminTokens.space2,
          runSpacing: AdminTokens.space2,
          children: [
            _Chip(
              label: 'All',
              selected: selected == null,
              onTap: () => onSelect(null),
            ),
            ...options.map(
              (option) => _Chip(
                label: labelOf(option),
                selected: option == selected,
                // Tapping the selected chip clears it, so the filter can be
                // undone without hunting for "All".
                onTap: () => onSelect(option == selected ? null : option),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The sport-complex filter. Reuses the venue list the controller already
/// loaded for the form rather than fetching a second copy.
class _ComplexGroup extends StatelessWidget {
  const _ComplexGroup({required this.controller});

  final EmployeesController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final complexes = controller.complexes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              'SPORT COMPLEX',
              style: TextStyle(
                color: tokens.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            if (controller.complexesState.isLoading)
              const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (controller.complexesState.isFailed)
              TextButton(
                onPressed: () => controller.loadComplexes(refresh: true),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Retry', style: TextStyle(fontSize: 11.5)),
              ),
          ],
        ),
        const SizedBox(height: AdminTokens.space3),
        if (complexes.isEmpty)
          Text(
            controller.complexesState.isLoading
                ? 'Loading complexes…'
                : 'No complexes available to filter by.',
            style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
          )
        else
          Wrap(
            spacing: AdminTokens.space2,
            runSpacing: AdminTokens.space2,






            children: [
              _Chip(
                label: 'All',
                selected: controller.complexFilter == null,
                onTap: () => controller.setComplexFilter(null),
              ),
              ...complexes.map(
                (complex) => _Chip(
                  label: complex.name,
                  selected: complex.id == controller.complexFilter,
                  onTap: () => controller.setComplexFilter(
                    complex.id == controller.complexFilter ? null : complex.id,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AdminTokens.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AdminTokens.space3 + 2,
          vertical: AdminTokens.space2 + 2,
        ),
        decoration: BoxDecoration(
          color: selected ? tokens.accentSoft : tokens.surface,
          borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
          border: Border.all(color: selected ? tokens.accent : tokens.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              Icon(Icons.check_rounded, size: 14, color: tokens.accent),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? tokens.accent : tokens.textSecondary,
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
