import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../admin/core/admin_log.dart';
import '../../../admin/presentation/state/view_state.dart';
import '../../../admin/presentation/theme/admin_theme.dart';
import '../../../admin/presentation/widgets/admin_dialogs.dart';
import '../../../admin/presentation/widgets/admin_states.dart';
import '../../../admin/presentation/widgets/glass_card.dart';
import '../../domain/entities/gate_scan.dart';
import '../../domain/entities/pass_code_router.dart';
import '../state/security_guard_controller.dart';
import '../widgets/guard_stat_grid.dart';
import '../widgets/scan_activity_feed.dart';
import 'gate_scanner_page.dart';

/// `/security/dashboard` — what a guard sees when they sign in.
///
/// Four gates, eight counters, one activity feed and a search box that works
/// out which scanner a code belongs to. Everything a person on a door needs is
/// one tap from here.
class SecurityGuardDashboardPage extends StatefulWidget {
  const SecurityGuardDashboardPage({super.key, this.onOpenVisitorPasses});

  /// Opens the full Visitor Passes module, where the list, its filters and the
  /// admin-only delete live. Null hides the link — a guard on the standalone
  /// console has no module to open.
  final VoidCallback? onOpenVisitorPasses;

  @override
  State<SecurityGuardDashboardPage> createState() =>
      _SecurityGuardDashboardPageState();
}

