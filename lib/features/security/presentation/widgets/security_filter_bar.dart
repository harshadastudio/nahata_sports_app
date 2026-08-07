import 'package:flutter/material.dart';

import '../../../admin/domain/entities/visitor_pass.dart';
import '../../../admin/presentation/theme/admin_theme.dart';
import '../../domain/entities/security_dashboard_data.dart';
import '../state/security_dashboard_controller.dart';

/// The date window, the three dropdowns and the search box.
///
/// The window drives everything on the screen; the rest narrow the activity
/// table only — a filter must not quietly redefine what "visitors today" means
/// on the cards above it.
class SecurityFilterBar extends StatelessWidget {
  const SecurityFilterBar({
    super.key,
    required this.controller,
    required this.searchController,
    required this.data,
  });

  final SecurityDashboardController controller;
  final TextEditingController searchController;
  final SecurityDashboardData data;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < AdminTokens.tabletMax;

    final search = SizedBox(
      width: narrow ? double.infinity : 300,
      child: TextField(
        controller: searchController,
        onChanged: controller.onSearchChanged,
        style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search name, phone, code or purpose',
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
          isDense: true,
        ),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RangeChips(controller: controller),
        const SizedBox(height: AdminTokens.space3),
        Wrap(
          spacing: AdminTokens.space3,
          runSpacing: AdminTokens.space3,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            search,
            _Dropdown<VisitorPassStatus?>(
              label: 'Status',
              value: controller.statusFilter,
              onChanged: controller.setStatusFilter,
              items: [
                const DropdownMenuItem<VisitorPassStatus?>(
                  child: Text('All statuses'),
                ),
                for (final status in VisitorPassStatus.values)
                  DropdownMenuItem<VisitorPassStatus?>(
                    value: status,
                    child: Text(status.label),
                  ),
              ],
            ),
            if (data.purposes.isNotEmpty)
              _Dropdown<String?>(
                label: 'Purpose',
                value: controller.purposeFilter,
                onChanged: controller.setPurposeFilter,
                items: [
                  const DropdownMenuItem<String?>(child: Text('All purposes')),
                  for (final purpose in data.purposes)
                    DropdownMenuItem<String?>(
                      value: purpose,
                      child: Text(purpose),
                    ),
                ],
              ),
            if (data.staff.isNotEmpty)
              _Dropdown<String?>(
                label: 'Security',
                value: controller.staffFilter,
                onChanged: controller.setStaffFilter,
                items: [
                  const DropdownMenuItem<String?>(child: Text('All staff')),
                  for (final person in data.staff)
                    DropdownMenuItem<String?>(
                      value: person,
                      child: Text(person),
                    ),
                ],
              ),
            if (controller.hasFilters)
              TextButton.icon(
                onPressed: controller.clearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 17),
                label: Text('Clear (${controller.activeFilterCount})'),
              ),
          ],
        ),
      ],
    );
  }
}

class _RangeChips extends StatelessWidget {
  const _RangeChips({required this.controller});

  final SecurityDashboardController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Wrap(
      spacing: AdminTokens.space2,
      runSpacing: AdminTokens.space2,
      children: [
        for (final range in SecurityRange.values)
          _RangeChip(
            label: range == SecurityRange.custom
                ? _customLabel(controller)
                : range.label,
            selected: controller.range == range,
            icon: range == SecurityRange.custom
                ? Icons.date_range_rounded
                : null,
            onTap: () => range == SecurityRange.custom
                ? _pickCustom(context, controller)
                : controller.setRange(range),
          ),
        if (controller.range != SecurityRange.today)
          Padding(
            padding: const EdgeInsets.only(left: AdminTokens.space2),
            child: Text(
              controller.window.label,
              style: TextStyle(
                color: tokens.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }

  static String _customLabel(SecurityDashboardController controller) =>
      controller.range == SecurityRange.custom
          ? controller.window.label
          : 'Custom';

  static Future<void> _pickCustom(
    BuildContext context,
    SecurityDashboardController controller,
  ) async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      // Two years back is well beyond anything the sweep can reach, but the
      // picker should not be the thing that stops an admin asking.
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: controller.customStart == null
          ? null
          : DateTimeRange(
              start: controller.customStart!,
              end: controller.customEnd ?? controller.customStart!,
            ),
    );

    if (picked == null) return;
    await controller.setRange(
      SecurityRange.custom,
      start: picked.start,
      end: picked.end,
    );
  }
}

class _RangeChip extends StatelessWidget {
  const _RangeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: AdminTokens.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AdminTokens.space4,
          vertical: AdminTokens.space2 + 1,
        ),
        decoration: BoxDecoration(
          color: selected ? tokens.accentSoft : tokens.surface,
          borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
          border: Border.all(
            color: selected ? tokens.accent : tokens.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: selected ? tokens.accent : tokens.textMuted,
              ),
              const SizedBox(width: 6),
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

class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SizedBox(
      width: 200,
      child: DropdownButtonFormField<T>(
        initialValue: value,
        isDense: true,
        // A purpose or a guard's name can be longer than the box; expanding
        // lets the label ellipsize instead of overflowing the row.
        isExpanded: true,
        items: items,
        onChanged: (next) => onChanged(next as T),
        style: TextStyle(fontSize: 13, color: tokens.textPrimary),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AdminTokens.space3,
            vertical: AdminTokens.space3,
          ),
        ),
      ),
    );
  }
}