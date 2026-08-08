import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/coach_log.dart';
import '../../domain/entities/coach_fee.dart';
import '../theme/coach_theme.dart';
import '../utils/coach_gate_pass.dart';

/// The fee record's details, the edit form behind them, and the gate pass.
///
/// This is the website's Fees Approval detail modal on a phone:
///
/// * **View** — student, batch, money, statuses, dates and notes.
/// * **Edit** — the same fields the web form writes through `PUT /fees/{id}`.
/// * **Gate pass** — shown only once an admin has approved the record, with
///   the QR the gate scans and the WhatsApp hand-off.
///
/// Returns `true` when an edit was saved, so the caller can say so.
Future<bool> showCoachFeeDetailSheet({
  required BuildContext context,
  required CoachFee fee,
  required Future<void> Function(CoachFeeEdit edit) onSave,
}) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CoachFeeDetailSheet(fee: fee, onSave: onSave),
  );
  return saved ?? false;
}

class _CoachFeeDetailSheet extends StatefulWidget {
  const _CoachFeeDetailSheet({required this.fee, required this.onSave});

  final CoachFee fee;
  final Future<void> Function(CoachFeeEdit edit) onSave;

  @override
  State<_CoachFeeDetailSheet> createState() => _CoachFeeDetailSheetState();
}

class _CoachFeeDetailSheetState extends State<_CoachFeeDetailSheet> {
  late final TextEditingController _name;
  late final TextEditingController _amount;
  late final TextEditingController _notes;

  late CoachPaymentStatus _status;
  DateTime? _enrolledOn;
  DateTime? _validTill;

  bool _editing = false;
  bool _saving = false;
  bool _sending = false;
  String? _error;

