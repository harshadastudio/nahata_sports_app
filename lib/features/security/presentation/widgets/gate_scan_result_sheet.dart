import 'package:flutter/material.dart';

import '../../../admin/core/admin_log.dart';
import '../../../admin/presentation/theme/admin_theme.dart';
import '../../../admin/presentation/widgets/glass_card.dart';
import '../../domain/entities/gate_scan.dart';

/// The verdict, big enough to read at arm's length.
///
/// One sheet for all four gates. The colour is the message — green means let
/// them through, orange means the pass is real but this scan changed nothing,
/// red means do not. The server's own sentence is always shown verbatim
/// underneath, because that is the reason a guard has to repeat to the person
/// in front of them.
class GateScanResultSheet extends StatelessWidget {
  const GateScanResultSheet({
    super.key,
    required this.result,
    this.onScanAgain,
    this.onCheckIn,
    this.onCheckOut,
  });

  final GateScanResult result;

  final VoidCallback? onScanAgain;

  /// Offered when the gate can act on the pass without re-presenting it.
  final Future<void> Function()? onCheckIn;
  final Future<void> Function()? onCheckOut;

  static Future<void> show(
    BuildContext context, {
    required GateScanResult result,
    VoidCallback? onScanAgain,
    Future<void> Function()? onCheckIn,
    Future<void> Function()? onCheckOut,
  }) {
    AdminLog.ui(
      'Gate result: ${result.kind.label} → ${result.outcome.label} '
      'for ${result.passCode}',
    );

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AdminTheme.of(context).canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AdminTokens.radiusXl),
        ),
      ),
      builder: (_) => GateScanResultSheet(
        result: result,
        onScanAgain: onScanAgain,
        onCheckIn: onCheckIn,
        onCheckOut: onCheckOut,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final accent = severityColour(tokens, result.severity);

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AdminTokens.space5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Verdict(result: result, accent: accent),
              if ((result.message ?? '').trim().isNotEmpty) ...[
                const SizedBox(height: AdminTokens.space4),
                _Reason(message: result.message!.trim(), accent: accent),
              ],
              if (result.facts.isNotEmpty) ...[
                const SizedBox(height: AdminTokens.space4),
                _Details(result: result),
              ],
              const SizedBox(height: AdminTokens.space5),
              _Actions(
                onScanAgain: onScanAgain,
                onCheckIn: onCheckIn,
                onCheckOut: onCheckOut,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Green / orange / red, from the console's own palette so the sheet matches
  /// the rest of the app in both themes.
  static Color severityColour(AdminTokens tokens, GateScanSeverity severity) {
    return switch (severity) {
      GateScanSeverity.success => tokens.success,
      GateScanSeverity.warning => tokens.warning,
      GateScanSeverity.danger => tokens.danger,
    };
  }

  static IconData severityIcon(GateScanOutcome outcome) {
    return switch (outcome) {
      GateScanOutcome.granted => Icons.check_circle_rounded,
      GateScanOutcome.exitRecorded => Icons.logout_rounded,
      GateScanOutcome.alreadyCheckedIn ||
      GateScanOutcome.alreadyCheckedOut ||
      GateScanOutcome.duplicate =>
        Icons.info_rounded,
      GateScanOutcome.expired => Icons.schedule_rounded,
      GateScanOutcome.cancelled => Icons.event_busy_rounded,
      GateScanOutcome.invalid => Icons.gpp_bad_rounded,
      GateScanOutcome.error => Icons.cloud_off_rounded,
    };
  }
}

/// The headline: an icon, the verdict and who it is about.
///
/// Animated in — a guard scanning a queue needs to see that *this* is a new
/// answer, not the previous one still on screen.
class _Verdict extends StatefulWidget {
  const _Verdict({required this.result, required this.accent});

  final GateScanResult result;
  final Color accent;

  @override
  State<_Verdict> createState() => _VerdictState();
}

class _VerdictState extends State<_Verdict>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  )..forward();

  late final Animation<double> _scale = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutBack,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final result = widget.result;

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
        color: widget.accent.withValues(alpha: 0.10),
        border: Border.all(color: widget.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ScaleTransition(
            scale: _scale,
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.accent.withValues(alpha: 0.16),
              ),
              child: Icon(
                GateScanResultSheet.severityIcon(result.outcome),
                size: 38,
                color: widget.accent,
              ),
            ),
          ),
          const SizedBox(height: AdminTokens.space4),
          Text(
            result.headline,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: widget.accent,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            result.kind.label,
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
          ),
          if ((result.personName ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: AdminTokens.space4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: widget.accent.withValues(alpha: 0.18),
                  backgroundImage: (result.avatarUrl ?? '').trim().isEmpty
                      ? null
                      : NetworkImage(result.avatarUrl!.trim()),
                  child: (result.avatarUrl ?? '').trim().isEmpty
                      ? Icon(Icons.person_rounded, color: widget.accent)
                      : null,
                ),
                const SizedBox(width: AdminTokens.space3),
                Flexible(
                  child: Text(
                    result.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (result.passCode.isNotEmpty &&
              !result.passCode.startsWith('member:')) ...[
            const SizedBox(height: AdminTokens.space3),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: tokens.surface,
                borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
                border: Border.all(color: tokens.border),
              ),
              child: Text(
                result.passCode,
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Reason extends StatelessWidget {
  const _Reason({required this.message, required this.accent});

  final String message;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      color: tokens.surfaceAlt,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, size: 18, color: accent),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.result});

  final GateScanResult result;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final fact in result.facts) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 120,
                    child: Text(
                      fact.label,
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      fact.value,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: fact.emphasised ? 14 : 13,
                        fontWeight: fact.emphasised
                            ? FontWeight.w700
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (fact != result.facts.last)
              Divider(height: 1, color: tokens.border),
          ],
        ],
      ),
    );
  }
}

class _Actions extends StatefulWidget {
  const _Actions({
    required this.onScanAgain,
    required this.onCheckIn,
    required this.onCheckOut,
  });

  final VoidCallback? onScanAgain;
  final Future<void> Function()? onCheckIn;
  final Future<void> Function()? onCheckOut;

  @override
  State<_Actions> createState() => _ActionsState();
}

class _ActionsState extends State<_Actions> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.onCheckIn != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AdminTokens.space3),
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _run(widget.onCheckIn!),
              icon: const Icon(Icons.login_rounded, size: 18),
              label: const Text('Check in'),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.success,
                minimumSize: const Size(0, 48),
              ),
            ),
          ),
        if (widget.onCheckOut != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AdminTokens.space3),
            child: FilledButton.icon(
              onPressed: _busy ? null : () => _run(widget.onCheckOut!),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text('Check out'),
              style: FilledButton.styleFrom(
                backgroundColor: tokens.warning,
                minimumSize: const Size(0, 48),
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 46),
                ),
                child: const Text('Close'),
              ),
            ),
            if (widget.onScanAgain != null) ...[
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onScanAgain!();
                  },
                  icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                  label: const Text('Scan next'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 46),
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}