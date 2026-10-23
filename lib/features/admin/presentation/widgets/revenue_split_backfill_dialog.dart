import 'package:flutter/material.dart';

import '../../core/admin_log.dart';
import '../../domain/entities/revenue_split.dart';
import '../state/revenue_split_controller.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'admin_dialogs.dart';
import 'admin_form_fields.dart';
import 'admin_states.dart';
import 'glass_card.dart';

/// The historical backfill wizard: **coverage** (already loaded on the page)
/// → **dry-run** (this dialog, on open) → **apply** (behind a confirm) →
/// optional **rollback** once something has been applied.
///
/// Apply and rollback both demand `{confirm: true}` server-side; this dialog
/// adds its own [ConfirmDialog] step in front of each so nothing fires from a
/// stray tap.
class RevenueSplitBackfillDialog extends StatefulWidget {
  const RevenueSplitBackfillDialog({super.key, required this.controller});

  final RevenueSplitController controller;

  static Future<void> show(
    BuildContext context, {
    required RevenueSplitController controller,
  }) {
    AdminLog.ui('Backfill wizard opened');
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => RevenueSplitBackfillDialog(controller: controller),
    ).whenComplete(controller.clearBackfillPreview);
  }

  @override
  State<RevenueSplitBackfillDialog> createState() =>
      _RevenueSplitBackfillDialogState();
}

enum _Stage { preview, applied, rolledBack }

class _RevenueSplitBackfillDialogState
    extends State<RevenueSplitBackfillDialog> {
  _Stage _stage = _Stage.preview;
  bool _busy = false;
  String? _actionError;
  RevenueSplitBackfillResult? _applyResult;
  RevenueSplitRollbackResult? _rollbackResult;

  @override
  void initState() {
    super.initState();
    widget.controller.loadBackfillPreview();
  }

  Future<void> _apply() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Apply the backfill?',
      message:
          'This writes the historical fee ledger for every pending, matched '
          'enrolment. It is idempotent — running it again writes nothing new '
          '— and can be undone with Rollback right after.',
      confirmLabel: 'Apply backfill',
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _busy = true;
      _actionError = null;
    });

    try {
      final result = await widget.controller.applyBackfill();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stage = _Stage.applied;
        _applyResult = result;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _actionError = _messageOf(error);
      });
      AdminLog.failure('Backfill apply failed', error: error);
    }
  }

  Future<void> _rollback() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Roll back the backfill?',
      message:
          'Removes only the payment rows this backfill just wrote — money '
          'recorded through normal fee collection is never touched.',
      confirmLabel: 'Roll back',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _busy = true;
      _actionError = null;
    });

    try {
      final result = await widget.controller.rollbackBackfill();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _stage = _Stage.rolledBack;
        _rollbackResult = result;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _actionError = _messageOf(error);
      });
      AdminLog.failure('Backfill rollback failed', error: error);
    }
  }

  static String _messageOf(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.isEmpty ? 'That did not go through.' : text;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final size = MediaQuery.sizeOf(context);
    final controller = widget.controller;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: size.width < AdminTokens.mobileMax
                ? AdminTokens.space4
                : AdminTokens.space8,
            vertical: AdminTokens.space6,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 720,
              maxHeight: size.height * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AdminFormHeader(
                  title: 'Historical backfill',
                  subtitle: _subtitleFor(controller),
                  icon: Icons.history_rounded,
                  onClose: _busy ? null : () => Navigator.of(context).pop(),
                ),
                Flexible(child: _body(context, controller)),
                Container(
                  padding: const EdgeInsets.all(AdminTokens.space5),
                  decoration: BoxDecoration(
                    color: tokens.surfaceAlt,
                    border: Border(top: BorderSide(color: tokens.border)),
                  ),
                  child: _footer(context, controller),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _subtitleFor(RevenueSplitController controller) {
    switch (_stage) {
      case _Stage.preview:
        return 'Step 1 of 2 — preview, writes nothing';
      case _Stage.applied:
        return 'Applied';
      case _Stage.rolledBack:
        return 'Rolled back';
    }
  }

  Widget _body(BuildContext context, RevenueSplitController controller) {
    if (_stage == _Stage.applied) {
      final result = _applyResult;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AdminTokens.space5),
        child: _ResultBanner(
          icon: Icons.check_circle_rounded,
          tone: AdminTheme.of(context).success,
          message: result?.message ??
              'Backfilled ${result?.written ?? 0} payment(s).',
          detail:
              'Written ${result?.written ?? 0} · Skipped ${result?.skipped ?? 0} · '
              'Ledger total ${AdminFormat.currency(result?.ledgerTotal ?? 0)}',
        ),
      );
    }

    if (_stage == _Stage.rolledBack) {
      final result = _rollbackResult;
      return SingleChildScrollView(
        padding: const EdgeInsets.all(AdminTokens.space5),
        child: _ResultBanner(
          icon: Icons.undo_rounded,
          tone: AdminTheme.of(context).warning,
          message: result?.message ?? 'Rolled back ${result?.removed ?? 0} row(s).',
          detail: 'Removed ${result?.removed ?? 0} backfilled payment(s).',
        ),
      );
    }

    if (controller.previewState.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(AdminTokens.space6),
        child: TableShimmer(rows: 5, dense: true),
      );
    }

    if (controller.previewState.isFailed) {
      return Padding(
        padding: const EdgeInsets.all(AdminTokens.space5),
        child: ErrorStateView(
          message: controller.previewError ?? 'Could not load the preview.',
          onRetry: controller.loadBackfillPreview,
          compact: true,
        ),
      );
    }

    final preview = controller.preview;
    if (preview == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AdminTokens.space5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_actionError != null) ...[
            AdminFormErrorBanner(message: _actionError!),
            const SizedBox(height: AdminTokens.space4),
          ],
          if (!preview.canApply)
            _ResultBanner(
              icon: Icons.block_rounded,
              tone: AdminTheme.of(context).danger,
              message: preview.blockedReason ??
                  'The backfill cannot be applied right now.',
              detail: preview.coverage.gaps.isEmpty
                  ? null
                  : '${preview.coverage.gaps.length} batch(es) still have no '
                        'matching rule.',
            )
          else
            _ResultBanner(
              icon: Icons.check_circle_outline_rounded,
              tone: AdminTheme.of(context).success,
              message: 'Ready to apply — ${preview.wouldWrite} payment(s) '
                  'would be written.',
              detail: null,
            ),
          const SizedBox(height: AdminTokens.space4),
          _TotalsRow(totals: preview.totals),
          if (preview.rows.isNotEmpty) ...[
            const SizedBox(height: AdminTokens.space5),
            Text(
              'What would be written',
              style: TextStyle(
                color: AdminTheme.of(context).textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 13.5,
              ),
            ),
            const SizedBox(height: AdminTokens.space3),
            _RowsTable(rows: preview.rows),
          ],
        ],
      ),
    );
  }

  Widget _footer(BuildContext context, RevenueSplitController controller) {
    if (_stage == _Stage.applied) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_actionError != null)
            Expanded(
              child: Text(
                _actionError!,
                style: TextStyle(color: AdminTheme.of(context).danger, fontSize: 12),
              ),
            ),
          OutlinedButton.icon(
            onPressed: _busy ? null : _rollback,
            icon: const Icon(Icons.undo_rounded, size: 17),
            label: const Text('Roll back'),
          ),
          const SizedBox(width: AdminTokens.space3),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Done'),
          ),
        ],
      );
    }

    if (_stage == _Stage.rolledBack) {
      return Align(
        alignment: Alignment.centerRight,
        child: FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      );
    }

    final preview = controller.preview;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
        const SizedBox(width: AdminTokens.space3),
        FilledButton.icon(
          onPressed: _busy || preview == null || !preview.canApply
              ? null
              : _apply,
          icon: _busy
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.play_arrow_rounded, size: 18),
          label: const Text('Apply backfill'),
        ),
      ],
    );
  }
}

