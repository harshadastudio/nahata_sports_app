import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/membership.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'admin_form_fields.dart';

/// `PATCH /memberships/{id}/cancel` — confirmation plus the required reason.
///
/// The route takes a `reason`, so this is not a plain yes/no: cancelling
/// without recording why leaves nobody able to answer the member's next call.
class CancelMembershipDialog extends StatefulWidget {
  const CancelMembershipDialog({
    super.key,
    required this.membership,
    required this.onSubmit,
  });

  final Membership membership;

  /// Throws on failure so this dialog can stay open and explain itself.
  final Future<void> Function(String reason) onSubmit;

  /// Resolves to true when the cancellation went through.
  static Future<bool> show(
    BuildContext context, {
    required Membership membership,
    required Future<void> Function(String reason) onSubmit,
  }) async {
    AdminLog.ui('Cancel membership dialog opened for ${membership.id}');

    final cancelled = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => CancelMembershipDialog(
        membership: membership,
        onSubmit: onSubmit,
      ),
    );

    return cancelled ?? false;
  }

  @override
  State<CancelMembershipDialog> createState() => _CancelMembershipDialogState();
}

class _CancelMembershipDialogState extends State<CancelMembershipDialog> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  /// Offered as a starting point; the field stays editable.
  static const List<String> _presets = [
    'Customer request',
    'Duplicate membership',
    'Payment failed',
    'Relocated',
    'Service issue',
  ];

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
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
      await widget.onSubmit(_reason.text.trim());
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not cancel this membership. Please try again.';
      });
      AdminLog.failure(
        'Membership cancel crashed',
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
          maxWidth: 520,
          maxHeight: size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminFormHeader(
              title: 'Cancel this membership?',
              subtitle:
                  '${widget.membership.displayUser} · '
                  '${widget.membership.displayPlan}',
              icon: Icons.cancel_outlined,
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
                        AdminFormErrorBanner(message: _error!),
                        const SizedBox(height: AdminTokens.space4),
                      ],
                      const AdminFormNote(
                        icon: Icons.info_outline_rounded,
                        text:
                            'Cancelling keeps the record and its history. To '
                            'remove it entirely, delete it instead.',
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminTextField(
                        controller: _reason,
                        label: 'Reason',
                        icon: Icons.notes_rounded,
                        hint: 'Why is this membership being cancelled?',
                        required: true,
                        enabled: !_saving,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'A reason is required.'
                            : null,
                      ),
                      const SizedBox(height: AdminTokens.space3),
                      Wrap(
                        spacing: AdminTokens.space2,
                        runSpacing: AdminTokens.space2,
                        children: [
                          for (final preset in _presets)
                            ActionChip(
                              label: Text(preset),
                              onPressed: _saving
                                  ? null
                                  : () {
                                      _reason.text = preset;
                                      _formKey.currentState?.validate();
                                    },
                              labelStyle: TextStyle(
                                color: tokens.textSecondary,
                                fontSize: 12,
                              ),
                              backgroundColor: tokens.surfaceAlt,
                              side: BorderSide(color: tokens.border),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AdminFormFooter(
              saving: _saving,
              submitLabel: 'Cancel membership',
              onCancel: () => Navigator.of(context).pop(false),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// `POST /memberships/{id}/renew` — validity and amount, seeded from the plan.
class RenewMembershipDialog extends StatefulWidget {
  const RenewMembershipDialog({
    super.key,
    required this.membership,
    required this.onSubmit,
  });

  final Membership membership;

  final Future<void> Function(int validityDays, num totalAmount) onSubmit;

  static Future<bool> show(
    BuildContext context, {
    required Membership membership,
    required Future<void> Function(int validityDays, num totalAmount) onSubmit,
  }) async {
    AdminLog.ui('Renew membership dialog opened for ${membership.id}');

    final renewed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => RenewMembershipDialog(
        membership: membership,
        onSubmit: onSubmit,
      ),
    );

    return renewed ?? false;
  }

  @override
  State<RenewMembershipDialog> createState() => _RenewMembershipDialogState();
}

class _RenewMembershipDialogState extends State<RenewMembershipDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _validity;
  late final TextEditingController _amount;

  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final row = widget.membership;

    // Seeded from the plan on record, which is what a renewal usually repeats.
    _validity = TextEditingController(
      text: row.validityDays == null ? '' : '${row.validityDays}',
    );
    final amount = row.totalAmount ?? row.price;
    _validity.addListener(_refresh);
    _amount = TextEditingController(
      text: amount == null
          ? ''
          : (amount == amount.roundToDouble()
                ? amount.round().toString()
                : amount.toString()),
    );
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _validity.removeListener(_refresh);
    _validity.dispose();
    _amount.dispose();
    super.dispose();
  }

  /// What the term becomes if this renewal goes through.
  ///
  /// Extends from the later of today and the current end date: renewing a plan
  /// that still has a month left should add to it, not throw that month away.
  DateTime? get _newEnd {
    final days = int.tryParse(_validity.text.trim());
    if (days == null || days < 1) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = widget.membership.endDate;
    final from = (current == null || current.isBefore(today)) ? today : current;
    return from.add(Duration(days: days));
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onSubmit(
        int.parse(_validity.text.trim()),
        num.parse(_amount.text.trim()),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
      });
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not renew this membership. Please try again.';
      });
      AdminLog.failure(
        'Membership renew crashed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < AdminTokens.mobileMax;
    final newEnd = _newEnd;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? AdminTokens.space4 : AdminTokens.space8,
        vertical: AdminTokens.space6,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 520,
          maxHeight: size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminFormHeader(
              title: 'Renew membership',
              subtitle:
                  '${widget.membership.displayUser} · '
                  '${widget.membership.displayPlan}',
              icon: Icons.autorenew_rounded,
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
                        AdminFormErrorBanner(message: _error!),
                        const SizedBox(height: AdminTokens.space4),
                      ],
                      AdminReadOnlyField(
                        label: 'Current end date',
                        value: AdminFormat.date(widget.membership.endDate),
                        icon: Icons.event_rounded,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminTextField(
                        controller: _validity,
                        label: 'Validity (days)',
                        icon: Icons.timelapse_rounded,
                        hint: 'e.g. 365',
                        required: true,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (value) {
                          final parsed = int.tryParse((value ?? '').trim());
                          if (parsed == null) return 'Enter the validity.';
                          if (parsed < 1) {
                            return 'Renew for at least one day.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminTextField(
                        controller: _amount,
                        label: 'Total amount',
                        icon: Icons.currency_rupee_rounded,
                        hint: 'What the member pays to renew',
                        required: true,
                        enabled: !_saving,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: (value) {
                          final parsed = num.tryParse((value ?? '').trim());
                          if (parsed == null) return 'Enter the amount.';
                          if (parsed < 0) {
                            return 'The amount cannot be negative.';
                          }
                          return null;
                        },
                      ),
                      if (newEnd != null) ...[
                        const SizedBox(height: AdminTokens.space4),
                        AdminFormNote(
                          icon: Icons.event_available_rounded,
                          // Said as an expectation, not a promise: the server
                          // computes the real end date.
                          text:
                              'If the server extends from the current end '
                              'date, the term should run to '
                              '${AdminFormat.date(newEnd)}.',
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            AdminFormFooter(
              saving: _saving,
              submitLabel: 'Renew',
              onCancel: () => Navigator.of(context).pop(false),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
