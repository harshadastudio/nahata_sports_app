import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/booking.dart';
import '../navigation/admin_module.dart';
import '../state/bookings_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_export.dart';
import '../utils/admin_format.dart';
import '../widgets/admin_dialogs.dart';
import '../widgets/admin_states.dart';
import '../widgets/booking_calendar.dart';
import '../widgets/booking_charts.dart';
import '../widgets/booking_detail_panel.dart';
import '../widgets/booking_filter_sheet.dart';
import '../widgets/booking_form_dialog.dart';
import '../widgets/booking_timeline.dart';
import '../widgets/bookings_table.dart';
import '../widgets/glass_card.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/stat_card.dart';

/// Booking management: the analytics cards, the list, today's board, the
/// calendar, the statistics charts, and every write action.
class BookingsPage extends StatefulWidget {
  const BookingsPage({super.key});

  @override
  State<BookingsPage> createState() => _BookingsPageState();
}

class _BookingsPageState extends State<BookingsPage> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    AdminLog.life('BookingsPage mounted');
    _search = TextEditingController(
      text: context.read<BookingsController>().search,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = context.read<BookingsController>();
      if (controller.state.isIdle) controller.load();
      // The dashboard cards prefer /bookings/stats, so it is warmed with the
      // list rather than only when the Stats view is opened.
      if (controller.statsState.isIdle) controller.loadStats();
      controller.loadSports();
      controller.loadCourts();
      controller.loadComplexes();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    AdminLog.life('BookingsPage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<BookingsController>();
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
    final isList = controller.view == BookingsView.list;

    final body = switch (controller.view) {
      BookingsView.list => _Body(
        controller: controller,
        isMobile: isMobile,
        shrinkWrap: isMobile,
        onAdd: AdminAccess.canCreate(AdminModules.bookings)
            ? () => _openForm(context, controller)
            : null,
        onAction: (action, booking) =>
            _handleAction(context, controller, action, booking),
      ),
      BookingsView.today => BookingTimelineView(
        controller: controller,
        onAction: (action, booking) =>
            _handleAction(context, controller, action, booking),
      ),
      BookingsView.calendar => BookingCalendarView(
        controller: controller,
        onAction: (action, booking) =>
            _handleAction(context, controller, action, booking),
      ),
      BookingsView.stats => _StatsView(controller: controller),
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

    final inline = isMobile && isList;

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
        onAdd: AdminAccess.canCreate(AdminModules.bookings)
            ? () => _openForm(context, controller)
            : null,
        onExport: (format, origin) =>
            _export(context, controller, format, origin),
      ),
      const SizedBox(height: AdminTokens.space4),
      _ViewSwitcher(controller: controller),
      const SizedBox(height: AdminTokens.space4),
      _SummaryCards(controller: controller),
      if (isList) ...[
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

    // Nine analytics cards plus a stacked header do not fit above a fixed
    // height on a phone, so the whole page scrolls there instead.
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
                    // The other views own a scroll of their own, so they get a
                    // bounded height rather than nesting unbounded.
                    if (inline)
                      listCard
                    else
                      SizedBox(height: 560, child: listCard),
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
          child: BookingDetailPanel(
            booking: selected,
            state: controller.detailState,
            error: controller.detailError,
            onClose: controller.closeBooking,
            onRetry: () => controller.openBooking(selected),
            onAction: (action, booking) =>
                _handleAction(context, controller, action, booking),
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
    BookingsController controller,
    BookingAction action,
    Booking booking,
  ) async {
    // Last line of defence for the write actions: even if some path still
    // offered one, `data.user.permissions` decides whether it runs.
    if (!(action == BookingAction.view) &&
        !AdminAccess.can(
          AdminModules.bookings,
          action == BookingAction.delete ? 'delete' : 'edit',
        )) {
      return;
    }

    switch (action) {
      case BookingAction.view:
        unawaited(controller.openBooking(booking));
        if (MediaQuery.sizeOf(context).width < AdminTokens.tabletMax) {
          await _showDetailSheet(context, controller);
        }
      case BookingAction.edit:
        await _openForm(context, controller, booking: booking);
      case BookingAction.delete:
        await _confirmDelete(context, controller, booking);
      case BookingAction.markConfirmed:
        await _setStatus(context, controller, booking, BookingStatus.confirmed);
      case BookingAction.markCompleted:
        await _setStatus(context, controller, booking, BookingStatus.completed);
      case BookingAction.markCancelled:
        await _confirmCancel(context, controller, booking);
      case BookingAction.markPaid:
        await _setPayment(context, controller, booking, PaymentStatus.paid);
    }
  }

  Future<void> _setStatus(
    BuildContext context,
    BookingsController controller,
    Booking booking,
    BookingStatus status,
  ) async {
    try {
      await controller.setStatus(booking.id, status);
      if (!context.mounted) return;
      AdminFeedback.success(
        context,
        '${booking.displayReference} is now ${status.label}.',
      );
    } catch (error) {
      if (!context.mounted) return;
      AdminFeedback.error(context, _messageOf(error, 'change the status'));
    }
  }

  Future<void> _setPayment(
    BuildContext context,
    BookingsController controller,
    Booking booking,
    PaymentStatus payment,
  ) async {
    try {
      await controller.setPaymentStatus(booking.id, payment);
      if (!context.mounted) return;
      AdminFeedback.success(
        context,
        '${booking.displayReference} is marked ${payment.label}.',
      );
    } catch (error) {
      if (!context.mounted) return;
      AdminFeedback.error(context, _messageOf(error, 'update the payment'));
    }
  }

  /// Cancelling frees the court and may trigger a refund, so it asks first —
  /// unlike the other status changes, which are reversible in one tap.
  Future<void> _confirmCancel(
    BuildContext context,
    BookingsController controller,
    Booking booking,
  ) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Cancel this booking?',
      message:
          '${booking.displayReference} for ${booking.displayCustomer} will be '
          'marked Cancelled and the slot released. Any refund is handled '
          'separately.',
      confirmLabel: 'Cancel booking',
      cancelLabel: 'Keep it',
      destructive: true,
      icon: Icons.event_busy_rounded,
    );

    if (!confirmed || !context.mounted) return;
    await _setStatus(context, controller, booking, BookingStatus.cancelled);
  }

  Future<void> _showDetailSheet(
    BuildContext context,
    BookingsController controller,
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
        return ChangeNotifierProvider<BookingsController>.value(
          value: controller,
          child: Consumer<BookingsController>(
            builder: (context, live, _) {
              final booking = live.selected;
              if (booking == null) return const SizedBox.shrink();

              return SizedBox(
                height: MediaQuery.sizeOf(context).height * 0.88,
                child: BookingDetailPanel(
                  booking: booking,
                  state: live.detailState,
                  error: live.detailError,
                  onClose: () => Navigator.of(sheetContext).pop(),
                  onRetry: () => live.openBooking(booking),
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
    ).whenComplete(controller.closeBooking);
  }

  Future<void> _openForm(
    BuildContext context,
    BookingsController controller, {
    Booking? booking,
  }) async {
    final warmups = <Future<void>>[
      if (controller.sports.isEmpty && !controller.sportsState.isLoading)
        controller.loadSports(),
      if (controller.courts.isEmpty && !controller.courtsState.isLoading)
        controller.loadCourts(),
    ];
    if (warmups.isNotEmpty) await Future.wait(warmups);
    if (!context.mounted) return;

    final saved = await BookingFormDialog.show(
      context,
      booking: booking,
      courts: controller.courts,
      courtsState: controller.courtsState,
      onReloadCourts: () => controller.loadCourts(refresh: true),
      sports: controller.sports,
      sportsState: controller.sportsState,
      onReloadSports: () => controller.loadSports(refresh: true),
      // There is no customer catalogue in this console — the Users module is
      // its own screen — so a create takes the numeric id, and says so.
      customerHint:
          'This console has no customer picker yet: enter the user ID from the '
          'Users module.',
      clashScopeNote: controller.isCatalogueMode
          ? 'Checked against every loaded booking. The server remains the '
                'authority.'
          : 'Checked against the bookings on this page and today\'s board '
                'only. The server remains the authority.',
      findClashes: (draft) =>
          controller.clashesWith(draft, ignoreId: booking?.id),
      onSubmit: (draft) async {
        if (booking == null) {
          await controller.create(draft);
        } else {
          await controller.update(booking.id, draft);
        }
      },
    );

    if (!saved || !context.mounted) return;

    AdminFeedback.success(
      context,
      booking == null
          ? 'Booking created and the list has been refreshed.'
          : 'Changes to ${booking.displayReference} were saved.',
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    BookingsController controller,
    Booking booking,
  ) async {
    final tokens = AdminTheme.of(context);

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete this booking?',
      message:
          'Deleting removes the record entirely, including its payment and '
          'attendance history. Cancelling instead keeps the record. This '
          'cannot be undone.',
      confirmLabel: 'Delete booking',
      destructive: true,
      detail: SolidCard(
        padding: const EdgeInsets.all(AdminTokens.space3),
        color: tokens.surfaceAlt,
        radius: AdminTokens.radiusMd,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${booking.displayReference} · '
                    '${booking.displayCustomer}',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    [
                      AdminFormat.date(booking.date),
                      booking.windowLabel,
                      AdminFormat.currency(booking.amount),
                    ].where((part) => part != AdminFormat.dash).join(' · '),
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
      await controller.delete(booking.id);
      if (!context.mounted) return;
      AdminFeedback.success(
        context,
        '${booking.displayReference} was deleted.',
      );
    } catch (error) {
      if (!context.mounted) return;
      // The controller has already put the row back.
      AdminFeedback.error(context, _messageOf(error, 'delete this booking'));
    }
  }

  Future<void> _export(
    BuildContext context,
    BookingsController controller,
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
        ? '${rows.length} bookings matching the current filters'
        : '${rows.length} bookings on this page';

    try {
      await AdminExport.run<Booking>(
        format: format,
        fileName: AdminExport.buildFileName('bookings', DateTime.now()),
        title: 'Bookings',
        subtitle: 'Nahata Sports · $scope',
        sharePositionOrigin: origin,
        columns: _exportColumns,
        rows: rows,
      );

      if (!context.mounted) return;
      AdminFeedback.success(context, 'Exported $scope as ${format.label}.');
    } catch (error) {
      if (!context.mounted) return;
      AdminFeedback.error(context, _messageOf(error, 'export the bookings'));
    }
  }

  /// The export layout, mirroring the table so the two stay in step. Every cell
  /// goes through the same formatters the screen uses, so an exported "—" means
  /// exactly what it means on screen.
  static final List<ExportColumn<Booking>> _exportColumns = [
    ExportColumn('Booking ID', (booking) => booking.displayReference),
    ExportColumn('Customer', (booking) => booking.displayCustomer),
    ExportColumn('Phone', (booking) => AdminFormat.text(booking.customerPhone)),
    ExportColumn('Email', (booking) => AdminFormat.text(booking.customerEmail)),
    ExportColumn('Sport', (booking) => AdminFormat.text(booking.sportName)),
    ExportColumn('Court', (booking) => AdminFormat.text(booking.courtName)),
    ExportColumn(
      'Sports complex',
      (booking) => AdminFormat.text(booking.sportComplexName),
    ),
    ExportColumn('Date', (booking) => AdminFormat.date(booking.date)),
    ExportColumn(
      'Start',
      (booking) => booking.startTime?.label ?? AdminFormat.dash,
    ),
    ExportColumn(
      'End',
      (booking) => booking.endTime?.label ?? AdminFormat.dash,
    ),
    ExportColumn('Duration', (booking) => booking.durationLabel),
    ExportColumn('Source', (booking) => booking.sourceLabel),
    ExportColumn(
      'Amount',
      (booking) => AdminFormat.currency(booking.amount),
      numeric: true,
    ),
    ExportColumn('Payment', (booking) => booking.paymentLabel),
    ExportColumn('Status', (booking) => booking.statusLabel),
    ExportColumn(
      'Transaction ID',
      (booking) => AdminFormat.text(booking.transactionId),
    ),
    ExportColumn('Created', (booking) => AdminFormat.date(booking.createdAt)),
  ];

  static String _messageOf(Object error, String action) {
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.isEmpty ? 'Could not $action.' : text;
  }
}

// -----------------------------------------------------------------------------
// Statistics
// -----------------------------------------------------------------------------

class _StatsView extends StatelessWidget {
  const _StatsView({required this.controller});

  final BookingsController controller;

  @override
  Widget build(BuildContext context) {
    if (controller.statsState.isLoading) {
      return const SingleChildScrollView(child: TableShimmer(rows: 6));
    }

    if (controller.statsState.isFailed) {
      return ErrorStateView(
        title: 'Could not load the statistics',
        message:
            controller.statsError ??
            'The server did not return the booking statistics.',
        onRetry: controller.loadStats,
      );
    }

    final stats = controller.stats;
    if (stats == null || stats.isEmpty) {
      return EmptyStateView(
        icon: Icons.insights_outlined,
        title: 'No statistics yet',
        message: 'The statistics endpoint returned nothing to show.',
        actionLabel: 'Refresh',
        onAction: controller.loadStats,
      );
    }

    return ListView(
      padding: const EdgeInsets.all(AdminTokens.space4),
      children: [BookingChartsSection(stats: stats)],
    );
  }
}

// -----------------------------------------------------------------------------
// Chrome
// -----------------------------------------------------------------------------

class _ViewSwitcher extends StatelessWidget {
  const _ViewSwitcher({required this.controller});

  final BookingsController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < AdminTokens.mobileMax;

    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: BookingsView.values.map((view) {
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
                    borderRadius: BorderRadius.circular(
                      AdminTokens.radiusPill,
                    ),
                    boxShadow: selected ? tokens.softShadow : null,
                  ),
                  child: Text(
                    narrow ? view.shortLabel : view.label,
                    style: TextStyle(
                      color: selected ? tokens.accent : tokens.textSecondary,
                      fontSize: 12.5,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _CapNotice extends StatelessWidget {
  const _CapNotice({required this.controller});

  final BookingsController controller;

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
              'Filtering across the first $loaded of $total bookings. Narrow '
              'the date filter to search the rest.',
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

/// The nine analytics cards.
///
/// `/bookings/stats` is the authority; each card falls back to a figure counted
/// from the rows in hand, and captions itself when it does so — a number
/// derived from one page is not the same claim as the endpoint's own total.
class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.controller});

  final BookingsController controller;

  @override
  Widget build(BuildContext context) {
    final stats = controller.stats;
    final summary = controller.summary;
    final loading = controller.isFirstLoad && controller.statsState.isLoading;
    final scoped = controller.summaryIsPageScoped;

    /// The endpoint's figure when it sent one, otherwise the counted fallback.
    ({int? value, String? caption}) figure(int? fromStats, int fallback) {
      if (fromStats != null) return (value: fromStats, caption: null);
      return (
        value: fallback,
        caption: scoped ? 'Counted on this page' : 'Counted from the list',
      );
    }

    final total = figure(stats?.total, summary.total);
    final confirmed = figure(stats?.confirmed, summary.confirmed);
    final pending = figure(stats?.pending, summary.pending);
    final cancelled = figure(stats?.cancelled, summary.cancelled);
    final completed = figure(stats?.completed, summary.completed);
    final paid = figure(stats?.paid, summary.paid);
    final unpaid = figure(stats?.unpaid, summary.unpaid);

    final revenue = stats?.revenue ?? summary.revenue;

    final cards = <Widget>[
      StatCard(
        label: 'Total bookings',
        value: loading ? null : total.value,
        icon: Icons.event_available_rounded,
        gradient: const [Color(0xFF1A237E), Color(0xFF3F51B5)],
        caption: loading ? null : total.caption,
      ),
      StatCard(
        label: "Today's bookings",
        value: loading ? null : stats?.today,
        icon: Icons.today_rounded,
        gradient: const [Color(0xFF0EA5E9), Color(0xFF67E8F9)],
        // No honest fallback: the list is not scoped to today.
        caption: loading
            ? null
            : (stats?.today == null ? 'Not reported' : null),
      ),
      StatCard(
        label: 'Confirmed',
        value: loading ? null : confirmed.value,
        icon: Icons.check_circle_outline_rounded,
        gradient: const [Color(0xFF10B981), Color(0xFF34D399)],
        caption: loading ? null : confirmed.caption,
      ),
      StatCard(
        label: 'Pending',
        value: loading ? null : pending.value,
        icon: Icons.schedule_rounded,
        gradient: const [Color(0xFFF59E0B), Color(0xFFFBBF24)],
        caption: loading ? null : pending.caption,
      ),
      StatCard(
        label: 'Cancelled',
        value: loading ? null : cancelled.value,
        icon: Icons.cancel_outlined,
        gradient: const [Color(0xFFEF4444), Color(0xFFFCA5A5)],
        caption: loading ? null : cancelled.caption,
      ),
      StatCard(
        label: 'Completed',
        value: loading ? null : completed.value,
        icon: Icons.task_alt_rounded,
        gradient: const [Color(0xFF3949AB), Color(0xFF7986CB)],
        caption: loading ? null : completed.caption,
      ),
      _RevenueCard(
        revenue: loading ? null : revenue,
        fromStats: stats?.revenue != null,
        growth: stats?.growthPercent,
        scoped: scoped,
      ),
      StatCard(
        label: 'Paid bookings',
        value: loading ? null : paid.value,
        icon: Icons.payments_rounded,
        gradient: const [Color(0xFF059669), Color(0xFF6EE7B7)],
        caption: loading ? null : paid.caption,
      ),
      StatCard(
        label: 'Unpaid bookings',
        value: loading ? null : unpaid.value,
        icon: Icons.hourglass_empty_rounded,
        gradient: const [Color(0xFFEC4899), Color(0xFFF9A8D4)],
        caption: loading ? null : unpaid.caption,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 1200
            ? 3
            : (constraints.maxWidth >= 700 ? 3 : 2);
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

/// Revenue is money, not a count, so it does not go through [StatCard].
class _RevenueCard extends StatelessWidget {
  const _RevenueCard({
    required this.revenue,
    required this.fromStats,
    required this.growth,
    required this.scoped,
  });

  final num? revenue;
  final bool fromStats;
  final double? growth;
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
          Row(
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
              const Spacer(),
              if (growth != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      growth! >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 15,
                      color: growth! >= 0 ? tokens.success : tokens.danger,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      AdminFormat.growth(growth),
                      style: TextStyle(
                        color: growth! >= 0 ? tokens.success : tokens.danger,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: AdminTokens.space4),
          Text(
            // An em dash when nothing was reported — never a zero.
            revenue == null ? '—' : AdminFormat.currency(revenue),
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            'Total revenue',
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
    required this.onExport,
  });

  final BookingsController controller;
  final TextEditingController searchController;
  final VoidCallback? onAdd;
  final void Function(ExportFormat format, Rect? origin) onExport;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final narrow = width < AdminTokens.tabletMax;
    final isList = controller.view == BookingsView.list;

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Bookings',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(color: tokens.textPrimary),
        ),
        const SizedBox(height: 2),
        Text(
          controller.state.isReady && isList
              ? '${controller.page.total} booking'
                    '${controller.page.total == 1 ? '' : 's'}'
                    '${controller.isCatalogueMode ? ' matching' : ''}'
              : 'Court and event reservations',
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
          hintText: 'Search by booking ID, name or phone',
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

    // Hidden rather than disabled: an action the account may not perform
    // should not be advertised.
    final add = onAdd == null
        ? const SizedBox.shrink()
        : FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add_rounded, size: 19),
            label: const Text('Add Booking'),
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

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.controller});

  final BookingsController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final count = controller.activeFilterCount;
    final active = count > 0;

    return OutlinedButton.icon(
      onPressed: () => BookingFilterSheet.show(context, controller),
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

class _ActiveFilters extends StatelessWidget {
  const _ActiveFilters({required this.controller});

  final BookingsController controller;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      if (controller.dateFilter != null)
        _RemovableChip(
          label: AdminFormat.date(controller.dateFilter),
          onRemove: () => controller.setDateFilter(null),
        ),
      if (controller.statusFilter != null)
        _RemovableChip(
          label: controller.statusFilter!.label,
          onRemove: () => controller.setStatusFilter(null),
        ),
      if (controller.paymentFilter != null)
        _RemovableChip(
          label: controller.paymentFilter!.label,
          onRemove: () => controller.setPaymentFilter(null),
        ),
      if (controller.sourceFilter != null)
        _RemovableChip(
          label: controller.sourceFilter!.label,
          onRemove: () => controller.setSourceFilter(null),
        ),
      if (controller.sportFilter != null)
        _RemovableChip(
          // Falls back to the id if the catalogue has not landed yet.
          label:
              controller.filteredSport?.displayName ??
              'Sport #${controller.sportFilter}',
          onRemove: () => controller.setSportFilter(null),
        ),
      if (controller.courtFilter != null)
        _RemovableChip(
          label:
              controller.filteredCourt?.displayName ??
              'Court #${controller.courtFilter}',
          onRemove: () => controller.setCourtFilter(null),
        ),
      if (controller.complexFilter != null)
        _RemovableChip(
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

  final BookingsController controller;
  final bool isMobile;
  final bool shrinkWrap;
  final VoidCallback? onAdd;
  final void Function(BookingAction action, Booking booking) onAction;

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
          title: 'Could not load bookings',
          message:
              controller.error ??
              'The server did not return the bookings list. Check your '
                  'connection and try again.',
          onRetry: controller.refresh,
        ),
      );
    }

    final bookings = controller.pageRows;

    if (bookings.isEmpty) {
      return _sized(
        controller.hasFilters
            ? EmptyStateView(
                icon: Icons.search_off_rounded,
                title: 'No bookings found',
                message:
                    'Nothing matches these filters. Try a different search '
                    'term, or clear the filters to see every booking.',
                actionLabel: 'Clear filters',
                onAction: controller.clearFilters,
              )
            : EmptyStateView(
                icon: Icons.event_busy_outlined,
                title: 'No bookings found',
                message:
                    'Add the first booking to start filling the courts.',
                actionLabel: 'Add Booking',
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
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          final booking = bookings[index];
          return BookingCard(
            booking: booking,
            busy: controller.isRowBusy(booking.id),
            onAction: onAction,
          );
        },
      );
    }

    return SingleChildScrollView(
      child: BookingsTable(
        bookings: bookings,
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
