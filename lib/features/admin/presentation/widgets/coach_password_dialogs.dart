import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/coach.dart';
import '../theme/admin_theme.dart';
import 'admin_states.dart';

/// Shows a coach's current sign-in credentials.
///
/// The values are held only by this dialog's state and go with it when it
/// closes — nothing caches them, and no log line ever contains the password
/// (`AppLogger` also redacts any `*password*` JSON field on the way in).
///
/// Typed to [Coach] rather than sharing the employee dialog: that one is bound
/// to its own entity, and widening it would mean editing a shipped module.
class CoachPasswordDialog extends StatefulWidget {
  const CoachPasswordDialog({
    super.key,
    required this.coach,
    required this.load,
  });

  final Coach coach;
  final Future<CoachCredentials> Function() load;

  static Future<void> show(
    BuildContext context, {
    required Coach coach,
    required Future<CoachCredentials> Function() load,
  }) {
    AdminLog.ui('Password dialog opened for coach ${coach.id}');
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => CoachPasswordDialog(coach: coach, load: load),
    ).whenComplete(
      () => AdminLog.ui('Password dialog closed for coach ${coach.id}'),
    );
  }

  @override
  State<CoachPasswordDialog> createState() => _CoachPasswordDialogState();
}

class _CoachPasswordDialogState extends State<CoachPasswordDialog> {
  CoachCredentials? _credentials;
  String? _error;
  bool _loading = true;

  /// Masked until the admin asks to see it — a shoulder-surfing guard, and a
  /// reminder that this is a credential rather than ordinary detail.
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final credentials = await widget.load();
      if (!mounted) return;
      setState(() {
        _credentials = credentials;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      AdminLog.failure(
        'Coach credential read crashed',
        error: error,
        stackTrace: stackTrace,
      );
      setState(() {
        _error = 'Could not read the credentials for this coach.';
        _loading = false;
      });
    }
  }

  Future<void> _copy(String label, String? value) async {
    final text = (value ?? '').trim();
    if (text.isEmpty) return;

    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;

    // Logs that a copy happened, never what was copied.
    AdminLog.ui('$label copied to the clipboard');
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$label copied')));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final credentials = _credentials;

    // The list row already carries the email; showing it while the request is
    // in flight means the dialog is never entirely blank.
    final email = credentials?.email ?? widget.coach.email;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(AdminTokens.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tokens.accent.withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      Icons.key_rounded,
                      color: tokens.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AdminTokens.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Sign-in credentials',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          widget.coach.displayName,
                          overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: AdminTokens.space5),
              if (_loading)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: const [
                    ShimmerBox(height: 56, radius: AdminTokens.radiusMd),
                    SizedBox(height: AdminTokens.space3),
                    ShimmerBox(height: 56, radius: AdminTokens.radiusMd),
                  ],
                )
              else if (_error != null)
                _ErrorBlock(message: _error!, onRetry: _load)
              else ...[
                _CredentialRow(
                  label: 'Email',
                  value: email,
                  icon: Icons.mail_outline_rounded,
                  onCopy: () => _copy('Email', email),
                ),
                const SizedBox(height: AdminTokens.space3),
                _CredentialRow(
                  label: 'Password',
                  value: credentials?.password,
                  icon: Icons.lock_outline_rounded,
                  secret: true,
                  revealed: _revealed,
                  onToggleReveal: () => setState(() => _revealed = !_revealed),
                  onCopy: () => _copy('Password', credentials?.password),
                ),
                if (credentials != null && !credentials.hasPassword) ...[
                  const SizedBox(height: AdminTokens.space3),
                  _Note(
                    icon: Icons.info_outline_rounded,
                    color: tokens.warning,
                    text:
                        'The server did not return a password. It has most '
                        'likely already been changed by the coach — use Reset '
                        'password to set a new one.',
                  ),
                ],
                const SizedBox(height: AdminTokens.space4),
                _Note(
                  icon: Icons.shield_outlined,
                  color: tokens.textMuted,
                  text:
                      'Share this over a private channel. It is shown here '
                      'only while this dialog is open.',
                ),
              ],
              const SizedBox(height: AdminTokens.space6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
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

class _CredentialRow extends StatelessWidget {
  const _CredentialRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.onCopy,
    this.secret = false,
    this.revealed = false,
    this.onToggleReveal,
  });

  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback onCopy;
  final bool secret;
  final bool revealed;
  final VoidCallback? onToggleReveal;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final text = (value ?? '').trim();
    final empty = text.isEmpty;

    final display = empty
        ? '—'
        : (secret && !revealed ? '•' * text.length.clamp(6, 18) : text);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space3),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: tokens.textMuted),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  display,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: empty ? tokens.textMuted : tokens.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    fontFamily: secret ? 'monospace' : null,
                    letterSpacing: secret && !revealed ? 1.5 : null,
                  ),
                ),
              ],
            ),
          ),
          if (secret && onToggleReveal != null)
            IconButton(
              onPressed: empty ? null : onToggleReveal,
              icon: Icon(
                revealed
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 17,
              ),
              color: tokens.textMuted,
              tooltip: revealed ? 'Hide' : 'Reveal',
            ),
          IconButton(
            onPressed: empty ? null : onCopy,
            icon: const Icon(Icons.copy_rounded, size: 16),
            color: tokens.textMuted,
            tooltip: 'Copy $label',
          ),
        ],
      ),
    );
  }
}

