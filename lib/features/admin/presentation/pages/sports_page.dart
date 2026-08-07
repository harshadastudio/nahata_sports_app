import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/sport.dart';
import '../navigation/admin_module.dart';
import '../state/sports_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dialogs.dart';
import '../widgets/admin_states.dart';
import '../widgets/assign_complex_dialog.dart';
import '../widgets/glass_card.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/sport_detail_panel.dart';
import '../widgets/sport_filter_sheet.dart';
import '../widgets/sport_form_dialog.dart';
import '../widgets/sports_table.dart';
import '../widgets/stat_card.dart';

/// Sports management: the summary cards, the list, and every write action.
class SportsPage extends StatefulWidget {
  const SportsPage({super.key});

  @override
  State<SportsPage> createState() => _SportsPageState();
}

class _SportsPageState extends State<SportsPage> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    AdminLog.life('SportsPage mounted');
    _search = TextEditingController(
      text: context.read<SportsController>().search,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<SportsController>();
      if (controller.state.isIdle) controller.load();
      // Warmed here so the Add dialog, the complex filter and the assign
      // dialog all open ready.
      controller.loadComplexes();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    AdminLog.life('SportsPage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SportsController>();
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

    final body = _Body(
      controller: controller,
      isMobile: isMobile,
      // On a phone the page scrolls as one piece, so the row list must lay
      // itself out inline rather than claim a viewport of its own.
      shrinkWrap: isMobile,
      onAdd: AdminAccess.canCreate(AdminModules.sports)
          ? () => _openForm(context, controller)
          : null,
      onAction: (action, sport) =>
          _handleAction(context, controller, action, sport),
      onToggleVisibility: (sport, value) =>
          _toggleVisibility(context, controller, sport, value),
    );

    final pagination = (controller.page.isNotEmpty || controller.page.page > 1)
        ? PaginationBar(
            page: controller.page,
            limit: controller.limit,
            busy: controller.state.isLoading,
            onPage: controller.goToPage,
            onLimit: controller.setLimit,
          )
        : null;

    final listCard = SolidCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
        child: Column(
          mainAxisSize: isMobile ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RefreshLine(visible: controller.isRefreshing),
            // Expanded only where the card has a height to fill; on a phone it
            // is sized by its own content inside the page scroll.
            if (isMobile) body else Expanded(child: body),
            if (pagination != null) pagination,
          ],
        ),
      ),
    );

    final above = <Widget>[
      _Header(
        controller: controller,
        searchController: _search,
        onAdd: AdminAccess.canCreate(AdminModules.sports)
            ? () => _openForm(context, controller)
            : null,
      ),
      const SizedBox(height: AdminTokens.space4),
      _SummaryCards(controller: controller),
      if (controller.activeFilterCount > 0) ...[
        const SizedBox(height: AdminTokens.space3),
        _ActiveFilters(controller: controller),
      ],
      const SizedBox(height: AdminTokens.space4),
    ];

    // Seven summary cards plus a stacked header do not fit above a fixed-height
    // list on a phone, so the whole page scrolls there instead.
    final list = ColoredBox(
      color: tokens.canvas,
      child: isMobile
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(AdminTokens.space4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [...above, listCard],
              ),
            )
          : Padding(
              padding: const EdgeInsets.all(AdminTokens.space6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [...above, Expanded(child: listCard)],
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
          child: SportDetailPanel(
            sport: selected,
            state: controller.detailState,
            error: controller.detailError,
            stats: controller.stats,
            statsState: controller.statsState,
            busy: controller.isRowBusy(selected.id),
            onClose: controller.closeSport,
            onRetry: () => controller.openSport(selected),
            onRetryStats: controller.retryStats,
            onAction: (action, sport) =>
                _handleAction(context, controller, action, sport),
            onToggleVisibility: (sport, value) =>
                _toggleVisibility(context, controller, sport, value),
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
    SportsController controller,
    SportAction action,
    Sport sport,
  ) async {
    switch (action) {
      case SportAction.view:
        // Not awaited: the panel opens with the row already in hand and fills
        // in when the detail and stats reads land.
        unawaited(controller.openSport(sport));
        if (MediaQuery.sizeOf(context).width < AdminTokens.tabletMax) {
          await _showDetailSheet(context, controller);
        }
      case SportAction.edit:
        await _openForm(context, controller, sport: sport);
      case SportAction.delete:
        await _confirmDelete(context, controller, sport);
      case SportAction.setActive:
        await _changeStatus(context, controller, sport, AdminUserStatus.active);
      case SportAction.setInactive:
        await _changeStatus(
          context,
          controller,
          sport,
          AdminUserStatus.inactive,
        );
      case SportAction.assignComplex:
        await _assignComplex(context, controller, sport);
    }
  }

  /// `PATCH /{id}/status`. The controller flips the badge first, so the only
  /// thing left here is telling the admin when the server disagreed.
  Future<void> _changeStatus(
    BuildContext context,
    SportsController controller,
    Sport sport,
    AdminUserStatus status,
  ) async {
    try {
      await controller.setStatus(sport.id, status);
      if (!context.mounted) return;
      AdminFeedback.success(
        context,
        '${sport.displayName} is now ${status.label}.',
      );
    } catch (error) {
      if (!context.mounted) return;
      AdminFeedback.error(context, _messageOf(error, 'change the status'));
    }
  }

  /// `PATCH /{id}/show-on-frontend`, same optimistic treatment as the status.
  Future<void> _toggleVisibility(
    BuildContext context,
    SportsController controller,
    Sport sport,
    bool showOnFrontend,
  ) async {
    try {
      await controller.setVisibility(sport.id, showOnFrontend);
      if (!context.mounted) return;
      AdminFeedback.success(
        context,
        showOnFrontend
            ? '${sport.displayName} is now shown in the app.'
            : '${sport.displayName} is now hidden from the app.',
      );
    } catch (error) {
      if (!context.mounted) return;
      AdminFeedback.error(context, _messageOf(error, 'update the visibility'));
    }
  }

  /// `POST /{id}/assign-ground`.
  Future<void> _assignComplex(
    BuildContext context,
    SportsController controller,
    Sport sport,
  ) async {
    // The picker needs its options before the dialog is useful.
    if (controller.complexes.isEmpty && !controller.complexesState.isLoading) {
      await controller.loadComplexes();
    }
    if (!context.mounted) return;

    final assigned = await AssignComplexDialog.show(
      context,
      sport: sport,
      complexes: controller.complexes,
      complexesState: controller.complexesState,
      onReloadComplexes: () => controller.loadComplexes(refresh: true),
      onSubmit: (complexId) => controller.assignComplex(sport.id, complexId),
    );

    if (!assigned || !context.mounted) return;

    AdminFeedback.success(
      context,
      '${sport.displayName} was assigned to a new complex.',
    );
  }

  Future<void> _showDetailSheet(
    BuildContext context,
    SportsController controller,
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
        return ChangeNotifierProvider<SportsController>.value(
          value: controller,
          child: Consumer<SportsController>(
            builder: (context, live, _) {
              final sport = live.selected;
              if (sport == null) return const SizedBox.shrink();

              return SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.88,
                child: SportDetailPanel(
                  sport: sport,
                  state: live.detailState,
                  error: live.detailError,
                  stats: live.stats,
                  statsState: live.statsState,
                  busy: live.isRowBusy(sport.id),
                  onClose: () => Navigator.of(sheetContext).pop(),
                  onRetry: () => live.openSport(sport),
                  onRetryStats: live.retryStats,
                  onToggleVisibility: (target, value) =>
                      _toggleVisibility(context, live, target, value),
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
    ).whenComplete(controller.closeSport);
  }

  Future<void> _openForm(
    BuildContext context,
    SportsController controller, {
    Sport? sport,
  }) async {
    // The venue picker needs its options before the dialog is useful.
    if (controller.complexes.isEmpty && !controller.complexesState.isLoading) {
      await controller.loadComplexes();
    }
    if (!context.mounted) return;

    final saved = await SportFormDialog.show(
      context,
      sport: sport,
      complexes: controller.complexes,
      complexesState: controller.complexesState,
      onReloadComplexes: () => controller.loadComplexes(refresh: true),
      onUploadImage: controller.uploadImage,
      onSubmit: (draft) async {
        if (sport == null) {
          await controller.create(draft);
        } else {
          await controller.update(sport.id, draft);
        }
      },
    );

    if (!saved || !context.mounted) return;

    AdminFeedback.success(
      context,
      sport == null
          ? 'Sport created and the list has been refreshed.'
          : 'Changes to ${sport.displayName} were saved.',
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    SportsController controller,
    Sport sport,
  ) async {
    final tokens = AdminTheme.of(context);

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete this sport?',
      message:
          'Deleting this sport may affect programs, batches, courts and '
          'student records. This cannot be undone.',
      confirmLabel: 'Delete sport',
      destructive: true,
      detail: SolidCard(
        padding: const EdgeInsets.all(AdminTokens.space3),
        color: tokens.surfaceAlt,
        radius: AdminTokens.radiusMd,
        child: Row(
          children: [
            SportThumb(sport: sport, size: 38),
            const SizedBox(width: AdminTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sport.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    [
                      if ((sport.sportComplexName ?? '').isNotEmpty)
                        sport.sportComplexName!,
                      if ((sport.categoryRaw ?? '').isNotEmpty)
                        sport.categoryLabel,
                      if (sport.programCount != null)
                        '${sport.programCount} programs',
                    ].join(' · '),
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
      await controller.delete(sport.id);
      if (!context.mounted) return;
      AdminFeedback.success(context, '${sport.displayName} was deleted.');
    } catch (error) {
      if (!context.mounted) return;
      // The controller has already put the row back.
      AdminFeedback.error(context, _messageOf(error, 'delete this sport'));
    }
  }

  static String _messageOf(Object error, String action) {
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.isEmpty ? 'Could not $action.' : text;
  }
}

// -----------------------------------------------------------------------------
// Summary cards
// -----------------------------------------------------------------------------

/// The seven figures above the table, counted from the rows `/sports` returned
/// for the current complex and status — there is no catalogue-wide statistics
/// endpoint to ask.
class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.controller});

  final SportsController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    final loading = controller.isFirstLoad;

    final cards = <Widget>[
      StatCard(
        label: 'Total sports',
        value: loading ? null : summary.total,
        icon: Icons.sports_tennis_rounded,
        gradient: const [Color(0xFF1A237E), Color(0xFF3F51B5)],
      ),
      StatCard(
        label: 'Active sports',
        value: loading ? null : summary.active,
        icon: Icons.check_circle_outline_rounded,
        gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
      ),
      StatCard(
        label: 'Indoor sports',
        value: loading ? null : summary.indoor,
        icon: Icons.home_work_outlined,
        gradient: const [Color(0xFF3949AB), Color(0xFF7986CB)],
      ),
      StatCard(
        label: 'Outdoor sports',
        value: loading ? null : summary.outdoor,
        icon: Icons.park_outlined,
        gradient: const [Color(0xFF059669), Color(0xFF6EE7B7)],
      ),
      StatCard(
        label: 'Visible on frontend',
        value: loading ? null : summary.onFrontend,
        icon: Icons.visibility_outlined,
        gradient: const [Color(0xFF0EA5E9), Color(0xFF67E8F9)],
      ),
      StatCard(
        label: 'Total programs',
        value: loading ? null : summary.programs,
        icon: Icons.school_outlined,
        gradient: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
      ),
      StatCard(
        label: 'Total courts',
        value: loading ? null : summary.courts,
        icon: Icons.grid_view_rounded,
        gradient: const [Color(0xFFEC4899), Color(0xFFF9A8D4)],
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Four across on a desktop, two below that — never one, which would
        // push the table off a phone screen behind seven stacked cards.
        final columns = constraints.maxWidth >= 1000 ? 4 : 2;
        const gap = AdminTokens.space4;
        final cardWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: cards
              .map((card) => SizedBox(width: cardWidth, child: card))
              .toList(),
        );
      },
    );
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

  final SportsController controller;
  final TextEditingController searchController;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < AdminTokens.tabletMax;

    final complex = controller.filteredComplex;

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Sports',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: tokens.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          controller.state.isReady
              ? complex == null
                    ? '${controller.page.total} of ${controller.summary.total} '
                          'sports across every complex'
                    : '${controller.page.total} of '
                          '${controller.summary.total} sports at '
                          '${complex.name}'
              : 'Sports offered across complexes',
          style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
        ),
      ],
    );

    final search = SizedBox(
      width: narrow ? double.infinity : 320,
      child: TextField(
        controller: searchController,
        onChanged: controller.onSearchChanged,
        style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search by sport name',
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

    // Hidden rather than disabled: an action the account may not perform
    // should not be advertised.
    final add = onAdd == null
        ? const SizedBox.shrink()
        : FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 19),
            label: const Text('Add Sport'),
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

  final SportsController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final count = controller.activeFilterCount;
    final active = count > 0;

    return OutlinedButton.icon(
      onPressed: () => SportFilterSheet.show(context, controller),
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

  final SportsController controller;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (controller.complexFilter != null)
        _RemovableChip(
          // Falls back to the id if the venue list has not landed yet.
          label:
              controller.filteredComplex?.name ??
              'Complex #${controller.complexFilter}',
          onRemove: () => controller.setComplexFilter(null),
        ),
      if (controller.statusFilter != null)
        _RemovableChip(
          label: controller.statusFilter!.label,
          onRemove: () => controller.setStatusFilter(null),
        ),
      if (controller.categoryFilter != null)
        _RemovableChip(
          label: controller.categoryFilter!.label,
          onRemove: () => controller.setCategoryFilter(null),
        ),
      if (controller.visibilityFilter != null)
        _RemovableChip(
          label: controller.visibilityFilter! ? 'Shown' : 'Hidden',
          onRemove: () => controller.setVisibilityFilter(null),
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
    required this.shrinkWrap,
    required this.onAdd,
    required this.onAction,
    required this.onToggleVisibility,
  });

  final SportsController controller;
  final bool isMobile;

  /// True when the page owns the scroll, so every branch here has to size
  /// itself rather than expand into a viewport it does not have.
  final bool shrinkWrap;

  final VoidCallback? onAdd;
  final void Function(SportAction action, Sport sport) onAction;
  final void Function(Sport sport, bool showOnFrontend) onToggleVisibility;

  /// The empty and error views centre themselves in whatever height they are
  /// given; inline inside the page scroll there is none, so one is supplied.
  Widget _sized(Widget child) =>
      shrinkWrap ? SizedBox(height: 340, child: child) : child;

  @override
  Widget build(BuildContext context) {
    if (controller.isFirstLoad) {
      final shimmer = TableShimmer(rows: shrinkWrap ? 5 : 8, dense: isMobile);
      return shrinkWrap ? shimmer : SingleChildScrollView(child: shimmer);
    }

    if (controller.state.isFailed) {
      return _sized(
        ErrorStateView(
          title: 'Could not load sports',
          message:
              controller.error ??
              'The server did not return the sports list. Check your '
                  'connection and try again.',
          onRetry: controller.refresh,
        ),
      );
    }

    final sports = controller.pageRows;

    if (sports.isEmpty) {
      return _sized(
        controller.hasFilters
            ? EmptyStateView(
                icon: Icons.search_off_rounded,
                title: 'No sports match these filters',
                message:
                    'Try a different search term, or clear the filters to '
                    'see every sport.',
                actionLabel: 'Clear filters',
                onAction: controller.clearFilters,
              )
            : EmptyStateView(
                icon: Icons.sports_tennis_outlined,
                title: 'No sports yet',
                message:
                    'Add the first sport to start managing programs, '
                    'courts and enrolments against it.',
                actionLabel: 'Add Sport',
                onAction: onAdd,
                secondaryLabel: 'Refresh',
                onSecondary: controller.refresh,
              ),
      );
    }

    if (isMobile) {
      return ListView.builder(
        padding: EdgeInsets.zero,
        shrinkWrap: shrinkWrap,
        // The page's own scroll view drives this list when it is inline.
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        itemCount: sports.length,
        itemBuilder: (context, index) {
          final sport = sports[index];
          return SportCard(
            sport: sport,
            busy: controller.isRowBusy(sport.id),
            onAction: onAction,
            onToggleVisibility: onToggleVisibility,
          );
        },
      );
    }

    return SingleChildScrollView(
      child: SportsTable(
        sports: sports,
        sort: controller.sort,
        descending: controller.descending,
        onSort: controller.toggleSort,
        onAction: onAction,
        onToggleVisibility: onToggleVisibility,
        isBusy: controller.isRowBusy,
        selectedId: controller.selected?.id,
      ),
    );
  }
}
