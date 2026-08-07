import 'package:flutter/material.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/visitor_pass.dart';
import '../pages/visitor_pass_scanner_page.dart';
import '../state/view_state.dart';
import '../state/visitor_passes_controller.dart';
import '../theme/admin_theme.dart';
import '../widgets/admin_dialogs.dart';
import '../widgets/glass_card.dart';
import '../widgets/visitor_pass_created_sheet.dart';
import '../widgets/visitor_pass_email_dialog.dart';
import '../widgets/visitor_pass_form_dialog.dart';
import '../widgets/visitor_pass_result_sheet.dart';
import 'visitor_pass_sharing.dart';

/// The visitor-pass flows, in one place.
///
/// Generating a pass, scanning it, verifying a code by hand, looking one up,
/// emailing it and deleting it are each a dialog plus its follow-up sheet plus
/// its snackbar. The Visitor Passes page and the Security Dashboard both offer
/// all six, and a gate desk that saw two different "generate" dialogs — or,
/// worse, two implementations of the check-in rules — would be a bug waiting to
/// happen. Both screens call these.
///
/// Every method takes the [VisitorPassesController] that owns the data, so the
/// list a caller is showing is patched by the same call that performed the
/// write.
class VisitorPassActions {
  const VisitorPassActions._();

  // ---------------------------------------------------------------------------
  // Generate
  // ---------------------------------------------------------------------------

  /// `POST /visitor-passes`, then the QR sheet with copy / download / email /
  /// print. Returns the created pass, or null when the desk cancelled.
  static Future<VisitorPass?> generate(
    BuildContext context,
    VisitorPassesController controller,
  ) async {
    // The venue picker needs its options before the dialog is useful.
    if (controller.complexes.isEmpty && !controller.complexesState.isLoading) {
      await controller.loadComplexes();
    }
    if (!context.mounted) return null;

    final created = await VisitorPassFormDialog.show(
      context,
      complexes: controller.complexes,
      complexesState: controller.complexesState,
      onReloadComplexes: () => controller.loadComplexes(refresh: true),
      onSubmit: controller.create,
    );

    if (created == null || !context.mounted) return null;

    AdminFeedback.success(
      context,
      'Visitor pass generated for ${created.displayName}.',
    );

    await VisitorPassCreatedSheet.show(
      context,
      pass: created,
      onShareOutcome: (outcome) => reportOutcome(context, outcome),
      onEmail: () => sendEmail(context, controller, created),
    );

    return created;
  }

  // ---------------------------------------------------------------------------
  // Scanning
  // ---------------------------------------------------------------------------

  /// Opens the camera scanner. Returns true when it was used, so the caller can
  /// refresh — statuses will have moved on while it was open.
  static Future<bool> openScanner(
    BuildContext context,
    VisitorPassesController controller,
  ) async {
    await VisitorPassScannerPage.push(
      context,
      onVerify: (code, type) =>
          controller.verify(passCode: code, scanType: type),
      onLookup: controller.lookup,
    );
    return context.mounted;
  }

  /// Type a code, see the visitor, then check them in or out — for a desk with
  /// no camera, or a QR the lens will not read.
  ///
  /// The code is resolved through the read-only `/lookup` first, so the desk
  /// confirms *who* it is about to admit before a leg of the visit is spent.
  /// The IN / OUT buttons on the result sheet then call `/verify`.
  static Future<bool> manualVerify(
    BuildContext context,
    VisitorPassesController controller,
  ) =>
      _promptAndLookup(
        context,
        controller,
        title: 'Verify a pass',
        message:
            'Enter the code from the visitor pass. You will see who it belongs '
            'to before checking them in or out.',
        confirmLabel: 'Verify',
        icon: Icons.pin_rounded,
        allowScanning: true,
      );

  /// Read-only `/lookup`: shows who a pass belongs to and what state it is in
  /// without consuming a leg of the visit.
  static Future<bool> lookup(
    BuildContext context,
    VisitorPassesController controller,
  ) =>
      _promptAndLookup(
        context,
        controller,
        title: 'Look up a pass',
        message:
            'Enter a pass code to see the visitor and the current status. This '
            'does not check anyone in or out.',
        confirmLabel: 'Look up',
        icon: Icons.plagiarism_outlined,
        allowScanning: false,
      );

  /// Shared body of [manualVerify] and [lookup].
  ///
  /// Returns true when a scan was performed, so the caller knows to refresh.
  /// [allowScanning] is what separates the two: verifying offers the IN / OUT
  /// buttons, looking up is purely informational.
  static Future<bool> _promptAndLookup(
    BuildContext context,
    VisitorPassesController controller, {
    required String title,
    required String message,
    required String confirmLabel,
    required IconData icon,
    required bool allowScanning,
  }) async {
    final code = await _PassCodePrompt.show(
      context,
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      icon: icon,
    );

    if (code == null || !context.mounted) return false;

    try {
      final result = await controller.lookup(code);
      if (!context.mounted) return false;

      final pass = result.pass;
      var scanned = false;

      // The IN / OUT buttons are offered only for the leg the pass is actually
      // waiting for. A spent pass gets neither — the lifecycle rule is
      // Pending → IN → OUT, and after OUT the pass is finished for good.
      Future<void> runScan(VisitorScanType type) async {
        scanned = true;
        await scan(context, controller, pass!, type);
      }

      await VisitorPassResultSheet.show(
        context,
        result: result,
        passCode: code,
        onCheckIn: allowScanning && (pass?.canCheckIn ?? false)
            ? () => runScan(VisitorScanType.checkIn)
            : null,
        onCheckOut: allowScanning && (pass?.canCheckOut ?? false)
            ? () => runScan(VisitorScanType.checkOut)
            : null,
      );

      return scanned;
    } catch (error) {
      if (!context.mounted) return false;
      AdminFeedback.error(context, messageOf(error));
      return false;
    }
  }

