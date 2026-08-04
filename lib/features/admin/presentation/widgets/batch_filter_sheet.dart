import 'package:flutter/material.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../state/batches_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';

/// The five batch filters, in a sheet behind the header's Filter button — the
/// same shape as the other modules' sheets.
///
/// Status and sport are the two `/batches` actually accepts; coach, complex and
/// age group are applied here. Because the list route is paginated, using one
/// of those three pulls the whole catalogue first — each group says so, so the
/// extra wait is never a surprise.
class BatchFilterSheet extends StatefulWidget {
  const BatchFilterSheet({super.key, required this.controller});

  static Future<void> show(
    BuildContext context,
    BatchesController controller,
  ) {
    AdminLog.ui('Batch filter sheet opened');
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminTheme.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AdminTokens.radiusXl),
        ),
      ),
      builder: (_) => BatchFilterSheet(controller: controller),
    ).whenComplete(() => AdminLog.ui('Batch filter sheet closed'));
  }

  final BatchesController controller;

  @override
  State<BatchFilterSheet> createState() => _BatchFilterSheetState();
}

class _BatchFilterSheetState extends State<BatchFilterSheet> {
  final _sportQuery = TextEditingController();
  final _coachQuery = TextEditingController();
  final _complexQuery = TextEditingController();

  @override
  void dispose() {
    _sportQuery.dispose();
    _coachQuery.dispose();
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
                            'Filter batches',
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
                      note: 'Sent to the server as /batches?status=',
                      options: const [
                        AdminUserStatus.active,
                        AdminUserStatus.inactive,
                      ],
                      selected: controller.statusFilter,
                      labelOf: (status) => status.label,
                      onSelect: controller.setStatusFilter,
                    ),
                    const SizedBox(height: AdminTokens.space5),
                    _SearchableGroup(
                      label: 'Sport',
                      note: 'Sent to the server as /batches?sportId=',
                      query: _sportQuery,
                      onQueryChanged: () => setState(() {}),
                      state: controller.sportsState,
                      onReload: () => controller.loadSports(refresh: true),
                      options: [
                        for (final sport in controller.sports)
                          (id: sport.id, label: sport.displayName),
                      ],
                      selectedId: controller.sportFilter,
                      onSelect: controller.setSportFilter,
                    ),
                    const SizedBox(height: AdminTokens.space5),
                    _SearchableGroup(
                      label: 'Coach',
                      note: _localNote,
                      query: _coachQuery,
                      onQueryChanged: () => setState(() {}),
                      state: controller.coachesState,
                      onReload: () => controller.loadCoaches(refresh: true),
                      options: [
                        for (final coach in controller.coaches)
                          (id: coach.id, label: coach.displayName),
                      ],
                      selectedId: controller.coachFilter,
                      onSelect: controller.setCoachFilter,
                    ),
                    const SizedBox(height: AdminTokens.space5),
                    _SearchableGroup(
                      label: 'Sports complex',
                      note: _localNote,
                      query: _complexQuery,
                      onQueryChanged: () => setState(() {}),
                      state: controller.complexesState,
                      onReload: () => controller.loadComplexes(refresh: true),
                      options: [
                        for (final complex in controller.complexes)
                          (id: complex.id, label: complex.name),
                      ],
                      selectedId: controller.complexFilter,
                      onSelect: controller.setComplexFilter,
                    ),
                    const SizedBox(height: AdminTokens.space5),
                    _AgeGroupGroup(controller: controller, note: _localNote),
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

  /// Said once, in three places: these filters have no query parameter, so the
  /// module has to hold the whole catalogue to apply them honestly.
  static const String _localNote =
      'Applied here — the route takes no such parameter, so every page is '
      'loaded first.';
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

/// A filter over a fetched catalogue, with a search box and its own retry.
class _SearchableGroup extends StatelessWidget {
  const _SearchableGroup({
    required this.label,
    required this.query,
    required this.onQueryChanged,
    required this.state,
    required this.onReload,
    required this.options,
    required this.selectedId,
    required this.onSelect,
    this.note,
  });

  final String label;
  final TextEditingController query;
  final VoidCallback onQueryChanged;
  final ViewState state;
  final VoidCallback onReload;
  final List<({int id, String label})> options;
  final int? selectedId;
  final ValueChanged<int?> onSelect;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final text = query.text.trim().toLowerCase();

    // Local filtering — the whole catalogue is already in memory, so a debounce
    // and a round trip would only add latency.
    final filtered = text.isEmpty
        ? options
        : options
              .where((option) => option.label.toLowerCase().contains(text))
              .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _GroupLabel(label),
            const Spacer(),
            if (state.isLoading)
              const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (state.isFailed)
              TextButton(
                onPressed: onReload,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Retry', style: TextStyle(fontSize: 11.5)),
              ),
          ],
        ),
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
        if (options.isEmpty)
          Text(
            state.isLoading
                ? 'Loading…'
                : 'Nothing available to filter by.',
            style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
          )
        else ...[
          // The search box only earns its space once the list is long enough to
          // need it.
          if (options.length > 6) ...[
            TextField(
              controller: query,
              onChanged: (_) => onQueryChanged(),
              style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search ${label.toLowerCase()}',
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
          ],
          if (filtered.isEmpty)
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
                  selected: selectedId == null,
                  onTap: () => onSelect(null),
                ),
                ...filtered.map(
                  (option) => _Chip(
                    label: option.label,
                    selected: option.id == selectedId,
                    onTap: () =>
                        onSelect(option.id == selectedId ? null : option.id),
                  ),
                ),
              ],
            ),
        ],
      ],
    );
  }
}

/// Age groups, learned from the rows rather than from an endpoint.
class _AgeGroupGroup extends StatelessWidget {
  const _AgeGroupGroup({required this.controller, this.note});

  final BatchesController controller;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final groups = controller.knownAgeGroups;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _GroupLabel('Age group'),
        if (note != null) ...[
          const SizedBox(height: AdminTokens.space2),
          Text(
            '$note There is no age-group endpoint, so these are the values '
            'the loaded batches use.',
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
        const SizedBox(height: AdminTokens.space3),
        if (groups.isEmpty)
          Text(
            'None of the loaded batches records an age group.',
            style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
          )
        else
          Wrap(
            spacing: AdminTokens.space2,
            runSpacing: AdminTokens.space2,
            children: [
              _Chip(
                label: 'All',
                selected: controller.ageGroupFilter == null,
                onTap: () => controller.setAgeGroupFilter(null),
              ),
              ...groups.map(
                (group) => _Chip(
                  label: group,
                  selected:
                      group.toLowerCase() ==
                      (controller.ageGroupFilter ?? '').toLowerCase(),
                  onTap: () => controller.setAgeGroupFilter(
                    group.toLowerCase() ==
                            (controller.ageGroupFilter ?? '').toLowerCase()
                        ? null
                        : group,
                  ),
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
