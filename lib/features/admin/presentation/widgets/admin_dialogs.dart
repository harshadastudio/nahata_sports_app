import 'package:flutter/material.dart';

import '../../core/admin_log.dart';
import '../theme/admin_theme.dart';

/// Destructive-action confirmation.
///
/// Returns true only when the admin explicitly confirms; dismissing the barrier
/// or pressing Escape resolves to false, so a stray tap can never delete.
class ConfirmDialog extends StatelessWidget {
  const ConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.destructive = false,
    this.icon,
    this.detail,
  });

  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final bool destructive;
  final IconData? icon;

  /// An extra line — typically what exactly is about to be affected.
  final Widget? detail;

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
    IconData? icon,
    Widget? detail,
  }) async {
    AdminLog.ui('Confirm dialog: $title');
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => ConfirmDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        destructive: destructive,
        icon: icon,
        detail: detail,
      ),
    );
    AdminLog.ui('Confirm dialog result: ${result ?? false}');
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final accent = destructive ? tokens.danger : tokens.accent;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AdminTokens.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      icon ??
                          (destructive
                              ? Icons.delete_outline_rounded
                              : Icons.help_outline_rounded),
                      color: accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AdminTokens.space3),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AdminTokens.space4),
              Text(
                message,
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 13.5,
                  height: 1.5,
                ),
              ),
              if (detail != null) ...[
                const SizedBox(height: AdminTokens.space4),
                detail!,
              ],
              const SizedBox(height: AdminTokens.space6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: TextButton.styleFrom(
                      foregroundColor: tokens.textSecondary,
                    ),
                    child: Text(cancelLabel),
                  ),
                  const SizedBox(width: AdminTokens.space3),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: FilledButton.styleFrom(backgroundColor: accent),
                    child: Text(confirmLabel),
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

/// Feedback toasts, so success and failure look the same everywhere.
class AdminFeedback {
  const AdminFeedback._();

  static void success(BuildContext context, String message) {
    AdminLog.success('Snackbar: $message');
    _show(
      context,
      message,
      Icons.check_circle_rounded,
      const Color(0xFF10B981),
    );
  }

  static void error(BuildContext context, String message) {
    AdminLog.failure('Snackbar: $message');
    _show(context, message, Icons.error_rounded, const Color(0xFFF87171));
  }

  static void info(BuildContext context, String message) {
    AdminLog.ui('Snackbar: $message');
    _show(context, message, Icons.info_rounded, const Color(0xFF60A5FA));
  }

  static void _show(
    BuildContext context,
    String message,
    IconData icon,
    Color color,
  ) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 4),
          width: null,
          margin: const EdgeInsets.all(AdminTokens.space4),
          content: Row(
            children: [
              Icon(icon, color: color, size: 19),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(fontSize: 13.5, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      );
  }
}
