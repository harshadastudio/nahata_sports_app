import 'package:flutter/material.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/revenue_split.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import 'admin_form_fields.dart';

/// **CHECK A BATCH** — "which rule actually applies here?". Runs the same
/// resolver the write path uses, so the preview cannot drift from what the
/// money will really do.
class RevenueSplitCheckDialog extends StatefulWidget {
  const RevenueSplitCheckDialog({
    super.key,
    required this.options,
    required this.optionsState,
    required this.onReloadOptions,
    required this.onCheck,
  });

  final RevenueSplitOptions options;
  final ViewState optionsState;
  final VoidCallback onReloadOptions;

  final Future<RevenueSplitResolution> Function({
    int? batchId,
    int? sportId,
    int? coachId,
    DateTime? paidOn,
  })
  onCheck;

  static Future<void> show(
    BuildContext context, {
    required RevenueSplitOptions options,
    required ViewState optionsState,
    required VoidCallback onReloadOptions,
    required Future<RevenueSplitResolution> Function({
      int? batchId,
      int? sportId,
      int? coachId,
      DateTime? paidOn,
    })
    onCheck,
  }) {
    AdminLog.ui('Check a batch dialog opened');
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => RevenueSplitCheckDialog(
        options: options,
        optionsState: optionsState,
        onReloadOptions: onReloadOptions,
        onCheck: onCheck,
      ),
    );
  }

  @override
  State<RevenueSplitCheckDialog> createState() =>
      _RevenueSplitCheckDialogState();
}

class _RevenueSplitCheckDialogState extends State<RevenueSplitCheckDialog> {
  RevenueSplitBatchOption? _batch;
  DateTime? _paidOn;

  bool _checking = false;
  String? _error;
  RevenueSplitResolution? _result;

  Future<void> _pickPaidOn() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _paidOn ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1),
      helpText: 'Check the rate as of',
    );
    if (picked == null || !mounted) return;
    setState(() => _paidOn = DateTime(picked.year, picked.month, picked.day));
  }

  Future<void> _check() async {
    final batch = _batch;
    if (batch == null) {
      setState(() => _error = 'Pick a batch to check.');
      return;
    }

    setState(() {
      _checking = true;
      _error = null;
      _result = null;
    });

    try {
      final result = await widget.onCheck(batchId: batch.id, paidOn: _paidOn);
      if (!mounted) return;
      setState(() {
        _checking = false;
        _result = result;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = 'Could not check this batch. Please try again.';
      });
      AdminLog.failure('Check a batch failed', error: error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final result = _result;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: size.width < AdminTokens.mobileMax
            ? AdminTokens.space4
            : AdminTokens.space8,
        vertical: AdminTokens.space6,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminFormHeader(
              title: 'Check a batch',
              subtitle: 'Which rule actually applies here?',
              icon: Icons.fact_check_outlined,
              onClose: () => Navigator.of(context).pop(),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AdminTokens.space5),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      AdminFormErrorBanner(message: _error!),
                      const SizedBox(height: AdminTokens.space4),
                    ],
                    AdminCatalogueDropdown<RevenueSplitBatchOption>(
                      label: 'Batch',
                      icon: Icons.groups_2_outlined,
                      options: widget.options.batches,
                      value: _batch,
                      labelOf: (batch) => batch.displayName,
                      idOf: (batch) => batch.id,
                      state: widget.optionsState,
                      onReload: widget.onReloadOptions,
                      enabled: !_checking,
                      required: true,
                      onChanged: (batch) =>
                          setState(() {
                            _batch = batch;
                            _result = null;
                          }),
                    ),
                    const SizedBox(height: AdminTokens.space4),
                    _PaidOnField(
                      value: _paidOn,
                      enabled: !_checking,
                      onTap: _pickPaidOn,
                      onClear: () => setState(() => _paidOn = null),
                    ),
                    const SizedBox(height: AdminTokens.space5),
                    FilledButton.icon(
                      onPressed: _checking ? null : _check,
                      icon: _checking
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.search_rounded, size: 18),
                      label: const Text('Check'),
                    ),
                    if (result != null) ...[
                      const SizedBox(height: AdminTokens.space5),
                      _ResolutionCard(result: result),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AdminTokens.space5),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaidOnField extends StatelessWidget {
  const _PaidOnField({
    required this.value,
    required this.enabled,
    required this.onTap,
    required this.onClear,
  });

  final DateTime? value;
  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const AdminFieldLabel('Check the rate as of'),
        const SizedBox(height: AdminTokens.space2),
        InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AdminTokens.space4,
              vertical: AdminTokens.space3 + 2,
            ),
            decoration: BoxDecoration(
              color: tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
              border: Border.all(color: tokens.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 17,
                  color: tokens.textMuted,
                ),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Text(
                    value == null
                        ? 'Today'
                        : '${value!.year}-${value!.month.toString().padLeft(2, '0')}'
                              '-${value!.day.toString().padLeft(2, '0')}',
                    style: TextStyle(color: tokens.textPrimary, fontSize: 13.5),
                  ),
                ),
                if (value != null)
                  IconButton(
                    onPressed: enabled ? onClear : null,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    color: tokens.textMuted,
                    tooltip: 'Back to today',
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          'Backdate this to see which rule a historical payment would have used.',
          style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
        ),
      ],
    );
  }
}

class _ResolutionCard extends StatelessWidget {
  const _ResolutionCard({required this.result});

  final RevenueSplitResolution result;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final matched = result.matched;

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space4),
      decoration: BoxDecoration(
        color: (matched ? tokens.success : tokens.warning).withValues(
          alpha: 0.1,
        ),
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(
          color: (matched ? tokens.success : tokens.warning).withValues(
            alpha: 0.35,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                matched ? Icons.check_circle_rounded : Icons.warning_rounded,
                size: 18,
                color: matched ? tokens.success : tokens.warning,
              ),
              const SizedBox(width: AdminTokens.space2),
              Expanded(
                child: Text(
                  matched
                      ? 'Rule #${result.rule?.id ?? '—'} · ${result.rule?.scopeLabel ?? '—'}'
                      : 'No rule matches — this payment would need a split rule',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          Text(
            '${result.coachPercent}% coach / ${result.nahataPercent}% Nahata',
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (!matched) ...[
            const SizedBox(height: AdminTokens.space2),
            Text(
              'The honest answer, never a guess — this payment would be '
              'recorded 100% Nahata and flagged for review until a rule is '
              'added.',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