class _SecurityGuardDashboardPageState
    extends State<SecurityGuardDashboardPage> {
  final TextEditingController _search = TextEditingController();

  /// Held so [dispose] can stop the poll: the controller outlives this page.
  SecurityGuardController? _controller;

  @override
  void initState() {
    super.initState();
    AdminLog.life('SecurityGuardDashboardPage mounted');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = context.read<SecurityGuardController>();
      _controller = controller;
      controller.load();
      controller.startAutoRefresh();
    });
  }

  @override
  void dispose() {
    _controller?.stopAutoRefresh();
    _search.dispose();
    AdminLog.life('SecurityGuardDashboardPage disposed');
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SecurityGuardController>();
    final tokens = AdminTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < AdminTokens.mobileMax;
    final isDesktop = width >= AdminTokens.tabletMax;

    if (controller.state.isFailed && controller.loadedAt == null) {
      return ColoredBox(
        color: tokens.canvas,
        child: Center(
          child: ErrorStateView(
            title: 'Dashboard unavailable',
            message: controller.error ??
                'The gate figures could not be loaded. Please try again.',
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

            _GlobalSearch(controller: _search, onSubmit: _resolveCode),
            const SizedBox(height: AdminTokens.space5),

            GuardStatGrid(
              counters: controller.counters,
              loading: controller.isFirstLoad,
              onOpenVisitors: widget.onOpenVisitorPasses,
            ),
            const SizedBox(height: AdminTokens.space3),
            const GuardCounterNote(),
            const SizedBox(height: AdminTokens.space5),

            _Panel(
              title: 'Quick Scan',
              subtitle: 'Open a gate scanner',
              icon: Icons.bolt_rounded,
              child: _QuickScans(onScan: _openScanner),
            ),
            const SizedBox(height: AdminTokens.space5),

            _Panel(
              title: 'Recent Scan Activity',
              subtitle: 'Every scan at this gate, newest first',
              icon: Icons.history_rounded,
              padding: isDesktop
                  ? const EdgeInsets.fromLTRB(
                      AdminTokens.space3,
                      0,
                      AdminTokens.space3,
                      AdminTokens.space3,
                    )
                  : null,
              child: ScanActivityFeed(
                entries: controller.recentActivity(isDesktop ? 15 : 8),
                loading: controller.isFirstLoad,
                compact: !isDesktop,
              ),
            ),
            const SizedBox(height: AdminTokens.space6),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Scanning
  // ---------------------------------------------------------------------------

  SecurityGuardController get _guard =>
      context.read<SecurityGuardController>();

  /// Opens the scanner for one gate. The handler is the only thing that differs
  /// between the four.
  Future<void> _openScanner(GateScanKind kind, {String? prefilled}) async {
    final guard = _guard;
    final gates = guard.gates;

    await GateScannerPage.push(
      context,
      kind: kind,
      supportsDirection: kind != GateScanKind.coaching,
      onRecorded: guard.recordScan,
      initialCode: prefilled,
      onScan: (code, direction) => switch (kind) {
        GateScanKind.visitor => gates.scanVisitorPass(
            passCode: code,
            direction: direction,
          ),
        GateScanKind.event => gates.scanEventPass(
            passCode: code,
            direction: direction,
          ),
        GateScanKind.courtBooking => gates.scanCourtBooking(
            passCode: code,
            direction: direction,
          ),
        GateScanKind.coaching => gates.scanCoachingPass(code),
      },
    );

    if (!mounted) return;
    await guard.refresh();
  }

  /// The global search box: identify the pass type, then open its scanner.
  ///
  /// A code nothing recognises is **not** guessed at — sending it to the wrong
  /// `/scan` route could spend a leg of somebody's real pass — so the guard is
  /// asked which gate it belongs to.
  Future<void> _resolveCode(String raw) async {
    final resolved = PassCodeRouter.resolve(raw);
    if (resolved == null) {
      AdminFeedback.info(context, 'Enter or paste a pass code first.');
      return;
    }

    final kind = resolved.kind ?? await _askWhichGate(resolved.code);
    if (kind == null || !mounted) return;

    AdminLog.ui('Global search → ${kind.label} for ${resolved.code}');
    _search.clear();
    await _openScanner(kind, prefilled: resolved.code);
  }

  Future<GateScanKind?> _askWhichGate(String code) {
    final tokens = AdminTheme.of(context);

    return showDialog<GateScanKind>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
        ),
        title: Text(
          'Which pass is this?',
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '“$code” does not match a known pass format. Pick the gate it '
              'belongs to — sending it to the wrong one could use up a scan.',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AdminTokens.space4),
            for (final kind in GateScanKind.values)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(_iconFor(kind), color: tokens.accent, size: 20),
                title: Text(
                  kind.label,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () => Navigator.of(dialogContext).pop(kind),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(GateScanKind kind) => switch (kind) {
        GateScanKind.visitor => Icons.badge_rounded,
        GateScanKind.event => Icons.confirmation_number_rounded,
        GateScanKind.courtBooking => Icons.sports_tennis_rounded,
        GateScanKind.coaching => Icons.school_rounded,
      };
}

// -----------------------------------------------------------------------------
// Pieces
// -----------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final SecurityGuardController controller;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < AdminTokens.tabletMax;
    final at = controller.loadedAt;

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
        Row(
          children: [
            Container(
              width: 7,
              height: 7,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tokens.success,
              ),
            ),
            Text(
              at == null
                  ? 'Live'
                  : 'Live · updated '
                      '${at.hour.toString().padLeft(2, '0')}:'
                      '${at.minute.toString().padLeft(2, '0')}',
              style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
            ),
          ],
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

    return Row(children: [Expanded(child: title), refresh]);
  }
}

class _GlobalSearch extends StatelessWidget {
  const _GlobalSearch({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(Icons.travel_explore_rounded, size: 18, color: tokens.accent),
              const SizedBox(width: AdminTokens.space2),
              Text(
                'Global pass search',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            'Paste any code — visitor, event, booking or student — and it '
            'opens the right scanner.',
            style: TextStyle(color: tokens.textMuted, fontSize: 12),
          ),
          const SizedBox(height: AdminTokens.space3),
          TextField(
            controller: controller,
            textCapitalization: TextCapitalization.characters,
            textInputAction: TextInputAction.search,
            onSubmitted: onSubmit,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 14,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              hintText: 'GATEPASS-2026-000042',
              prefixIcon: Icon(
                Icons.qr_code_rounded,
                size: 18,
                color: tokens.textMuted,
              ),
              suffixIcon: IconButton(
                onPressed: () => onSubmit(controller.text),
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                tooltip: 'Find',
                color: tokens.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickScans extends StatelessWidget {
  const _QuickScans({required this.onScan});

  final void Function(GateScanKind kind) onScan;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final columns = width < AdminTokens.mobileMax ? 2 : 4;

    const gates = <(GateScanKind, String, IconData, Color)>[
      (
        GateScanKind.visitor,
        'Visitor Scan',
        Icons.badge_rounded,
        Color(0xFF1A237E),
      ),
      (
        GateScanKind.event,
        'Event Scan',
        Icons.confirmation_number_rounded,
        Color(0xFF8B5CF6),
      ),
      (
        GateScanKind.courtBooking,
        'Court Booking Scan',
        Icons.sports_tennis_rounded,
        Color(0xFF14B8A6),
      ),
      (
        GateScanKind.coaching,
        'Coaching Pass Scan',
        Icons.school_rounded,
        Color(0xFFF59E0B),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = AdminTokens.space3;
        final cardWidth =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final (kind, label, icon, colour) in gates)
              SizedBox(
                width: cardWidth,
                child: _QuickScanCard(
                  label: label,
                  icon: icon,
                  colour: colour,
                  onTap: () => onScan(kind),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _QuickScanCard extends StatefulWidget {
  const _QuickScanCard({
    required this.label,
    required this.icon,
    required this.colour,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color colour;
  final VoidCallback onTap;

  @override
  State<_QuickScanCard> createState() => _QuickScanCardState();
}

class _QuickScanCardState extends State<_QuickScanCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: AdminTokens.fast,
          curve: AdminTokens.curve,
          padding: const EdgeInsets.all(AdminTokens.space4),
          decoration: BoxDecoration(
            color: _hovered
                ? widget.colour.withValues(alpha: 0.10)
                : tokens.surface,
            borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
            border: Border.all(
              color: _hovered
                  ? widget.colour.withValues(alpha: 0.45)
                  : tokens.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
                  gradient: LinearGradient(
                    colors: [
                      widget.colour.withValues(alpha: 0.22),
                      widget.colour.withValues(alpha: 0.07),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(widget.icon, size: 21, color: widget.colour),
              ),
              const SizedBox(height: AdminTokens.space3),
              Text(
                widget.label,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              Row(
                children: [
                  Icon(
                    Icons.qr_code_scanner_rounded,
                    size: 12,
                    color: tokens.textMuted,
                  ),
                  const SizedBox(width: 4),
                  // Flexible: on a phone these cards are two to a row, and the
                  // caption has to give way rather than overflow.
                  Flexible(
                    child: Text(
                      'Open scanner',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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