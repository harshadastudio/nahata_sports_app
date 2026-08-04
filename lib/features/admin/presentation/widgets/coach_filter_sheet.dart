import 'package:flutter/material.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/sport.dart';
import '../state/coaches_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';

/// The four coach filters, in a sheet behind the header's Filter button — the
/// same shape as the other modules' sheets.
///
/// The sport is searchable and leads: it is the module's primary filter, and
/// the only one with a route of its own (`/coaches/sport/{sportId}`). Status is
/// also server-side (`/coaches?status=`), while the complex and the category
/// are applied locally.
class CoachFilterSheet extends StatefulWidget {
  const CoachFilterSheet({super.key, required this.controller});

  static Future<void> show(
    BuildContext context,
    CoachesController controller,
  ) {
    AdminLog.ui('Coach filter sheet opened');
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminTheme.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AdminTokens.radiusXl),
        ),
      ),
      builder: (_) => CoachFilterSheet(controller: controller),
    ).whenComplete(() => AdminLog.ui('Coach filter sheet closed'));
  }

  final CoachesController controller;

  @override
  State<CoachFilterSheet> createState() => _CoachFilterSheetState();
}

class _CoachFilterSheetState extends State<CoachFilterSheet> {
  final _sportQuery = TextEditingController();
  final _complexQuery = TextEditingController();

  @override
  void dispose() {
    _sportQuery.dispose();
    _complexQuery.dispose();
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
                            'Filter coaches',
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
                    _SportGroup(
                      controller: controller,
                      query: _sportQuery,
                      onQueryChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: AdminTokens.space5),
                    _Group<AdminUserStatus>(
                      label: 'Status',
                      note: controller.sportFilter == null
                          ? 'Sent to the server as /coaches?status='
                          : 'Applied here — the sport route does not take a '
                                'status parameter.',
                      options: const [
                        AdminUserStatus.active,
                        AdminUserStatus.inactive,
                      ],
                      selected: controller.statusFilter,
                      labelOf: (status) => status.label,
                      onSelect: controller.setStatusFilter,
                    ),
                    const SizedBox(height: AdminTokens.space5),
                    _ComplexGroup(
                      controller: controller,
                      query: _complexQuery,
                      onQueryChanged: () => setState(() {}),
                    ),
                    const SizedBox(height: AdminTokens.space5),
                    _Group<SportCategory>(
                      label: 'Category',
                      note: 'Only coaches whose payload carries a category can '
                          'be matched.',
                      options: SportCategory.values,
                      selected: controller.categoryFilter,
                      labelOf: (category) => category.label,
                      onSelect: controller.setCategoryFilter,
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
    this.note,
  });

  final String label;
  final List<T> options;
  final T? selected;
  final String Function(T value) labelOf;
  final ValueChanged<T?> onSelect;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _GroupLabel(label),
        if (note != null) ...[
          const SizedBox(height: AdminTokens.space2),
          Text(
            note!,
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
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

/// The sport filter, searchable. Reuses the sport list the controller already
/// loaded for the form rather than fetching a second copy.
class _SportGroup extends StatelessWidget {
  const _SportGroup({
    required this.controller,
    required this.query,
    required this.onQueryChanged,
  });

  final CoachesController controller;
  final TextEditingController query;
  final VoidCallback onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final text = query.text.trim().toLowerCase();

    // Local filtering — the whole sport list is already in memory, so a
    // debounce and a round trip would only add latency.
    final sports = text.isEmpty
        ? controller.sports
        : controller.sports
              .where(
                (sport) => sport.displayName.toLowerCase().contains(text),
              )
              .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const _GroupLabel('Sport'),
            const Spacer(),
            if (controller.sportsState.isLoading)
              const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (controller.sportsState.isFailed)
              TextButton(
                onPressed: () => controller.loadSports(refresh: true),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Retry', style: TextStyle(fontSize: 11.5)),
              ),
          ],
        ),
        const SizedBox(height: AdminTokens.space2),
        Text(
          'The primary filter — switches the read to '
          '/coaches/sport/{sportId}',
          style: TextStyle(color: tokens.textMuted, fontSize: 11, height: 1.4),
        ),
        const SizedBox(height: AdminTokens.space3),
        if (controller.sports.isEmpty)
          Text(
            controller.sportsState.isLoading
                ? 'Loading sports…'
                : 'No sports available to filter by.',
            style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
          )
        else ...[
          TextField(
            controller: query,
            onChanged: (_) => onQueryChanged(),
            style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search sports by name',
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
          if (sports.isEmpty)
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
                  selected: controller.sportFilter == null,
                  onTap: () => controller.setSportFilter(null),
                ),
                ...sports.map(
                  (sport) => _Chip(
                    label: sport.displayName,
                    selected: sport.id == controller.sportFilter,
                    onTap: () => controller.setSportFilter(
                      sport.id == controller.sportFilter ? null : sport.id,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

/// The sports complex filter, searchable and applied locally.
class _ComplexGroup extends StatelessWidget {
  const _ComplexGroup({
    required this.controller,
    required this.query,
    required this.onQueryChanged,
  });

  final CoachesController controller;
  final TextEditingController query;
  final VoidCallback onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final text = query.text.trim().toLowerCase();

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
            const _GroupLabel('Sports complex'),
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
        const SizedBox(height: AdminTokens.space2),
        Text(
          'Applied here — neither coach route takes a complex parameter.',
          style: TextStyle(color: tokens.textMuted, fontSize: 11, height: 1.4),
        ),
        const SizedBox(height: AdminTokens.space3),
        if (controller.complexes.isEmpty)
          Text(
            controller.complexesState.isLoading
                ? 'Loading complexes…'
                : 'No complexes available to filter by.',
            style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
          )
        else ...[
          TextField(
            controller: query,
            onChanged: (_) => onQueryChanged(),
            style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search complexes by name or city',
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
          if (complexes.isEmpty)
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
                      complex.id == controller.complexFilter
                          ? null
                          : complex.id,
                    ),
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
