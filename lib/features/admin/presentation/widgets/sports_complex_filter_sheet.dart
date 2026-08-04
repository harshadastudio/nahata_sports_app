import 'package:flutter/material.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../state/sports_complexes_controller.dart';
import '../theme/admin_theme.dart';

/// The four sports complex filters, in a sheet behind the header's Filter
/// button — the same shape as the employee and security guard sheets.
///
/// City and state are searchable because a catalogue can carry dozens of each;
/// both re-read from their dedicated endpoints, while status and visibility are
/// applied locally over the rows already in hand.
class SportsComplexFilterSheet extends StatefulWidget {
  const SportsComplexFilterSheet({super.key, required this.controller});

  static Future<void> show(
    BuildContext context,
    SportsComplexesController controller,
  ) {
    AdminLog.ui('Complex filter sheet opened');
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminTheme.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AdminTokens.radiusXl),
        ),
      ),
      builder: (_) => SportsComplexFilterSheet(controller: controller),
    ).whenComplete(() => AdminLog.ui('Complex filter sheet closed'));
  }

  final SportsComplexesController controller;

  @override
  State<SportsComplexFilterSheet> createState() =>
      _SportsComplexFilterSheetState();
}

class _SportsComplexFilterSheetState extends State<SportsComplexFilterSheet> {
  final _cityQuery = TextEditingController();
  final _stateQuery = TextEditingController();

  @override
  void dispose() {
    _cityQuery.dispose();
    _stateQuery.dispose();
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
                            'Filter sports complexes',
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
                      options: const [
                        AdminUserStatus.active,
                        AdminUserStatus.inactive,
                      ],
                      selected: controller.statusFilter,
                      labelOf: (status) => status.label,
                      onSelect: controller.setStatusFilter,
                    ),
                    const SizedBox(height: AdminTokens.space5),
                    _Group<bool>(
                      label: 'Show on frontend',
                      options: const [true, false],
                      selected: controller.visibilityFilter,
                      labelOf: (value) => value ? 'Shown' : 'Hidden',
                      onSelect: controller.setVisibilityFilter,
                    ),
                    const SizedBox(height: AdminTokens.space5),
                    _SearchableGroup(
                      label: 'City',
                      hint: 'Search cities',
                      note:
                          'Picking a city re-reads it from '
                          '/sports-complexes/city/{city}.',
                      query: _cityQuery,
                      options: controller.cities,
                      selected: controller.cityFilter,
                      onQueryChanged: () => setState(() {}),
                      onSelect: controller.setCityFilter,
                      emptyMessage:
                          'Cities appear here once complexes have loaded.',
                    ),
                    const SizedBox(height: AdminTokens.space5),
                    _SearchableGroup(
                      label: 'State',
                      hint: 'Search states',
                      note:
                          'Picking a state re-reads it from '
                          '/sports-complexes/state/{state}.',
                      query: _stateQuery,
                      options: controller.states,
                      selected: controller.stateFilter,
                      onQueryChanged: () => setState(() {}),
                      onSelect: controller.setStateFilter,
                      emptyMessage:
                          'States appear here once complexes have loaded.',
                    ),
                    const SizedBox(height: AdminTokens.space6),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
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

/// A filter whose options are numerous enough to need a search box. The options
/// are learned from the catalogue — there is no endpoint that enumerates
/// cities or states.
class _SearchableGroup extends StatelessWidget {
  const _SearchableGroup({
    required this.label,
    required this.hint,
    required this.note,
    required this.query,
    required this.options,
    required this.selected,
    required this.onQueryChanged,
    required this.onSelect,
    required this.emptyMessage,
  });

  final String label;
  final String hint;
  final String note;
  final TextEditingController query;
  final List<String> options;
  final String? selected;
  final VoidCallback onQueryChanged;
  final ValueChanged<String?> onSelect;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final text = query.text.trim().toLowerCase();

    // Local filtering — the option list is already in memory, so a debounce
    // and a round trip would only add latency.
    final matches = text.isEmpty
        ? options
        : options
              .where((option) => option.toLowerCase().contains(text))
              .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _GroupLabel(label),
        const SizedBox(height: AdminTokens.space2),
        Text(
          note,
          style: TextStyle(color: tokens.textMuted, fontSize: 11, height: 1.4),
        ),
        const SizedBox(height: AdminTokens.space3),
        if (options.isEmpty)
          Text(
            emptyMessage,
            style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
          )
        else ...[
          TextField(
            controller: query,
            onChanged: (_) => onQueryChanged(),
            style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
            decoration: InputDecoration(
              hintText: hint,
              isDense: true,
              prefixIcon: Icon(
                Icons.search_rounded,
                size: 18,
                color: tokens.textMuted,
              ),
              suffixIcon: query.text.isEmpty
                  ? null
                  : IconButton(
                      onPressed: () {
                        query.clear();
                        onQueryChanged();
                      },
                      icon: const Icon(Icons.close_rounded, size: 16),
                      color: tokens.textMuted,
                      tooltip: 'Clear',
                    ),
            ),
          ),
          const SizedBox(height: AdminTokens.space3),
          if (matches.isEmpty)
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
                  selected: selected == null,
                  onTap: () => onSelect(null),
                ),
                ...matches.map(
                  (option) => _Chip(
                    label: option,
                    selected: option == selected,
                    onTap: () => onSelect(option == selected ? null : option),
                  ),
                ),
              ],
            ),
        ],
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
