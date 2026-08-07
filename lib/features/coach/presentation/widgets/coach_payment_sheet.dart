import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/coach_log.dart';
import '../../domain/entities/coach_fee.dart';
import '../theme/coach_theme.dart';

/// Record a fee payment.
///
/// Carries an explicit warning that collecting is not approving: the backend
/// resets `approvalStatus` to `Pending` on every coach payment, so the
/// student's gate pass stays locked until an admin signs off. A coach who does
/// not know that will think the QR is broken.
///
/// Returns `true` once a payment is recorded.
Future<bool> showCoachPaymentSheet({
  required BuildContext context,
  required CoachFee fee,
  required Future<void> Function(CoachPaymentDraft draft) onSubmit,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CoachPaymentSheet(fee: fee, onSubmit: onSubmit),
  );
  return result ?? false;
}

class _CoachPaymentSheet extends StatefulWidget {
  const _CoachPaymentSheet({required this.fee, required this.onSubmit});

  final CoachFee fee;
  final Future<void> Function(CoachPaymentDraft draft) onSubmit;

  @override
  State<_CoachPaymentSheet> createState() => _CoachPaymentSheetState();
}

class _CoachPaymentSheetState extends State<_CoachPaymentSheet> {
  late final TextEditingController _amount;
  late final TextEditingController _notes;

  late CoachPaymentStatus _status;
  CoachPaymentMode? _mode;

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    final fee = widget.fee;

