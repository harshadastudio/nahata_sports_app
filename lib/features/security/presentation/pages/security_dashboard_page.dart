import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../admin/core/admin_log.dart';
import '../../../admin/domain/entities/visitor_pass.dart';
import '../../../admin/presentation/navigation/admin_destination.dart';
import '../../../admin/presentation/navigation/admin_module.dart';
import '../../../admin/presentation/state/admin_shell_controller.dart';
import '../../../admin/presentation/state/view_state.dart';
import '../../../admin/presentation/state/visitor_passes_controller.dart';
import '../../../admin/presentation/theme/admin_theme.dart';
import '../../../admin/presentation/utils/visitor_pass_actions.dart';
import '../../../admin/presentation/widgets/admin_states.dart';
import '../../../admin/presentation/widgets/glass_card.dart';
import '../../../admin/presentation/widgets/visitor_pass_detail_panel.dart';
// VisitorPassAction — the detail panel's action set — is declared beside the
// table that first used it.
import '../../../admin/presentation/widgets/visitor_passes_table.dart';
import '../../domain/entities/security_dashboard_data.dart';
import '../state/security_dashboard_controller.dart';
import '../widgets/live_gate_status.dart';
import '../widgets/recent_passes_strip.dart';
import '../widgets/security_activity_table.dart';
import '../widgets/security_charts.dart';
import '../widgets/security_filter_bar.dart';
import '../widgets/security_quick_actions.dart';
import '../widgets/security_stat_cards.dart';
import '../widgets/security_timeline.dart';

/// The Security Dashboard.
///
/// Reads from two controllers on purpose: [SecurityDashboardController] owns
/// the figures (a bounded sweep of `/visitor-passes` aggregated in memory,
/// because the module has no statistics endpoint), while
/// [VisitorPassesController] owns the write operations the quick actions and
/// the row buttons perform. Sharing the second one with the Visitor Passes
/// module means a pass checked in here is checked in there, with no second
/// implementation of the lifecycle rules.
class SecurityDashboardPage extends StatefulWidget {
  const SecurityDashboardPage({
    super.key,
    this.onOpenReports,
    this.enforceModulePermissions = true,
  });

  /// Where the Reports quick action goes. Null hides it — the standalone
  /// SECURITY screen has no console to navigate inside.
  final VoidCallback? onOpenReports;

  /// Whether the quick actions are gated on the admin permission modules.
  ///
  /// True inside the console, where an ADMIN or COMPLEX_ADMIN's
  /// `permissions.bookings.*` decides what they may do. False on the standalone
  /// SECURITY screen: issuing and scanning passes *is* that role, and gating it
  /// on an admin-shaped module the payload may not even carry would leave a
  /// guard staring at a dashboard they cannot use.
  final bool enforceModulePermissions;

  @override
  State<SecurityDashboardPage> createState() => _SecurityDashboardPageState();
}

class _SecurityDashboardPageState extends State<SecurityDashboardPage> {
  late final TextEditingController _search;

  /// Held so [dispose] can stop the poll. The controller outlives this page —
  /// the console owns it — so a timer left running would keep sweeping
  /// `/visitor-passes` long after the desk moved to another module.
  SecurityDashboardController? _dashboard;

