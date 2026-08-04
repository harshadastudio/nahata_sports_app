import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/complex_admin.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import 'complex_picker_field.dart';

/// Add / Edit complex admin.
///
/// [admin] null means create (`POST /admin/complex-admins`), otherwise edit
/// (`PUT /admin/complex-admins/{id}`). On edit the password field becomes
/// optional and is only sent when something was actually typed into it.
class ComplexAdminFormDialog extends StatefulWidget {
  const ComplexAdminFormDialog({
    super.key,
    required this.onSubmit,
    required this.complexes,
    required this.complexesState,
    required this.onReloadComplexes,
    this.admin,
  });

  final ComplexAdmin? admin;
  final Future<void> Function(ComplexAdminDraft draft) onSubmit;
  final List<SportsComplex> complexes;
  final ViewState complexesState;
  final VoidCallback onReloadComplexes;

  bool get isEdit => admin != null;

  /// Resolves to true when a save succeeded.
  static Future<bool> show(
    BuildContext context, {
    ComplexAdmin? admin,
    required Future<void> Function(ComplexAdminDraft draft) onSubmit,
    required List<SportsComplex> complexes,
    required ViewState complexesState,
    required VoidCallback onReloadComplexes,
  }) async {
    AdminLog.ui(
      '${admin == null ? 'Add' : 'Edit'} complex-admin dialog opened'
      '${admin == null ? '' : ' for ${admin.id}'}',
    );

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => ComplexAdminFormDialog(
        admin: admin,
        onSubmit: onSubmit,
        complexes: complexes,
        complexesState: complexesState,
        onReloadComplexes: onReloadComplexes,
      ),
    );

    AdminLog.ui('Complex-admin dialog closed (saved: ${saved ?? false})');
    return saved ?? false;
  }

  @override
  State<ComplexAdminFormDialog> createState() => _ComplexAdminFormDialogState();
}

