import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/coach_log.dart';
import '../../domain/entities/coach_enrollment.dart';
import '../theme/coach_theme.dart';

/// Copy to Next Month — the editable preview and its commit.
///
/// Mirrors [showCoachPaymentSheet]'s draggable-sheet shape. Returns the commit
/// result once the coach confirms, or `null` if the sheet was dismissed.
Future<CoachRenewMonthResult?> showCoachRenewalSheet({
  required BuildContext context,
  required CoachRenewalPreview preview,
  required Future<CoachRenewMonthResult> Function(List<CoachRenewItem> items)
      onConfirm,
}) {
  return showModalBottomSheet<CoachRenewMonthResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CoachRenewalSheet(preview: preview, onConfirm: onConfirm),
  );
}

class _RenewalRowState {
  _RenewalRowState(CoachRenewalLine line)
      : selected = line.defaultSelected,
        collected = false,
        feeController = TextEditingController(
          text: line.suggestedFee > 0 ? line.suggestedFee.round().toString() : '',
        );

  bool selected;
  bool collected;
  final TextEditingController feeController;
}

class _CoachRenewalSheet extends StatefulWidget {
  const _CoachRenewalSheet({required this.preview, required this.onConfirm});

  final CoachRenewalPreview preview;
  final Future<CoachRenewMonthResult> Function(List<CoachRenewItem> items)
      onConfirm;

  @override
  State<_CoachRenewalSheet> createState() => _CoachRenewalSheetState();
}

class _CoachRenewalSheetState extends State<_CoachRenewalSheet> {
  final Map<int, _RenewalRowState> _rows = {};

  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final batch in widget.preview.batches) {
      for (final line in batch.students) {
        _rows[line.enrollmentId] = _RenewalRowState(line);
      }
    }
  }

  @override
  void dispose() {
    for (final row in _rows.values) {
      row.feeController.dispose();
    }
    super.dispose();
  }

  int get _selectedCount => _rows.values.where((r) => r.selected).length;

  void _setAllCollected(bool collected) {
    setState(() {
      for (final row in _rows.values) {
        if (row.selected) row.collected = collected;
      }
    });
  }

  Future<void> _submit() async {
    final items = <CoachRenewItem>[];

    for (final entry in _rows.entries) {
      final row = entry.value;
      if (!row.selected) continue;

      final feeText = row.feeController.text.trim();
      final fee = feeText.isEmpty ? null : num.tryParse(feeText);
      if (row.collected && (fee == null || fee <= 0)) {
        setState(() {
          _error = 'Enter a fee greater than zero for every collected row.';
        });
        return;
      }

      items.add(CoachRenewItem(
        enrollmentId: entry.key,
        collected: row.collected,
        fee: fee,
        validTill: widget.preview.defaultValidTill,
      ));
    }

    if (items.isEmpty) {
      setState(() => _error = 'Select at least one student to renew.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final result = await widget.onConfirm(items);
      if (!mounted) return;
      Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      CoachLog.failure('Renewal submit failed', error: e);
      setState(() {
        _error = e is ApiException
            ? e.message
            : 'Could not renew those students. Please try again.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;
    final preview = widget.preview;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.86,
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
              _header(preview),
              const Divider(height: 1, color: CoachTokens.border),
              Expanded(child: _body(scrollController, preview)),
              _footer(insets),
            ],
          ),
        );
      },
    );
  }

  Widget _header(CoachRenewalPreview preview) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CoachTokens.space5,
        0,
        CoachTokens.space3,
        CoachTokens.space4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Copy to Next Month',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: CoachTokens.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${preview.fromLabel} → ${preview.toLabel}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: CoachTokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed:
                _submitting ? null : () => Navigator.of(context).pop(null),
            icon: const Icon(Icons.close_rounded),
            color: CoachTokens.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _body(ScrollController scrollController, CoachRenewalPreview preview) {
    if (preview.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(CoachTokens.space6),
          child: Text(
            'No students are eligible to be carried into next month.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, color: CoachTokens.textMuted),
          ),
        ),
      );
    }

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.all(CoachTokens.space5),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '$_selectedCount of ${preview.candidates} selected',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: CoachTokens.textBody,
                ),
              ),
            ),
            TextButton(
              onPressed: _submitting ? null : () => _setAllCollected(true),
              child: const Text('Mark all collected'),
            ),
          ],
        ),
        const SizedBox(height: CoachTokens.space2),
        for (final batch in preview.batches) _batchSection(batch),
      ],
    );
  }

  Widget _batchSection(CoachRenewalBatchGroup batch) {
    return Padding(
      padding: const EdgeInsets.only(bottom: CoachTokens.space4),
      child: CoachCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(CoachTokens.space4),
              child: Text(
                batch.displayName,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: CoachTokens.textDark,
                ),
              ),
            ),
            const Divider(height: 1, color: CoachTokens.border),
            for (final line in batch.students) _lineRow(line),
          ],
        ),
      ),
    );
  }

  Widget _lineRow(CoachRenewalLine line) {
    final row = _rows[line.enrollmentId]!;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: CoachTokens.space4,
        vertical: CoachTokens.space3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: row.selected,
                onChanged: _submitting
                    ? null
                    : (value) => setState(() => row.selected = value ?? false),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      line.displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: CoachTokens.textDark,
                      ),
                    ),
                    if (line.note.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          line.note,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: CoachTokens.textMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (row.selected) ...[
            const SizedBox(height: CoachTokens.space2),
            Padding(
              padding: const EdgeInsets.only(left: 40),
              child: Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: row.feeController,
                      enabled: !_submitting,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                      ],
                      style: const TextStyle(fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        prefixText: '₹ ',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: CoachTokens.space2,
                          vertical: CoachTokens.space2,
                        ),
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(CoachTokens.radiusSm),
                          borderSide: const BorderSide(color: CoachTokens.border),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: CoachTokens.space3),
                  Expanded(
                    child: InkWell(
                      onTap: _submitting
                          ? null
                          : () => setState(() => row.collected = !row.collected),
                      child: Row(
                        children: [
                          Icon(
                            row.collected
                                ? Icons.check_box_rounded
                                : Icons.check_box_outline_blank_rounded,
                            size: 18,
                            color: row.collected
                                ? CoachTokens.success
                                : CoachTokens.textMuted,
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'Fee collected',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: CoachTokens.textBody,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
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
              onPressed:
                  (_submitting || widget.preview.isEmpty) ? null : _submit,
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
              label: Text(
                _submitting ? 'Saving…' : 'Confirm & Renew ($_selectedCount)',
              ),
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
