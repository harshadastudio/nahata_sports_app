import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/court.dart';
import '../../domain/entities/court_slot.dart';
import '../../domain/repositories/court_slot_repository.dart';
import '../navigation/admin_module.dart';
import '../state/courts_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dialogs.dart';
import '../widgets/admin_states.dart';
import '../widgets/availability_calendar.dart';
import '../widgets/court_detail_panel.dart';
import '../widgets/court_filter_sheet.dart';
import '../widgets/court_form_dialog.dart';
import '../widgets/courts_table.dart';
import '../widgets/glass_card.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/stat_card.dart';
import 'court_slots_page.dart';

/// Court management: the summary cards, the list, the cross-court availability
/// view, and every write action.
class CourtsPage extends StatefulWidget {
  const CourtsPage({super.key});

  @override
  State<CourtsPage> createState() => _CourtsPageState();
}

class _CourtsPageState extends State<CourtsPage> {
  late final TextEditingController _search;

  /// The two views this page offers. Availability is court-agnostic by design
  /// — `/courts/availability` answers "is anything free", not "which court" —
  /// so it is a mode rather than a filter on the table.
  bool _showAvailability = false;

  @override
  void initState() {
    super.initState();
    AdminLog.life('CourtsPage mounted');
    _search = TextEditingController(
      text: context.read<CourtsController>().search,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<CourtsController>();
      if (controller.state.isIdle) controller.load();
      // Warmed here so the Add dialog and both filters open ready.
      controller.loadSports();
      controller.loadComplexes();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    AdminLog.life('CourtsPage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CourtsController>();
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

    final body = _showAvailability
        ? _AvailabilityView(controller: controller)
        : _Body(
            controller: controller,
            isMobile: isMobile,
            // On a phone the page scrolls as one piece, so the row list must
            // lay itself out inline rather than claim a viewport of its own.
            shrinkWrap: isMobile,
            onAdd: AdminAccess.canCreate(AdminModules.courts)
                ? () => _openForm(context, controller)
                : null,
            onAction: (action, court) =>
                _handleAction(context, controller, action, court),
            onToggleVisibility: (court, value) =>
                _toggleVisibility(context, controller, court, value),
          );

    final pagination =
        !_showAvailability &&
            (controller.page.isNotEmpty || controller.page.page > 1)
        ? PaginationBar(
            page: controller.page,
            limit: controller.limit,
            busy: controller.state.isLoading,
            onPage: controller.goToPage,
            onLimit: controller.setLimit,
          )
        : null;

    final inline = isMobile && !_showAvailability;

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
        showAvailability: _showAvailability,
        onAdd: AdminAccess.canCreate(AdminModules.courts)
            ? () => _openForm(context, controller)
            : null,
      ),
      const SizedBox(height: AdminTokens.space4),
      _ViewSwitcher(
        showAvailability: _showAvailability,
        onChanged: (value) => setState(() => _showAvailability = value),
      ),
      if (!_showAvailability) ...[
        const SizedBox(height: AdminTokens.space4),
        _SummaryCards(controller: controller),
        if (controller.activeFilterCount > 0) ...[
          const SizedBox(height: AdminTokens.space3),
          _ActiveFilters(controller: controller),
        ],
      ],
      const SizedBox(height: AdminTokens.space4),
    ];

    // Six summary cards plus a stacked header do not fit above a fixed-height
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
                    // The availability view owns a scroll of its own, so it
                    // gets a bounded height rather than nesting unbounded.
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

    if (!isDesktop || selected == null || _showAvailability) return list;

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
          child: CourtDetailPanel(
            court: selected,
            state: controller.detailState,
            error: controller.detailError,
            busy: controller.isRowBusy(selected.id),
            onClose: controller.closeCourt,
            onRetry: () => controller.openCourt(selected),
            onAction: (action, court) =>
                _handleAction(context, controller, action, court),
            onToggleVisibility: (court, value) =>
                _toggleVisibility(context, controller, court, value),
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
    CourtsController controller,
    CourtAction action,
    Court court,
  ) async {
    // Last line of defence for the write actions: even if some path still
    // offered one, `data.user.permissions` decides whether it runs.
    if (!(action == CourtAction.view) &&
        !AdminAccess.can(
          AdminModules.courts,
          action == CourtAction.delete ? 'delete' : 'edit',
        )) {
      return;
    }

    switch (action) {
      case CourtAction.view:
        // Not awaited: the panel opens with the row already in hand and fills
        // in when the detail read lands.
        unawaited(controller.openCourt(court));
        if (MediaQuery.sizeOf(context).width < AdminTokens.tabletMax) {
          await _showDetailSheet(context, controller);
        }
      case CourtAction.edit:
        await _openForm(context, controller, court: court);
      case CourtAction.manageSlots:
        await CourtSlotsPage.open(
          context,
          court: court,
          repository: context.read<CourtSlotRepository>(),
        );
      case CourtAction.delete:
        await _confirmDelete(context, controller, court);
      case CourtAction.setActive:
        await _changeStatus(context, controller, court, AdminUserStatus.active);
      case CourtAction.setInactive:
        await _changeStatus(
          context,
          controller,
          court,
          AdminUserStatus.inactive,
        );
    }
  }

  Future<void> _changeStatus(
    BuildContext context,
    CourtsController controller,
    Court court,
    AdminUserStatus status,
  ) async {
    try {
      await controller.setStatus(court.id, status);
      if (!context.mounted) return;
      AdminFeedback.success(
        context,
        '${court.displayName} is now ${status.label}.',
      );
    } catch (error) {
      if (!context.mounted) return;
      AdminFeedback.error(context, _messageOf(error, 'change the status'));
    }
  }

  /// `PATCH /{id}/show-on-frontend`. The controller flips the switch first, so
  /// the only thing left here is telling the admin when the server disagreed.
  Future<void> _toggleVisibility(
    BuildContext context,
    CourtsController controller,
    Court court,
    bool showOnFrontend,
  ) async {
    try {
      await controller.setVisibility(court.id, showOnFrontend);
      if (!context.mounted) return;
      AdminFeedback.success(
        context,
        showOnFrontend
            ? '${court.displayName} is now shown in the app.'
            : '${court.displayName} is now hidden from the app.',
      );
    } catch (error) {
      if (!context.mounted) return;
      AdminFeedback.error(context, _messageOf(error, 'update the visibility'));
    }
  }

  Future<void> _showDetailSheet(
    BuildContext context,
    CourtsController controller,
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
        return ChangeNotifierProvider<CourtsController>.value(
          value: controller,
          child: Consumer<CourtsController>(
            builder: (context, live, _) {
              final court = live.selected;
              if (court == null) return const SizedBox.shrink();

              return SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.88,
                child: CourtDetailPanel(
                  court: court,
                  state: live.detailState,
                  error: live.detailError,
                  busy: live.isRowBusy(court.id),
                  onClose: () => Navigator.of(sheetContext).pop(),
                  onRetry: () => live.openCourt(court),
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
    ).whenComplete(controller.closeCourt);
  }

  Future<void> _openForm(
    BuildContext context,
    CourtsController controller, {
    Court? court,
  }) async {
    // Both pickers need their options before the dialog is useful.
    final warmups = <Future<void>>[
      if (controller.sports.isEmpty && !controller.sportsState.isLoading)
        controller.loadSports(),
      if (controller.complexes.isEmpty && !controller.complexesState.isLoading)
        controller.loadComplexes(),
    ];
    if (warmups.isNotEmpty) await Future.wait(warmups);
    if (!context.mounted) return;

    final saved = await CourtFormDialog.show(
      context,
      court: court,
      sports: controller.sports,
      sportsState: controller.sportsState,
      onReloadSports: () => controller.loadSports(refresh: true),
      complexes: controller.complexes,
      complexesState: controller.complexesState,
      onReloadComplexes: () => controller.loadComplexes(refresh: true),
      knownSurfaces: controller.knownSurfaces,
      onUploadImage: controller.uploadImage,
      onSubmit: (draft) async {
        if (court == null) {
          await controller.create(draft);
        } else {
          await controller.update(court.id, draft);
        }
      },
    );

    if (!saved || !context.mounted) return;

    AdminFeedback.success(
      context,
      court == null
          ? 'Court created and the list has been refreshed.'
          : 'Changes to ${court.displayName} were saved.',
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CourtsController controller,
    Court court,
  ) async {
    final tokens = AdminTheme.of(context);

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete this court?',
      message:
          'Deleting this court removes its slots and may affect existing '
          'bookings. This cannot be undone.',
      confirmLabel: 'Delete court',
      destructive: true,
      detail: SolidCard(
        padding: const EdgeInsets.all(AdminTokens.space3),
        color: tokens.surfaceAlt,
        radius: AdminTokens.radiusMd,
        child: Row(
          children: [
            CourtThumb(court: court, size: 38),
            const SizedBox(width: AdminTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    court.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    [
                      if ((court.sportName ?? '').isNotEmpty) court.sportName!,
                      if ((court.sportComplexName ?? '').isNotEmpty)
                        court.sportComplexName!,
                      if (court.slotCount != null) '${court.slotCount} slots',
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
      await controller.delete(court.id);
      if (!context.mounted) return;
      AdminFeedback.success(context, '${court.displayName} was deleted.');
    } catch (error) {
      if (!context.mounted) return;
      // The controller has already put the row back.
      AdminFeedback.error(context, _messageOf(error, 'delete this court'));
    }
  }

  static String _messageOf(Object error, String action) {
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.isEmpty ? 'Could not $action.' : text;
  }
}

// -----------------------------------------------------------------------------
// Cross-court availability
// -----------------------------------------------------------------------------

/// `GET /courts/availability` for the filters already on the page, plus a date.
///
/// It has no controller of its own: three inputs and one read, all of which
/// belong to this view rather than to the court list.
class _AvailabilityView extends StatefulWidget {
  const _AvailabilityView({required this.controller});

  final CourtsController controller;

  @override
  State<_AvailabilityView> createState() => _AvailabilityViewState();
}

class _AvailabilityViewState extends State<_AvailabilityView> {
  late DateTime _date;
  List<AvailabilityWindow> _windows = const [];
  ViewState _state = ViewState.idle;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _date = DateTime(now.year, now.month, now.day);
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repository = context.read<CourtSlotRepository>();
    final requested = _date;

    setState(() {
      _state = ViewState.loading;
      _error = null;
    });

    try {
      final result = await repository.fetchAvailability(
        complexId: widget.controller.complexFilter,
        sportId: widget.controller.sportFilter,
        date: requested,
      );
      // Dropped if the admin moved the date while this was in flight.
      if (!mounted || requested != _date) return;
      setState(() {
        _windows = result;
        _state = ViewState.ready;
      });
    } catch (error, stackTrace) {
      if (!mounted || requested != _date) return;
      AdminLog.failure(
        'Court availability failed',
        error: error,
        stackTrace: stackTrace,
      );
      setState(() {
        _state = ViewState.failed;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
      helpText: 'Select a date',
    );

    if (picked == null || !mounted) return;
    final normalised = DateTime(picked.year, picked.month, picked.day);
    if (normalised == _date) return;

    setState(() => _date = normalised);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final controller = widget.controller;

    final scope = [
      controller.filteredComplex?.name ?? 'Every complex',
      controller.filteredSport?.displayName ?? 'every sport',
    ].join(' · ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(AdminTokens.space4),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      scope,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      // Said plainly, because it is the point of this view.
                      'Free time across every court — court names are not '
                      'shown here.',
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today_rounded, size: 17),
                label: Text(
                  '${_date.day}/${_date.month}/${_date.year}',
                ),
              ),
              const SizedBox(width: AdminTokens.space3),
              OutlinedButton.icon(
                onPressed: _state.isLoading ? null : _load,
                icon: const Icon(Icons.refresh_rounded, size: 17),
                label: const Text('Refresh'),
              ),
            ],
          ),
        ),
        Expanded(
          child: CourtAvailabilityList(
            windows: _windows,
            state: _state,
            error: _error,
            onRetry: _load,
          ),
        ),
      ],
    );
  }
}

/// Courts / Availability.
class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({
    required this.showAvailability,
    required this.onChanged,
  });

  final bool showAvailability;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

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
          children: [
            for (final entry in const [
              (false, 'All courts'),
              (true, 'Availability'),
            ])
              GestureDetector(
                onTap: () => onChanged(entry.$1),
                child: AnimatedContainer(
                  duration: AdminTokens.fast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AdminTokens.space4,
                    vertical: AdminTokens.space2 + 2,
                  ),
                  decoration: BoxDecoration(
                    color: showAvailability == entry.$1
                        ? tokens.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(
                      AdminTokens.radiusPill,
                    ),
                    boxShadow: showAvailability == entry.$1
                        ? tokens.softShadow
                        : null,
                  ),
                  child: Text(
                    entry.$2,
                    style: TextStyle(
                      color: showAvailability == entry.$1
                          ? tokens.accent
                          : tokens.textSecondary,
                      fontSize: 12.5,
                      fontWeight: showAvailability == entry.$1
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Summary cards
// -----------------------------------------------------------------------------

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.controller});

  final CourtsController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    final loading = controller.isFirstLoad;

    final cards = <Widget>[
      StatCard(
        label: 'Total courts',
        value: loading ? null : summary.total,
        icon: Icons.grid_view_rounded,
        gradient: const [Color(0xFF1A237E), Color(0xFF3F51B5)],
      ),
      StatCard(
        label: 'Active courts',
        value: loading ? null : summary.active,
        icon: Icons.check_circle_outline_rounded,
        gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
      ),
      StatCard(
        label: 'Visible on frontend',
        value: loading ? null : summary.onFrontend,
        icon: Icons.visibility_outlined,
        gradient: const [Color(0xFF0EA5E9), Color(0xFF67E8F9)],
      ),
      StatCard(
        label: 'Hidden courts',
        value: loading ? null : summary.hidden,
        icon: Icons.visibility_off_outlined,
        gradient: const [Color(0xFF64748B), Color(0xFF94A3B8)],
      ),
      StatCard(
        label: 'Total slots',
        value: loading ? null : summary.slots,
        icon: Icons.schedule_rounded,
        gradient: const [Color(0xFF3949AB), Color(0xFF7986CB)],
        // The list route does not promise slot counters, so an em dash here
        // means "not reported" rather than "none".
        caption: loading
            ? null
            : (summary.slots == null ? 'Not reported by the list' : null),
      ),
      StatCard(
        label: 'Available slots',
        value: loading ? null : summary.availableSlots,
        icon: Icons.event_available_rounded,
        gradient: const [Color(0xFFEC4899), Color(0xFFF9A8D4)],
        caption: loading
            ? null
            : (summary.availableSlots == null
                  ? 'Not reported by the list'
                  : null),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // Three across on a desktop, two below that — never one, which would
        // push the table off a phone screen behind six stacked cards.
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
    required this.showAvailability,
    required this.onAdd,
  });

  final CourtsController controller;
  final TextEditingController searchController;
  final bool showAvailability;
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
          'Courts',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: tokens.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          controller.state.isReady && !showAvailability
              ? complex == null
                    ? '${controller.page.total} of ${controller.summary.total} '
                          'courts across every complex'
                    : '${controller.page.total} of '
                          '${controller.summary.total} courts at '
                          '${complex.name}'
              : 'Courts, surfaces and availability',
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
          hintText: 'Search by court name',
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
            label: const Text('Add Court'),
          );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: AdminTokens.space4),
          // The availability view has its own controls; the table's would only
          // confuse it.
          if (!showAvailability) ...[
            search,
            const SizedBox(height: AdminTokens.space3),
          ],
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
        if (!showAvailability) ...[
          const SizedBox(height: AdminTokens.space4),
          Align(alignment: Alignment.centerLeft, child: search),
        ],
      ],
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.controller});

