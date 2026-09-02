import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/coupon.dart';
import '../navigation/admin_module.dart';
import '../state/coupons_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dialogs.dart';
import '../widgets/admin_states.dart';
import '../widgets/coupon_detail_panel.dart';
import '../widgets/coupon_form_dialog.dart';
import '../widgets/coupon_validate_dialog.dart';
import '../widgets/coupons_table.dart';
import '../widgets/glass_card.dart';
import '../widgets/pagination_bar.dart';

/// Coupons: the list, the CRUD, and the checkout validator.
class CouponsPage extends StatefulWidget {
  const CouponsPage({super.key});

  @override
  State<CouponsPage> createState() => _CouponsPageState();
}

class _CouponsPageState extends State<CouponsPage> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    AdminLog.life('CouponsPage mounted');
    _search = TextEditingController(
      text: context.read<CouponsController>().search,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<CouponsController>();
      if (controller.state.isIdle) controller.load();
      // Warmed here so the form opens with its dropdowns filled, and so the
      // scope can be locked for a complex admin without a flash of the wrong
      // options.
      controller.loadRole();
      controller.loadFormOptions();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    AdminLog.life('CouponsPage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<CouponsController>();
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
              onAdd: AdminAccess.canCreate(AdminModules.coupons)
                  ? () => _openForm(context, controller)
                  : null,
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
                          onAdd: AdminAccess.canCreate(AdminModules.coupons)
                              ? () => _openForm(context, controller)
                              : null,
                          onAction: (action, coupon) => _handleAction(
                            context,
                            controller,
                            action,
                            coupon,
                          ),
                        ),
                      ),
                      // The phone list scrolls infinitely, so the page controls
                      // would only get in its way there.
                      if (!isMobile &&
                          (controller.coupons.isNotEmpty ||
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
          child: CouponDetailPanel(
            coupon: selected,
            state: controller.detailState,
            onClose: controller.clearSelection,
            onAction: (action, coupon) =>
                _handleAction(context, controller, action, coupon),
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
    CouponsController controller,
    CouponAction action,
    AdminCoupon coupon,
  ) async {
    // Last line of defence for the write actions: even if some path still
    // offered one, `data.user.permissions` decides whether it runs.
    if (!(action == CouponAction.view || action == CouponAction.copyCode) &&
        !AdminAccess.can(
          AdminModules.coupons,
          action == CouponAction.delete ? 'delete' : 'edit',
        )) {
      return;
    }

    switch (action) {
      case CouponAction.view:
        controller.select(coupon);
        if (MediaQuery.sizeOf(context).width < AdminTokens.tabletMax) {
          await _showDetailSheet(context, controller);
        }
      case CouponAction.edit:
        await _openForm(context, controller, coupon: coupon);
      case CouponAction.copyCode:
        await Clipboard.setData(ClipboardData(text: coupon.displayCode));
        if (!context.mounted) return;
        AdminFeedback.success(context, '${coupon.displayCode} copied.');
      case CouponAction.validate:
        await CouponValidateDialog.show(
          context,
          coupon: coupon,
          onValidate: controller.validate,
        );
      case CouponAction.delete:
        await _confirmDelete(context, controller, coupon);
    }
  }

  Future<void> _showDetailSheet(
    BuildContext context,
    CouponsController controller,
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
        return ChangeNotifierProvider<CouponsController>.value(
          value: controller,
          child: Consumer<CouponsController>(
            builder: (context, live, _) {
              final coupon = live.selected;
              if (coupon == null) return const SizedBox.shrink();

              // top: false — the sheet is bottom-anchored, so only the
              // gesture bar / home indicator has to be kept clear of the
              // panel's action buttons.
              return SafeArea(
                top: false,
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.9,
                  child: CouponDetailPanel(
                    coupon: coupon,
                    state: live.detailState,
                    onClose: () => Navigator.of(sheetContext).pop(),
                    onAction: (action, target) async {
                      // Copying does not need the sheet out of the way.
                      if (action == CouponAction.copyCode) {
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
    CouponsController controller, {
    AdminCoupon? coupon,
  }) async {
    // The dropdowns need their options before the dialog is useful.
    if (controller.complexes.isEmpty && !controller.complexesState.isLoading) {
      await controller.loadFormOptions();
    }
    if (!context.mounted) return;

    final saved = await CouponFormDialog.show(
      context,
      coupon: coupon,
      complexes: controller.selectableComplexes,
      complexesState: controller.complexesState,
      sports: controller.sports,
      sportsState: controller.sportsState,
      events: controller.events,
      eventsState: controller.eventsState,
      onReloadOptions: () => controller.loadFormOptions(refresh: true),
      allowedScopes: controller.allowedScopes,
      lockedComplexId: controller.isComplexScoped
          ? controller.ownComplexId
          : null,
      onCheckCode: controller.findByCode,
      onSubmit: (draft) async {
        if (coupon == null) {
          await controller.create(draft);
        } else {
          await controller.update(coupon.id, draft);
        }
      },
    );

    if (!saved || !context.mounted) return;

    AdminFeedback.success(
      context,
      coupon == null
          ? 'Coupon created and the list has been refreshed.'
          : 'Changes to ${coupon.displayCode} were saved.',
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    CouponsController controller,
    AdminCoupon coupon,
  ) async {
    final tokens = AdminTheme.of(context);

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete this coupon?',
      message:
          'Customers who already have the code will no longer be able to use '
          'it. This cannot be undone.',
      confirmLabel: 'Delete coupon',
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
              coupon.displayCode,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.6,
              ),
            ),
            Text(
              [
                if (coupon.discountLabel.isNotEmpty) coupon.discountLabel,
                if (coupon.appliesToLabel.isNotEmpty) coupon.appliesToLabel,
                if ((coupon.usedCount ?? 0) > 0)
                  '${coupon.usedCount} already redeemed',
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
      await controller.delete(coupon.id);
      if (!context.mounted) return;
      AdminFeedback.success(context, '${coupon.displayCode} was deleted.');
    } catch (error) {
      if (!context.mounted) return;
      AdminFeedback.error(context, _messageOf(error));
    }
  }

  static String _messageOf(Object error) {
    // ApiException.toString() carries the user-facing message.
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.isEmpty ? 'Could not delete this coupon.' : text;
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

  final CouponsController controller;
  final TextEditingController searchController;
  final VoidCallback? onAdd;

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
          hintText: 'Search code or description',
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

    // Exact column values, so the chips send what the backend compares on.
    final statusFilter = Wrap(
      spacing: AdminTokens.space2,
      children: [
        for (final option in <String?>[
          null,
          ...CouponsController.statusOptions,
        ])
          ChoiceChip(
            label: Text(option ?? 'All'),
            labelStyle: const TextStyle(fontSize: 12.5),
            selected: controller.status == option,
            // Re-tapping the active chip clears it, so the list is never
            // stuck in a filter with no visible way out.
            onSelected: controller.state.isLoading
                ? null
                : (_) => controller.setStatus(
                    controller.status == option ? null : option,
                  ),
          ),
      ],
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

    // Hidden rather than disabled: an action the account may not perform
    // should not be advertised.
    final add = onAdd == null
        ? const SizedBox.shrink()
        : FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 19),
            label: const Text('Create coupon'),
          );

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          search,
          const SizedBox(height: AdminTokens.space3),
          Align(alignment: Alignment.centerLeft, child: statusFilter),
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            search,
            const Spacer(),
            refresh,
            const SizedBox(width: AdminTokens.space3),
            add,
          ],
        ),
        const SizedBox(height: AdminTokens.space3),
        Align(alignment: Alignment.centerLeft, child: statusFilter),
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

  final CouponsController controller;
  final bool isMobile;
  final VoidCallback? onAdd;
  final void Function(CouponAction action, AdminCoupon coupon) onAction;

  @override
  Widget build(BuildContext context) {
    if (controller.isFirstLoad) {
      return SingleChildScrollView(
        child: TableShimmer(rows: 7, dense: isMobile),
      );
    }

    if (controller.state.isFailed && controller.coupons.isEmpty) {
      return ErrorStateView(
        title: 'Could not load coupons',
        message:
            controller.error ??
            'The server did not return a list. Check your connection and '
                'try again.',
        onRetry: controller.refresh,
      );
    }

    final coupons = controller.coupons;

    if (coupons.isEmpty) {
      return controller.hasFilters
          ? EmptyStateView(
              icon: Icons.search_off_rounded,
              title: 'No coupons match this search',
              message:
                  'Try a different code or description, or clear the search '
                  'to see every coupon.',
              actionLabel: 'Clear search',
              onAction: controller.clearSearch,
            )
          : EmptyStateView(
              icon: Icons.local_offer_outlined,
              title: 'No coupons yet',
              message:
                  'Create one to offer a discount on court bookings or event '
                  'passes.',
              actionLabel: 'Create coupon',
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
            child: CouponsTable(
              coupons: coupons,
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

  final CouponsController controller;
  final void Function(CouponAction action, AdminCoupon coupon) onAction;

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
    final coupons = controller.coupons;

    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView.builder(
        controller: _scroll,
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: coupons.length + 1,
        itemBuilder: (context, index) {
          if (index == coupons.length) {
            return _ListFooter(controller: controller);
          }
          return CouponCard(
            key: ValueKey<int>(coupons[index].id),
            coupon: coupons[index],
            onAction: widget.onAction,
          );
        },
      ),
    );
  }
}

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.controller});

  final CouponsController controller;

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
              controller.error ?? 'Could not load more coupons.',
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
          '${controller.coupons.length} coupon'
          '${controller.coupons.length == 1 ? '' : 's'} loaded',
          style: TextStyle(color: tokens.textMuted, fontSize: 12),
        ),
      ),
    );
  }
}
