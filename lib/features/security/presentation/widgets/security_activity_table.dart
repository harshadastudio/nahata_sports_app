import 'package:flutter/material.dart';

import '../../../admin/domain/entities/visitor_pass.dart';
import '../../../admin/presentation/theme/admin_theme.dart';
import '../../../admin/presentation/utils/admin_format.dart';
import '../../../admin/presentation/widgets/visitor_pass_status_chip.dart';

/// What a row of the activity table can be asked to do.
enum SecurityRowAction { view, checkIn, checkOut }

/// Recent visitor activity.
///
/// Wide layouts get the nine documented columns inside one horizontal scroll —
/// the same construction as the console's other tables, so twelve columns never
/// squeeze into unreadable slivers. Narrow layouts get the same rows as cards,
/// because a nine-column table on a phone is not a table anybody can read.
class SecurityActivityTable extends StatelessWidget {
  const SecurityActivityTable({
    super.key,
    required this.rows,
    required this.onAction,
    this.compact = false,
  });

  final List<VisitorPass> rows;
  final void Function(SecurityRowAction action, VisitorPass pass) onAction;

  /// Phone layout: cards instead of columns.
  final bool compact;

  static const double _minWidth = 1180;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AdminTokens.space3),
        itemCount: rows.length,
        separatorBuilder: (_, __) => const SizedBox(height: AdminTokens.space3),
        itemBuilder: (context, index) =>
            _Card(pass: rows[index], onAction: onAction),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth < _minWidth
            ? _minWidth
            : constraints.maxWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                const _HeaderRow(),
                for (final pass in rows) _Row(pass: pass, onAction: onAction),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Column widths, shared by the header and every row so they stay aligned.
const List<int> _flex = [22, 13, 14, 13, 11, 10, 10, 12, 9];
const List<String> _labels = [
  'Visitor',
  'Phone',
  'Purpose',
  'Pass Code',
  'Status',
  'Entry Time',
  'Exit Time',
  'Security',
  'Action',
];

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.space4,
        vertical: AdminTokens.space3,
      ),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
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
                textAlign: i == _labels.length - 1
                    ? TextAlign.right
                    : TextAlign.left,
                style: TextStyle(
                  color: tokens.textMuted,
                  fontSize: 11.5,
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

class _Row extends StatefulWidget {
  const _Row({required this.pass, required this.onAction});

  final VisitorPass pass;
  final void Function(SecurityRowAction action, VisitorPass pass) onAction;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final pass = widget.pass;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onAction(SecurityRowAction.view, pass),
        child: AnimatedContainer(
          duration: AdminTokens.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AdminTokens.space4,
            vertical: AdminTokens.space3,
          ),
          decoration: BoxDecoration(
            color: _hovered ? tokens.surfaceAlt : Colors.transparent,
            border: Border(bottom: BorderSide(color: tokens.border)),
          ),
          child: Row(
            children: [
              Expanded(flex: _flex[0], child: _Visitor(pass: pass)),
              Expanded(flex: _flex[1], child: _Cell(pass.phoneNumber)),
              Expanded(flex: _flex[2], child: _Cell(pass.visitPurpose)),
              Expanded(flex: _flex[3], child: _Code(code: pass.passCode)),
              Expanded(
                flex: _flex[4],
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: VisitorPassStatusChip(pass: pass, dense: true),
                ),
              ),
              Expanded(flex: _flex[5], child: _Time(pass.entryTime)),
              Expanded(flex: _flex[6], child: _Time(pass.exitTime)),
              Expanded(flex: _flex[7], child: _Cell(pass.createdByName)),
              Expanded(
                flex: _flex[8],
                child: _RowActions(pass: pass, onAction: widget.onAction),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Visitor extends StatelessWidget {
  const _Visitor({required this.pass});

  final VisitorPass pass;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Row(
      children: [
        CircleAvatar(
          radius: 15,
          backgroundColor: tokens.accentSoft,
          child: Text(
            pass.initials,
            style: TextStyle(
              color: tokens.accent,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: AdminTokens.space3),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pass.displayName,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.25,
                ),
              ),
              if ((pass.sportComplexName ?? '').trim().isNotEmpty)
                Text(
                  pass.sportComplexName!.trim(),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell(this.value);

  final String? value;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final text = (value ?? '').trim();

    return Text(
      text.isEmpty ? AdminFormat.dash : text,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: text.isEmpty ? tokens.textMuted : tokens.textSecondary,
        fontSize: 12.5,
      ),
    );
  }
}

class _Code extends StatelessWidget {
  const _Code({required this.code});

  final String? code;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final text = (code ?? '').trim();
    if (text.isEmpty) return const _Cell(null);

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: tokens.surfaceAlt,
          borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
          border: Border.all(color: tokens.border),
        ),
        child: Text(
          text,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _Time extends StatelessWidget {
  const _Time(this.value);

  final DateTime? value;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final at = value;

    if (at == null) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _clock(at),
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            height: 1.25,
          ),
        ),
        Text(
          '${at.day}/${at.month}',
          style: TextStyle(color: tokens.textMuted, fontSize: 11),
        ),
      ],
    );
  }

  static String _clock(DateTime at) =>
      '${at.hour.toString().padLeft(2, '0')}:'
      '${at.minute.toString().padLeft(2, '0')}';
}

/// The row's own IN / OUT button — only ever the leg the pass is waiting for.
///
/// Pending → IN → OUT, and after OUT the pass is spent for good, so a
/// checked-out row offers nothing but View.
class _RowActions extends StatelessWidget {
  const _RowActions({required this.pass, required this.onAction});

  final VisitorPass pass;
  final void Function(SecurityRowAction action, VisitorPass pass) onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final next = pass.nextScan;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (next != null)
          TextButton.icon(
            onPressed: () => onAction(
              next == VisitorScanType.checkIn
                  ? SecurityRowAction.checkIn
                  : SecurityRowAction.checkOut,
              pass,
            ),
            icon: Icon(
              next == VisitorScanType.checkIn
                  ? Icons.login_rounded
                  : Icons.logout_rounded,
              size: 15,
            ),
            label: Text(next == VisitorScanType.checkIn ? 'In' : 'Out'),
            style: TextButton.styleFrom(
              foregroundColor: next == VisitorScanType.checkIn
                  ? tokens.success
                  : tokens.warning,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 32),
              textStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          IconButton(
            onPressed: () => onAction(SecurityRowAction.view, pass),
            icon: const Icon(Icons.visibility_outlined, size: 17),
            tooltip: 'View details',
            color: tokens.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          ),
      ],
    );
  }
}

