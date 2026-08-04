import 'package:flutter/material.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../state/courts_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';

/// The five court filters, in a sheet behind the header's Filter button.
///
/// The complex and the sport are the two `/courts` actually accepts; status,
/// surface type and frontend visibility are applied over the returned rows.
class CourtFilterSheet extends StatefulWidget {
  const CourtFilterSheet({super.key, required this.controller});

  static Future<void> show(
    BuildContext context,
    CourtsController controller,
  ) {
    AdminLog.ui('Court filter sheet opened');
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminTheme.of(context).surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AdminTokens.radiusXl),
        ),
      ),
      builder: (_) => CourtFilterSheet(controller: controller),
    ).whenComplete(() => AdminLog.ui('Court filter sheet closed'));
  }

  final CourtsController controller;

  @override
  State<CourtFilterSheet> createState() => _CourtFilterSheetState();
}

class _CourtFilterSheetState extends State<CourtFilterSheet> {
  final _complexQuery = TextEditingController();
  final _sportQuery = TextEditingController();

  @override
  void dispose() {
    _complexQuery.dispose();
    _sportQuery.dispose();
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
                            'Filter courts',
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
                    CourtSearchableGroup(
                      label: 'Sports complex',
                      note: 'Sent to the server as /courts?sportComplexId=',
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
                    CourtSearchableGroup(
                      label: 'Sport',
                      note: 'Sent to the server as /courts?sportId=',
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
                    _Group<AdminUserStatus>(
                      label: 'Status',
                      note: _localNote,
                      options: const [
                        AdminUserStatus.active,
                        AdminUserStatus.inactive,
                      ],
                      selected: controller.statusFilter,
                      labelOf: (status) => status.label,
                      onSelect: controller.setStatusFilter,
                    ),
                    const SizedBox(height: AdminTokens.space5),
                    _SurfaceGroup(controller: controller),
                    const SizedBox(height: AdminTokens.space5),
                    _Group<bool>(
                      label: 'Show on frontend',
                      note: _localNote,
                      options: const [true, false],
                      selected: controller.visibilityFilter,
                      labelOf: (value) => value ? 'Shown' : 'Hidden',
                      onSelect: controller.setVisibilityFilter,
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

  static const String _localNote =
      'Applied here — the route takes no such parameter.';
}

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
        CourtGroupLabel(label),
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
            CourtFilterChip(
              label: 'All',
              selected: selected == null,
              onTap: () => onSelect(null),
            ),
            ...options.map(
              (option) => CourtFilterChip(
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

/// Surface types, learned from the rows rather than from an endpoint.
class _SurfaceGroup extends StatelessWidget {
  const _SurfaceGroup({required this.controller});

  final CourtsController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final surfaces = controller.knownSurfaces;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const CourtGroupLabel('Surface type'),
        const SizedBox(height: AdminTokens.space2),
        Text(
          'Applied here. There is no surface-type endpoint, so these are the '
          'values the loaded courts use.',
          style: TextStyle(color: tokens.textMuted, fontSize: 11, height: 1.4),
        ),
        const SizedBox(height: AdminTokens.space3),
        if (surfaces.isEmpty)
          Text(
            'None of the loaded courts records a surface type.',
            style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
          )
        else
          Wrap(
            spacing: AdminTokens.space2,
            runSpacing: AdminTokens.space2,
            children: [
              CourtFilterChip(
                label: 'All',
                selected: controller.surfaceFilter == null,
                onTap: () => controller.setSurfaceFilter(null),
              ),
              ...surfaces.map(
                (surface) => CourtFilterChip(
                  label: surface,
                  selected:
                      surface.toLowerCase() ==
                      (controller.surfaceFilter ?? '').toLowerCase(),
                  onTap: () => controller.setSurfaceFilter(
                    surface.toLowerCase() ==
                            (controller.surfaceFilter ?? '').toLowerCase()
                        ? null
                        : surface,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// A filter over a fetched catalogue, with a search box and its own retry.
class CourtSearchableGroup extends StatelessWidget {
  const CourtSearchableGroup({
    super.key,
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
            CourtGroupLabel(label),
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
            state.isLoading ? 'Loading…' : 'Nothing available to filter by.',
            style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
          )
        else ...[
          // The search box only earns its space once the list is long enough.
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
                CourtFilterChip(
                  label: 'All',
                  selected: selectedId == null,
                  onTap: () => onSelect(null),
                ),
                ...filtered.map(
                  (option) => CourtFilterChip(
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

class CourtGroupLabel extends StatelessWidget {
  const CourtGroupLabel(this.label, {super.key});

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

class CourtFilterChip extends StatelessWidget {
  const CourtFilterChip({
    super.key,
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
