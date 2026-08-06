import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/coaching_enquiry.dart';
import '../state/coaching_enquiries_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dialogs.dart';
import '../widgets/admin_states.dart';
import '../widgets/coaching_enquiries_table.dart';
import '../widgets/coaching_enquiry_detail_panel.dart';
import '../widgets/coaching_enquiry_form_dialog.dart';
import '../widgets/enquiry_action_dialogs.dart';
import '../widgets/enquiry_stat_cards.dart';
import '../widgets/glass_card.dart';
import '../widgets/pagination_bar.dart';

/// Coaching Enquiries: the counters, the queue, and the follow-up.
class CoachingEnquiriesPage extends StatefulWidget {
  const CoachingEnquiriesPage({super.key});

  @override
  State<CoachingEnquiriesPage> createState() => _CoachingEnquiriesPageState();
}

class _CoachingEnquiriesPageState extends State<CoachingEnquiriesPage> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    AdminLog.life('CoachingEnquiriesPage mounted');
    _search = TextEditingController(
      text: context.read<CoachingEnquiriesController>().search,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<CoachingEnquiriesController>();
      if (controller.state.isIdle) controller.load();
      controller.loadStats();
      // Warmed here so the form and the assign dialog open with their lists
      // already filled.
      controller.loadFormOptions();
      controller.loadCoaches();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    AdminLog.life('CoachingEnquiriesPage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CoachingEnquiriesController>();
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

    final list = ColoredBox(
      color: tokens.canvas,
      child: Padding(
        padding: EdgeInsets.all(
          isMobile ? AdminTokens.space4 : AdminTokens.space6,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EnquiryStatCards(
              stats: controller.stats,
              state: controller.statsState,
              activeFilter: controller.statusFilter,
              onFilter: controller.setStatusFilter,
              onClearFilter: () => controller.setStatusFilter(
                controller.statusFilter ?? CoachingEnquiryStatus.isNew,
              ),
            ),
            const SizedBox(height: AdminTokens.space5),
            _Toolbar(
              controller: controller,
              searchController: _search,
              onAdd: () => _openForm(context, controller),
            ),
            const SizedBox(height: AdminTokens.space4),
            Expanded(
              child: SolidCard(
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      RefreshLine(visible: controller.isRefreshing),
                      Expanded(
                        child: _Body(
                          controller: controller,
                          isMobile: isMobile,
                          onAdd: () => _openForm(context, controller),
                          onAction: (action, enquiry) => _handleAction(
                            context,
                            controller,
                            action,
                            enquiry,
                          ),
                        ),
                      ),
                      // The phone list scrolls infinitely, so the page controls
                      // would only get in its way there.
                      if (!isMobile &&
                          (controller.enquiries.isNotEmpty ||
                              controller.page.page > 1))
                        PaginationBar(
                          page: controller.page,
                          limit: controller.limit,
                          busy: controller.state.isLoading,
                          onPage: controller.goToPage,
                          onLimit: controller.setLimit,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
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
          child: CoachingEnquiryDetailPanel(
            enquiry: selected,
            state: controller.detailState,
            onClose: controller.clearSelection,
            onAction: (action, enquiry) =>
                _handleAction(context, controller, action, enquiry),
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
    CoachingEnquiriesController controller,
    EnquiryAction action,
    CoachingEnquiry enquiry,
  ) async {
    switch (action) {
      case EnquiryAction.view:
        controller.select(enquiry);
        if (MediaQuery.sizeOf(context).width < AdminTokens.tabletMax) {
          await _showDetailSheet(context, controller);
        }
      case EnquiryAction.edit:
        await _openRemarks(context, controller, enquiry);
      case EnquiryAction.assignCoach:
        await _openAssignCoach(context, controller, enquiry);
      case EnquiryAction.changeStatus:
        await _openStatus(context, controller, enquiry);
      case EnquiryAction.call:
        await _launch(
          context,
          Uri(scheme: 'tel', path: (enquiry.phone ?? '').trim()),
          'No dialler is available on this device.',
        );
      case EnquiryAction.email:
        await _launch(
          context,
          Uri(scheme: 'mailto', path: (enquiry.email ?? '').trim()),
          'No email app is available on this device.',
        );
      case EnquiryAction.delete:
        await _confirmDelete(context, controller, enquiry);
    }
  }

  Future<void> _launch(
    BuildContext context,
    Uri uri,
    String unavailable,
  ) async {
    if (uri.path.isEmpty) return;

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched || !context.mounted) return;
      AdminFeedback.info(context, unavailable);
    } catch (error) {
      AdminLog.failure('Could not open $uri', error: error);
      if (!context.mounted) return;
      AdminFeedback.info(context, unavailable);
    }
  }

  Future<void> _showDetailSheet(
    BuildContext context,
    CoachingEnquiriesController controller,
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
        return ChangeNotifierProvider<CoachingEnquiriesController>.value(
          value: controller,
          child: Consumer<CoachingEnquiriesController>(
            builder: (context, live, _) {
              final enquiry = live.selected;
              if (enquiry == null) return const SizedBox.shrink();

              // top: false — the sheet is bottom-anchored, so only the
              // gesture bar / home indicator has to be kept clear of the
              // panel's action buttons.
              return SafeArea(
                top: false,
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.9,
                  child: CoachingEnquiryDetailPanel(
                    enquiry: enquiry,
                    state: live.detailState,
                    onClose: () => Navigator.of(sheetContext).pop(),
                    onAction: (action, target) async {
                      // Calling, emailing and the follow-up dialogs all leave
                      // the sheet where it is — the desk comes straight back to
                      // the same enquiry.
                      if (action != EnquiryAction.delete) {
                        await _handleAction(sheetContext, live, action, target);
                        return;
                      }

                      Navigator.of(sheetContext).pop();
                      if (!context.mounted) return;
                      await _handleAction(context, live, action, target);
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    ).whenComplete(controller.clearSelection);
  }

  Future<void> _openForm(
    BuildContext context,
    CoachingEnquiriesController controller,
  ) async {
    // The dropdowns need their options before the dialog is useful.
    if (controller.complexes.isEmpty && !controller.complexesState.isLoading) {
      await controller.loadFormOptions();
    }
    if (!context.mounted) return;

    final created = await CoachingEnquiryFormDialog.show(
      context,
      sports: controller.sports,
      sportsState: controller.sportsState,
      complexes: controller.complexes,
      complexesState: controller.complexesState,
      onReloadOptions: () => controller.loadFormOptions(refresh: true),
      onSubmit: controller.create,
    );

    if (created == null || !context.mounted) return;

    AdminFeedback.success(
      context,
      'Enquiry logged for ${created.displayName}.',
    );
  }

  Future<void> _openStatus(
    BuildContext context,
    CoachingEnquiriesController controller,
    CoachingEnquiry enquiry,
  ) async {
    final changed = await EnquiryStatusDialog.show(
      context,
      enquiry: enquiry,
      onSubmit: (status) =>
          controller.changeStatus(id: enquiry.id, status: status),
    );

    if (!changed || !context.mounted) return;
    AdminFeedback.success(context, 'Status updated.');
  }

  Future<void> _openAssignCoach(
    BuildContext context,
    CoachingEnquiriesController controller,
    CoachingEnquiry enquiry,
  ) async {
    if (controller.coaches.isEmpty && !controller.coachesState.isLoading) {
      await controller.loadCoaches();
    }
    if (!context.mounted) return;

    final assigned = await AssignCoachDialog.show(
      context,
      enquiry: enquiry,
      coaches: controller.coaches,
      coachesState: controller.coachesState,
      onReload: () => controller.loadCoaches(refresh: true),
      onSubmit: (coach) => controller.assignCoach(id: enquiry.id, coach: coach),
    );

    if (!assigned || !context.mounted) return;
    AdminFeedback.success(context, 'Coach assigned to this enquiry.');
  }

  Future<void> _openRemarks(
    BuildContext context,
    CoachingEnquiriesController controller,
    CoachingEnquiry enquiry,
  ) async {
    final saved = await EnquiryRemarksDialog.show(
      context,
      enquiry: enquiry,
      onSubmit: (update) => controller.update(enquiry.id, update),
    );

    if (!saved || !context.mounted) return;
    AdminFeedback.success(context, 'Enquiry updated.');
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CoachingEnquiriesController controller,
    CoachingEnquiry enquiry,
  ) async {
    final tokens = AdminTheme.of(context);

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete this enquiry?',
      message:
          'The enquiry and everything noted against it are removed. This '
          'cannot be undone.',
      confirmLabel: 'Delete enquiry',
      destructive: true,
      detail: SolidCard(
        padding: const EdgeInsets.all(AdminTokens.space3),
        color: tokens.surfaceAlt,
        radius: AdminTokens.radiusMd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              enquiry.displayName,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              [
                if (enquiry.interestLabel.isNotEmpty) enquiry.interestLabel,
                if (enquiry.statusLabel.isNotEmpty) enquiry.statusLabel,
              ].join(' · '),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: tokens.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );

    if (!confirmed || !context.mounted) return;

    try {
      await controller.delete(enquiry.id);
      if (!context.mounted) return;
      AdminFeedback.success(context, 'The enquiry was deleted.');
    } catch (error) {
      if (!context.mounted) return;
      AdminFeedback.error(context, _messageOf(error));
    }
  }

  static String _messageOf(Object error) {
    // ApiException.toString() carries the user-facing message.
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.isEmpty ? 'Could not delete this enquiry.' : text;
  }
}

// -----------------------------------------------------------------------------
// Toolbar
// -----------------------------------------------------------------------------

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.controller,
    required this.searchController,
    required this.onAdd,
  });

  final CoachingEnquiriesController controller;
  final TextEditingController searchController;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < AdminTokens.tabletMax;

    final search = SizedBox(
      width: narrow ? double.infinity : 320,
      child: TextField(
        controller: searchController,
        onChanged: controller.onSearchChanged,
        style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
        decoration: InputDecoration(
          hintText: 'Search name, phone or email',
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

    final filterChip = controller.statusFilter == null
        ? null
        : InputChip(
            label: Text('${controller.statusFilter!.label} only'),
            onDeleted: () => controller.setStatusFilter(null),
            deleteIcon: const Icon(Icons.close_rounded, size: 15),
            labelStyle: TextStyle(fontSize: 12, color: tokens.accent),
            backgroundColor: tokens.accentSoft,
            side: BorderSide(color: tokens.accent.withValues(alpha: 0.3)),
          );

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
      label: const Text('Log enquiry'),
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          search,
          if (filterChip != null) ...[
            const SizedBox(height: AdminTokens.space3),
            Align(alignment: Alignment.centerLeft, child: filterChip),
          ],
          const SizedBox(height: AdminTokens.space3),
          Row(
            children: [
              Expanded(child: refresh),
              const SizedBox(width: AdminTokens.space3),
              Expanded(flex: 2, child: add),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        search,
        if (filterChip != null) ...[
          const SizedBox(width: AdminTokens.space3),
          filterChip,
        ],
        const Spacer(),
        refresh,
        const SizedBox(width: AdminTokens.space3),
        add,
      ],
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
    required this.onAdd,
    required this.onAction,
  });

  final CoachingEnquiriesController controller;
  final bool isMobile;
  final VoidCallback onAdd;
  final void Function(EnquiryAction action, CoachingEnquiry enquiry) onAction;

  @override
  Widget build(BuildContext context) {
    if (controller.isFirstLoad) {
      return SingleChildScrollView(
        child: TableShimmer(rows: 7, dense: isMobile),
      );
    }

    if (controller.state.isFailed && controller.enquiries.isEmpty) {
      return ErrorStateView(
        title: 'Could not load coaching enquiries',
        message:
            controller.error ??
            'The server did not return a list. Check your connection and '
                'try again.',
        onRetry: controller.refresh,
      );
    }

    final enquiries = controller.enquiries;

    if (enquiries.isEmpty) {
      return controller.hasFilters
          ? EmptyStateView(
              icon: Icons.search_off_rounded,
              title: 'No enquiries match these filters',
              message:
                  'Try a different name or status — or clear the filters to '
                  'see the whole queue.',
              actionLabel: 'Clear filters',
              onAction: controller.clearFilters,
            )
          : EmptyStateView(
              icon: Icons.support_agent_rounded,
              title: 'No coaching enquiries yet',
              message:
                  'Enquiries submitted from the app land here. You can also '
                  'log one taken over the phone.',
              actionLabel: 'Log enquiry',
              onAction: onAdd,
              secondaryLabel: 'Refresh',
              onSecondary: controller.refresh,
            );
    }

    if (isMobile) {
      return _MobileList(controller: controller, onAction: onAction);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // A failed page change would otherwise leave the previous page on
        // screen with nothing to say it did not move.
        if (controller.state.isFailed)
          _InlineError(
            message: controller.error ?? 'Could not refresh this list.',
            onRetry: controller.refresh,
          ),
        Expanded(
          child: SingleChildScrollView(
            child: CoachingEnquiriesTable(
              enquiries: enquiries,
              onAction: onAction,
              selectedId: controller.selected?.id,
            ),
          ),
        ),
      ],
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.space5,
        vertical: AdminTokens.space3,
      ),
      decoration: BoxDecoration(
        color: tokens.danger.withValues(alpha: 0.08),
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 17, color: tokens.danger),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: tokens.danger, fontSize: 12.5),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

/// The phone list: pull to refresh at the top, load-more at the bottom.
class _MobileList extends StatefulWidget {
  const _MobileList({required this.controller, required this.onAction});

  final CoachingEnquiriesController controller;
  final void Function(EnquiryAction action, CoachingEnquiry enquiry) onAction;

  @override
  State<_MobileList> createState() => _MobileListState();
}

class _MobileListState extends State<_MobileList> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  /// Fetches the next page a screen before the end, so the list does not stall
  /// under the thumb. The controller ignores a call it is already serving.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels < position.maxScrollExtent - 400) return;
    widget.controller.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final enquiries = controller.enquiries;

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: enquiries.length + 1,
        itemBuilder: (context, index) {
          if (index == enquiries.length) {
            return _ListFooter(controller: controller);
          }
          return CoachingEnquiryCard(
            key: ValueKey<int>(enquiries[index].id),
            enquiry: enquiries[index],
            onAction: widget.onAction,
          );
        },
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.controller});

  final CoachingEnquiriesController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    if (controller.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(AdminTokens.space5),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (controller.state.isFailed) {
      return Padding(
        padding: const EdgeInsets.all(AdminTokens.space5),
        child: Column(
          children: [
            Text(
              controller.error ?? 'Could not load more enquiries.',
              textAlign: TextAlign.center,
              style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
            ),
            const SizedBox(height: AdminTokens.space3),
            OutlinedButton.icon(
              onPressed: controller.loadMore,
              icon: const Icon(Icons.refresh_rounded, size: 17),
              label: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    if (controller.hasMore) {
      return Padding(
        padding: const EdgeInsets.all(AdminTokens.space5),
        child: Center(
          child: TextButton(
            onPressed: controller.loadMore,
            child: const Text('Load more'),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(AdminTokens.space5),
      child: Center(
        child: Text(
          '${controller.enquiries.length} enquir'
          '${controller.enquiries.length == 1 ? 'y' : 'ies'} loaded',
          style: TextStyle(color: tokens.textMuted, fontSize: 12),
        ),
      ),
    );
  }
}
