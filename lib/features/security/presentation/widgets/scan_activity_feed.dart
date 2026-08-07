import 'package:flutter/material.dart';

import '../../../admin/presentation/theme/admin_theme.dart';
import '../../../admin/presentation/widgets/admin_states.dart';
import '../../domain/entities/gate_scan.dart';
import '../state/scan_journal.dart';
import 'gate_scan_result_sheet.dart';

/// Recent scan activity — every scan this gate made, successful or refused,
/// newest first.
///
/// Refusals are the reason this exists at all: no backend stores a scan that
/// was turned away, and "what was that code that just failed?" is the question
/// a guard asks most.
class ScanActivityFeed extends StatelessWidget {
  const ScanActivityFeed({
    super.key,
    required this.entries,
    this.loading = false,
    this.compact = false,
  });

  final List<ScanJournalEntry> entries;
  final bool loading;

  /// Phone layout: cards rather than columns.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Column(
        children: [
          ShimmerBox(height: 48),
          SizedBox(height: AdminTokens.space2),
          ShimmerBox(height: 48),
          SizedBox(height: AdminTokens.space2),
          ShimmerBox(height: 48),
        ],
      );
    }

    if (entries.isEmpty) {
      return const EmptyStateView(
        icon: Icons.qr_code_scanner_rounded,
        title: 'No scans yet',
        message:
            'Every pass scanned at this gate appears here — including the ones '
            'that were turned away.',
      );
    }

    if (compact) {
      return Column(
        children: [
          for (final entry in entries) ...[
            _Card(entry: entry),
            if (entry != entries.last)
              const SizedBox(height: AdminTokens.space2),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _HeaderRow(),
        for (final entry in entries) _Row(entry: entry),
      ],
    );
  }
}

const List<int> _flex = [10, 18, 22, 24, 16];
const List<String> _labels = ['Time', 'Gate', 'Pass', 'Person', 'Result'];

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.space3,
        vertical: AdminTokens.space3,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _labels.length; i++)
            Expanded(
              flex: _flex[i],
              child: Text(
                _labels[i],
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry});

  final ScanJournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final accent = GateScanResultSheet.severityColour(
      tokens,
      entry.outcome.severity,
    );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.space3,
        vertical: AdminTokens.space3,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: _flex[0],
            child: Text(
              entry.timeLabel,
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Expanded(flex: _flex[1], child: _GateChip(kind: entry.kind)),
          Expanded(
            flex: _flex[2],
            child: Text(
              entry.passCode.startsWith('member:')
                  ? 'Member scan'
                  : (entry.passCode.isEmpty ? '—' : entry.passCode),
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12,
                letterSpacing: 0.4,
              ),
            ),
          ),
          Expanded(
            flex: _flex[3],
            child: Text(
              entry.displayName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            flex: _flex[4],
            child: _Outcome(entry: entry, accent: accent),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.entry});

  final ScanJournalEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final accent = GateScanResultSheet.severityColour(
      tokens,
      entry.outcome.severity,
    );

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space3),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 38,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                  ),
                ),
                Text(
                  '${entry.kind.shortLabel} · ${entry.timeLabel}',
                  style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ),
          _Outcome(entry: entry, accent: accent),
        ],
      ),
    );
  }
}

class _GateChip extends StatelessWidget {
  const _GateChip({required this.kind});

  final GateScanKind kind;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
          border: Border.all(color: tokens.border),
        ),
        child: Text(
          kind.shortLabel,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tokens.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _Outcome extends StatelessWidget {
  const _Outcome({required this.entry, required this.accent});

  final ScanJournalEntry entry;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              GateScanResultSheet.severityIcon(entry.outcome),
              size: 13,
              color: accent,
            ),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                entry.outcome.label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}