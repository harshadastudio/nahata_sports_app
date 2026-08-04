import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/batch.dart';
import '../state/batches_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_export.dart';
import '../utils/admin_format.dart';
import '../widgets/admin_dialogs.dart';
import '../widgets/admin_states.dart';
import '../widgets/batch_detail_panel.dart';
import '../widgets/batch_filter_sheet.dart';
import '../widgets/batch_form_dialog.dart';
import '../widgets/batch_group_views.dart';
import '../widgets/batches_table.dart';
import '../widgets/glass_card.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/stat_card.dart';

/// Batch management: the summary cards, the list, the two grouped breakdowns,
/// and every write action.
class BatchesPage extends StatefulWidget {
  const BatchesPage({super.key});

  @override
  State<BatchesPage> createState() => _BatchesPageState();
}

class _BatchesPageState extends State<BatchesPage> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    AdminLog.life('BatchesPage mounted');
    _search = TextEditingController(
      text: context.read<BatchesController>().search,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<BatchesController>();
      if (controller.state.isIdle) controller.load();
      // Warmed here so the Add dialog, the filters and both grouped views open
      // ready.
      controller.loadSports();
      controller.loadCoaches();
      controller.loadComplexes();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    AdminLog.life('BatchesPage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BatchesController>();
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
    final isList = controller.view == BatchesView.list;

    final body = switch (controller.view) {
      BatchesView.list => _Body(
        controller: controller,
        isMobile: isMobile,
        // On a phone the page scrolls as one piece, so the row list must lay
        // itself out inline rather than claim a viewport of its own.
        shrinkWrap: isMobile,
        onAdd: () => _openForm(context, controller),
        onAction: (action, batch) =>
            _handleAction(context, controller, action, batch),
      ),
      BatchesView.bySport => SportBatchesView(
        controller: controller,
        onAction: (action, batch) =>
            _handleAction(context, controller, action, batch),
      ),
      BatchesView.byCoach => CoachBatchesView(
        controller: controller,
        onAction: (action, batch) =>
            _handleAction(context, controller, action, batch),
      ),
    };

    final pagination =
        isList && (controller.page.isNotEmpty || controller.page.page > 1)
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
          mainAxisSize: isMobile && isList ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RefreshLine(visible: controller.isRefreshing),
            if (isMobile && isList) body else Expanded(child: body),
            if (pagination != null) pagination,
          ],
        ),
      ),
    );

    final above = <Widget>[
      _Header(
        controller: controller,
        searchController: _search,
        onAdd: () => _openForm(context, controller),
        onExport: (format, origin) =>
            _export(context, controller, format, origin),
      ),
      const SizedBox(height: AdminTokens.space4),
      _ViewSwitcher(controller: controller),
      if (isList) ...[
        const SizedBox(height: AdminTokens.space4),
        _SummaryCards(controller: controller),
        if (controller.catalogueCapped != null) ...[
          const SizedBox(height: AdminTokens.space3),
          _CapNotice(controller: controller),
        ],
        if (controller.activeFilterCount > 0) ...[
          const SizedBox(height: AdminTokens.space3),
          _ActiveFilters(controller: controller),
        ],
      ],
      const SizedBox(height: AdminTokens.space4),
    ];

    // Five summary cards plus a stacked header do not fit above a fixed-height
    // list on a phone, so the whole page scrolls there instead. Pull-to-refresh
    // wraps that scroll, which is the only place the gesture makes sense.
    final list = ColoredBox(
      color: tokens.canvas,
      child: isMobile
          ? RefreshIndicator(
              onRefresh: controller.refresh,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AdminTokens.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...above,
                    // The grouped views own a scroll of their own, so they get
                    // a bounded height rather than being nested unbounded.
                    if (isList)
                      listCard
                    else
                      SizedBox(height: 520, child: listCard),
                  ],
                ),
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
          child: BatchDetailPanel(
            batch: selected,
            state: controller.detailState,
            error: controller.detailError,
            stats: controller.stats,
            statsState: controller.statsState,
            busy: controller.isRowBusy(selected.id),
            onClose: controller.closeBatch,
            onRetry: () => controller.openBatch(selected),
            onRetryStats: controller.retryStats,
            onAction: (action, batch) =>
                _handleAction(context, controller, action, batch),
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
    BatchesController controller,
    BatchAction action,
    AdminBatch batch,
  ) async {
    switch (action) {
      case BatchAction.view:
        // Not awaited: the panel opens with the row already in hand and fills
        // in when the detail and stats reads land.
        unawaited(controller.openBatch(batch));
        if (MediaQuery.sizeOf(context).width < AdminTokens.tabletMax) {
          await _showDetailSheet(context, controller);
        }
      case BatchAction.edit:
        await _openForm(context, controller, batch: batch);
      case BatchAction.delete:
        await _confirmDelete(context, controller, batch);
      case BatchAction.setActive:
        await _changeStatus(context, controller, batch, AdminUserStatus.active);
      case BatchAction.setInactive:
        await _changeStatus(
          context,
          controller,
          batch,
          AdminUserStatus.inactive,
        );
    }
  }

  /// `PATCH /{id}/status`. The controller flips the badge first, so the only
  /// thing left here is telling the admin when the server disagreed.
  Future<void> _changeStatus(
    BuildContext context,
    BatchesController controller,
    AdminBatch batch,
    AdminUserStatus status,
  ) async {
    try {
      await controller.setStatus(batch.id, status);
      if (!context.mounted) return;
      AdminFeedback.success(
        context,
        '${batch.displayName} is now ${status.label}.',
      );
    } catch (error) {
      if (!context.mounted) return;
      AdminFeedback.error(context, _messageOf(error, 'change the status'));
    }
  }

  Future<void> _showDetailSheet(
    BuildContext context,
    BatchesController controller,
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
        return ChangeNotifierProvider<BatchesController>.value(
          value: controller,
          child: Consumer<BatchesController>(
            builder: (context, live, _) {
              final batch = live.selected;
              if (batch == null) return const SizedBox.shrink();

              return SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.88,
                child: BatchDetailPanel(
                  batch: batch,
                  state: live.detailState,
                  error: live.detailError,
                  stats: live.stats,
                  statsState: live.statsState,
                  busy: live.isRowBusy(batch.id),
                  onClose: () => Navigator.of(sheetContext).pop(),
                  onRetry: () => live.openBatch(batch),
                  onRetryStats: live.retryStats,
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
    ).whenComplete(controller.closeBatch);
  }

  Future<void> _openForm(
    BuildContext context,
    BatchesController controller, {
    AdminBatch? batch,
  }) async {
    // All three pickers need their options before the dialog is useful.
    final warmups = <Future<void>>[
      if (controller.sports.isEmpty && !controller.sportsState.isLoading)
        controller.loadSports(),
      if (controller.coaches.isEmpty && !controller.coachesState.isLoading)
        controller.loadCoaches(),
      if (controller.complexes.isEmpty && !controller.complexesState.isLoading)
        controller.loadComplexes(),
    ];
    if (warmups.isNotEmpty) await Future.wait(warmups);
    if (!context.mounted) return;

    final saved = await BatchFormDialog.show(
      context,
      batch: batch,
      sports: controller.sports,
      sportsState: controller.sportsState,
      onReloadSports: () => controller.loadSports(refresh: true),
      coaches: controller.coaches,
      coachesState: controller.coachesState,
      onReloadCoaches: () => controller.loadCoaches(refresh: true),
      complexes: controller.complexes,
      complexesState: controller.complexesState,
      onReloadComplexes: () => controller.loadComplexes(refresh: true),
      knownAgeGroups: controller.knownAgeGroups,
      onUploadImage: controller.uploadImage,
      onSubmit: (draft) async {
        if (batch == null) {
          await controller.create(draft);
        } else {
          await controller.update(batch.id, draft);
        }
      },
    );

    if (!saved || !context.mounted) return;

    AdminFeedback.success(
      context,
      batch == null
          ? 'Batch created and the list has been refreshed.'
          : 'Changes to ${batch.displayName} were saved.',
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    BatchesController controller,
    AdminBatch batch,
  ) async {
    final tokens = AdminTheme.of(context);
    final enrolled = batch.currentStudents ?? 0;

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete this batch?',
      message: enrolled > 0
          // The count is the whole point of the warning when there is one.
          ? '$enrolled student${enrolled == 1 ? ' is' : 's are'} currently '
                'enrolled. Deleting this batch may affect their enrolment, '
                'attendance and payment records. This cannot be undone.'
          : 'Deleting this batch may affect enrolment, attendance and payment '
                'records. This cannot be undone.',
      confirmLabel: 'Delete batch',
      destructive: true,
      detail: SolidCard(
        padding: const EdgeInsets.all(AdminTokens.space3),
        color: tokens.surfaceAlt,
        radius: AdminTokens.radiusMd,
        child: Row(
          children: [
            BatchThumb(batch: batch, size: 38),
            const SizedBox(width: AdminTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    batch.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    [
                      if ((batch.sportName ?? '').isNotEmpty) batch.sportName!,
                      if ((batch.coachName ?? '').isNotEmpty) batch.coachName!,
                      if (batch.maxStudents != null)
                        '${batch.currentStudents ?? 0}/${batch.maxStudents}',
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
      await controller.delete(batch.id);
      if (!context.mounted) return;
      AdminFeedback.success(context, '${batch.displayName} was deleted.');
    } catch (error) {
      if (!context.mounted) return;
      // The controller has already put the row back.
      AdminFeedback.error(context, _messageOf(error, 'delete this batch'));
    }
  }

  /// Writes whatever the table is currently showing.
  Future<void> _export(
    BuildContext context,
    BatchesController controller,
    ExportFormat format,
    Rect? origin,
  ) async {
    final rows = controller.exportRows;

    if (rows.isEmpty) {
      AdminFeedback.error(context, 'There is nothing to export yet.');
      return;
    }

    // Said plainly, because it is the one thing an export can quietly get
    // wrong: while paging, only the page in hand is written.
    final scope = controller.isCatalogueMode
        ? '${rows.length} batches matching the current filters'
        : '${rows.length} batches on this page';

    try {
      await AdminExport.run<AdminBatch>(
        format: format,
        fileName: AdminExport.buildFileName('batches', DateTime.now()),
        title: 'Batches',
        subtitle: 'Nahata Sports · $scope',
        sharePositionOrigin: origin,
        columns: _exportColumns,
        rows: rows,
      );

      if (!context.mounted) return;
      AdminFeedback.success(
        context,
        'Exported $scope as ${format.label}.',
      );
    } catch (error) {
      if (!context.mounted) return;
      AdminFeedback.error(context, _messageOf(error, 'export the batches'));
    }
  }

  /// The export layout, kept beside the table it mirrors so the two stay in
  /// step. Every cell goes through the same formatters the screen uses, so an
  /// exported "—" means exactly what it means on screen.
  static final List<ExportColumn<AdminBatch>> _exportColumns = [
    ExportColumn('Batch name', (batch) => batch.displayName),
    ExportColumn('Sport', (batch) => AdminFormat.text(batch.sportName)),
    ExportColumn('Coach', (batch) => AdminFormat.text(batch.coachName)),
    ExportColumn(
      'Sports complex',
      (batch) => AdminFormat.text(batch.sportComplexName),
    ),
    ExportColumn('Schedule', (batch) => batch.scheduleLabel),
    ExportColumn('Days', (batch) => batch.daysLabel),
    ExportColumn('Start date', (batch) => AdminFormat.date(batch.startDate)),
    ExportColumn('End date', (batch) => AdminFormat.date(batch.endDate)),
    ExportColumn('Age group', (batch) => AdminFormat.text(batch.ageGroup)),
    ExportColumn('Duration', (batch) => AdminFormat.text(batch.duration)),
    ExportColumn(
      'Fees',
      (batch) => AdminFormat.currency(batch.fees),
      numeric: true,
    ),
    ExportColumn(
      'Max students',
      (batch) => AdminFormat.number(batch.maxStudents),
      numeric: true,
    ),
    ExportColumn(
      'Current students',
      (batch) => AdminFormat.number(batch.currentStudents),
      numeric: true,
    ),
    ExportColumn(
      'Available seats',
      (batch) => AdminFormat.number(batch.availableSeats),
      numeric: true,
    ),
    ExportColumn(
      'Occupancy',
      (batch) => batch.occupancyPercent == null
          ? AdminFormat.dash
          : '${batch.occupancyPercent}%',
      numeric: true,
    ),
    ExportColumn(
      'Status',
      (batch) =>
          batch.statusLabel.isEmpty ? AdminFormat.dash : batch.statusLabel,
    ),
  ];

  static String _messageOf(Object error, String action) {
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.isEmpty ? 'Could not $action.' : text;
  }
}

// -----------------------------------------------------------------------------
// View switcher
// -----------------------------------------------------------------------------

/// List / By sport / By coach. The two grouped views are separate routes rather
/// than a client-side regrouping of the list, so they are a mode rather than a
/// filter.
class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({required this.controller});

  final BatchesController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < AdminTokens.mobileMax;

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: BatchesView.values.map((view) {
            final selected = controller.view == view;

            return GestureDetector(
              onTap: () => controller.setView(view),
              child: AnimatedContainer(
                duration: AdminTokens.fast,
                padding: const EdgeInsets.symmetric(
                  horizontal: AdminTokens.space4,
                  vertical: AdminTokens.space2 + 2,
                ),
                decoration: BoxDecoration(
                  color: selected ? tokens.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
                  boxShadow: selected ? tokens.softShadow : null,
                ),
                child: Text(
                  narrow ? view.shortLabel : view.label,
                  style: TextStyle(
                    color: selected ? tokens.accent : tokens.textSecondary,
                    fontSize: 12.5,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// Shown when the catalogue read stopped at its page cap, so a filter that
/// looks like "no matches" can be recognised as "not everything is loaded".
class _CapNotice extends StatelessWidget {
  const _CapNotice({required this.controller});

  final BatchesController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final capped = controller.catalogueCapped;
    if (capped == null) return const SizedBox.shrink();

    final (loaded, total) = capped;

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space3),
      decoration: BoxDecoration(
        color: tokens.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: tokens.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 17, color: tokens.warning),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              'Filtering across the first $loaded of $total batches. Narrow '
              'the sport or status filter — those are applied by the server — '
              'to search the rest.',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Summary cards
// -----------------------------------------------------------------------------

/// The five figures above the table.
///
/// "Total batches" is the server's own count. The other four are counted from
/// the rows in hand, so while paging they caption themselves "on this page"
/// rather than implying they describe the whole academy.
class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.controller});

  final BatchesController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    final loading = controller.isFirstLoad;
    final scoped = controller.summaryIsPageScoped;
    final caption = scoped ? 'On this page' : null;

    final cards = <Widget>[
      StatCard(
        label: 'Total batches',
        value: loading ? null : summary.total,
        icon: Icons.groups_2_rounded,
        gradient: const [Color(0xFF1A237E), Color(0xFF3F51B5)],
      ),
      StatCard(
        label: 'Active batches',
        value: loading ? null : summary.active,
        icon: Icons.check_circle_outline_rounded,
        gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
        caption: caption,
      ),
      StatCard(
        label: 'Inactive batches',
        value: loading ? null : summary.inactive,
        icon: Icons.pause_circle_outline_rounded,
        gradient: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
        caption: caption,
      ),
      StatCard(
        label: 'Total students',
        value: loading ? null : summary.totalStudents,
        icon: Icons.groups_outlined,
        gradient: const [Color(0xFF0EA5E9), Color(0xFF67E8F9)],
        caption: loading
            ? null
            : (summary.totalStudents == null ? 'Not reported' : caption),
      ),
      StatCard(
        label: 'Available seats',
        value: loading ? null : summary.availableSeats,
        icon: Icons.event_seat_outlined,
        gradient: const [Color(0xFFEC4899), Color(0xFFF9A8D4)],
        caption: loading
            ? null
            : (summary.availableSeats == null ? 'Capacity not set' : caption),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Three across on a desktop, two below that — never one, which would
        // push the table off a phone screen behind five stacked cards.
        final columns = constraints.maxWidth >= 1000 ? 3 : 2;
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
    required this.onExport,
  });

  final BatchesController controller;
  final TextEditingController searchController;
  final VoidCallback onAdd;
  final void Function(ExportFormat format, Rect? origin) onExport;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < AdminTokens.tabletMax;
    final isList = controller.view == BatchesView.list;

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Batches',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: tokens.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          controller.state.isReady && isList
              ? '${controller.page.total} batch'
                    '${controller.page.total == 1 ? '' : 'es'}'
                    '${controller.isCatalogueMode ? ' matching' : ''}'
              : 'Programmes, schedules and enrolment',
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
          hintText: 'Search by batch, coach or sport',
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
    final export = _ExportButton(onExport: onExport);

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
      label: const Text('Add Batch'),
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          if (isList) ...[
            const SizedBox(height: AdminTokens.space4),
            search,
            const SizedBox(height: AdminTokens.space3),
            Row(
              children: [
                Expanded(child: filter),
                const SizedBox(width: AdminTokens.space3),
                Expanded(child: export),
              ],
            ),
          ],
          const SizedBox(height: AdminTokens.space3),
          Row(
            children: [
              Expanded(child: refresh),
              const SizedBox(width: AdminTokens.space3),
              Expanded(child: add),
            ],
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: title),
            if (isList) ...[
              filter,
              const SizedBox(width: AdminTokens.space3),
              export,
              const SizedBox(width: AdminTokens.space3),
            ],
            refresh,
            const SizedBox(width: AdminTokens.space3),
            add,
          ],
        ),
        if (isList) ...[
          const SizedBox(height: AdminTokens.space4),
          Align(alignment: Alignment.centerLeft, child: search),
        ],
      ],
    );
  }
}

/// Opens the filter sheet, with a badge counting the filters in force.
class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.controller});

  final BatchesController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final count = controller.activeFilterCount;
    final active = count > 0;

    return OutlinedButton.icon(
      onPressed: () => BatchFilterSheet.show(context, controller),
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

/// CSV / Excel / PDF.
class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.onExport});

  final void Function(ExportFormat format, Rect? origin) onExport;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return PopupMenuButton<ExportFormat>(
      tooltip: 'Export',
      position: PopupMenuPosition.under,
      onSelected: (format) {
        // The share sheet is a popover on iPad and has to be anchored to the
        // control that opened it, so the button's own rect goes along.
        final box = context.findRenderObject() as RenderBox?;
        final origin = box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size;
        onExport(format, origin);
      },
      itemBuilder: (context) => [
        for (final format in ExportFormat.values)
          PopupMenuItem<ExportFormat>(
            value: format,
            height: 40,
            child: Row(
              children: [
                Icon(
                  switch (format) {
                    ExportFormat.csv => Icons.description_outlined,
                    ExportFormat.excel => Icons.table_chart_outlined,
                    ExportFormat.pdf => Icons.picture_as_pdf_outlined,
                  },
                  size: 17,
                  color: tokens.textPrimary,
                ),
                const SizedBox(width: AdminTokens.space3),
                Text(
                  format.label,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
      ],
      child: OutlinedButton.icon(
        // The menu owns the tap; the button is the affordance.
        onPressed: null,
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.textPrimary,
          side: BorderSide(color: tokens.borderStrong),
          disabledForegroundColor: tokens.textPrimary,
        ),
        icon: const Icon(Icons.ios_share_rounded, size: 17),
        label: const Text('Export'),
      ),
    );
  }
}

/// The filters currently in force, each removable in one tap.
class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.controller});

  final BatchesController controller;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (controller.statusFilter != null)
        _RemovableChip(
          label: controller.statusFilter!.label,
          onRemove: () => controller.setStatusFilter(null),
        ),
      if (controller.sportFilter != null)
        _RemovableChip(
          // Falls back to the id if the sport list has not landed yet.
          label:
              controller.filteredSport?.displayName ??
              'Sport #${controller.sportFilter}',
          onRemove: () => controller.setSportFilter(null),
        ),
      if (controller.coachFilter != null)
        _RemovableChip(
          label:
              controller.filteredCoach?.displayName ??
              'Coach #${controller.coachFilter}',
          onRemove: () => controller.setCoachFilter(null),
        ),
      if (controller.complexFilter != null)
        _RemovableChip(
          label:
              controller.filteredComplex?.name ??
              'Complex #${controller.complexFilter}',
          onRemove: () => controller.setComplexFilter(null),
        ),
      if (controller.ageGroupFilter != null)
        _RemovableChip(
          label: controller.ageGroupFilter!,
          onRemove: () => controller.setAgeGroupFilter(null),
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
  });

  final BatchesController controller;
  final bool isMobile;

  /// True when the page owns the scroll, so every branch here has to size
  /// itself rather than expand into a viewport it does not have.
  final bool shrinkWrap;

  final VoidCallback onAdd;
  final void Function(BatchAction action, AdminBatch batch) onAction;

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
          title: 'Could not load batches',
          message:
              controller.error ??
              'The server did not return the batches list. Check your '
                  'connection and try again.',
          onRetry: controller.refresh,
        ),
      );
    }

    final batches = controller.pageRows;

    if (batches.isEmpty) {
      return _sized(
        controller.hasFilters
            ? EmptyStateView(
                icon: Icons.search_off_rounded,
                title: 'No batches found',
                message:
                    'Nothing matches these filters. Try a different search '
                    'term, or clear the filters to see every batch.',
                actionLabel: 'Clear filters',
                onAction: controller.clearFilters,
              )
            : EmptyStateView(
                icon: Icons.groups_2_outlined,
                title: 'No batches found',
                message:
                    'Add the first batch to start scheduling sessions and '
                    'enrolling students.',
                actionLabel: 'Add Batch',
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
        itemCount: batches.length,
        itemBuilder: (context, index) {
          final batch = batches[index];
          return BatchCard(
            batch: batch,
            busy: controller.isRowBusy(batch.id),
            onAction: onAction,
          );
        },
      );
    }

    return SingleChildScrollView(
      child: BatchesTable(
        batches: batches,
        sort: controller.sort,
        descending: controller.descending,
        onSort: controller.toggleSort,
        onAction: onAction,
        isBusy: controller.isRowBusy,
        selectedId: controller.selected?.id,
      ),
    );
  }
}
