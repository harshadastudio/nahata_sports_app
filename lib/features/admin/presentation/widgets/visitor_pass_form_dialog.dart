import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/visitor_pass.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/server_field_errors.dart';
import 'complex_picker_field.dart';

/// Generate a visitor pass (`POST /visitor-passes`).
///
/// Resolves to the created pass so the page can show its QR straight away, or
/// to null when the desk cancelled.
class VisitorPassFormDialog extends StatefulWidget {
  const VisitorPassFormDialog({
    super.key,
    required this.onSubmit,
    required this.complexes,
    required this.complexesState,
    required this.onReloadComplexes,
    this.initialComplex,
  });

  final Future<VisitorPass> Function(VisitorPassDraft draft) onSubmit;
  final List<SportsComplex> complexes;
  final ViewState complexesState;
  final VoidCallback onReloadComplexes;

  /// Preselected venue — the desk usually issues passes for one complex all
  /// day, so the last one used is offered again.
  final SportsComplex? initialComplex;

  static Future<VisitorPass?> show(
    BuildContext context, {
    required Future<VisitorPass> Function(VisitorPassDraft draft) onSubmit,
    required List<SportsComplex> complexes,
    required ViewState complexesState,
    required VoidCallback onReloadComplexes,
    SportsComplex? initialComplex,
  }) async {
    AdminLog.ui('Generate visitor-pass dialog opened');

    final created = await showDialog<VisitorPass>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => VisitorPassFormDialog(
        onSubmit: onSubmit,
        complexes: complexes,
        complexesState: complexesState,
        onReloadComplexes: onReloadComplexes,
        initialComplex: initialComplex,
      ),
    );

    AdminLog.ui(
      'Generate visitor-pass dialog closed '
      '(created: ${created?.reference ?? 'none'})',
    );
    return created;
  }

  @override
  State<VisitorPassFormDialog> createState() => _VisitorPassFormDialogState();
}

class _VisitorPassFormDialogState extends State<VisitorPassFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _purpose;

  SportsComplex? _complex;

  bool _saving = false;
  String? _error;
  ServerFieldErrors _fieldErrors = ServerFieldErrors.none;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _phone = TextEditingController();
    _purpose = TextEditingController();
    _complex = widget.initialComplex;
    AdminLog.life('VisitorPassFormDialog mounted');
  }

  @override
  void didUpdateWidget(covariant VisitorPassFormDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The venue list may land after the dialog opened.
    if (_complex == null && widget.initialComplex != null) {
      setState(() => _complex = widget.initialComplex);
    }
  }

  @override
  void dispose() {
    for (final controller in [_name, _phone, _purpose]) {
      controller.dispose();
    }
    AdminLog.life('VisitorPassFormDialog disposed');
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      AdminLog.ui('Visitor-pass form failed local validation');
      return;
    }

    final draft = VisitorPassDraft(
      visitorName: _name.text,
      phoneNumber: _phone.text,
      visitPurpose: _purpose.text,
      sportComplexId: _complex?.id,
    );

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = ServerFieldErrors.none;
    });

    try {
      final created = await widget.onSubmit(draft);
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } on ApiException catch (error) {
      if (!mounted) return;
      final parsed = ServerFieldErrors.from(error);
      setState(() {
        _saving = false;
        _error = parsed.summary ?? error.message;
        _fieldErrors = parsed;
      });
      _formKey.currentState?.validate();
      AdminLog.failure('Visitor-pass create rejected: ${error.message}');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not generate this pass. Please try again.';
      });
      AdminLog.failure(
        'Visitor-pass create crashed',
        error: error,
        stackTrace: stackTrace,
      );
    }
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
          maxWidth: 560,
          maxHeight: size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(
              title: 'Generate visitor pass',
              subtitle: 'A QR pass valid for one entry and one exit',
              icon: Icons.badge_outlined,
              onClose: _saving ? null : () => Navigator.of(context).pop(),
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
                          label: 'Visitor name',
                          hint: 'e.g. Mahesh Pawar',
                          icon: Icons.person_outline_rounded,
                          enabled: !_saving,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            final server = _fieldErrors.forKeys(const [
                              'visitorName',
                              'visitor_name',
                              'name',
                            ]);
                            if (server != null) return server;
                            if ((value ?? '').trim().length < 2) {
                              return "Enter the visitor's name";
                            }
                            return null;
                          },
                        ),
                        second: _Field(
                          controller: _phone,
                          label: 'Phone number',
                          hint: '10-digit mobile number',
                          icon: Icons.phone_outlined,
                          enabled: !_saving,
                          keyboardType: TextInputType.phone,
                          // The endpoint takes exactly ten digits, so nothing
                          // else can be typed in the first place.
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(10),
                          ],
                          validator: (value) {
                            final server = _fieldErrors.forKeys(const [
                              'phoneNumber',
                              'phone_number',
                              'phone',
                            ]);
                            if (server != null) return server;
                            final digits = (value ?? '').trim();
                            if (digits.isEmpty) return 'Phone is required';
                            if (digits.length != 10) {
                              return 'Must be exactly 10 digits';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Field(
                        controller: _purpose,
                        label: 'Visit purpose',
                        hint: 'e.g. Meeting the manager',
                        icon: Icons.flag_outlined,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.sentences,
                        maxLines: 2,
                        validator: (value) {
                          final server = _fieldErrors.forKeys(const [
                            'visitPurpose',
                            'visit_purpose',
                            'purpose',
                          ]);
                          if (server != null) return server;
                          if ((value ?? '').trim().isEmpty) {
                            return 'Enter why the visitor is here';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      ComplexPickerField(
                        complexes: widget.complexes,
                        state: widget.complexesState,
                        onReload: widget.onReloadComplexes,
                        initialComplex: _complex,
                        enabled: !_saving,
                        serverError: _fieldErrors.forKeys(const [
                          'sportComplexId',
                          'sport_complex_id',
                        ]),
                        onChanged: (complex) =>
                            setState(() => _complex = complex),
                        validator: (complex) => complex == null
                            ? 'Pick the complex the visitor is coming to'
                            : null,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Note(
                        text:
                            'The pass starts as Pending. The first scan at the '
                            'gate records the entry, the second records the '
                            'exit, and after that the pass cannot be used '
                            'again.',
                        color: tokens.info,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _Footer(
              saving: _saving,
              submitLabel: 'Generate pass',
              onCancel: _saving ? null : () => Navigator.of(context).pop(),
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
    this.enabled = true,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final bool enabled;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final int maxLines;
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
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          maxLines: maxLines,
          validator: validator,
          style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: tokens.textMuted),
          ),
        ),
      ],
    );
  }
}
