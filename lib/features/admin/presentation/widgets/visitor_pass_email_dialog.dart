import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/visitor_pass.dart';
import '../theme/admin_theme.dart';
import '../utils/server_field_errors.dart';

/// Email a visitor pass (`POST /visitor-passes/{id}/send-email`).
///
/// Resolves to the server's confirmation message on success, and to null when
/// the desk cancelled.
class VisitorPassEmailDialog extends StatefulWidget {
  const VisitorPassEmailDialog({
    super.key,
    required this.pass,
    required this.onSubmit,
  });

  final VisitorPass pass;

  final Future<String> Function(String email, String name) onSubmit;

  static Future<String?> show(
    BuildContext context, {
    required VisitorPass pass,
    required Future<String> Function(String email, String name) onSubmit,
  }) async {
    AdminLog.ui('Email visitor-pass dialog opened for ${pass.reference}');

    final message = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => VisitorPassEmailDialog(pass: pass, onSubmit: onSubmit),
    );

    AdminLog.ui('Email visitor-pass dialog closed (sent: ${message != null})');
    return message;
  }

  @override
  State<VisitorPassEmailDialog> createState() => _VisitorPassEmailDialogState();
}

class _VisitorPassEmailDialogState extends State<VisitorPassEmailDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _email;
  late final TextEditingController _name;

  bool _sending = false;
  String? _error;
  ServerFieldErrors _fieldErrors = ServerFieldErrors.none;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController();
    // The pass is normally emailed to the visitor it was issued to, so their
    // name is filled in — it stays editable for a colleague or a host.
    _name = TextEditingController(text: widget.pass.visitorName ?? '');
    AdminLog.life('VisitorPassEmailDialog mounted');
  }

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    AdminLog.life('VisitorPassEmailDialog disposed');
    super.dispose();
  }

  Future<void> _submit() async {
    if (_sending) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _sending = true;
      _error = null;
      _fieldErrors = ServerFieldErrors.none;
    });

    try {
      final message = await widget.onSubmit(_email.text, _name.text);
      if (!mounted) return;
      Navigator.of(context).pop(message);
    } on ApiException catch (error) {
      if (!mounted) return;
      final parsed = ServerFieldErrors.from(error);
      setState(() {
        _sending = false;
        _error = parsed.summary ?? error.message;
        _fieldErrors = parsed;
      });
      _formKey.currentState?.validate();
      AdminLog.failure('Visitor-pass email rejected: ${error.message}');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Could not send this pass. Please try again.';
      });
      AdminLog.failure(
        'Visitor-pass email crashed',
        error: error,
        stackTrace: stackTrace,
      );
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
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
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
                        Icons.mail_outline_rounded,
                        size: 20,
                        color: tokens.accent,
                      ),
                    ),
                    const SizedBox(width: AdminTokens.space3),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Send this pass by email',
                            style: TextStyle(
                              color: tokens.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                          Text(
                            widget.pass.passCode ?? widget.pass.displayName,
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
                if (_error != null) ...[
                  const SizedBox(height: AdminTokens.space4),
                  Container(
                    padding: const EdgeInsets.all(AdminTokens.space3),
                    decoration: BoxDecoration(
                      color: tokens.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
                      border: Border.all(
                        color: tokens.danger.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: tokens.danger,
                        ),
                        const SizedBox(width: AdminTokens.space3),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: tokens.danger,
                              fontSize: 12.5,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AdminTokens.space5),
                _Label('Recipient name'),
                const SizedBox(height: AdminTokens.space2),
                TextFormField(
                  controller: _name,
                  enabled: !_sending,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g. Mahesh Pawar',
                    prefixIcon: Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: tokens.textMuted,
                    ),
                  ),
                  validator: (value) {
                    final server = _fieldErrors.forKeys(const [
                      'recipientName',
                      'recipient_name',
                      'name',
                    ]);
                    if (server != null) return server;
                    return (value ?? '').trim().isEmpty
                        ? "Enter the recipient's name"
                        : null;
                  },
                ),
                const SizedBox(height: AdminTokens.space4),
                _Label('Email address'),
                const SizedBox(height: AdminTokens.space2),
                TextFormField(
                  controller: _email,
                  enabled: !_sending,
                  keyboardType: TextInputType.emailAddress,
                  autofocus: true,
                  onFieldSubmitted: (_) => _submit(),
                  style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'visitor@example.com',
                    prefixIcon: Icon(
                      Icons.alternate_email_rounded,
                      size: 18,
                      color: tokens.textMuted,
                    ),
                  ),
                  validator: (value) {
                    final server = _fieldErrors.forKeys(const [
                      'recipientEmail',
                      'recipient_email',
                      'email',
                    ]);
                    if (server != null) return server;
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return 'Email is required';
                    final valid = RegExp(
                      r'^[\w.+-]+@[\w-]+\.[\w.-]+$',
                    ).hasMatch(text);
                    return valid ? null : 'Enter a valid email';
                  },
                ),
                const SizedBox(height: AdminTokens.space6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _sending
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: tokens.textSecondary,
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: AdminTokens.space3),
                    FilledButton.icon(
                      onPressed: _sending ? null : _submit,
                      icon: _sending
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded, size: 17),
                      label: const Text('Send pass'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

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