    // Pre-filled with the full batch fee when nothing has been collected yet —
    // the overwhelmingly common case is a student paying in full.
    final suggested = fee.amountPaid > 0
        ? fee.amountPaid
        : (fee.batchFees ?? 0);
    _amount = TextEditingController(
      text: suggested > 0 ? suggested.round().toString() : '',
    );
    _notes = TextEditingController(text: fee.notes ?? '');
    _status = fee.paymentStatus ?? CoachPaymentStatus.paid;
    _mode = fee.paymentMode;
  }

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final raw = _amount.text.trim();
    final amount = raw.isEmpty ? null : num.tryParse(raw);

    if (raw.isNotEmpty && amount == null) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.onSubmit(
        CoachPaymentDraft(
          paymentStatus: _status,
          amountPaid: amount,
          paymentMode: _mode,
          notes: _notes.text,
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      CoachLog.failure('Payment submit failed', error: e);
      setState(() {
        _error = e is ApiException
            ? e.message
            : 'Could not record that payment. Please try again.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    final fee = widget.fee;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
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
              Container(
                width: 44,
                height: 4,
                margin:
                    const EdgeInsets.symmetric(vertical: CoachTokens.space3),
                decoration: BoxDecoration(
                  color: CoachTokens.border,
                  borderRadius: BorderRadius.circular(CoachTokens.radiusPill),
                ),
              ),
              _header(fee),
              const Divider(height: 1, color: CoachTokens.border),
              Expanded(child: _body(scrollController, fee)),
              _footer(insets),
            ],
          ),
        );
      },
    );
  }

  Widget _header(CoachFee fee) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CoachTokens.space5,
        0,
        CoachTokens.space3,
        CoachTokens.space4,
      ),
      child: Row(
        children: [
          CoachAvatar(initial: fee.initial, radius: 20),
          const SizedBox(width: CoachTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fee.displayName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: CoachTokens.textDark,
                  ),
                ),
                if (fee.contextLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    fee.contextLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: CoachTokens.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed:
                _submitting ? null : () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded),
            color: CoachTokens.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _body(ScrollController scrollController, CoachFee fee) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(CoachTokens.space5),
      children: [
        _approvalNotice(),
        const SizedBox(height: CoachTokens.space5),
        if (fee.batchFees != null) ...[
          Container(
            padding: const EdgeInsets.all(CoachTokens.space4),
            decoration: BoxDecoration(
              color: CoachTokens.canvas,
              borderRadius: BorderRadius.circular(CoachTokens.radiusMd),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _figure('Batch fee', '₹${fee.batchFees!.round()}'),
                ),
                Expanded(
                  child: _figure(
                    'Collected so far',
                    '₹${fee.amountPaid.round()}',
                  ),
                ),
                if (fee.outstanding != null)
                  Expanded(
                    child: _figure(
                      'Outstanding',
                      '₹${fee.outstanding!.round()}',
                      tone: fee.outstanding! > 0
                          ? CoachTokens.danger
                          : CoachTokens.success,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: CoachTokens.space5),
        ],
        _label('Amount collected'),
        const SizedBox(height: CoachTokens.space2),
        TextField(
          controller: _amount,
          enabled: !_submitting,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
          ],
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          decoration: _decoration('0', Icons.currency_rupee_rounded),
        ),
        const SizedBox(height: CoachTokens.space5),
        _label('Payment status'),
        const SizedBox(height: CoachTokens.space2),
        Wrap(
          spacing: CoachTokens.space2,
          runSpacing: CoachTokens.space2,
          children: CoachPaymentStatus.settable.map((status) {
            final selected = _status == status;
            final tone = CoachTokens.statusColor(status.slug);
            return ChoiceChip(
              label: Text(status.label),
              selected: selected,
              showCheckmark: false,
              onSelected: _submitting
                  ? null
                  : (_) => setState(() => _status = status),
              labelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? tone : CoachTokens.textBody,
              ),
              backgroundColor: CoachTokens.canvas,
              selectedColor: tone.withValues(alpha: 0.14),
              side: BorderSide(color: selected ? tone : CoachTokens.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CoachTokens.radiusPill),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: CoachTokens.space5),
        _label('Payment mode'),
        const SizedBox(height: CoachTokens.space2),
        Wrap(
          spacing: CoachTokens.space2,
          runSpacing: CoachTokens.space2,
          children: CoachPaymentMode.values.map((mode) {
            final selected = _mode == mode;
            return ChoiceChip(
              label: Text(mode.label),
              selected: selected,
              showCheckmark: false,
              // Tapping the selected mode clears it — the field is optional.
              onSelected: _submitting
                  ? null
                  : (_) => setState(() => _mode = selected ? null : mode),
              labelStyle: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: selected ? CoachTokens.brand : CoachTokens.textBody,
              ),
              backgroundColor: CoachTokens.canvas,
              selectedColor: CoachTokens.brandSoft,
              side: BorderSide(
                color: selected ? CoachTokens.brand : CoachTokens.border,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CoachTokens.radiusPill),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: CoachTokens.space5),
        _label('Notes'),
        const SizedBox(height: CoachTokens.space2),
        TextField(
          controller: _notes,
          enabled: !_submitting,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(fontSize: 14.5),
          decoration: _decoration(
            'Receipt number, part payment terms…',
            Icons.notes_rounded,
          ),
        ),
      ],
    );
  }

  /// The one thing a coach must understand before recording a payment.
  Widget _approvalNotice() {
    return Container(
      padding: const EdgeInsets.all(CoachTokens.space4),
      decoration: BoxDecoration(
        color: CoachTokens.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(CoachTokens.radiusMd),
        border: Border.all(
          color: CoachTokens.warning.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 19,
            color: CoachTokens.warning,
          ),
          const SizedBox(width: CoachTokens.space3),
          const Expanded(
            child: Text(
              'Recording a payment sends this record back for admin approval. '
              "The student's gate pass stays locked until an admin approves "
              'it.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: CoachTokens.textBody,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _figure(String label, String value, {Color? tone}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 10.5, color: CoachTokens.textMuted),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: tone ?? CoachTokens.textDark,
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
          color: CoachTokens.textMuted,
        ),
      );

  InputDecoration _decoration(String hint, IconData icon) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 14, color: CoachTokens.textMuted),
      prefixIcon: Icon(icon, size: 19, color: CoachTokens.textMuted),
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
    );
  }

  Widget _footer(double insets) {
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
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 19),
              label: Text(_submitting ? 'Saving…' : 'Record payment'),
              style: FilledButton.styleFrom(
                backgroundColor: CoachTokens.brand,
                padding:
                    const EdgeInsets.symmetric(vertical: CoachTokens.space4),
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
