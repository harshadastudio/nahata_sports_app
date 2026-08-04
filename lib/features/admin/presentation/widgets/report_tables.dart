import 'package:flutter/material.dart';

import '../../domain/entities/report.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'membership_status_chip.dart' show StatusPill;

/// The shared chrome for the three report tables.
///
/// They are read-only lists — a report is a view of the past, so there are no
/// row actions and nothing here writes.
class ReportTableFrame extends StatefulWidget {
  const ReportTableFrame({
    super.key,
    required this.minWidth,
    required this.header,
    required this.rows,
  });

  final double minWidth;
  final Widget header;
  final List<Widget> rows;

  @override
  State<ReportTableFrame> createState() => _ReportTableFrameState();
}

class _ReportTableFrameState extends State<ReportTableFrame> {
  /// Owned here rather than left to the PrimaryScrollController: a visible
  /// Scrollbar asserts without one.
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final overflows = constraints.maxWidth < widget.minWidth;
        final width = overflows ? widget.minWidth : constraints.maxWidth;

        return Scrollbar(
          controller: _horizontal,
          thumbVisibility: overflows,
          child: SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [widget.header, ...widget.rows],
              ),
            ),
          ),
        );
      },
    );
  }
}

class ReportHeaderRow extends StatelessWidget {
  const ReportHeaderRow({super.key, required this.cells});

