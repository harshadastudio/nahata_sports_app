import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/event_pass.dart';
import '../state/event_passes_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dialogs.dart';
import '../widgets/admin_states.dart';
import '../widgets/court_filter_sheet.dart';
import '../widgets/event_booking_dialog.dart';
import '../widgets/event_pass_detail_panel.dart';
import '../widgets/event_pass_form_dialog.dart';
import '../widgets/event_passes_table.dart';
import '../widgets/glass_card.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/stat_card.dart';

/// Event pass management: the summary cards, the event list, the bookings
/// board, and every write action.
class EventPassesPage extends StatefulWidget {
  const EventPassesPage({super.key});

  @override
  State<EventPassesPage> createState() => _EventPassesPageState();
}

class _EventPassesPageState extends State<EventPassesPage> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    AdminLog.life('EventPassesPage mounted');
    _search = TextEditingController(
      text: context.read<EventPassesController>().search,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<EventPassesController>();
      if (controller.state.isIdle) controller.load();
      controller.loadComplexes();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    AdminLog.life('EventPassesPage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<EventPassesController>();
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
    final isEvents = controller.view == EventsView.events;

    final body = isEvents
        ? _Body(
            controller: controller,
            isMobile: isMobile,
            shrinkWrap: isMobile,
            onAdd: () => _openForm(context, controller),
            onAction: (action, event) =>
                _handleAction(context, controller, action, event),
          )
        : _BookingsBody(controller: controller, isMobile: isMobile);

    final pagination = isEvents
        ? ((controller.page.isNotEmpty || controller.page.page > 1)
              ? PaginationBar(
                  page: controller.page,
                  limit: controller.limit,
                  busy: controller.state.isLoading,
                  onPage: controller.goToPage,
                  onLimit: controller.setLimit,
                )
              : null)
        : ((controller.bookingsPage.isNotEmpty ||
                  controller.bookingsPage.page > 1)
              ? PaginationBar(
                  page: controller.bookingsPage,
                  limit: controller.limit,
                  busy: controller.bookingsState.isLoading,
                  onPage: controller.goToBookingsPage,
                  onLimit: controller.setLimit,
                )
              : null);

    final inline = isMobile && isEvents;

    final listCard = SolidCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
        child: Column(
          mainAxisSize: inline ? MainAxisSize.min : MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RefreshLine(visible: controller.isRefreshing),
            if (inline) body else Expanded(child: body),
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
      ),
      const SizedBox(height: AdminTokens.space4),
      _ViewSwitcher(controller: controller),
      if (isEvents) ...[
        const SizedBox(height: AdminTokens.space4),
        _SummaryCards(controller: controller),
        if (controller.activeFilterCount > 0) ...[
          const SizedBox(height: AdminTokens.space3),
          _ActiveFilters(controller: controller),
        ],
      ],
      const SizedBox(height: AdminTokens.space4),
    ];

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
                    // The bookings board owns a scroll of its own, so it gets a
                    // bounded height rather than nesting unbounded.
                    if (inline)
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

    if (!isDesktop || selected == null || !isEvents) return list;

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
          child: EventPassDetailPanel(
            event: selected,
            state: controller.detailState,
            error: controller.detailError,
            onClose: controller.closeEvent,
            onRetry: () => controller.openEvent(selected),
            onAction: (action, event) =>
                _handleAction(context, controller, action, event),
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
    EventPassesController controller,
    EventAction action,
    AdminEventPass event,
  ) async {
    switch (action) {
      case EventAction.view:
        unawaited(controller.openEvent(event));
        if (MediaQuery.sizeOf(context).width < AdminTokens.tabletMax) {
          await _showDetailSheet(context, controller);
        }
      case EventAction.edit:
        await _openForm(context, controller, event: event);
      case EventAction.delete:
        await _confirmDelete(context, controller, event);
      case EventAction.setActive:
        await _setStatus(context, controller, event, AdminUserStatus.active);
      case EventAction.setInactive:
        await _setStatus(context, controller, event, AdminUserStatus.inactive);
      case EventAction.book:
        await _book(context, controller, event);
    }
  }

  Future<void> _setStatus(
    BuildContext context,
    EventPassesController controller,
    AdminEventPass event,
    AdminUserStatus status,
  ) async {
    try {
      await controller.setStatus(event.id, status);
      if (!context.mounted) return;
      AdminFeedback.success(
        context,
        '${event.displayTitle} is now ${status.label}.',
      );
    } catch (error) {
      if (!context.mounted) return;
      AdminFeedback.error(context, _messageOf(error, 'change the status'));
    }
  }

  /// Books passes for a walk-in. The dialog needs slot ids, which only the
  /// detail read reliably carries, so it is loaded first when the row has none.
  Future<void> _book(
    BuildContext context,
    EventPassesController controller,
    AdminEventPass event,
  ) async {
    var target = event;

    if (event.slots.every((slot) => slot.id == null)) {
      await controller.openEvent(event);
      if (!context.mounted) return;
      target = controller.selected ?? event;
    }

    if (!context.mounted) return;

    final booked = await EventBookingDialog.show(
      context,
      event: target,
      onSubmit: controller.createBooking,
    );

    if (!booked || !context.mounted) return;
    AdminFeedback.success(context, 'Passes booked for ${target.displayTitle}.');
  }

  Future<void> _showDetailSheet(
    BuildContext context,
    EventPassesController controller,
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
        return ChangeNotifierProvider<EventPassesController>.value(
          value: controller,
          child: Consumer<EventPassesController>(
            builder: (context, live, _) {
              final event = live.selected;
              if (event == null) return const SizedBox.shrink();

              return SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.88,
                child: EventPassDetailPanel(
                  event: event,
                  state: live.detailState,
                  error: live.detailError,
                  onClose: () => Navigator.of(sheetContext).pop(),
                  onRetry: () => live.openEvent(event),
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
    ).whenComplete(controller.closeEvent);
  }

  Future<void> _openForm(
    BuildContext context,
    EventPassesController controller, {
    AdminEventPass? event,
  }) async {
    if (controller.complexes.isEmpty && !controller.complexesState.isLoading) {
      await controller.loadComplexes();
    }
    if (!context.mounted) return;

    final saved = await EventPassFormDialog.show(
      context,
      event: event,
      complexes: controller.complexes,
      complexesState: controller.complexesState,
      onReloadComplexes: () => controller.loadComplexes(refresh: true),
      onUploadImage: controller.uploadImage,
      onSubmit: (draft) async {
        if (event == null) {
          await controller.create(draft);
        } else {
          await controller.update(event.id, draft);
        }
      },
    );

    if (!saved || !context.mounted) return;

    AdminFeedback.success(
      context,
      event == null
          ? 'Event created and the list has been refreshed.'
          : 'Changes to ${event.displayTitle} were saved.',
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    EventPassesController controller,
    AdminEventPass event,
  ) async {
    final tokens = AdminTheme.of(context);

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete this event?',
      message:
          'Deleting removes the event, its slots and its FAQs. Passes already '
          'sold against it may be affected. This cannot be undone.',
      confirmLabel: 'Delete event',
      destructive: true,
      detail: SolidCard(
        padding: const EdgeInsets.all(AdminTokens.space3),
        color: tokens.surfaceAlt,
        radius: AdminTokens.radiusMd,
        child: Row(
          children: [
            EventThumb(event: event, size: 38),
            const SizedBox(width: AdminTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    event.displayTitle,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    [
                      if ((event.sportComplexName ?? '').isNotEmpty)
                        event.sportComplexName!,
                      '${event.slotCount} slots',
                      if (event.totalCapacity != null)
                        '${event.totalCapacity} seats',
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
      await controller.delete(event.id);
      if (!context.mounted) return;
      AdminFeedback.success(context, '${event.displayTitle} was deleted.');
    } catch (error) {
      if (!context.mounted) return;
      // The controller has already put the row back.
      AdminFeedback.error(context, _messageOf(error, 'delete this event'));
    }
  }

  static String _messageOf(Object error, String action) {
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.isEmpty ? 'Could not $action.' : text;
  }
}

// -----------------------------------------------------------------------------
// Chrome
// -----------------------------------------------------------------------------

class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({required this.controller});

  final EventPassesController controller;

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
          children: EventsView.values.map((view) {
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

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.controller});

  final EventPassesController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    final loading = controller.isFirstLoad;
    final scoped = controller.summaryIsPageScoped;
    final caption = scoped ? 'On this page' : null;

    final cards = <Widget>[
      StatCard(
        label: 'Total events',
        value: loading ? null : summary.total,
        icon: Icons.confirmation_number_rounded,
        gradient: const [Color(0xFF1A237E), Color(0xFF3F51B5)],
      ),
      StatCard(
        label: 'Active events',
        value: loading ? null : summary.active,
        icon: Icons.check_circle_outline_rounded,
        gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
        caption: caption,
      ),
      StatCard(
        label: 'Still to run',
        value: loading ? null : summary.upcoming,
        icon: Icons.upcoming_rounded,
        gradient: const [Color(0xFF0EA5E9), Color(0xFF67E8F9)],
        caption: caption,
      ),
      StatCard(
        label: 'Total slots',
        value: loading ? null : summary.slots,
        icon: Icons.event_note_rounded,
        gradient: const [Color(0xFF3949AB), Color(0xFF7986CB)],
        caption: caption,
      ),
      StatCard(
        label: 'Total capacity',
        value: loading ? null : summary.capacity,
        icon: Icons.groups_outlined,
        gradient: const [Color(0xFFEC4899), Color(0xFFF9A8D4)],
        // An em dash means "no slot declared one", not "no seats".
        caption: loading
            ? null
            : (summary.capacity == null ? 'Not reported' : caption),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1000 ? 5 : 2;
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

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.searchController,
    required this.onAdd,
  });

  final EventPassesController controller;
  final TextEditingController searchController;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < AdminTokens.tabletMax;
    final isEvents = controller.view == EventsView.events;

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Event Passes',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: tokens.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          controller.state.isReady && isEvents
              ? '${controller.page.total} event'
                    '${controller.page.total == 1 ? '' : 's'}'
                    '${controller.isCatalogueMode ? ' matching' : ''}'
              : 'Events, their slots and their passes',
          style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
        ),
      ],
    );

    final search = SizedBox(
      width: narrow ? double.infinity : 320,
      child: TextField(
        controller: isEvents ? searchController : null,
        onChanged: isEvents
            ? controller.onSearchChanged
            : controller.onBookingSearchChanged,
        style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
        decoration: InputDecoration(
          hintText: isEvents
              ? 'Search by event or venue'
              : 'Search by customer, event or contact',
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 18,
            color: tokens.textMuted,
          ),
          suffixIcon: (isEvents ? controller.search : controller.bookingSearch)
                  .isEmpty
              ? null
              : IconButton(
                  onPressed: isEvents
                      ? controller.clearSearch
                      : () => controller.onBookingSearchChanged(''),
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
      label: const Text('Add Event'),
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
              if (isEvents) ...[
                Expanded(child: filter),
                const SizedBox(width: AdminTokens.space3),
              ],
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
            if (isEvents) ...[
              filter,
              const SizedBox(width: AdminTokens.space3),
            ],
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

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.controller});

  final EventPassesController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final count = controller.activeFilterCount;
    final active = count > 0;

    return OutlinedButton.icon(
      onPressed: () => _showFilters(context, controller),
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

/// Three filters is too few to justify a sheet file of its own, so it is built
/// inline from the shared chip and group widgets the Courts module exports.
Future<void> _showFilters(
  BuildContext context,
  EventPassesController controller,
) {
  AdminLog.ui('Event filter sheet opened');
  final query = TextEditingController();

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AdminTheme.of(context).surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(
        top: Radius.circular(AdminTokens.radiusXl),
      ),
    ),
    builder: (sheetContext) {
      final tokens = AdminTheme.of(sheetContext);

      return StatefulBuilder(
        builder: (context, setSheetState) {
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
                                  'Filter events',
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
                          const SizedBox(height: AdminTokens.space2),
                          Text(
                            'The events route documents no filter parameters, '
                            'so these are applied here — which means every '
                            'page is loaded first.',
                            style: TextStyle(
                              color: tokens.textMuted,
                              fontSize: 11,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: AdminTokens.space4),
                          const CourtGroupLabel('Status'),
                          const SizedBox(height: AdminTokens.space3),
                          Wrap(
                            spacing: AdminTokens.space2,
                            runSpacing: AdminTokens.space2,
                            children: [
                              CourtFilterChip(
                                label: 'All',
                                selected: controller.statusFilter == null,
                                onTap: () => controller.setStatusFilter(null),
                              ),
                              for (final status in const [
                                AdminUserStatus.active,
                                AdminUserStatus.inactive,
                              ])
                                CourtFilterChip(
                                  label: status.label,
                                  selected: controller.statusFilter == status,
                                  onTap: () => controller.setStatusFilter(
                                    controller.statusFilter == status
                                        ? null
                                        : status,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: AdminTokens.space5),
                          const CourtGroupLabel('Timing'),
                          const SizedBox(height: AdminTokens.space3),
                          Wrap(
                            spacing: AdminTokens.space2,
                            runSpacing: AdminTokens.space2,
                            children: [
                              CourtFilterChip(
                                label: 'All events',
                                selected: !controller.upcomingOnly,
                                onTap: () =>
                                    controller.setUpcomingOnly(false),
                              ),
                              CourtFilterChip(
                                label: 'Still to run',
                                selected: controller.upcomingOnly,
                                onTap: () => controller.setUpcomingOnly(true),
                              ),
                            ],
                          ),
                          const SizedBox(height: AdminTokens.space5),
                          CourtSearchableGroup(
                            label: 'Sports complex',
                            query: query,
                            onQueryChanged: () => setSheetState(() {}),
                            state: controller.complexesState,
                            onReload: () =>
                                controller.loadComplexes(refresh: true),
                            options: [
                              for (final complex in controller.complexes)
                                (id: complex.id, label: complex.name),
                            ],
                            selectedId: controller.complexFilter,
                            onSelect: controller.setComplexFilter,
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
        },
      );
    },
  ).whenComplete(() {
    query.dispose();
    AdminLog.ui('Event filter sheet closed');
  });
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.controller});

  final EventPassesController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    final chips = <Widget>[
      if (controller.statusFilter != null)
        _Chip(
          label: controller.statusFilter!.label,
          onRemove: () => controller.setStatusFilter(null),
        ),
      if (controller.upcomingOnly)
        _Chip(
          label: 'Still to run',
          onRemove: () => controller.setUpcomingOnly(false),
        ),
      if (controller.complexFilter != null)
        _Chip(
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
              foregroundColor: tokens.textSecondary,
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

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onRemove});

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
// Bodies
// -----------------------------------------------------------------------------

class _Body extends StatelessWidget {
  const _Body({
    required this.controller,
    required this.isMobile,
    required this.shrinkWrap,
    required this.onAdd,
    required this.onAction,
  });

  final EventPassesController controller;
  final bool isMobile;
  final bool shrinkWrap;
  final VoidCallback onAdd;
  final void Function(EventAction action, AdminEventPass event) onAction;

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
          title: 'Could not load the events',
          message:
              controller.error ??
              'The server did not return the event list. Check your '
                  'connection and try again.',
          onRetry: controller.refresh,
        ),
      );
    }

    final events = controller.pageRows;

    if (events.isEmpty) {
      return _sized(
        controller.hasFilters
            ? EmptyStateView(
                icon: Icons.search_off_rounded,
                title: 'No events found',
                message:
                    'Nothing matches these filters. Try a different search '
                    'term, or clear the filters to see every event.',
                actionLabel: 'Clear filters',
                onAction: controller.clearFilters,
              )
            : EmptyStateView(
                icon: Icons.confirmation_number_outlined,
                title: 'No events found',
                message:
                    'Add the first event to start selling passes for it.',
                actionLabel: 'Add Event',
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
        physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          return EventPassCard(
            event: event,
            busy: controller.isRowBusy(event.id),
            onAction: onAction,
          );
        },
      );
    }

    return SingleChildScrollView(
      child: EventPassesTable(
        events: events,
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

class _BookingsBody extends StatelessWidget {
  const _BookingsBody({required this.controller, required this.isMobile});

  final EventPassesController controller;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    if (controller.bookingsState.isLoading && controller.bookings.isEmpty) {
      return const SingleChildScrollView(child: TableShimmer(rows: 8));
    }

    if (controller.bookingsState.isFailed) {
      return ErrorStateView(
        title: 'Could not load the event bookings',
        message:
            controller.bookingsError ??
            'The server did not return any event bookings.',
        onRetry: controller.loadBookings,
      );
    }

    final bookings = controller.visibleBookings;

    if (bookings.isEmpty) {
      return EmptyStateView(
        icon: Icons.confirmation_number_outlined,
        title: 'No bookings found',
        message: controller.bookingSearch.trim().isEmpty
            ? 'No passes have been sold yet.'
            : 'Nothing matches that search among the bookings on this page.',
        actionLabel: 'Refresh',
        onAction: controller.loadBookings,
      );
    }

    if (isMobile) {
      return ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: bookings.length,
        itemBuilder: (context, index) =>
            EventBookingCard(booking: bookings[index]),
      );
    }

    return SingleChildScrollView(
      child: EventBookingsTable(bookings: bookings),
    );
  }
}