  final CourtsController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final count = controller.activeFilterCount;
    final active = count > 0;

    return OutlinedButton.icon(
      onPressed: () => CourtFilterSheet.show(context, controller),
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

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.controller});

  final CourtsController controller;

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
      if (controller.sportFilter != null)
        _RemovableChip(
          label:
              controller.filteredSport?.displayName ??
              'Sport #${controller.sportFilter}',
          onRemove: () => controller.setSportFilter(null),
        ),
      if (controller.statusFilter != null)
        _RemovableChip(
          label: controller.statusFilter!.label,
          onRemove: () => controller.setStatusFilter(null),
        ),
      if (controller.surfaceFilter != null)
        _RemovableChip(
          label: controller.surfaceFilter!,
          onRemove: () => controller.setSurfaceFilter(null),
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

  final CourtsController controller;
  final bool isMobile;

  /// True when the page owns the scroll, so every branch here has to size
  /// itself rather than expand into a viewport it does not have.
  final bool shrinkWrap;

  final VoidCallback? onAdd;
  final void Function(CourtAction action, Court court) onAction;
  final void Function(Court court, bool showOnFrontend) onToggleVisibility;

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
          title: 'Could not load courts',
          message:
              controller.error ??
              'The server did not return the courts list. Check your '
                  'connection and try again.',
          onRetry: controller.refresh,
        ),
      );
    }

    final courts = controller.pageRows;

    if (courts.isEmpty) {
      return _sized(
        controller.hasFilters
            ? EmptyStateView(
                icon: Icons.search_off_rounded,
                title: 'No courts found',
                message:
                    'Nothing matches these filters. Try a different search '
                    'term, or clear the filters to see every court.',
                actionLabel: 'Clear filters',
                onAction: controller.clearFilters,
              )
            : EmptyStateView(
                icon: Icons.grid_view_outlined,
                title: 'No courts found',
                message:
                    'Add the first court to start scheduling slots and taking '
                    'bookings.',
                actionLabel: 'Add Court',
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
        itemCount: courts.length,
        itemBuilder: (context, index) {
          final court = courts[index];
          return CourtCard(
            court: court,
            busy: controller.isRowBusy(court.id),
            onAction: onAction,
            onToggleVisibility: onToggleVisibility,
          );
        },
      );
    }

    return SingleChildScrollView(
      child: CourtsTable(
        courts: courts,
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
