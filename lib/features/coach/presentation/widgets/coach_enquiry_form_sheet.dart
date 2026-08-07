import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/coach_log.dart';
import '../../domain/entities/coach_enquiry.dart';
import '../../domain/entities/coach_option.dart';
import '../../domain/repositories/coach_dashboard_repository.dart';
import '../state/coach_overview_controller.dart';
import '../state/coach_view_state.dart';
import '../theme/coach_theme.dart';
import 'coach_states.dart';

/// The "Send Enquiry" sheet — a coach logging a coaching enquiry on a
/// prospect's behalf, which lands on the admin desk as `Pending`.
///
/// Returns `true` once one is filed, so the caller knows to refresh.
///
/// The batch is required and the picker only offers the coach's **Active**
/// batches, so a coach with none is told why they cannot file rather than
/// being shown an empty dropdown.
Future<bool> showCoachEnquiryFormSheet({
  required BuildContext context,
  required CoachDashboardRepository repository,
  required Future<void> Function(CoachEnquiryDraft) onSubmit,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CoachEnquiryFormSheet(
      repository: repository,
      onSubmit: onSubmit,
    ),
  );
  return result ?? false;
}

class _CoachEnquiryFormSheet extends StatefulWidget {
  const _CoachEnquiryFormSheet({
    required this.repository,
    required this.onSubmit,
  });

  final CoachDashboardRepository repository;
  final Future<void> Function(CoachEnquiryDraft) onSubmit;

  @override
  State<_CoachEnquiryFormSheet> createState() => _CoachEnquiryFormSheetState();
}

