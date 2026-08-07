import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/membership.dart';
import '../navigation/admin_module.dart';
import '../state/memberships_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import '../widgets/admin_dialogs.dart';
import '../widgets/admin_states.dart';
import '../widgets/court_filter_sheet.dart';
import '../widgets/glass_card.dart';
import '../widgets/membership_action_dialogs.dart';
import '../widgets/membership_detail_panel.dart';
import '../widgets/membership_form_dialog.dart';
import '../widgets/memberships_table.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/stat_card.dart';

/// Membership management: the summary cards, the list, and every write action.
class MembershipsPage extends StatefulWidget {
  const MembershipsPage({super.key});

  @override
  State<MembershipsPage> createState() => _MembershipsPageState();
}

class _MembershipsPageState extends State<MembershipsPage> {
  late final TextEditingController _search;

  /// Drives the infinite scroll on narrow layouts.
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    AdminLog.life('MembershipsPage mounted');
    _search = TextEditingController(
      text: context.read<MembershipsController>().search,
    );
    _scroll.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<MembershipsController>();
      if (controller.state.isIdle) controller.load();
      controller.loadStats();
    });
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    // Fires a screen early, so the next page is usually there by the time the
    // list reaches the bottom. The controller ignores a second call while one
    // is in flight, so a fast flick cannot request the same page twice.
    if (position.pixels >= position.maxScrollExtent - 400) {
      context.read<MembershipsController>().loadMore();
    }
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _search.dispose();
    AdminLog.life('MembershipsPage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MembershipsController>();
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
      shrinkWrap: isMobile,
      scrollController: isMobile ? _scroll : null,
      onAdd: AdminAccess.canCreate(AdminModules.memberships)
          ? () => _openForm(context, controller)
          : null,
      onAction: (action, membership) =>
          _handleAction(context, controller, action, membership),
    );

    // The desktop list pages; the phone list appends as it scrolls, so the bar
    // would be a second, contradictory control.
    final pagination = (!isMobile &&
            (controller.page.isNotEmpty || controller.page.page > 1))
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
        onAdd: AdminAccess.canCreate(AdminModules.memberships)
            ? () => _openForm(context, controller)
            : null,
        onSweep: () => _runSweep(context, controller),
      ),
      const SizedBox(height: AdminTokens.space4),
      _SummaryCards(controller: controller),
      if (controller.activeFilterCount > 0) ...[
        const SizedBox(height: AdminTokens.space3),
        _ActiveFilters(controller: controller),
      ],
      const SizedBox(height: AdminTokens.space4),
    ];

    final list = ColoredBox(
      color: tokens.canvas,
      child: isMobile
          ? RefreshIndicator(
              onRefresh: controller.refresh,
              child: SingleChildScrollView(
                controller: _scroll,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AdminTokens.space4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [...above, listCard],
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
          child: MembershipDetailPanel(
            membership: selected,
            state: controller.detailState,
            error: controller.detailError,
            history: controller.userHistory,
            activePlan: controller.userActive,
            historyState: controller.historyState,
            onClose: controller.closeMembership,
            onRetry: () => controller.openMembership(selected),
            onAction: (action, membership) =>
                _handleAction(context, controller, action, membership),
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
    MembershipsController controller,
    MembershipAction action,
    Membership membership,
  ) async {
    switch (action) {
      case MembershipAction.view:
        unawaited(controller.openMembership(membership));
        if (MediaQuery.sizeOf(context).width < AdminTokens.tabletMax) {
          await _showDetailSheet(context, controller);
        }
      case MembershipAction.edit:
        await _openForm(context, controller, membership: membership);
      case MembershipAction.renew:
        await _renew(context, controller, membership);
      case MembershipAction.cancel:
        await _cancel(context, controller, membership);
      case MembershipAction.delete:
        await _confirmDelete(context, controller, membership);
      case MembershipAction.setActive:
        await _setStatus(context, controller, membership, MembershipStatus.active);
      case MembershipAction.setInactive:
        await _setStatus(
          context,
          controller,
          membership,
          MembershipStatus.inactive,
        );
      case MembershipAction.setExpired:
        await _setStatus(
          context,
          controller,
          membership,
          MembershipStatus.expired,
        );
      case MembershipAction.markPaid:
        await _setPayment(
          context,
          controller,
          membership,
          MembershipPaymentStatus.paid,
        );
      case MembershipAction.markPending:
        await _setPayment(
          context,
          controller,
          membership,
          MembershipPaymentStatus.pending,
        );
      case MembershipAction.markFailed:
        await _setPayment(
          context,
          controller,
          membership,
          MembershipPaymentStatus.failed,
        );
      case MembershipAction.markRefunded:
        await _setPayment(
          context,
          controller,
          membership,
          MembershipPaymentStatus.refunded,
        );
    }
  }

  Future<void> _setStatus(
    BuildContext context,
    MembershipsController controller,
    Membership membership,
    MembershipStatus status,
  ) async {
    try {
      await controller.setStatus(membership.id, status);
      if (!context.mounted) return;
      AdminFeedback.success(
        context,
        '${membership.displayPlan} is now ${status.label}.',
      );
    } catch (error) {
      if (!context.mounted) return;
      AdminFeedback.error(context, _messageOf(error, 'change the status'));
    }
  }

  Future<void> _setPayment(
    BuildContext context,
    MembershipsController controller,
    Membership membership,
    MembershipPaymentStatus payment,
  ) async {
    try {
      await controller.setPaymentStatus(membership.id, payment);
      if (!context.mounted) return;
      AdminFeedback.success(context, 'Payment marked ${payment.label}.');
    } catch (error) {
      if (!context.mounted) return;
      AdminFeedback.error(
        context,
        _messageOf(error, 'change the payment status'),
      );
    }
  }

  Future<void> _cancel(
    BuildContext context,
    MembershipsController controller,
    Membership membership,
  ) async {
    final cancelled = await CancelMembershipDialog.show(
      context,
      membership: membership,
      onSubmit: (reason) => controller.cancel(membership.id, reason),
    );

    if (!cancelled || !context.mounted) return;
    AdminFeedback.success(
      context,
      '${membership.displayPlan} was cancelled.',
    );
  }

  Future<void> _renew(
    BuildContext context,
    MembershipsController controller,
    Membership membership,
  ) async {
    final renewed = await RenewMembershipDialog.show(
      context,
      membership: membership,
      onSubmit: (validityDays, totalAmount) => controller.renew(
        membership.id,
        validityDays: validityDays,
        totalAmount: totalAmount,
      ),
    );

    if (!renewed || !context.mounted) return;
    AdminFeedback.success(context, '${membership.displayPlan} was renewed.');
  }

  Future<void> _runSweep(
    BuildContext context,
    MembershipsController controller,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Mark lapsed memberships expired?',
      message:
          'This runs the maintenance job on the server. Every membership '
          'whose end date has passed is set to Expired.',
      confirmLabel: 'Run now',
      icon: Icons.cleaning_services_rounded,
    );
    if (!confirmed || !context.mounted) return;

    try {
      final changed = await controller.runExpirySweep();
      if (!context.mounted) return;
      AdminFeedback.success(
        context,
        // Never invents a count the server did not report.
        changed == null
            ? 'The expiry sweep finished.'
            : 'The expiry sweep updated $changed membership'
                  '${changed == 1 ? '' : 's'}.',
      );
    } catch (error) {
      if (!context.mounted) return;
      AdminFeedback.error(context, _messageOf(error, 'run the expiry sweep'));
    }
  }

  Future<void> _showDetailSheet(
    BuildContext context,
    MembershipsController controller,
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
        return ChangeNotifierProvider<MembershipsController>.value(
          value: controller,
          child: Consumer<MembershipsController>(
            builder: (context, live, _) {
              final membership = live.selected;
              if (membership == null) return const SizedBox.shrink();

              return SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.88,
                child: MembershipDetailPanel(
                  membership: membership,
                  state: live.detailState,
                  error: live.detailError,
                  history: live.userHistory,
                  activePlan: live.userActive,
                  historyState: live.historyState,
                  onClose: () => Navigator.of(sheetContext).pop(),
                  onRetry: () => live.openMembership(membership),
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
    ).whenComplete(controller.closeMembership);
  }

  Future<void> _openForm(
    BuildContext context,
    MembershipsController controller, {
    Membership? membership,
  }) async {
    final saved = await MembershipFormDialog.show(
      context,
      membership: membership,
      onSubmit: (draft) async {
        if (membership == null) {
          await controller.create(draft);
        } else {
          await controller.update(membership.id, draft);
        }
      },
    );

    if (!saved || !context.mounted) return;

    AdminFeedback.success(
      context,
      membership == null
          ? 'Membership created and the list has been refreshed.'
          : 'Changes to ${membership.displayPlan} were saved.',
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    MembershipsController controller,
    Membership membership,
  ) async {
    final tokens = AdminTheme.of(context);

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Are you sure?',
      message:
          'Deleting removes this membership and its history. Cancelling keeps '
          'the record and is usually what is wanted. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
      detail: SolidCard(
        padding: const EdgeInsets.all(AdminTokens.space3),
        color: tokens.surfaceAlt,
        radius: AdminTokens.radiusMd,
        child: Row(
          children: [
            MemberAvatar(membership: membership, size: 38),
            const SizedBox(width: AdminTokens.space3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    membership.displayUser,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    [
                      membership.displayPlan,
                      membership.statusLabel,
                      if (membership.endDate != null)
                        'ends ${AdminFormat.date(membership.endDate)}',
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
      await controller.delete(membership.id);
      if (!context.mounted) return;
      AdminFeedback.success(context, 'The membership was deleted.');
    } catch (error) {
      if (!context.mounted) return;
      // The controller has already put the row back.
      AdminFeedback.error(context, _messageOf(error, 'delete this membership'));
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

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.controller});

  final MembershipsController controller;

  @override
  Widget build(BuildContext context) {
    final summary = controller.summary;
    final loading = controller.isFirstLoad;

    // A counted figure is a different claim from the endpoint's own, and the
    // caption says which this is.
    final caption = loading
        ? null
        : (summary.countedLocally
              ? (controller.summaryIsPageScoped
                    ? 'Counted on this page'
                    : 'Counted from the list')
              : null);

    final cards = <Widget>[
      StatCard(
        label: 'Total memberships',
        value: loading ? null : summary.total,
        icon: Icons.card_membership_rounded,
        gradient: const [Color(0xFF1A237E), Color(0xFF3F51B5)],
        caption: caption,
      ),
      StatCard(
        label: 'Active',
        value: loading ? null : summary.active,
        icon: Icons.verified_rounded,
        gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
        caption: caption,
      ),
      StatCard(
        label: 'Expired',
        value: loading ? null : summary.expired,
        icon: Icons.event_busy_rounded,
        gradient: const [Color(0xFFF59E0B), Color(0xFFFCD34D)],
        caption: caption,
      ),
      StatCard(
        label: 'Cancelled',
        value: loading ? null : summary.cancelled,
        icon: Icons.cancel_outlined,
        gradient: const [Color(0xFFEF4444), Color(0xFFFCA5A5)],
        caption: caption,
      ),
      _RevenueCard(
        revenue: loading ? null : summary.revenue,
        // Only the stats endpoint can speak for revenue across every page.
        fromStats: controller.stats.revenue != null,
        scoped: controller.summaryIsPageScoped,
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

/// Money needs its own card: [StatCard] takes an int, and rupees are not that.
class _RevenueCard extends StatelessWidget {
  const _RevenueCard({
    required this.revenue,
    required this.fromStats,
    required this.scoped,
  });

  final num? revenue;
  final bool fromStats;
  final bool scoped;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    const gradient = [Color(0xFF16A34A), Color(0xFF86EFAC)];

    final caption = fromStats
        ? null
        : (scoped ? 'Counted on this page' : 'Counted from the list');

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
              gradient: const LinearGradient(
                colors: gradient,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              size: 18,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: AdminTokens.space4),
          Text(
            // An em dash when nothing was reported — never a zero.
            revenue == null ? AdminFormat.dash : AdminFormat.currency(revenue),
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Revenue',
            style: TextStyle(color: tokens.textMuted, fontSize: 12),
          ),
          if (caption != null) ...[
            const SizedBox(height: 2),
            Text(
              caption,
              style: TextStyle(color: tokens.textMuted, fontSize: 10.5),
            ),
          ],
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.controller,
    required this.searchController,
    required this.onAdd,
    required this.onSweep,
  });

  final MembershipsController controller;
  final TextEditingController searchController;
  final VoidCallback? onAdd;
  final VoidCallback onSweep;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < AdminTokens.tabletMax;

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Memberships',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: tokens.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          controller.state.isReady
              ? '${controller.page.total} membership'
                    '${controller.page.total == 1 ? '' : 's'}'
                    '${controller.isCatalogueMode ? ' matching' : ''}'
              : 'Plans, their members and their terms',
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
          hintText: 'Search by member, plan or code',
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

    final sweep = OutlinedButton.icon(
      onPressed: controller.state.isLoading ? null : onSweep,
      icon: const Icon(Icons.cleaning_services_rounded, size: 17),
      label: const Text('Check expired'),
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
            label: const Text('Add Membership'),
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
          Row(
            children: [
              Expanded(child: sweep),
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
            filter,
            const SizedBox(width: AdminTokens.space3),
            sweep,
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

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.controller});

  final MembershipsController controller;

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
  MembershipsController controller,
) {
  AdminLog.ui('Membership filter sheet opened');

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

      return ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AdminTokens.space5),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Filter memberships',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: controller.hasFilters
                              ? controller.clearFilters
                              : null,
                          child: const Text('Clear all'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AdminTokens.space4),
                    const CourtGroupLabel('Status'),
                    const SizedBox(height: AdminTokens.space2),
                    Wrap(
                      spacing: AdminTokens.space2,
                      runSpacing: AdminTokens.space2,
                      children: [
                        CourtFilterChip(
                          label: 'All',
                          selected: controller.statusFilter == null,
                          onTap: () => controller.setStatusFilter(null),
                        ),
                        for (final status in MembershipStatus.values)
                          CourtFilterChip(
                            label: status.label,
                            selected: controller.statusFilter == status,
                            onTap: () => controller.setStatusFilter(status),
                          ),
                      ],
                    ),
                    const SizedBox(height: AdminTokens.space5),
                    const CourtGroupLabel('Payment'),
                    const SizedBox(height: AdminTokens.space2),
                    Wrap(
                      spacing: AdminTokens.space2,
                      runSpacing: AdminTokens.space2,
                      children: [
                        CourtFilterChip(
                          label: 'All',
                          selected: controller.paymentFilter == null,
                          onTap: () => controller.setPaymentFilter(null),
                        ),
                        for (final payment in MembershipPaymentStatus.values)
                          CourtFilterChip(
                            label: payment.label,
                            selected: controller.paymentFilter == payment,
                            onTap: () => controller.setPaymentFilter(payment),
                          ),
                      ],
                    ),
                    const SizedBox(height: AdminTokens.space5),
                    const CourtGroupLabel('Term'),
                    const SizedBox(height: AdminTokens.space2),
                    Wrap(
                      spacing: AdminTokens.space2,
                      runSpacing: AdminTokens.space2,
                      children: [
                        CourtFilterChip(
                          label: 'Expiring in '
                              '${MembershipsController.expiringSoonDays} days',
                          selected: controller.expiringSoonOnly,
                          onTap: () => controller.setExpiringSoonOnly(
                            !controller.expiringSoonOnly,
                          ),
                        ),
                      ],
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
          );
        },
      );
    },
  ).whenComplete(() => AdminLog.ui('Membership filter sheet closed'));
}

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.controller});

  final MembershipsController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    final chips = <Widget>[
      if (controller.statusFilter != null)
        _Chip(
          label: controller.statusFilter!.label,
          onRemove: () => controller.setStatusFilter(null),
        ),
      if (controller.paymentFilter != null)
        _Chip(
          label: 'Payment: ${controller.paymentFilter!.label}',
          onRemove: () => controller.setPaymentFilter(null),
        ),
      if (controller.expiringSoonOnly)
        _Chip(
          label: 'Expiring in ${MembershipsController.expiringSoonDays} days',
          onRemove: () => controller.setExpiringSoonOnly(false),
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
// Body
// -----------------------------------------------------------------------------

class _Body extends StatelessWidget {
  const _Body({
    required this.controller,
    required this.isMobile,
    required this.shrinkWrap,
    required this.scrollController,
    required this.onAdd,
    required this.onAction,
  });

  final MembershipsController controller;
  final bool isMobile;
  final bool shrinkWrap;
  final ScrollController? scrollController;
  final VoidCallback? onAdd;
  final void Function(MembershipAction action, Membership membership) onAction;

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
          title: 'Could not load the memberships',
          message:
              controller.error ??
              'The server did not return the membership list. Check your '
                  'connection and try again.',
          onRetry: controller.refresh,
        ),
      );
    }

    final rows = controller.pageRows;

    if (rows.isEmpty) {
      return _sized(
        controller.hasFilters
            ? EmptyStateView(
                icon: Icons.search_off_rounded,
                title: 'No memberships found',
                message:
                    'Nothing matches these filters. Try a different search '
                    'term, or clear the filters to see every membership.',
                actionLabel: 'Clear filters',
                onAction: controller.clearFilters,
              )
            : EmptyStateView(
                icon: Icons.card_membership_outlined,
                title: 'No memberships found',
                message: 'Sell the first plan to start tracking memberships.',
                actionLabel: 'Add Membership',
                onAction: onAdd,
                secondaryLabel: 'Refresh',
                onSecondary: controller.refresh,
              ),
      );
    }

    if (isMobile) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Non-scrolling: the page itself scrolls, and its controller drives
          // the infinite append.
          ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final membership = rows[index];
              return MembershipCard(
                membership: membership,
                busy: controller.isRowBusy(membership.id),
                onAction: onAction,
              );
            },
          ),
          if (controller.isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(AdminTokens.space4),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (!controller.hasMore && rows.length > 5)
            Padding(
              padding: const EdgeInsets.all(AdminTokens.space4),
              child: Center(
                child: Text(
                  'That is every membership.',
                  style: TextStyle(
                    color: AdminTheme.of(context).textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
        ],
      );
    }

    return SingleChildScrollView(
      child: MembershipsTable(
        memberships: rows,
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
