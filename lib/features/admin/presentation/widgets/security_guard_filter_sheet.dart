import 'package:flutter/material.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/employee_vocabulary.dart';
import '../state/security_guards_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';

/// The four security guard filters, in a sheet behind the header's Filter
/// button.
///
/// A sheet rather than four inline dropdowns: status, shift, complex and area
/// would not fit the toolbar beside search and the action buttons, and hiding
/// them behind one button keeps the header identical in shape to the other
/// modules'.
class SecurityGuardFilterSheet extends StatefulWidget {
  const SecurityGuardFilterSheet({super.key, required this.controller});

  static Future<void> show(
    BuildContext context,
    SecurityGuardsController controller,
  ) {
    AdminLog.ui('Guard filter sheet opened');
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminTheme.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AdminTokens.radiusXl),
        ),
      ),
      builder: (_) => SecurityGuardFilterSheet(controller: controller),
    ).whenComplete(() => AdminLog.ui('Guard filter sheet closed'));
  }

  final SecurityGuardsController controller;

  @override
  State<SecurityGuardFilterSheet> createState() =>
      _SecurityGuardFilterSheetState();
}

class _SecurityGuardFilterSheetState extends State<SecurityGuardFilterSheet> {
  final _complexQuery = TextEditingController();
  late final TextEditingController _areaQuery;

  @override
  void initState() {
    super.initState();
    _areaQuery = TextEditingController(
      text: widget.controller.areaFilter ?? '',
    );
  }

  @override
  void dispose() {
    _complexQuery.dispose();
    _areaQuery.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final controller = widget.controller;

    // Listens so a selection updates the sheet's own chips immediately.
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.85,
              ),
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
                            'Filter security guards',
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
                      // Only the two the spec lists — Suspended is not a guard
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
                    _Group<Shift>(
                      label: 'Shift',
                      options: Shift.values,
                      selected: controller.shiftFilter,
                      labelOf: (shift) => shift.label,
                      onSelect: controller.setShiftFilter,
                    ),
                    const SizedBox(height: AdminTokens.space5),
                    _ComplexGroup(
                      controller: controller,
                      query: _complexQuery,
                      onQueryChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: AdminTokens.space5),
                    _AreaGroup(
                      controller: controller,
                      query: _areaQuery,
                      onQueryChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: AdminTokens.space6),
                    FilledButton(
                      onPressed: () {
                        // Anything typed but not committed is applied on Done,
                        // so a filter is never silently discarded.
                        controller.setAreaFilter(_areaQuery.text);
                        Navigator.of(context).pop();
                      },
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _GroupLabel(label),
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

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        color: tokens.textMuted,
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );
  }
}

/// The sport-complex filter, searchable. Reuses the venue list the controller
/// already loaded for the form rather than fetching a second copy.
class _ComplexGroup extends StatelessWidget {
  const _ComplexGroup({
    required this.controller,
    required this.query,
    required this.onQueryChanged,
  });

  final SecurityGuardsController controller;
  final TextEditingController query;
  final VoidCallback onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final text = query.text.trim().toLowerCase();

    // Local filtering — the whole venue list is already in memory, so a
    // debounce and a round trip would only add latency.
    final complexes = text.isEmpty
        ? controller.complexes
        : controller.complexes
              .where((complex) => complex.label.toLowerCase().contains(text))
              .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const _GroupLabel('Sport complex'),
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
        if (controller.complexes.isNotEmpty)
          _SearchBox(
            controller: query,
            hint: 'Search complexes by name or city',
            onChanged: onQueryChanged,
          ),
        if (controller.complexes.isNotEmpty)
          const SizedBox(height: AdminTokens.space3),
        if (controller.complexes.isEmpty)
          Text(
            controller.complexesState.isLoading
                ? 'Loading complexes…'
                : 'No complexes available to filter by.',
            style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
          )
        else if (complexes.isEmpty)
          Text(
            'Nothing matches "${query.text.trim()}".',
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

/// The assigned-area filter.
///
/// The five enum members, plus any other value the loaded
/// rows actually carry; anything can still be typed and sent as-is.
class _AreaGroup extends StatelessWidget {
  const _AreaGroup({
    required this.controller,
    required this.query,
    required this.onQueryChanged,
  });

  final SecurityGuardsController controller;
  final TextEditingController query;
  final VoidCallback onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final text = query.text.trim().toLowerCase();

    // The vocabulary leads, so every posting is filterable even before a
    // guard is assigned to it; anything the rows hold beyond it is appended so
    // a legacy value stays reachable rather than becoming invisible.
    final all = <String>[
      ...AssignedArea.values.map((area) => area.slug),
      ...controller.knownAreas.where(
        (area) => AssignedArea.tryParse(area) == null,
      ),
    ];

    final areas = text.isEmpty
        ? all
        : all
              .where((area) => area.toLowerCase().contains(text))
              .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _GroupLabel('Assigned area'),
        const SizedBox(height: AdminTokens.space3),
        _SearchBox(
          controller: query,
          hint: 'Search or type an area',
          onChanged: onQueryChanged,
          onSubmitted: () => controller.setAreaFilter(query.text),
          onClear: () => controller.setAreaFilter(null),
        ),
        const SizedBox(height: AdminTokens.space3),
        if (all.isEmpty)
          Text(
            'Areas appear here once guards have been loaded.',
            style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
          )
        else
          Wrap(
            spacing: AdminTokens.space2,
            runSpacing: AdminTokens.space2,
            children: [
              _Chip(
                label: 'All',
                selected: controller.areaFilter == null,
                onTap: () {
                  query.clear();
                  onQueryChanged();
                  controller.setAreaFilter(null);
                },
              ),
              ...areas.map(
                (area) => _Chip(
                  label: area,
                  selected: area == controller.areaFilter,
                  onTap: () {
                    final clearing = area == controller.areaFilter;
                    query.text = clearing ? '' : area;
                    onQueryChanged();
                    controller.setAreaFilter(clearing ? null : area);
                  },
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _SearchBox extends StatelessWidget {
  const _SearchBox({
    required this.controller,
    required this.hint,
    required this.onChanged,
    this.onSubmitted,
    this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onChanged;
  final VoidCallback? onSubmitted;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted!(),
      textInputAction: onSubmitted == null
          ? TextInputAction.search
          : TextInputAction.done,
      style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        prefixIcon: Icon(
          Icons.search_rounded,
          size: 18,
          color: tokens.textMuted,
        ),
        suffixIcon: controller.text.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  controller.clear();
                  onChanged();
                  onClear?.call();
                },
                icon: const Icon(Icons.close_rounded, size: 16),
                color: tokens.textMuted,
                tooltip: 'Clear',
              ),
      ),
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