class _CoachEnquiryFormSheetState extends State<_CoachEnquiryFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _message = TextEditingController();

  late final CoachEnquiryFormController _options =
      CoachEnquiryFormController(widget.repository);

  CoachOption? _batch;
  CoachOption? _sport;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _options.addListener(_onOptions);
    _options.load();
  }

  void _onOptions() {
    if (!mounted) return;
    // With one batch there is nothing to pick — select it so the coach does
    // not have to open a dropdown with a single entry.
    if (_batch == null && _options.batches.length == 1) {
      _batch = _options.batches.first;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _options.removeListener(_onOptions);
    _options.dispose();
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_batch == null) {
      setState(() => _error = 'Pick a batch.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.onSubmit(
        CoachEnquiryDraft(
          name: _name.text,
          email: _email.text,
          phone: _phone.text,
          batchId: _batch!.id,
          sportId: _sport?.id,
          message: _message.text,
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      CoachLog.failure('Enquiry submit failed', error: e);
      setState(() {
        _error = e is ApiException
            ? e.message
            : 'Could not send the enquiry. Please try again.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: CoachTokens.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(CoachTokens.radiusLg + 4),
            ),
          ),
          child: Column(
            children: [
              _grabber(),
              _header(context),
              const Divider(height: 1, color: CoachTokens.border),
              Expanded(child: _body(scrollController)),
              _footer(insets),
            ],
          ),
        );
      },
    );
  }

  Widget _grabber() => Container(
        width: 44,
        height: 4,
        margin: const EdgeInsets.symmetric(vertical: CoachTokens.space3),
        decoration: BoxDecoration(
          color: CoachTokens.border,
          borderRadius: BorderRadius.circular(CoachTokens.radiusPill),
        ),
      );

  Widget _header(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(
          CoachTokens.space5,
          0,
          CoachTokens.space3,
          CoachTokens.space4,
        ),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Send Enquiry to Admin',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: CoachTokens.textDark,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Submit a new coaching enquiry',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: CoachTokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: _submitting ? null : () => Navigator.of(context).pop(false),
              icon: const Icon(Icons.close_rounded),
              color: CoachTokens.textMuted,
            ),
          ],
        ),
      );

  Widget _body(ScrollController scrollController) {
    if (_options.state.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(CoachTokens.space8),
          child: CircularProgressIndicator(color: CoachTokens.brand),
        ),
      );
    }

    if (_options.state.isFailed) {
      return CoachErrorView(
        message: _options.error ?? 'Could not load your batches.',
        onRetry: _options.load,
      );
    }

    // `batchId` is required by the backend, so with no Active batch there is
    // nothing valid to submit — said plainly rather than shown as an empty
    // dropdown that silently refuses.
    if (_options.batches.isEmpty) {
      return const CoachEmptyView(
        icon: Icons.groups_2_outlined,
        title: 'No active batches',
        message:
            'An enquiry has to be filed against one of your batches, and you '
            'have none active right now. Ask an admin to assign you a batch.',
      );
    }

    return Form(
      key: _formKey,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(CoachTokens.space5),
        children: [
          _field(
            controller: _name,
            label: 'Student name',
            hint: 'Enter full name',
            icon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
            validator: (v) =>
                (v ?? '').trim().isEmpty ? "Enter the student's name" : null,
          ),
          _field(
            controller: _phone,
            label: 'Phone',
            hint: '10-digit mobile number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            // Digits only, hard-capped at 10 — the same rule the website
            // enforces before it will submit.
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(10),
            ],
            validator: (v) {
              final digits = (v ?? '').replaceAll(RegExp(r'\D'), '');
              if (digits.isEmpty) return 'Enter a phone number';
              if (digits.length != 10) return 'Must be exactly 10 digits';
              return null;
            },
          ),
          _field(
            controller: _email,
            label: 'Email',
            hint: 'name@example.com',
            icon: Icons.mail_outline_rounded,
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              final text = (v ?? '').trim();
              if (text.isEmpty) return 'Enter an email address';
              if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(text)) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
          _picker(
            label: 'Batch',
            required: true,
            value: _batch,
            options: _options.batches,
            icon: Icons.groups_2_outlined,
            onChanged: (value) => setState(() => _batch = value),
          ),
          if (_options.sports.isNotEmpty)
            _picker(
              label: 'Sport',
              required: false,
              value: _sport,
              options: _options.sports,
              icon: Icons.sports_tennis_outlined,
              onChanged: (value) => setState(() => _sport = value),
            ),
          _field(
            controller: _message,
            label: 'Message',
            hint: 'Anything the admin should know',
            icon: Icons.notes_rounded,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
          ),
        ],
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    int maxLines = 1,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CoachTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label, required: validator != null),
          const SizedBox(height: CoachTokens.space2),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            validator: validator,
            maxLines: maxLines,
            enabled: !_submitting,
            textCapitalization: textCapitalization,
            style: const TextStyle(fontSize: 14.5),
            decoration: _decoration(hint, icon, alignIcon: maxLines == 1),
          ),
        ],
      ),
    );
  }

  Widget _picker({
    required String label,
    required bool required,
    required CoachOption? value,
    required List<CoachOption> options,
    required IconData icon,
    required ValueChanged<CoachOption?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CoachTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(label, required: required),
          const SizedBox(height: CoachTokens.space2),
          DropdownButtonFormField<CoachOption>(
            initialValue: value,
            isExpanded: true,
            style: const TextStyle(fontSize: 14.5, color: CoachTokens.textDark),
            decoration: _decoration('Select $label'.toLowerCase(), icon),
            items: [
              if (!required)
                const DropdownMenuItem<CoachOption>(
                  value: null,
                  child: Text('None'),
                ),
              ...options.map(
                (option) => DropdownMenuItem<CoachOption>(
                  value: option,
                  child: Text(
                    option.displayName,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: _submitting ? null : onChanged,
          ),
        ],
      ),
    );
  }

  Widget _label(String text, {required bool required}) => Text(
        required ? '$text *' : text,
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
          color: CoachTokens.textMuted,
        ),
      );

  InputDecoration _decoration(
    String hint,
    IconData icon, {
    bool alignIcon = true,
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontSize: 14,
        color: CoachTokens.textMuted,
      ),
      prefixIcon: Icon(icon, size: 19, color: CoachTokens.textMuted),
      prefixIconConstraints: alignIcon
          ? null
          : const BoxConstraints(minWidth: 46, minHeight: 46),
      filled: true,
      fillColor: CoachTokens.canvas,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: CoachTokens.space3,
        vertical: CoachTokens.space3 + 2,
      ),
      border: border(CoachTokens.border),
      enabledBorder: border(CoachTokens.border),
      focusedBorder: border(CoachTokens.brand, 1.4),
      errorBorder: border(CoachTokens.danger),
      focusedErrorBorder: border(CoachTokens.danger, 1.4),
    );
  }

  Widget _footer(double insets) {
    final canSubmit = _options.state.isReady && _options.batches.isNotEmpty;

    return Container(
      padding: EdgeInsets.fromLTRB(
        CoachTokens.space5,
        CoachTokens.space4,
        CoachTokens.space5,
        CoachTokens.space4 + insets,
      ),
      decoration: const BoxDecoration(
        color: CoachTokens.canvas,
        border: Border(top: BorderSide(color: CoachTokens.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 17,
                  color: CoachTokens.danger,
                ),
                const SizedBox(width: CoachTokens.space2),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: CoachTokens.danger,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: CoachTokens.space3),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: (_submitting || !canSubmit) ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 18),
              label: Text(_submitting ? 'Sending…' : 'Send enquiry'),
              style: FilledButton.styleFrom(
                backgroundColor: CoachTokens.brand,
                padding: const EdgeInsets.symmetric(
                  vertical: CoachTokens.space4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