  @override
  void initState() {
    super.initState();
    AdminLog.life('SecurityDashboardPage mounted');
    _search = TextEditingController(
      text: context.read<SecurityDashboardController>().search,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final dashboard = context.read<SecurityDashboardController>();
      _dashboard = dashboard;
      dashboard.load();
      // "Currently inside" has to keep up with the gate without the desk
      // touching anything.
      dashboard.startLiveUpdates();

      // The write controller: venues for the Generate dialog, and the role,
      // which decides whether Delete is offered at all.
      final passes = context.read<VisitorPassesController>();
      passes.loadComplexes();
      passes.loadRole();
    });
  }

  @override
  void dispose() {
    _dashboard?.stopLiveUpdates();
    _search.dispose();
    AdminLog.life('SecurityDashboardPage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SecurityDashboardController>();
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

    final loading = controller.isFirstLoad;
    final data = controller.data;

    // A first load that failed outright has nothing to show around the error.
    if (controller.state.isFailed && !controller.hasData) {
      return ColoredBox(
        color: tokens.canvas,
        child: Center(
          child: ErrorStateView(
            title: 'Security dashboard unavailable',
            message: controller.error ??
                'The visitor passes could not be loaded. Please try again.',
            onRetry: controller.refresh,
          ),
        ),
      );
    }

    return ColoredBox(
      color: tokens.canvas,
      child: RefreshIndicator(
        onRefresh: controller.refresh,
        child: ListView(
          padding: EdgeInsets.all(
            isMobile ? AdminTokens.space4 : AdminTokens.space6,
          ),
          children: [
            _Header(controller: controller),
            const SizedBox(height: AdminTokens.space4),

            SecurityFilterBar(
              controller: controller,
              searchController: _search,
              data: data,
            ),
            const SizedBox(height: AdminTokens.space5),

            if (controller.truncated && !loading) ...[
              SecurityTruncationNotice(
                maxPasses: SecurityDashboardController.maxPages * 100,
              ),
              const SizedBox(height: AdminTokens.space4),
            ],

            // 1 — Statistics cards
            SecurityStatCards(
              data: data,
              loading: loading,
              onFilter: controller.setStatusFilter,
            ),
            const SizedBox(height: AdminTokens.space5),

            // 2 — Recent Visitor Activity
            _Panel(
              title: 'Recent Visitor Activity',
              subtitle: controller.hasFilters
                  ? '${controller.filteredPasses.length} of '
                      '${data.passes.length} passes match your filters'
                  : 'Passes issued ${data.window?.label.toLowerCase() ?? ''}',
              icon: Icons.fact_check_outlined,
              padding: EdgeInsets.zero,
              child: _Activity(controller: controller, isMobile: isMobile),
            ),
            const SizedBox(height: AdminTokens.space5),

            // 3 — Quick Actions
            _Panel(
              title: 'Quick Actions',
              subtitle: 'The gate desk’s six most common jobs',
              icon: Icons.bolt_rounded,
              child: SecurityQuickActions(
                canGenerate: _canGenerate,
                canOpenReports: widget.onOpenReports != null &&
                    (!widget.enforceModulePermissions ||
                        AdminAccess.canView(AdminModules.reports)),
                onGenerate: () => _generate(controller),
                onScan: () => _scanQr(controller),
                onManualVerify: () => _manualVerify(controller),
                onLookup: () => _lookup(controller),
                onTodaysVisitors: () => _showToday(controller),
                onReports: widget.onOpenReports ?? () {},
              ),
            ),
            const SizedBox(height: AdminTokens.space5),

            // 4 — Recent Generated Passes
            _Panel(
              title: 'Recent Generated Passes',
              subtitle: 'Codes ready to hand over',
              icon: Icons.badge_outlined,
              child: RecentPassesStrip(
                passes: controller.recentPasses(),
                loading: loading,
                onSelect: (pass) => _openPass(pass),
                onGenerate: _canGenerate ? () => _generate(controller) : null,
              ),
            ),
            const SizedBox(height: AdminTokens.space5),

            // 5 / 8 — Timeline beside the live gate, side by side where there
            // is room: they answer the same question at two time scales.
            if (isDesktop)
              // Each panel keeps its natural height: the timeline and the gate
              // list are rarely the same length, and forcing them to match
              // clips whichever is taller.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _TimelinePanel(data: data, busy: loading)),
                  const SizedBox(width: AdminTokens.space4),
                  Expanded(
                    child: _GatePanel(
                      data: data,
                      busy: loading,
                      updatedAt: controller.loadedAt,
                      onSelect: _openPass,
                      onCheckOut: (pass) => _scanRow(
                        controller,
                        pass,
                        VisitorScanType.checkOut,
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              _TimelinePanel(data: data, busy: loading),
              const SizedBox(height: AdminTokens.space5),
              _GatePanel(
                data: data,
                busy: loading,
                updatedAt: controller.loadedAt,
                onSelect: _openPass,
                onCheckOut: (pass) =>
                    _scanRow(controller, pass, VisitorScanType.checkOut),
              ),
            ],
            const SizedBox(height: AdminTokens.space5),

            // 6 / 7 — Charts
            if (isDesktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: SolidCard(
                      child: VisitorStatusPie(
                        series: data.statusBreakdown,
                        loading: loading,
                      ),
                    ),
                  ),
                  const SizedBox(width: AdminTokens.space4),
                  Expanded(
                    flex: 2,
                    child: SolidCard(
                      child: HourlyVisitorTrend(
                        series: data.hourlyTrend,
                        loading: loading,
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              SolidCard(
                child: VisitorStatusPie(
                  series: data.statusBreakdown,
                  loading: loading,
                ),
              ),
              const SizedBox(height: AdminTokens.space5),
              SolidCard(
                child: HourlyVisitorTrend(
                  series: data.hourlyTrend,
                  loading: loading,
                ),
              ),
            ],
            const SizedBox(height: AdminTokens.space5),

            SolidCard(
              child: DailyVisitorBars(
                series: data.dailyTrend,
                loading: loading,
              ),
            ),
            const SizedBox(height: AdminTokens.space6),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Actions
  //
  // Every one of them runs the shared [VisitorPassActions] flow, then refreshes
  // the figures — a check-in that did not move "Currently Inside" would be a
  // dashboard nobody trusts.
  // ---------------------------------------------------------------------------

  VisitorPassesController get _passes =>
      context.read<VisitorPassesController>();

  /// Issuing a pass is gated only inside the console — see
  /// [SecurityDashboardPage.enforceModulePermissions].
  bool get _canGenerate =>
      !widget.enforceModulePermissions ||
      AdminAccess.canCreate(AdminModules.bookings);

  Future<void> _generate(SecurityDashboardController controller) async {
    final created = await VisitorPassActions.generate(context, _passes);
    if (created == null || !mounted) return;
    await controller.refresh();
  }

  Future<void> _scanQr(SecurityDashboardController controller) async {
    if (!await VisitorPassActions.openScanner(context, _passes)) return;
    if (!mounted) return;
    await controller.refresh();
  }

  Future<void> _manualVerify(SecurityDashboardController controller) async {
    final scanned = await VisitorPassActions.manualVerify(context, _passes);
    if (!scanned || !mounted) return;
    await controller.refresh();
  }

  Future<void> _lookup(SecurityDashboardController controller) async {
    // A lookup never changes a pass, so there is nothing to refresh unless the
    // desk used the IN / OUT buttons on the result sheet.
    final scanned = await VisitorPassActions.lookup(context, _passes);
    if (!scanned || !mounted) return;
    await controller.refresh();
  }

  /// Today's Visitors: the activity table already holds them, so this resets
  /// the window and clears any filter narrowing it.
  Future<void> _showToday(SecurityDashboardController controller) async {
    controller.clearFilters();
    await controller.setRange(SecurityRange.today);
  }

  Future<void> _scanRow(
    SecurityDashboardController controller,
    VisitorPass pass,
    VisitorScanType type,
  ) async {
    await VisitorPassActions.scan(context, _passes, pass, type);
    if (!mounted) return;
    await controller.refresh();
  }

  /// The details drawer, on a pass from any panel.
  Future<void> _openPass(VisitorPass pass) async {
    final passes = _passes;
    passes.select(pass);

    await showModalBottomSheet<void>(
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
          value: passes,
          child: Consumer<VisitorPassesController>(
            builder: (context, live, _) {
              final selected = live.selected;
              if (selected == null) return const SizedBox.shrink();

              return SafeArea(
                top: false,
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.9,
                  child: VisitorPassDetailPanel(
                    pass: selected,
                    state: live.detailState,
                    canDelete: live.canDelete,
                    onClose: () => Navigator.of(sheetContext).pop(),
                    onShareOutcome: (outcome) =>
                        VisitorPassActions.reportOutcome(sheetContext, outcome),
                    onAction: (action, target) =>
                        _handleDetailAction(sheetContext, live, action, target),
                  ),
                ),
              );
            },
          ),
        );
      },
    );

    passes.clearSelection();
    if (!mounted) return;
    await context.read<SecurityDashboardController>().refresh();
  }

  Future<void> _handleDetailAction(
    BuildContext sheetContext,
    VisitorPassesController live,
    VisitorPassAction action,
    VisitorPass pass,
  ) async {
    switch (action) {
      case VisitorPassAction.view:
        live.select(pass);
      case VisitorPassAction.checkIn:
        await VisitorPassActions.scan(
          sheetContext,
          live,
          pass,
          VisitorScanType.checkIn,
        );
      case VisitorPassAction.checkOut:
        await VisitorPassActions.scan(
          sheetContext,
          live,
          pass,
          VisitorScanType.checkOut,
        );
      case VisitorPassAction.share:
      case VisitorPassAction.whatsapp:
        // The panel's own share bar reports its outcome; nothing to do here.
        break;
      case VisitorPassAction.email:
        await VisitorPassActions.sendEmail(sheetContext, live, pass);
      case VisitorPassAction.delete:
        // Closing first: the record the sheet is showing is about to go.
        Navigator.of(sheetContext).pop();
        if (!mounted) return;
        await VisitorPassActions.confirmDelete(context, live, pass);
    }
  }
}

// -----------------------------------------------------------------------------
// Chrome
// -----------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final SecurityDashboardController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < AdminTokens.tabletMax;

    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Security Dashboard',
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: narrow ? 19 : 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
            height: 1.2,
          ),
        ),
        Text(
          'Visitor passes, gate movements and who is on site',
          style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
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

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          const SizedBox(height: AdminTokens.space3),
          Align(alignment: Alignment.centerLeft, child: refresh),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: title),
        refresh,
      ],
    );
  }
}