  /// Label and flex for each column.
  final List<(String, int)> cells;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.space5,
        vertical: AdminTokens.space3,
      ),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          for (final (label, flex) in cells)
            Expanded(
              flex: flex,
              child: Padding(
                padding: const EdgeInsets.only(right: AdminTokens.space3),
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ReportCell extends StatelessWidget {
  const ReportCell(
    this.value,
    this.flex, {
    super.key,
    this.weight = FontWeight.w400,
    this.secondary,
  });

  final String value;
  final int flex;
  final FontWeight weight;

  /// A quieter second line, for a contact under a name.
  final String? secondary;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final missing = value == AdminFormat.dash;

    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: AdminTokens.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: missing ? tokens.textMuted : tokens.textSecondary,
                fontSize: 12.5,
                fontWeight: weight,
              ),
            ),
            if ((secondary ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                secondary!,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A status word from a report, coloured by what it says.
///
/// These are read-only reports over several different status vocabularies
/// (booking, student, coach), so the word is matched loosely rather than parsed
/// into one enum that would be wrong for two of the three.
class ReportStatusChip extends StatelessWidget {
  const ReportStatusChip({super.key, required this.status, this.dense = true});

  final String? status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final raw = (status ?? '').trim();

    if (raw.isEmpty) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    final lower = raw.toLowerCase();
    final (Color colour, IconData icon) = switch (lower) {
      _ when lower.contains('cancel') => (
        tokens.danger,
        Icons.cancel_outlined,
      ),
      _ when lower.contains('fail') => (tokens.danger, Icons.error_outline_rounded),
      _ when lower.contains('refund') => (tokens.info, Icons.undo_rounded),
      _ when lower.contains('pending') => (
        tokens.warning,
        Icons.hourglass_empty_rounded,
      ),
      _ when lower.contains('expire') => (tokens.warning, Icons.event_busy_rounded),
      _ when lower.contains('inactive') => (
        tokens.textMuted,
        Icons.pause_circle_outline_rounded,
      ),
      _ when lower.contains('complete') => (tokens.info, Icons.task_alt_rounded),
      _ when lower.contains('paid') || lower.contains('confirm') => (
        tokens.success,
        Icons.check_circle_outline_rounded,
      ),
      _ when lower.contains('active') => (tokens.success, Icons.verified_rounded),
      _ => (tokens.textMuted, Icons.label_outline_rounded),
    };

    return StatusPill(
      label: raw,
      color: colour,
      icon: icon,
      dense: dense,
    );
  }
}

// -----------------------------------------------------------------------------
// Booking report
// -----------------------------------------------------------------------------

class BookingReportTable extends StatelessWidget {
  const BookingReportTable({super.key, required this.rows});

  final List<BookingReportRow> rows;

  @override
  Widget build(BuildContext context) {
    return ReportTableFrame(
      minWidth: 1240,
      header: const ReportHeaderRow(
        cells: [
          ('Booking ID', 14),
          ('User', 18),
          ('Sport', 12),
          ('Court', 12),
          ('Date', 12),
          ('Slot', 14),
          ('Amount', 10),
          ('Status', 12),
          ('Payment', 12),
        ],
      ),
      rows: [
        for (final row in rows) _BookingRow(key: ValueKey(row.id), row: row),
      ],
    );
  }
}

class _BookingRow extends StatelessWidget {
  const _BookingRow({super.key, required this.row});

  final BookingReportRow row;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.space5,
        vertical: AdminTokens.space3,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          ReportCell(row.displayReference, 14, weight: FontWeight.w600),
          ReportCell(
            row.displayUser,
            18,
            weight: FontWeight.w600,
            secondary: row.userContact,
          ),
          ReportCell(AdminFormat.text(row.sportName), 12),
          ReportCell(AdminFormat.text(row.courtName), 12),
          ReportCell(AdminFormat.date(row.date), 12),
          ReportCell(AdminFormat.text(row.slotLabel), 14),
          ReportCell(
            row.amount == null ? AdminFormat.dash : AdminFormat.currency(row.amount),
            10,
            weight: FontWeight.w700,
          ),
          Expanded(
            flex: 12,
            child: Padding(
              padding: const EdgeInsets.only(right: AdminTokens.space3),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ReportStatusChip(status: row.statusRaw),
              ),
            ),
          ),
          Expanded(
            flex: 12,
            child: Padding(
              padding: const EdgeInsets.only(right: AdminTokens.space3),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ReportStatusChip(status: row.paymentStatusRaw),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class BookingReportCard extends StatelessWidget {
  const BookingReportCard({super.key, required this.row});

  final BookingReportRow row;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.displayUser,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                row.amount == null
                    ? AdminFormat.dash
                    : AdminFormat.currency(row.amount),
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            [
              row.displayReference,
              if ((row.sportName ?? '').isNotEmpty) row.sportName!,
              if ((row.courtName ?? '').isNotEmpty) row.courtName!,
            ].join(' · '),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.textMuted, fontSize: 12),
          ),
          const SizedBox(height: AdminTokens.space3),
          Wrap(
            spacing: AdminTokens.space2,
            runSpacing: AdminTokens.space2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ReportStatusChip(status: row.statusRaw),
              ReportStatusChip(status: row.paymentStatusRaw),
              Text(
                '${AdminFormat.date(row.date)} · '
                '${AdminFormat.text(row.slotLabel)}',
                style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Student report
// -----------------------------------------------------------------------------

class StudentReportTable extends StatelessWidget {
  const StudentReportTable({super.key, required this.rows});

  final List<StudentReportRow> rows;

  @override
  Widget build(BuildContext context) {
    return ReportTableFrame(
      minWidth: 1180,
      header: const ReportHeaderRow(
        cells: [
          ('Student', 20),
          ('Sport', 13),
          ('Coach', 15),
          ('Batch', 15),
          ('Membership', 14),
          ('Joined', 12),
          ('Status', 12),
        ],
      ),
      rows: [
        for (final row in rows) _StudentRow(key: ValueKey(row.id), row: row),
      ],
    );
  }
}

class _StudentRow extends StatelessWidget {
  const _StudentRow({super.key, required this.row});

  final StudentReportRow row;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.space5,
        vertical: AdminTokens.space3,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          ReportCell(
            row.displayName,
            20,
            weight: FontWeight.w600,
            secondary: row.contact,
          ),
          ReportCell(AdminFormat.text(row.sportName), 13),
          ReportCell(AdminFormat.text(row.coachName), 15),
          ReportCell(AdminFormat.text(row.batchName), 15),
          ReportCell(AdminFormat.text(row.membership), 14),
          ReportCell(AdminFormat.date(row.joinedAt), 12),
          Expanded(
            flex: 12,
            child: Padding(
              padding: const EdgeInsets.only(right: AdminTokens.space3),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ReportStatusChip(status: row.statusRaw),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StudentReportCard extends StatelessWidget {
  const StudentReportCard({super.key, required this.row});

  final StudentReportRow row;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            row.displayName,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            [
              if ((row.sportName ?? '').isNotEmpty) row.sportName!,
              if ((row.batchName ?? '').isNotEmpty) row.batchName!,
              if ((row.coachName ?? '').isNotEmpty) 'Coach ${row.coachName}',
            ].join(' · '),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.textMuted, fontSize: 12),
          ),
          const SizedBox(height: AdminTokens.space3),
          Wrap(
            spacing: AdminTokens.space2,
            runSpacing: AdminTokens.space2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ReportStatusChip(status: row.statusRaw),
              Text(
                'Joined ${AdminFormat.date(row.joinedAt)}',
                style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Coach report
// -----------------------------------------------------------------------------

class CoachReportTable extends StatelessWidget {
  const CoachReportTable({super.key, required this.rows});

  final List<CoachReportRow> rows;

  @override
  Widget build(BuildContext context) {
    return ReportTableFrame(
      minWidth: 1080,
      header: const ReportHeaderRow(
        cells: [
          ('Coach', 22),
          ('Sport', 15),
          ('Complex', 17),
          ('Students', 12),
          ('Revenue', 14),
          ('Programs', 12),
          ('Status', 12),
        ],
      ),
      rows: [
        for (final row in rows) _CoachRow(key: ValueKey(row.id), row: row),
      ],
    );
  }
}

class _CoachRow extends StatelessWidget {
  const _CoachRow({super.key, required this.row});

  final CoachReportRow row;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.space5,
        vertical: AdminTokens.space3,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          ReportCell(row.displayName, 22, weight: FontWeight.w600),
          ReportCell(AdminFormat.text(row.sportName), 15),
          ReportCell(AdminFormat.text(row.complexName), 17),
          ReportCell(AdminFormat.number(row.studentCount), 12,
              weight: FontWeight.w600),
          ReportCell(
            row.revenue == null
                ? AdminFormat.dash
                : AdminFormat.currency(row.revenue),
            14,
            weight: FontWeight.w700,
          ),
          ReportCell(AdminFormat.number(row.programCount), 12),
          Expanded(
            flex: 12,
            child: Padding(
              padding: const EdgeInsets.only(right: AdminTokens.space3),
              child: Align(
                alignment: Alignment.centerLeft,
                child: ReportStatusChip(status: row.statusRaw),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CoachReportCard extends StatelessWidget {
  const CoachReportCard({super.key, required this.row});

  final CoachReportRow row;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  row.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                row.revenue == null
                    ? AdminFormat.dash
                    : AdminFormat.currency(row.revenue),
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            [
              if ((row.sportName ?? '').isNotEmpty) row.sportName!,
              if ((row.complexName ?? '').isNotEmpty) row.complexName!,
            ].join(' · '),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.textMuted, fontSize: 12),
          ),
          const SizedBox(height: AdminTokens.space3),
          Wrap(
            spacing: AdminTokens.space2,
            runSpacing: AdminTokens.space2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ReportStatusChip(status: row.statusRaw),
              Text(
                '${AdminFormat.number(row.studentCount)} students · '
                '${AdminFormat.number(row.programCount)} programs',
                style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
