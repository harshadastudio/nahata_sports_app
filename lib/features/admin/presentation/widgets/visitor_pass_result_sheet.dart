import 'package:flutter/material.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/visitor_pass.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'glass_card.dart';
import 'visitor_pass_status_chip.dart';

/// The outcome of a scan or a lookup, shown the same way whether it succeeded
/// or was refused.
///
/// A refusal is deliberately as informative as an acceptance: the gate has to
/// see the visitor, the pass's current state and the server's own reason —
/// nothing about the response is hidden.
class VisitorPassResultSheet extends StatelessWidget {
  const VisitorPassResultSheet({
    super.key,
    required this.result,
    required this.passCode,
    this.onCheckIn,
    this.onCheckOut,
    this.onScanAgain,
    this.onOpenPass,
  });

  final VisitorPassCheck result;

  /// The code that was scanned or typed — shown when the server sent back no
  /// pass at all, so the desk can still see what was tried.
  final String passCode;

  /// Offered by the read-only lookup screen: having seen that a pass is valid,
  /// the desk can act on it without scanning it a second time.
  final Future<void> Function()? onCheckIn;
  final Future<void> Function()? onCheckOut;

  final VoidCallback? onScanAgain;
  final VoidCallback? onOpenPass;

  static Future<void> show(
    BuildContext context, {
    required VisitorPassCheck result,
    required String passCode,
    Future<void> Function()? onCheckIn,
    Future<void> Function()? onCheckOut,
    VoidCallback? onScanAgain,
    VoidCallback? onOpenPass,
  }) {
    AdminLog.ui('Scan result sheet: ${result.title} for $passCode');

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      backgroundColor: AdminTheme.of(context).canvas,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AdminTokens.radiusXl),
        ),
      ),
      builder: (sheetContext) => VisitorPassResultSheet(
        result: result,
        passCode: passCode,
        onCheckIn: onCheckIn,
        onCheckOut: onCheckOut,
        onScanAgain: onScanAgain,
        onOpenPass: onOpenPass,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final pass = result.pass;

    final accent = result.success
        ? (result.readOnly && !result.isValid ? tokens.warning : tokens.success)
        : tokens.danger;

    final icon = result.success
        ? (result.readOnly
              ? (result.isValid
                    ? Icons.verified_rounded
                    : Icons.report_problem_rounded)
              : (result.scanType == VisitorScanType.checkOut
                    ? Icons.logout_rounded
                    : Icons.login_rounded))
        : Icons.gpp_bad_rounded;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: AdminTokens.space3),
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: tokens.borderStrong,
                  borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(AdminTokens.space5),
                children: [
                  Row(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accent.withValues(alpha: 0.12),
                        ),
                        child: Icon(icon, size: 26, color: accent),
                      ),
                      const SizedBox(width: AdminTokens.space4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              result.title,
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              result.readOnly
                                  ? 'Read-only check — the pass was not changed'
                                  : (result.scanType?.label ?? 'Scan'),
                              style: TextStyle(
                                color: tokens.textMuted,
                                fontSize: 12.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if ((result.message ?? '').trim().isNotEmpty) ...[
                    const SizedBox(height: AdminTokens.space4),
                    // The server's own words, verbatim — "already checked out",
                    // "expired", whatever it said.
                    Container(
                      padding: const EdgeInsets.all(AdminTokens.space4),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(
                          AdminTokens.radiusMd,
                        ),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.28),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            result.success
                                ? Icons.info_outline_rounded
                                : Icons.error_outline_rounded,
                            size: 18,
                            color: accent,
                          ),
                          const SizedBox(width: AdminTokens.space3),
                          Expanded(
                            child: Text(
                              result.message!.trim(),
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontSize: 13,
                                height: 1.45,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: AdminTokens.space4),
                  if (pass == null)
                    _UnknownPassCard(passCode: passCode)
                  else
                    _VisitorCard(pass: pass, readOnly: result.readOnly),
                  const SizedBox(height: AdminTokens.space5),
                  _Actions(
                    result: result,
                    onCheckIn: onCheckIn,
                    onCheckOut: onCheckOut,
                    onScanAgain: onScanAgain,
                    onOpenPass: onOpenPass,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VisitorCard extends StatelessWidget {
  const _VisitorCard({required this.pass, required this.readOnly});

  final VisitorPass pass;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  pass.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AdminTokens.space3),
              VisitorPassStatusChip(pass: pass),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          _Row('Pass code', AdminFormat.text(pass.passCode)),
          _Row('Phone', AdminFormat.text(pass.phoneNumber)),
          _Row('Purpose', AdminFormat.text(pass.visitPurpose)),
          _Row('Sport complex', AdminFormat.text(pass.sportComplexName)),
          _Row('Generated', AdminFormat.dateTime(pass.createdAt)),
          _Row('Entry time', AdminFormat.dateTime(pass.entryTime)),
          _Row('Exit time', AdminFormat.dateTime(pass.exitTime)),
          if (readOnly) ...[
            const SizedBox(height: AdminTokens.space3),
            Row(
              children: [
                Icon(
                  pass.isSpent
                      ? Icons.do_not_disturb_on_outlined
                      : Icons.check_circle_outline_rounded,
                  size: 15,
                  color: pass.isSpent ? tokens.danger : tokens.success,
                ),
                const SizedBox(width: AdminTokens.space2),
                Text(
                  pass.isSpent
                      ? 'Not valid for further scans'
                      : 'Valid — waiting for ${pass.nextScan?.label.toLowerCase() ?? 'a scan'}',
                  style: TextStyle(
                    color: pass.isSpent ? tokens.danger : tokens.success,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _UnknownPassCard extends StatelessWidget {
  const _UnknownPassCard({required this.passCode});

  final String passCode;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      color: tokens.surfaceAlt,
      child: Row(
        children: [
          Icon(Icons.qr_code_2_rounded, size: 20, color: tokens.textMuted),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'The server returned no visitor details',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Code checked: ${AdminFormat.text(passCode)}',
                  style: TextStyle(color: tokens.textMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Actions extends StatefulWidget {
  const _Actions({
    required this.result,
    required this.onCheckIn,
    required this.onCheckOut,
    required this.onScanAgain,
    required this.onOpenPass,
  });

  final VisitorPassCheck result;
  final Future<void> Function()? onCheckIn;
  final Future<void> Function()? onCheckOut;
  final VoidCallback? onScanAgain;
  final VoidCallback? onOpenPass;

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
    final pass = widget.result.pass;

    // Only the leg the pass is actually waiting on is offered — a spent pass
    // gets no scan button at all.
    final canCheckIn = widget.onCheckIn != null && (pass?.canCheckIn ?? false);
    final canCheckOut =
        widget.onCheckOut != null && (pass?.canCheckOut ?? false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canCheckIn)
          FilledButton.icon(
            onPressed: _busy ? null : () => _run(widget.onCheckIn!),
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.login_rounded, size: 18),
            label: const Text('Check this visitor in'),
          ),
        if (canCheckOut)
          FilledButton.icon(
            onPressed: _busy ? null : () => _run(widget.onCheckOut!),
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Check this visitor out'),
          ),
        if (canCheckIn || canCheckOut)
          const SizedBox(height: AdminTokens.space3),
        Row(
          children: [
            if (widget.onOpenPass != null) ...[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onOpenPass!();
                  },
                  icon: const Icon(Icons.badge_outlined, size: 17),
                  label: const Text('Open pass'),
                ),
              ),
              const SizedBox(width: AdminTokens.space3),
            ],
            Expanded(
              child: widget.onScanAgain == null
                  ? OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    )
                  : FilledButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onScanAgain!();
                      },
                      icon: const Icon(Icons.qr_code_scanner_rounded, size: 17),
                      label: const Text('Scan next'),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              label,
              style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: value == AdminFormat.dash
                    ? tokens.textMuted
                    : tokens.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