/// The phone form of a row.
class _Card extends StatelessWidget {
  const _Card({required this.pass, required this.onAction});

  final VisitorPass pass;
  final void Function(SecurityRowAction action, VisitorPass pass) onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final next = pass.nextScan;

    return InkWell(
      onTap: () => onAction(SecurityRowAction.view, pass),
      borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
      child: Container(
        padding: const EdgeInsets.all(AdminTokens.space4),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
          border: Border.all(color: tokens.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _Visitor(pass: pass)),
                VisitorPassStatusChip(pass: pass, dense: true),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Wrap(
              spacing: AdminTokens.space4,
              runSpacing: AdminTokens.space2,
              children: [
                _Fact(label: 'Phone', value: pass.phoneNumber),
                _Fact(label: 'Purpose', value: pass.visitPurpose),
                _Fact(label: 'Code', value: pass.passCode),
                _Fact(label: 'In', value: _time(pass.entryTime)),
                _Fact(label: 'Out', value: _time(pass.exitTime)),
                _Fact(label: 'Security', value: pass.createdByName),
              ],
            ),
            if (next != null) ...[
              const SizedBox(height: AdminTokens.space3),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => onAction(
                    next == VisitorScanType.checkIn
                        ? SecurityRowAction.checkIn
                        : SecurityRowAction.checkOut,
                    pass,
                  ),
                  icon: Icon(
                    next == VisitorScanType.checkIn
                        ? Icons.login_rounded
                        : Icons.logout_rounded,
                    size: 17,
                  ),
                  label: Text(
                    next == VisitorScanType.checkIn ? 'Check in' : 'Check out',
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String? _time(DateTime? at) => at == null
      ? null
      : '${at.hour.toString().padLeft(2, '0')}:'
          '${at.minute.toString().padLeft(2, '0')}';
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final text = (value ?? '').trim();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: tokens.textMuted,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        Text(
          text.isEmpty ? AdminFormat.dash : text,
          style: TextStyle(
            color: tokens.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}