class _ResultBanner extends StatelessWidget {
  const _ResultBanner({
    required this.icon,
    required this.tone,
    required this.message,
    required this.detail,
  });

  final IconData icon;
  final Color tone;
  final String message;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    return Container(
      padding: const EdgeInsets.all(AdminTokens.space4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: tone.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: tone),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    detail!,
                    style: TextStyle(color: tokens.textSecondary, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({required this.totals});

  final RevenueSplitSummary totals;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    Widget stat(String label, String value) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(color: tokens.textMuted, fontSize: 11)),
        ],
      ),
    );

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      color: tokens.canvas,
      child: Wrap(
        runSpacing: AdminTokens.space3,
        children: [
          stat('Pending', '${totals.pending}'),
          stat('Received', AdminFormat.currency(totals.totalReceived)),
          stat('Coach total', AdminFormat.currency(totals.pendingCoachTotal)),
          stat('Nahata total', AdminFormat.currency(totals.pendingNahataTotal)),
          stat('Unmatched', '${totals.unmatched}'),
        ],
      ),
    );
  }
}

class _RowsTable extends StatelessWidget {
  const _RowsTable({required this.rows});

  final List<RevenueSplitBackfillRow> rows;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    // Capped — this is a preview, not the export; 200 rows is plenty to
    // confirm the shape of what would be written.
    final shown = rows.take(200).toList(growable: false);

    return SolidCard(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowHeight: 38,
          dataRowMinHeight: 40,
          dataRowMaxHeight: 48,
          columns: const [
            DataColumn(label: Text('Batch')),
            DataColumn(label: Text('Coach')),
            DataColumn(label: Text('Received')),
            DataColumn(label: Text('Split')),
            DataColumn(label: Text('Coach amt')),
            DataColumn(label: Text('Status')),
          ],
          rows: shown.map((row) {
            final flagged = row.needsSplitRule ||
                row.noCoachAssigned ||
                row.coachExceedsCash;
            return DataRow(
              cells: [
                DataCell(Text(row.displayName)),
                DataCell(Text(
                  row.coachName?.trim().isEmpty ?? true
                      ? '—'
                      : row.coachName!.trim(),
                )),
                DataCell(Text(AdminFormat.currency(row.amountReceived ?? 0))),
                DataCell(Text('${row.coachPercent}% / ${row.nahataPercent}%')),
                DataCell(Text(AdminFormat.currency(row.coachAmount))),
                DataCell(
                  Text(
                    flagged ? 'Flagged' : row.status,
                    style: TextStyle(
                      color: flagged ? tokens.warning : tokens.textSecondary,
                      fontWeight: flagged ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
