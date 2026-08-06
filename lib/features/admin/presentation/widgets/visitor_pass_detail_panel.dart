import 'package:flutter/material.dart';

import '../../domain/entities/visitor_pass.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import '../utils/visitor_pass_sharing.dart';
import 'admin_states.dart';
import 'glass_card.dart';
import 'visitor_pass_qr_view.dart';
import 'visitor_pass_status_chip.dart';
import 'visitor_passes_table.dart';

/// The right-side detail panel for a visitor pass.
///
/// The list row carries most of the record, but not the QR or the two
/// timestamps, so the panel opens on the row and fills in as
/// `GET /visitor-passes/{id}` lands — [state] drives the thin progress line
/// rather than a spinner that would hide what is already readable.
class VisitorPassDetailPanel extends StatelessWidget {
  const VisitorPassDetailPanel({
    super.key,
    required this.pass,
    required this.state,
    required this.canDelete,
    required this.onClose,
    required this.onAction,
    required this.onShareOutcome,
    this.showCloseButton = true,
  });

  final VisitorPass pass;
  final ViewState state;
  final bool canDelete;
  final VoidCallback onClose;
  final void Function(VisitorPassAction action, VisitorPass pass) onAction;

  /// Reports a copy / save result so the page can show one snackbar in one
  /// place, whichever surface the action was triggered from.
  final void Function(ShareOutcome outcome) onShareOutcome;

  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(
            AdminTokens.space5,
            AdminTokens.space4,
            AdminTokens.space3,
            AdminTokens.space4,
          ),
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border(bottom: BorderSide(color: tokens.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Visitor pass',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (showCloseButton)
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Close',
                  color: tokens.textMuted,
                ),
            ],
          ),
        ),
        RefreshLine(visible: state.isLoading),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AdminTokens.space5),
            children: [
              _IdentityCard(pass: pass),
              const SizedBox(height: AdminTokens.space4),
              SolidCard(
                child: Column(
                  children: [
                    VisitorPassQrView(pass: pass, size: 190),
                    const SizedBox(height: AdminTokens.space4),
                    VisitorPassShareBar(
                      pass: pass,
                      onOutcome: onShareOutcome,
                      onEmail: () => onAction(VisitorPassAction.email, pass),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AdminTokens.space4),
              _Card(
                icon: Icons.person_outline_rounded,
                title: 'Visitor',
                rows: [
                  _Row('Name', AdminFormat.text(pass.visitorName)),
                  _Row('Phone', AdminFormat.text(pass.phoneNumber)),
                  _Row('Purpose', AdminFormat.text(pass.visitPurpose)),
                ],
              ),
              const SizedBox(height: AdminTokens.space4),
              _Card(
                icon: Icons.timelapse_rounded,
                title: 'Visit',
                rows: [
                  _Row('Status', AdminFormat.text(pass.statusLabel)),
                  _Row('Entry time', AdminFormat.dateTime(pass.entryTime)),
                  _Row('Exit time', AdminFormat.dateTime(pass.exitTime)),
                ],
              ),
              const SizedBox(height: AdminTokens.space4),
              _Card(
                icon: Icons.info_outline_rounded,
                title: 'Pass',
                rows: [
                  _Row('Pass code', AdminFormat.text(pass.passCode)),
                  _Row(
                    'Sport complex',
                    AdminFormat.text(pass.sportComplexName),
                  ),
                  _Row('Created by', AdminFormat.text(pass.createdByName)),
                  _Row('Generated', AdminFormat.dateTime(pass.createdAt)),
                ],
              ),
              if (state.isFailed) ...[
                const SizedBox(height: AdminTokens.space4),
                const _StaleNotice(),
              ],
              const SizedBox(height: AdminTokens.space6),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AdminTokens.space4),
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border(top: BorderSide(color: tokens.border)),
          ),
          child: Row(
            children: [
              if (canDelete) ...[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => onAction(VisitorPassAction.delete, pass),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Delete'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: tokens.danger,
                      side: BorderSide(
                        color: tokens.danger.withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AdminTokens.space3),
              ],
              Expanded(
                flex: 2,
                child: _PrimaryAction(pass: pass, onAction: onAction),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Check in, check out, or nothing at all once the pass is spent.
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({required this.pass, required this.onAction});

  final VisitorPass pass;
  final void Function(VisitorPassAction action, VisitorPass pass) onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    if (pass.canCheckIn) {
      return FilledButton.icon(
        onPressed: () => onAction(VisitorPassAction.checkIn, pass),
        icon: const Icon(Icons.login_rounded, size: 18),
        label: const Text('Check in'),
      );
    }

    if (pass.canCheckOut) {
      return FilledButton.icon(
        onPressed: () => onAction(VisitorPassAction.checkOut, pass),
        icon: const Icon(Icons.logout_rounded, size: 18),
        label: const Text('Check out'),
      );
    }

    // Spent, expired or invalid: the button stays, disabled, so the panel does
    // not reflow — and it says why.
    return FilledButton.icon(
      onPressed: null,
      icon: const Icon(Icons.lock_outline_rounded, size: 18),
      label: Text(
        pass.status == VisitorPassStatus.checkedOut
            ? 'Visit complete'
            : 'Not usable',
        style: TextStyle(color: tokens.textMuted),
      ),
    );
  }
}

/// The row of share actions under the QR.
class VisitorPassShareBar extends StatefulWidget {
  const VisitorPassShareBar({
    super.key,
    required this.pass,
    required this.onOutcome,
    this.onEmail,
  });

  final VisitorPass pass;
  final void Function(ShareOutcome outcome) onOutcome;

  /// Opens the email dialog. Omitted where the caller has no way to show it.
  final VoidCallback? onEmail;

  @override
  State<VisitorPassShareBar> createState() => _VisitorPassShareBarState();
}

class _VisitorPassShareBarState extends State<VisitorPassShareBar> {
  /// Which action is running, so only that one shows a spinner.
  String? _busy;

  Future<void> _run(String key, Future<ShareOutcome> Function() action) async {
    if (_busy != null) return;
    setState(() => _busy = key);
    try {
      final outcome = await action();
      if (!mounted) return;
      widget.onOutcome(outcome);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pass = widget.pass;

    return Wrap(
      spacing: AdminTokens.space2,
      runSpacing: AdminTokens.space2,
      alignment: WrapAlignment.center,
      children: [
        _ShareButton(
          icon: Icons.chat_bubble_outline_rounded,
          label: 'WhatsApp',
          busy: _busy == 'whatsapp',
          onPressed: () =>
              _run('whatsapp', () => VisitorPassSharing.shareToWhatsApp(pass)),
        ),
        _ShareButton(
          icon: Icons.ios_share_rounded,
          label: 'Share',
          busy: _busy == 'share',
          onPressed: () => _run('share', () => VisitorPassSharing.share(pass)),
        ),
        if (widget.onEmail != null)
          _ShareButton(
            icon: Icons.mail_outline_rounded,
            label: 'Email',
            busy: false,
            onPressed: widget.onEmail!,
          ),
        _ShareButton(
          icon: Icons.copy_rounded,
          label: 'Copy code',
          busy: _busy == 'copy',
          onPressed: () =>
              _run('copy', () => VisitorPassSharing.copyCode(pass)),
        ),
        _ShareButton(
          icon: Icons.download_rounded,
          label: 'Save QR',
          busy: _busy == 'download',
          onPressed: () =>
              _run('download', () => VisitorPassSharing.downloadQr(pass)),
        ),
      ],
    );
  }
}

class _ShareButton extends StatelessWidget {
  const _ShareButton({
    required this.icon,
    required this.label,
    required this.busy,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final bool busy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return OutlinedButton.icon(
      onPressed: busy ? null : onPressed,
      icon: busy
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12.5)),
      style: OutlinedButton.styleFrom(
        foregroundColor: tokens.textSecondary,
        padding: const EdgeInsets.symmetric(
          horizontal: AdminTokens.space3,
          vertical: AdminTokens.space2 + 2,
        ),
        side: BorderSide(color: tokens.border),
      ),
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.pass});

  final VisitorPass pass;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      child: Column(
        children: [
          VisitorAvatar(pass: pass, size: 76),
          const SizedBox(height: AdminTokens.space4),
          Text(
            pass.displayName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AdminTokens.space1),
          Text(
            AdminFormat.text(pass.visitPurpose),
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.textMuted, fontSize: 13),
          ),
          const SizedBox(height: AdminTokens.space4),
          VisitorPassStatusChip(pass: pass),
        ],
      ),
    );
  }
}

class _StaleNotice extends StatelessWidget {
  const _StaleNotice();

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

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
          Icon(Icons.cloud_off_rounded, size: 16, color: tokens.warning),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              'Showing what the list returned — the full pass could not be '
              'loaded, so the QR and the scan times may be missing.',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.title, required this.rows});

  final IconData icon;
  final String title;
  final List<_Row> rows;

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
              Icon(icon, size: 17, color: tokens.accent),
              const SizedBox(width: AdminTokens.space2),
              Text(
                title,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          ...rows,
        ],
      ),
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
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
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