class _ComplexAdminFormDialogState extends State<ComplexAdminFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _password;
  late final TextEditingController _phone;

  SportsComplex? _complex;
  AdminUserStatus? _status;

  bool _obscurePassword = true;
  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    final admin = widget.admin;

    _name = TextEditingController(text: admin?.name ?? '');
    _email = TextEditingController(text: admin?.email ?? '');
    _password = TextEditingController();
    _phone = TextEditingController(text: admin?.phone ?? '');
    _status = admin?.status;
    _complex = _matchComplex(admin);

    AdminLog.life(
      'ComplexAdminFormDialog mounted '
      '(${widget.isEdit ? 'edit' : 'create'})',
    );
  }

  /// Preselects by id, falling back to the venue name when the row carried only
  /// a name.
  SportsComplex? _matchComplex(ComplexAdmin? admin) {
    if (admin == null) return null;

    final id = admin.sportComplexId;
    if (id != null) {
      for (final complex in widget.complexes) {
        if (complex.id == id) return complex;
      }
    }

    final name = (admin.sportComplexName ?? '').trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final complex in widget.complexes) {
      if (complex.name.trim().toLowerCase() == name) return complex;
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant ComplexAdminFormDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The venue list may land after the dialog opened; preselect once it does.
    if (_complex == null && widget.complexes.isNotEmpty) {
      final matched = _matchComplex(widget.admin);
      if (matched != null) setState(() => _complex = matched);
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _email, _password, _phone]) {
      controller.dispose();
    }
    AdminLog.life('ComplexAdminFormDialog disposed');
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      AdminLog.ui('Complex-admin form failed local validation');
      return;
    }

    final draft = ComplexAdminDraft(
      name: _name.text,
      // Email identifies the account, so it is only sent on create.
      email: widget.isEdit ? null : _email.text,
      // On edit an untouched password field means "leave it alone".
      password: _password.text.trim().isEmpty ? null : _password.text,
      phone: _phone.text,
      sportComplexId: _complex?.id,
      status: widget.isEdit ? _status : null,
    );

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = const {};
    });

    try {
      await widget.onSubmit(draft);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
        _fieldErrors = _readFieldErrors(error.errors);
      });
      _formKey.currentState?.validate();
      AdminLog.failure('Complex-admin save rejected: ${error.message}');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this complex admin. Please try again.';
      });
      AdminLog.failure(
        'Complex-admin save crashed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static Map<String, String> _readFieldErrors(Map<String, dynamic>? errors) {
    if (errors == null) return const {};
    final result = <String, String>{};
    errors.forEach((key, value) {
      if (value is List && value.isNotEmpty) {
        result[key] = value.first.toString();
      } else if (value != null) {
        result[key] = value.toString();
      }
    });
    return result;
  }

  String? _serverError(List<String> keys) {
    for (final key in keys) {
      final message = _fieldErrors[key];
      if (message != null) return message;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < AdminTokens.mobileMax;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? AdminTokens.space4 : AdminTokens.space8,
        vertical: AdminTokens.space6,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 580,
          maxHeight: size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(
              title: widget.isEdit ? 'Edit complex admin' : 'Add complex admin',
              subtitle: widget.isEdit
                  ? widget.admin!.displayName
                  : 'Create an admin scoped to one sports complex',
              icon: widget.isEdit
                  ? Icons.edit_outlined
                  : Icons.admin_panel_settings_rounded,
              onClose: _saving ? null : () => Navigator.of(context).pop(false),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AdminTokens.space5),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        _ErrorBanner(message: _error!),
                        const SizedBox(height: AdminTokens.space4),
                      ],
                      _Pair(
                        narrow: narrow,
                        first: _Field(
                          controller: _name,
                          label: 'Name',
                          hint: 'e.g. Priya Deshmukh',
                          icon: Icons.person_outline_rounded,
                          enabled: !_saving,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            final server = _serverError(['name']);
                            if (server != null) return server;
                            if ((value ?? '').trim().length < 2) {
                              return 'Enter the full name';
                            }
                            return null;
                          },
                        ),
                        second: _Field(
                          controller: _email,
                          label: 'Email',
                          hint: 'name@example.com',
                          icon: Icons.mail_outline_rounded,
                          enabled: !_saving && !widget.isEdit,
                          helper: widget.isEdit
                              ? 'Email cannot be changed here'
                              : null,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final server = _serverError(['email']);
                            if (server != null) return server;
                            if (widget.isEdit) return null;
                            final text = (value ?? '').trim();
                            if (text.isEmpty) return 'Email is required';
                            final valid = RegExp(
                              r'^[\w.+-]+@[\w-]+\.[\w.-]+$',
                            ).hasMatch(text);
                            return valid ? null : 'Enter a valid email';
                          },
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Pair(
                        narrow: narrow,
                        first: _Field(
                          controller: _phone,
                          label: 'Phone number',
                          hint: '10-digit mobile number',
                          icon: Icons.phone_outlined,
                          enabled: !_saving,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+\- ]'),
                            ),
                          ],
                          validator: (value) {
                            final server = _serverError([
                              'phone_number',
                              'phoneNumber',
                            ]);
                            if (server != null) return server;
                            final digits = (value ?? '').replaceAll(
                              RegExp(r'\D'),
                              '',
                            );
                            if (digits.isEmpty) return 'Phone is required';
                            if (digits.length < 10) {
                              return 'Enter at least 10 digits';
                            }
                            return null;
                          },
                        ),
                        second: _Field(
                          controller: _password,
                          label: widget.isEdit
                              ? 'New password (optional)'
                              : 'Password',
                          hint: widget.isEdit
                              ? 'Leave blank to keep the current one'
                              : 'At least 8 characters',
                          icon: Icons.lock_outline_rounded,
                          enabled: !_saving,
                          obscure: _obscurePassword,
                          onToggleObscure: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          validator: (value) {
                            final server = _serverError(['password']);
                            if (server != null) return server;
                            final text = value ?? '';
                            // Blank is valid on edit — it means "unchanged".
                            if (widget.isEdit && text.trim().isEmpty) {
                              return null;
                            }
                            if (text.isEmpty) return 'Password is required';
                            if (text.length < 8) {
                              return 'Use at least 8 characters';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      ComplexPickerField(
                        complexes: widget.complexes,
                        state: widget.complexesState,
                        onReload: widget.onReloadComplexes,
                        initialComplex: _complex,
                        enabled: !_saving,
                        serverError: _serverError(const [
                          'sportComplexId',
                          'sport_complex_id',
                        ]),
                        onChanged: (complex) =>
                            setState(() => _complex = complex),
                        validator: (complex) => complex == null
                            ? 'Pick the complex this admin manages'
                            : null,
                      ),
                      if (widget.isEdit) ...[
                        const SizedBox(height: AdminTokens.space4),
                        _StatusField(
                          value: _status,
                          enabled: !_saving,
                          error: _serverError(const ['status']),
                          onChanged: (status) {
                            AdminLog.ui(
                              'Complex-admin status → ${status?.slug ?? 'none'}',
                            );
                            setState(() => _status = status);
                          },
                        ),
                      ],
                      const SizedBox(height: AdminTokens.space4),
                      _Note(
                        text: widget.isEdit
                            ? 'Leaving the password blank keeps the existing '
                                  'one — it is only sent when you type a new one.'
                            : 'The admin signs in with this email and password '
                                  'and can only manage the complex you assign.',
                        color: tokens.info,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _Footer(
              saving: _saving,
              submitLabel: widget.isEdit
                  ? 'Save changes'
                  : 'Create complex admin',
              onCancel: _saving ? null : () => Navigator.of(context).pop(false),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Chrome
// -----------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onClose,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AdminTokens.space5,
        AdminTokens.space5,
        AdminTokens.space3,
        AdminTokens.space4,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
              color: tokens.accentSoft,
            ),
            child: Icon(icon, size: 20, color: tokens.accent),
          ),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 20),
            color: tokens.textMuted,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.saving,
    required this.submitLabel,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool saving;
  final String submitLabel;
  final VoidCallback? onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space5),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        border: Border(top: BorderSide(color: tokens.border)),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AdminTokens.radiusXl),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(onPressed: onCancel, child: const Text('Cancel')),
          const SizedBox(width: AdminTokens.space3),
          FilledButton(
            onPressed: saving ? null : onSubmit,
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(submitLabel),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

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
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.text, required this.color});

  final String text;
  final Color color;

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
          Icon(Icons.info_outline_rounded, size: 16, color: color),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: tokens.textMuted,
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

