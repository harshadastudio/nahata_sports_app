import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/visitor_pass.dart';
import '../state/view_state.dart';
import '../state/visitor_passes_controller.dart';
import '../theme/admin_theme.dart';
import '../utils/visitor_pass_actions.dart';
import '../utils/visitor_pass_sharing.dart';
import '../widgets/admin_dialogs.dart';
import '../widgets/admin_states.dart';
import '../widgets/glass_card.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/visitor_pass_detail_panel.dart';
import '../widgets/visitor_passes_table.dart';

/// Visitor Passes: the list, the gate scanner, and the pass lifecycle.
class VisitorPassesPage extends StatefulWidget {
  const VisitorPassesPage({super.key});

  @override
  State<VisitorPassesPage> createState() => _VisitorPassesPageState();
}

class _VisitorPassesPageState extends State<VisitorPassesPage> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    AdminLog.life('VisitorPassesPage mounted');
    _search = TextEditingController(
      text: context.read<VisitorPassesController>().search,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<VisitorPassesController>();
      if (controller.state.isIdle) controller.load();
      // Warmed here so the Generate dialog opens with its picker filled, and
      // so the Delete action can be shown or hidden without a flash.
      controller.loadComplexes();
      controller.loadRole();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    AdminLog.life('VisitorPassesPage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<VisitorPassesController>();
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
            _Toolbar(
              controller: controller,
              searchController: _search,
              onAdd: () => VisitorPassActions.generate(context, controller),
              onScan: () => _openScanner(context, controller),
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
                          onAdd: () =>
                              VisitorPassActions.generate(context, controller),
                          onAction: (action, pass) =>
                              _handleAction(context, controller, action, pass),
                        ),
                      ),
                      // The phone list scrolls infinitely, so the page
                      // controls would only get in its way there.
                      if (!isMobile &&
                          (controller.passes.isNotEmpty ||
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
          child: VisitorPassDetailPanel(
            pass: selected,
            state: controller.detailState,
            canDelete: controller.canDelete,
            onClose: controller.clearSelection,
            onShareOutcome: (outcome) => _reportOutcome(context, outcome),
            onAction: (action, pass) =>
                _handleAction(context, controller, action, pass),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  //
  // The flows themselves live in [VisitorPassActions] — the Security Dashboard
  // offers the same six, and one gate must not behave differently from another.
  // ---------------------------------------------------------------------------

  /// Opens the camera scanner, then refreshes: statuses will have moved on
  /// while it was up.
  Future<void> _openScanner(
    BuildContext context,
    VisitorPassesController controller,
  ) async {
    if (!await VisitorPassActions.openScanner(context, controller)) return;
    await controller.refresh();
  }

  Future<void> _handleAction(
    BuildContext context,
    VisitorPassesController controller,
    VisitorPassAction action,
    VisitorPass pass,
  ) async {
    switch (action) {
      case VisitorPassAction.view:
        controller.select(pass);
        if (MediaQuery.sizeOf(context).width < AdminTokens.tabletMax) {
          await _showDetailSheet(context, controller);
        }
      case VisitorPassAction.checkIn:
        await VisitorPassActions.scan(
          context,
          controller,
          pass,
          VisitorScanType.checkIn,
        );
      case VisitorPassAction.checkOut:
        await VisitorPassActions.scan(
          context,
          controller,
          pass,
          VisitorScanType.checkOut,
        );
      case VisitorPassAction.share:
        _reportOutcome(context, await VisitorPassSharing.share(pass));
      case VisitorPassAction.whatsapp:
        _reportOutcome(context, await VisitorPassSharing.shareToWhatsApp(pass));
      case VisitorPassAction.email:
        await VisitorPassActions.sendEmail(context, controller, pass);
      case VisitorPassAction.delete:
        await VisitorPassActions.confirmDelete(context, controller, pass);
    }
  }



  Future<void> _showDetailSheet(
    BuildContext context,
    VisitorPassesController controller,
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
        return ChangeNotifierProvider<VisitorPassesController>.value(
          value: controller,
          child: Consumer<VisitorPassesController>(
            builder: (context, live, _) {
              final pass = live.selected;
              if (pass == null) return const SizedBox.shrink();

              // top: false — the sheet is bottom-anchored, so only the
              // gesture bar / home indicator has to be kept clear of the
              // panel's action buttons.
              return SafeArea(
                top: false,
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.9,
                  child: VisitorPassDetailPanel(
                    pass: pass,
                    state: live.detailState,
                    canDelete: live.canDelete,
                    onClose: () => Navigator.of(sheetContext).pop(),
                    onShareOutcome: (outcome) =>
                        _reportOutcome(sheetContext, outcome),
                    onAction: (action, target) async {
                      // A scan keeps the sheet open so the desk sees the new
                      // status land; everything else replaces it.
                      if (action == VisitorPassAction.checkIn ||
                          action == VisitorPassAction.checkOut ||
                          action == VisitorPassAction.share ||
                          action == VisitorPassAction.whatsapp) {
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




  void _reportOutcome(BuildContext context, ShareOutcome outcome) {
    if (!context.mounted) return;
    if (outcome.ok) {
      AdminFeedback.success(context, outcome.message);
    } else {
      AdminFeedback.error(context, outcome.message);
    }
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
    required this.onScan,
  });

  final VisitorPassesController controller;
  final TextEditingController searchController;
  final VoidCallback onAdd;
  final VoidCallback onScan;

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
          hintText: 'Search name, phone or pass code',
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

    final scan = OutlinedButton.icon(
      onPressed: onScan,
      icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
      label: const Text('Scan'),
    );

    final add = FilledButton.icon(
      onPressed: onAdd,
      icon: const Icon(Icons.add_rounded, size: 19),
      label: const Text('Generate pass'),
    );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          search,
          const SizedBox(height: AdminTokens.space3),
          Row(
            children: [
              Expanded(child: refresh),
              const SizedBox(width: AdminTokens.space3),
              Expanded(child: scan),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          add,
        ],
      );
    }

    return Row(
      children: [
        search,
        const Spacer(),
        refresh,
        const SizedBox(width: AdminTokens.space3),
        scan,
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

  final VisitorPassesController controller;
  final bool isMobile;
  final VoidCallback onAdd;
  final void Function(VisitorPassAction action, VisitorPass pass) onAction;

  @override
  Widget build(BuildContext context) {
    if (controller.isFirstLoad) {
      return SingleChildScrollView(
        child: TableShimmer(rows: 7, dense: isMobile),
      );
    }

    if (controller.state.isFailed && controller.passes.isEmpty) {
      return ErrorStateView(
        title: 'Could not load visitor passes',
        message:
            controller.error ??
            'The server did not return a list. Check your connection and '
                'try again.',
        onRetry: controller.refresh,
      );
    }

    final passes = controller.passes;

    if (passes.isEmpty) {
      return controller.hasFilters
          ? EmptyStateView(
              icon: Icons.search_off_rounded,
              title: 'No visitor passes match this search',
              message:
                  'Try a different name, phone number or pass code — or clear '
                  'the search to see every pass.',
              actionLabel: 'Clear search',
              onAction: controller.clearSearch,
            )
          : EmptyStateView(
              icon: Icons.badge_outlined,
              title: 'No visitor passes yet',
              message:
                  'Generate a pass and the visitor gets a QR code to scan on '
                  'the way in and on the way out.',
              actionLabel: 'Generate pass',
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
            child: VisitorPassesTable(
              passes: passes,
              canDelete: controller.canDelete,
              onAction: onAction,
              selectedKey: controller.selected?.key,
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

  final VisitorPassesController controller;
  final void Function(VisitorPassAction action, VisitorPass pass) onAction;

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
    final passes = controller.passes;

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: passes.length + 1,
        itemBuilder: (context, index) {
          if (index == passes.length) {
            return _ListFooter(controller: controller);
          }
          return VisitorPassCard(
            key: ValueKey<String>(passes[index].key),
            pass: passes[index],
            canDelete: controller.canDelete,
            onAction: widget.onAction,
          );
        },
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.controller});

  final VisitorPassesController controller;

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
              controller.error ?? 'Could not load more passes.',
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
          '${controller.passes.length} pass'
          '${controller.passes.length == 1 ? '' : 'es'} loaded',
          style: TextStyle(color: tokens.textMuted, fontSize: 12),
        ),
      ),
    );
  }
}