/// Sets a new password and tells the admin what the backend did with it.
class CoachResetPasswordDialog extends StatefulWidget {
  const CoachResetPasswordDialog({
    super.key,
    required this.coach,
    required this.onSubmit,
  });

  final Coach coach;
  final Future<void> Function(String password) onSubmit;

  /// Resolves to true when the reset succeeded.
  static Future<bool> show(
    BuildContext context, {
    required Coach coach,
    required Future<void> Function(String password) onSubmit,
  }) async {
    AdminLog.ui('Reset-password dialog opened for coach ${coach.id}');
    final done = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) =>
          CoachResetPasswordDialog(coach: coach, onSubmit: onSubmit),
    );
    AdminLog.ui('Reset-password dialog closed (done: ${done ?? false})');
    return done ?? false;
  }

  @override
  State<CoachResetPasswordDialog> createState() =>
      _CoachResetPasswordDialogState();
}

class _CoachResetPasswordDialogState extends State<CoachResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  bool _obscure = true;
  bool _obscureConfirm = true;
  bool _saving = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onSubmit(_password.text);
      if (!mounted) return;
      // Stays open on success to show the confirmation, and clears the fields
      // so the new password is not left sitting in a text box.
      _password.clear();
      _confirm.clear();
      setState(() {
        _saving = false;
        _done = true;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      AdminLog.failure(
        'Coach password reset crashed',
        error: error,
        stackTrace: stackTrace,
      );
      setState(() {
        _saving = false;
        _error = 'Could not reset the password. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(AdminTokens.space6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: (_done ? tokens.success : tokens.accent)
                          .withValues(alpha: 0.12),
                    ),
                    child: Icon(
                      _done
                          ? Icons.check_circle_outline_rounded
                          : Icons.lock_reset_rounded,
                      color: _done ? tokens.success : tokens.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AdminTokens.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _done ? 'Password reset' : 'Reset password',
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        Text(
                          widget.coach.displayName,
                          overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: AdminTokens.space5),
              if (_done)
                _Note(
                  icon: Icons.check_circle_rounded,
                  color: tokens.success,
                  text:
                      'Password reset successfully. Share the new password '
                      'with the coach over a private channel.',
                )
              else ...[
                if (_error != null) ...[
                  _ErrorBlock(message: _error!),
                  const SizedBox(height: AdminTokens.space4),
                ],
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _FieldLabel('New Password'),
                      const SizedBox(height: AdminTokens.space2),
                      TextFormField(
                        controller: _password,
                        enabled: !_saving,
                        obscureText: _obscure,
                        autofocus: true,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: tokens.textPrimary,
                        ),
                        // Re-validates the confirmation as the first box is
                        // edited, so "does not match" clears itself.
                        onChanged: (_) {
                          if (_confirm.text.isNotEmpty) {
                            _formKey.currentState?.validate();
                          }
                        },
                        validator: (value) {
                          final text = value ?? '';
                          if (text.isEmpty) return 'Enter a new password';
                          if (text.length < 6) {
                            return 'Use at least 6 characters';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'At least 6 characters',
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                            color: tokens.textMuted,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () =>
                                setState(() => _obscure = !_obscure),
                            icon: Icon(
                              _obscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 17,
                            ),
                            color: tokens.textMuted,
                            tooltip: _obscure ? 'Show' : 'Hide',
                          ),
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _FieldLabel('Confirm Password'),
                      const SizedBox(height: AdminTokens.space2),
                      TextFormField(
                        controller: _confirm,
                        enabled: !_saving,
                        obscureText: _obscureConfirm,
                        onFieldSubmitted: (_) => _submit(),
                        style: TextStyle(
                          fontSize: 13.5,
                          color: tokens.textPrimary,
                        ),
                        validator: (value) {
                          final text = value ?? '';
                          if (text.isEmpty) return 'Re-enter the password';
                          if (text != _password.text) {
                            return 'The passwords do not match';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Repeat the new password',
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            size: 18,
                            color: tokens.textMuted,
                          ),
                          suffixIcon: IconButton(
                            onPressed: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                            icon: Icon(
                              _obscureConfirm
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 17,
                            ),
                            color: tokens.textMuted,
                            tooltip: _obscureConfirm ? 'Show' : 'Hide',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AdminTokens.space4),
                _Note(
                  icon: Icons.info_outline_rounded,
                  color: tokens.textMuted,
                  text:
                      'The coach will need this password the next time they '
                      'sign in. Their old one stops working immediately.',
                ),
              ],
              const SizedBox(height: AdminTokens.space6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (_done)
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Done'),
                    )
                  else ...[
                    TextButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        foregroundColor: tokens.textSecondary,
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: AdminTokens.space3),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Reset password'),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Text(
      text,
      style: TextStyle(
        color: tokens.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  const _ErrorBlock({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space3),
      decoration: BoxDecoration(
        color: tokens.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: tokens.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: tokens.danger),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: tokens.danger,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Retry', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space3),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              text,
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