  CoachFee get _fee => widget.fee;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _fee.displayName);
    _amount = TextEditingController(
      text: _fee.amountPaid > 0 ? _fee.amountPaid.round().toString() : '',
    );
    _notes = TextEditingController(text: _fee.notes ?? '');
    _status = _fee.paymentStatus ?? CoachPaymentStatus.pending;
    _enrolledOn = _day(_fee.enrollmentDate);
    _validTill = _day(_fee.validTill);
  }

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Dates
  // ---------------------------------------------------------------------------

  static DateTime? _day(String? raw) {
    final text = (raw ?? '').trim();
    if (text.isEmpty) return null;
    return DateTime.tryParse(text);
  }

  static String _wire(DateTime value) => DateFormat('yyyy-MM-dd').format(value);

  static String _pretty(String? raw) {
    final parsed = _day(raw);
    if (parsed == null) return (raw ?? '').trim().isEmpty ? '—' : raw!.trim();
    return DateFormat('dd MMM yyyy').format(parsed);
  }

  Future<void> _pickDate({
    required DateTime? current,
    required DateTime? notBefore,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final now = DateTime.now();
    final first = notBefore ?? DateTime(now.year - 3);
    final initial = current == null || current.isBefore(first)
        ? (current ?? now).isBefore(first)
            ? first
            : (current ?? now)
        : current;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(now.year + 5),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: Theme.of(context).colorScheme.copyWith(
                primary: CoachTokens.brand,
              ),
        ),
        child: child!,
      ),
    );
    if (picked != null) onPicked(picked);
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Only what actually changed is sent — a blanket write would rename the
  /// student's user account on every save, which is what the web form does and
  /// is not worth copying.
  CoachFeeEdit _draft() {
    final name = _name.text.trim();
    final rawAmount = _amount.text.trim();
    final amount = rawAmount.isEmpty ? null : num.tryParse(rawAmount);
    final notes = _notes.text.trim();

    final enrolled = _enrolledOn == null ? null : _wire(_enrolledOn!);
    final validTill = _validTill == null ? '' : _wire(_validTill!);

    return CoachFeeEdit(
      studentName: name == _fee.displayName ? null : name,
      amountPaid: amount == null || amount == _fee.amountPaid ? null : amount,
      paymentStatus: _status == _fee.paymentStatus ? null : _status,
      enrollmentDate:
          enrolled == null || enrolled == (_fee.enrollmentDate ?? '').trim()
              ? null
              : enrolled,
      validTill: validTill == (_fee.validTill ?? '').trim() ? null : validTill,
      notes: notes == (_fee.notes ?? '').trim() ? null : notes,
    );
  }

  Future<void> _save() async {
    final rawAmount = _amount.text.trim();
    if (rawAmount.isNotEmpty && num.tryParse(rawAmount) == null) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }
    if (_name.text.trim().isEmpty) {
      setState(() => _error = "The student's name cannot be empty.");
      return;
    }

    final edit = _draft();
    if (edit.isEmpty) {
      setState(() => _error = 'Nothing has changed yet.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.onSave(edit);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      CoachLog.failure('Fee record edit failed', error: e);
      setState(() {
        _error = e is ApiException
            ? e.message
            : 'Could not save those changes. Please try again.';
        _saving = false;
      });
    }
  }

  Future<void> _sendGatePass() async {
    setState(() => _sending = true);
    final message = await CoachGatePass.sendToWhatsApp(_fee);
    if (!mounted) return;
    setState(() => _sending = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: message == CoachGatePass.opening
            ? CoachTokens.success
            : CoachTokens.danger,
      ),
    );
  }

  Future<void> _copyPassCode() async {
    await Clipboard.setData(ClipboardData(text: _fee.gatePassCode));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Pass code ${_fee.gatePassCode} copied.'),
        backgroundColor: CoachTokens.textDark,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

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
              _header(),
              const Divider(height: 1, color: CoachTokens.border),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(CoachTokens.space5),
                  children: _editing ? _editFields() : _viewFields(),
                ),
              ),
              _footer(insets),
            ],
          ),
        );
      },
    );
  }

  Widget _header() {
    final busy = _saving || _sending;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CoachTokens.space5,
        0,
        CoachTokens.space3,
        CoachTokens.space4,
      ),
      child: Row(
        children: [
          CoachAvatar(initial: _fee.initial, radius: 20),
          const SizedBox(width: CoachTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _editing ? 'Edit fee record' : _fee.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: CoachTokens.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Record #${_fee.id}',
                  style: const TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.4,
                    color: CoachTokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (!_editing)
            IconButton(
              tooltip: 'Edit',
              onPressed: busy
                  ? null
                  : () => setState(() {
                        _editing = true;
                        _error = null;
                      }),
              icon: const Icon(Icons.edit_outlined),
              color: CoachTokens.brand,
            ),
          IconButton(
            onPressed: busy ? null : () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded),
            color: CoachTokens.textMuted,
          ),
        ],
      ),
    );
  }

  // ── View ───────────────────────────────────────────────────────────────────

  List<Widget> _viewFields() {
    final approvalTone = _fee.isApproved
        ? CoachTokens.success
        : _fee.isRejected
            ? CoachTokens.danger
            : CoachTokens.warning;

    return [
      Wrap(
        spacing: CoachTokens.space2,
        runSpacing: CoachTokens.space2,
        children: [
          CoachStatusChip(
            label: _fee.paymentLabel,
            color: CoachTokens.statusColor(_fee.paymentLabel),
          ),
          CoachStatusChip(
            label: _fee.isApproved
                ? 'Approved'
                : _fee.isRejected
                    ? 'Rejected'
                    : 'Awaiting approval',
            color: approvalTone,
            icon: _fee.isApproved
                ? Icons.verified_rounded
                : Icons.hourglass_bottom_rounded,
          ),
          if (_fee.paymentMode != null)
            CoachStatusChip(
              label: _fee.paymentMode!.label,
              color: CoachTokens.textMuted,
            ),
        ],
      ),
      const SizedBox(height: CoachTokens.space5),
      _row('Student', _fee.displayName),
      _row('Phone', _fee.studentPhone),
      _row('Batch', _fee.batchName),
      _row('Sport', _fee.sportName ?? ''),
      const Divider(height: CoachTokens.space6, color: CoachTokens.border),
      _row(
        'Amount paid',
        '₹${_fee.amountPaid.round()}',
        valueColor: CoachTokens.success,
      ),
      _row(
        'Batch fee',
        _fee.batchFees == null ? '—' : '₹${_fee.batchFees!.round()}',
      ),
      if (_fee.outstanding != null && _fee.outstanding! > 0)
        _row(
          'Outstanding',
          '₹${_fee.outstanding!.round()}',
          valueColor: CoachTokens.danger,
        ),
      _row('Enrolled on', _pretty(_fee.enrollmentDate)),
      _row(
        'Valid till',
        (_fee.validTill ?? '').trim().isEmpty
            ? 'No expiry'
            : _pretty(_fee.validTill),
      ),
      if ((_fee.notes ?? '').trim().isNotEmpty) _row('Notes', _fee.notes!),
      if (_fee.paidButUnapproved) ...[
        const SizedBox(height: CoachTokens.space4),
        _notice(
          icon: Icons.lock_clock_rounded,
          tone: CoachTokens.warning,
          text: 'Collected in full, but the gate pass stays locked until an '
              'admin or employee approves this payment.',
        ),
      ],
      if (_fee.isApproved) ...[
        const SizedBox(height: CoachTokens.space5),
        _gatePassPreview(),
      ],
    ];
  }

  /// The gate pass — only ever drawn once an admin has approved the record,
  /// exactly as the website gates it. A pass shown any earlier would be turned
  /// away at the scanner.
  Widget _gatePassPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'GATE PASS',
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 0.8,
            fontWeight: FontWeight.w600,
            color: CoachTokens.textMuted,
          ),
        ),
        const SizedBox(height: CoachTokens.space3),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(CoachTokens.space4),
          decoration: BoxDecoration(
            color: CoachTokens.canvas,
            borderRadius: BorderRadius.circular(CoachTokens.radiusMd),
            border: Border.all(color: CoachTokens.border),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(CoachTokens.space3),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
                  border: Border.all(color: CoachTokens.border),
                ),
                child: QrImageView(
                  data: _fee.gatePassCode,
                  version: QrVersions.auto,
                  size: 160,
                  gapless: true,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Color(0xFF000000),
                  ),
                  dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: Color(0xFF000000),
                  ),
                ),
              ),
              const SizedBox(height: CoachTokens.space3),
              const Text(
                'Scan at the entrance for verification',
                style: TextStyle(fontSize: 12, color: CoachTokens.textBody),
              ),
              const SizedBox(height: CoachTokens.space2),
              InkWell(
                onTap: _copyPassCode,
                borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: CoachTokens.space2,
                    vertical: CoachTokens.space1,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _fee.gatePassCode,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontFamily: 'monospace',
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w600,
                          color: CoachTokens.textDark,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(
                        Icons.copy_rounded,
                        size: 14,
                        color: CoachTokens.textMuted,
                      ),
                    ],
                  ),
                ),
              ),
              const Divider(
                height: CoachTokens.space5,
                color: CoachTokens.border,
              ),
              _passLine('Approved on', _approvedOnLabel),
              _passLine(
                'Valid until',
                (_fee.validTill ?? '').trim().isEmpty
                    ? 'Further notice'
                    : _pretty(_fee.validTill),
              ),
              const SizedBox(height: CoachTokens.space3),
              Wrap(
                spacing: CoachTokens.space2,
                runSpacing: CoachTokens.space2,
                alignment: WrapAlignment.center,
                children: const [
                  CoachStatusChip(
                    label: 'Approved',
                    color: CoachTokens.success,
                    icon: Icons.verified_rounded,
                  ),
                  CoachStatusChip(
                    label: 'Gate pass issued',
                    color: CoachTokens.info,
                    icon: Icons.confirmation_number_outlined,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  String get _approvedOnLabel {
    final at = _fee.approvedAt;
    if (at == null) return '—';
    return DateFormat('dd MMM yyyy, HH:mm').format(at);
  }

  Widget _passLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CoachTokens.space2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: CoachTokens.textMuted),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: CoachTokens.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? valueColor}) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: CoachTokens.space3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 116,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: CoachTokens.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: valueColor ?? CoachTokens.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Edit ───────────────────────────────────────────────────────────────────

  List<Widget> _editFields() {
    return [
      _notice(
        icon: Icons.info_outline_rounded,
        tone: CoachTokens.warning,
        text: 'Saving an edit sends this record back for admin approval, the '
            "same as recording a payment does. The student's gate pass stays "
            'locked until it is signed off again.',
      ),
      const SizedBox(height: CoachTokens.space5),
      _label('Student name'),
      const SizedBox(height: CoachTokens.space2),
      TextField(
        controller: _name,
        enabled: !_saving,
        textCapitalization: TextCapitalization.words,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        decoration: _decoration('Student name', Icons.person_outline_rounded),
      ),
      const SizedBox(height: CoachTokens.space5),
      _label('Amount paid'),
      const SizedBox(height: CoachTokens.space2),
      TextField(
        controller: _amount,
        enabled: !_saving,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        decoration: _decoration('0', Icons.currency_rupee_rounded),
      ),
      const SizedBox(height: CoachTokens.space2),
      Text(
        // The batch's own fee is deliberately not editable here: it belongs to
        // the batch, so changing it would move every student's fee, not this
        // one's. The website shows the field but never sends it.
        _fee.batchFees == null
            ? 'This batch has no fee set.'
            : 'Batch fee ₹${_fee.batchFees!.round()} — edit it on the batch, '
                'not here.',
        style: const TextStyle(fontSize: 11.5, color: CoachTokens.textMuted),
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
            onSelected:
                _saving ? null : (_) => setState(() => _status = status),
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
      _label('Enrolled on'),
      const SizedBox(height: CoachTokens.space2),
      _dateField(
        value: _enrolledOn,
        hint: 'Pick a date',
        onTap: () => _pickDate(
          current: _enrolledOn,
          notBefore: null,
          onPicked: (picked) => setState(() {
            _enrolledOn = picked;
            // Validity can never start before the enrollment it belongs to.
            if (_validTill != null && _validTill!.isBefore(picked)) {
              _validTill = null;
            }
          }),
        ),
      ),
      const SizedBox(height: CoachTokens.space5),
      _label('Enrollment valid till'),
      const SizedBox(height: CoachTokens.space2),
      _dateField(
        value: _validTill,
        hint: 'No expiry',
        onClear: _validTill == null
            ? null
            : () => setState(() => _validTill = null),
        onTap: () => _pickDate(
          current: _validTill,
          notBefore: _enrolledOn,
          onPicked: (picked) => setState(() => _validTill = picked),
        ),
      ),
      const SizedBox(height: CoachTokens.space2),
      const Text(
        'The student sees this date on their own screen. Leave it empty for '
        'no expiry.',
        style: TextStyle(fontSize: 11.5, color: CoachTokens.textMuted),
      ),
      const SizedBox(height: CoachTokens.space5),
      _label('Notes'),
      const SizedBox(height: CoachTokens.space2),
      TextField(
        controller: _notes,
        enabled: !_saving,
        maxLines: 3,
        textCapitalization: TextCapitalization.sentences,
        style: const TextStyle(fontSize: 14.5),
        decoration: _decoration(
          'Receipt number, part payment terms…',
          Icons.notes_rounded,
        ),
      ),
    ];
  }

  Widget _dateField({
    required DateTime? value,
    required String hint,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    return InkWell(
      onTap: _saving ? null : onTap,
      borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: CoachTokens.space3,
          vertical: CoachTokens.space4,
        ),
        decoration: BoxDecoration(
          color: CoachTokens.canvas,
          borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
          border: Border.all(color: CoachTokens.border),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.event_outlined,
              size: 19,
              color: CoachTokens.textMuted,
            ),
            const SizedBox(width: CoachTokens.space3),
            Expanded(
              child: Text(
                value == null ? hint : DateFormat('dd MMM yyyy').format(value),
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: value == null ? FontWeight.w400 : FontWeight.w600,
                  color: value == null
                      ? CoachTokens.textMuted
                      : CoachTokens.textDark,
                ),
              ),
            ),
            if (onClear != null)
              InkWell(
                onTap: _saving ? null : onClear,
                child: const Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: CoachTokens.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── Shared chrome ──────────────────────────────────────────────────────────

  Widget _notice({
    required IconData icon,
    required Color tone,
    required String text,
  }) {
    return Container(
      padding: const EdgeInsets.all(CoachTokens.space4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(CoachTokens.radiusMd),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: tone),
          const SizedBox(width: CoachTokens.space3),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
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
          if (_editing) ..._editActions() else ..._viewActions(),
        ],
      ),
    );
  }

  List<Widget> _editActions() {
    return [
      Row(
        children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_outlined, size: 18),
              label: Text(_saving ? 'Saving…' : 'Save changes'),
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
          const SizedBox(width: CoachTokens.space3),
          Expanded(
            child: OutlinedButton(
              onPressed: _saving
                  ? null
                  : () => setState(() {
                        _editing = false;
                        _error = null;
                        // Back to what the record actually says, so a
                        // half-typed edit does not linger behind the view.
                        _name.text = _fee.displayName;
                        _amount.text = _fee.amountPaid > 0
                            ? _fee.amountPaid.round().toString()
                            : '';
                        _notes.text = _fee.notes ?? '';
                        _status =
                            _fee.paymentStatus ?? CoachPaymentStatus.pending;
                        _enrolledOn = _day(_fee.enrollmentDate);
                        _validTill = _day(_fee.validTill);
                      }),
              style: OutlinedButton.styleFrom(
                foregroundColor: CoachTokens.textBody,
                side: const BorderSide(color: CoachTokens.border),
                padding:
                    const EdgeInsets.symmetric(vertical: CoachTokens.space4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
                ),
              ),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    ];
  }

  List<Widget> _viewActions() {
    return [
      if (_fee.isApproved)
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _sending ? null : _sendGatePass,
            icon: _sending
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.chat_rounded, size: 18),
            label: Text(
              _sending ? 'Opening…' : 'Send gate pass on WhatsApp',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: CoachTokens.space4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
              ),
            ),
          ),
        ),
      if (_fee.isApproved) const SizedBox(height: CoachTokens.space3),
      SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed:
              _sending ? null : () => Navigator.of(context).pop(false),
          style: OutlinedButton.styleFrom(
            foregroundColor: CoachTokens.textBody,
            side: const BorderSide(color: CoachTokens.border),
            padding: const EdgeInsets.symmetric(vertical: CoachTokens.space4),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
            ),
          ),
          child: const Text('Close'),
        ),
      ),
    ];
  }
}