  /// Records a leg of the visit for a pass already on screen — the code is all
  /// `/verify` needs, so the camera is not involved.
  static Future<void> scan(
    BuildContext context,
    VisitorPassesController controller,
    VisitorPass pass,
    VisitorScanType scanType,
  ) async {
    final code = (pass.passCode ?? '').trim();
    if (code.isEmpty) {
      AdminFeedback.error(
        context,
        'This pass has no code, so it cannot be scanned.',
      );
      return;
    }

    try {
      final result = await controller.verify(passCode: code, scanType: scanType);
      if (!context.mounted) return;

      await VisitorPassResultSheet.show(context, result: result, passCode: code);

      // The list row was patched in place; the open panel is re-read so its
      // timestamps come from the server rather than being inferred.
      if (controller.selected != null) {
        await controller.reloadSelected();
      }
    } catch (error) {
      if (!context.mounted) return;
      AdminFeedback.error(context, messageOf(error));
    }
  }

  // ---------------------------------------------------------------------------
  // Email / delete
  // ---------------------------------------------------------------------------

  static Future<void> sendEmail(
    BuildContext context,
    VisitorPassesController controller,
    VisitorPass pass,
  ) async {
    final message = await VisitorPassEmailDialog.show(
      context,
      pass: pass,
      onSubmit: (email, name) => controller.sendEmail(
        pass: pass,
        recipientEmail: email,
        recipientName: name,
      ),
    );

    if (message == null || !context.mounted) return;
    AdminFeedback.success(context, message);
  }

  /// `DELETE /visitor-passes/{id}` behind a confirmation. ADMIN and
  /// COMPLEX_ADMIN only — the caller is expected to have hidden the action for
  /// anyone else ([VisitorPassesController.canDelete]).
  static Future<void> confirmDelete(
    BuildContext context,
    VisitorPassesController controller,
    VisitorPass pass,
  ) async {
    final tokens = AdminTheme.of(context);

    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete this visitor pass?',
      message:
          'Are you sure you want to delete this visitor pass? The QR stops '
          'working immediately and the record is removed. This cannot be '
          'undone.',
      confirmLabel: 'Delete pass',
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
              pass.displayName,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              [
                if ((pass.passCode ?? '').trim().isNotEmpty)
                  pass.passCode!.trim(),
                if (pass.statusLabel.isNotEmpty) pass.statusLabel,
                if ((pass.sportComplexName ?? '').trim().isNotEmpty)
                  pass.sportComplexName!.trim(),
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
      await controller.delete(pass);
      if (!context.mounted) return;
      AdminFeedback.success(context, 'The visitor pass was deleted.');
    } catch (error) {
      if (!context.mounted) return;
      AdminFeedback.error(context, messageOf(error));
    }
  }

  // ---------------------------------------------------------------------------
  // Shared helpers
  // ---------------------------------------------------------------------------

  static void reportOutcome(BuildContext context, ShareOutcome outcome) {
    if (!context.mounted) return;
    if (outcome.ok) {
      AdminFeedback.success(context, outcome.message);
    } else {
      AdminFeedback.error(context, outcome.message);
    }
  }

  static String messageOf(Object error) {
    // ApiException.toString() carries the user-facing message.
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.isEmpty ? 'Something went wrong. Please try again.' : text;
  }
}

/// The small "type a pass code" dialog used by Lookup.
class _PassCodePrompt extends StatefulWidget {
  const _PassCodePrompt({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.icon,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final IconData icon;

  static Future<String?> show(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
    required IconData icon,
  }) {
    AdminLog.ui('Pass code prompt opened ($title)');
    return showDialog<String>(
      context: context,
      builder: (_) => _PassCodePrompt(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        icon: icon,
      ),
    );
  }

  @override
  State<_PassCodePrompt> createState() => _PassCodePromptState();
}

class _PassCodePromptState extends State<_PassCodePrompt> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return AlertDialog(
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
      ),
      title: Row(
        children: [
          Icon(widget.icon, size: 20, color: tokens.accent),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              widget.title,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.message,
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AdminTokens.space4),
            TextFormField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 15,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
              ),
              decoration: const InputDecoration(
                labelText: 'Pass code',
                hintText: 'e.g. VP-8FA23K',
              ),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Enter the pass code'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: Text(widget.confirmLabel)),
      ],
    );
  }
}