/// A titled card. The dashboard is a stack of these.
class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.padding,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(AdminTokens.space5),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
                    color: tokens.accentSoft,
                  ),
                  child: Icon(icon, size: 18, color: tokens.accent),
                ),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      Text(
                        subtitle,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: padding ??
                const EdgeInsets.fromLTRB(
                  AdminTokens.space5,
                  0,
                  AdminTokens.space5,
                  AdminTokens.space5,
                ),
            child: child,
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Sections
// -----------------------------------------------------------------------------

class _Activity extends StatelessWidget {
  const _Activity({required this.controller, required this.isMobile});

  final SecurityDashboardController controller;
  final bool isMobile;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    if (controller.isFirstLoad) {
      return const Padding(
        padding: EdgeInsets.all(AdminTokens.space4),
        child: TableShimmer(rows: 6),
      );
    }

    final rows = controller.activityRows;

    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AdminTokens.space8),
        child: controller.hasFilters
            ? EmptyStateView(
                icon: Icons.search_off_rounded,
                title: 'No matching visitors',
                message:
                    'No visitor in this period matches the filters you have '
                    'set. Try clearing them.',
                actionLabel: 'Clear filters',
                onAction: controller.clearFilters,
              )
            : const EmptyStateView(
                icon: Icons.people_outline_rounded,
                title: 'No visitors in this period',
                message:
                    'Visitor passes issued in the selected period appear here, '
                    'with their entry and exit times.',
              ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        RefreshLine(visible: controller.isRefreshing),
        SecurityActivityTable(
          rows: rows,
          compact: isMobile,
          onAction: (action, pass) => _onRowAction(context, action, pass),
        ),
        if (controller.activityPageCount > 1)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AdminTokens.space4,
              vertical: AdminTokens.space3,
            ),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: tokens.border)),
            ),
            child: Row(
              children: [
                Text(
                  'Page ${controller.activityPage} of '
                  '${controller.activityPageCount} · '
                  '${controller.filteredPasses.length} visitors',
                  style: TextStyle(color: tokens.textMuted, fontSize: 12),
                ),
                const Spacer(),
                OutlinedButton(
                  onPressed: controller.canPagePrevious
                      ? controller.previousActivityPage
                      : null,
                  child: const Text('Previous'),
                ),
                const SizedBox(width: AdminTokens.space2),
                OutlinedButton(
                  onPressed:
                      controller.canPageNext ? controller.nextActivityPage : null,
                  child: const Text('Next'),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// Row buttons are handled by the page's state, which owns the write
  /// controller and the refresh that follows a scan.
  void _onRowAction(
    BuildContext context,
    SecurityRowAction action,
    VisitorPass pass,
  ) {
    final page = context.findAncestorStateOfType<_SecurityDashboardPageState>();
    if (page == null) return;

    switch (action) {
      case SecurityRowAction.view:
        page._openPass(pass);
      case SecurityRowAction.checkIn:
        page._scanRow(controller, pass, VisitorScanType.checkIn);
      case SecurityRowAction.checkOut:
        page._scanRow(controller, pass, VisitorScanType.checkOut);
    }
  }
}

class _TimelinePanel extends StatelessWidget {
  const _TimelinePanel({required this.data, required this.busy});

  final SecurityDashboardData data;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Today’s Timeline',
      subtitle: 'Entries and exits, newest first',
      icon: Icons.schedule_rounded,
      child: busy
          ? const Column(
              children: [
                ShimmerBox(height: 44),
                SizedBox(height: AdminTokens.space3),
                ShimmerBox(height: 44),
                SizedBox(height: AdminTokens.space3),
                ShimmerBox(height: 44),
              ],
            )
          : data.timeline.isEmpty
              ? const EmptyStateView(
                  icon: Icons.timelapse_rounded,
                  title: 'No movements yet',
                  message:
                      'Entries and exits appear here the moment a pass is '
                      'scanned at the gate.',
                )
              : SecurityTimeline(events: data.timeline),
    );
  }
}

class _GatePanel extends StatelessWidget {
  const _GatePanel({
    required this.data,
    required this.busy,
    required this.updatedAt,
    required this.onSelect,
    required this.onCheckOut,
  });

  final SecurityDashboardData data;
  final bool busy;
  final DateTime? updatedAt;
  final ValueChanged<VisitorPass> onSelect;
  final ValueChanged<VisitorPass> onCheckOut;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Live Gate Status',
      subtitle: 'Who is inside right now',
      icon: Icons.sensor_door_outlined,
      child: busy
          ? const Column(
              children: [
                ShimmerBox(height: 52),
                SizedBox(height: AdminTokens.space2),
                ShimmerBox(height: 52),
                SizedBox(height: AdminTokens.space2),
                ShimmerBox(height: 52),
              ],
            )
          : LiveGateStatus(
              inside: data.insidePasses,
              updatedAt: updatedAt,
              onSelect: onSelect,
              onCheckOut: onCheckOut,
            ),
    );
  }
}

/// Sends the console to the Reports module — used as the page's
/// `onOpenReports` when it runs inside the admin shell.
void openReportsModule(BuildContext context) {
  AdminLog.ui('Security dashboard → Reports');
  context.read<AdminShellController>().go(AdminDestination.reports);
}