class _Pair extends StatelessWidget {
  const _Pair({
    required this.narrow,
    required this.first,
    required this.second,
  });

  final bool narrow;
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          first,
          const SizedBox(height: AdminTokens.space4),
          second,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: AdminTokens.space4),
        Expanded(child: second),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.helper,
    this.enabled = true,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.obscure = false,
    this.onToggleObscure,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final String? helper;
  final bool enabled;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            color: tokens.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AdminTokens.space2),
        TextFormField(
          controller: controller,
          enabled: enabled,
          obscureText: obscure,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          validator: validator,
          style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            helperStyle: TextStyle(color: tokens.textMuted, fontSize: 11),
            prefixIcon: Icon(icon, size: 18, color: tokens.textMuted),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 17,
                    ),
                    color: tokens.textMuted,
                    tooltip: obscure ? 'Show password' : 'Hide password',
                  ),
          ),
        ),
      ],
    );
  }
}

class _StatusField extends StatelessWidget {
  const _StatusField({
    required this.value,
    required this.onChanged,
    required this.enabled,
    this.error,
  });

  final AdminUserStatus? value;
  final ValueChanged<AdminUserStatus?> onChanged;
  final bool enabled;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Status',
          style: TextStyle(
            color: tokens.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: AdminTokens.space2),
        DropdownButtonFormField<AdminUserStatus>(
          initialValue: value,
          isExpanded: true,
          onChanged: enabled ? onChanged : null,
          validator: (_) => error,
          dropdownColor: tokens.surface,
          borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
          icon: Icon(
            Icons.expand_more_rounded,
            size: 18,
            color: tokens.textMuted,
          ),
          style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.toggle_on_outlined,
              size: 18,
              color: tokens.textMuted,
            ),
          ),
          items: AdminUserStatus.values
              .map(
                (status) => DropdownMenuItem<AdminUserStatus>(
                  value: status,
                  child: Text(
                    status.label,
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}
