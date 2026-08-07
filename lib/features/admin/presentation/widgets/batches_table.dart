import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/batch.dart';
import '../state/batches_controller.dart';
import '../navigation/admin_module.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'occupancy_ring.dart';

/// What a batch row can be asked to do.
enum BatchAction { view, edit, delete, setActive, setInactive }

/// The desktop/tablet table.
///
/// Same construction as the other console tables: a hand-built header/row pair
/// inside one horizontal scroll, so fourteen columns never squeeze into
/// unreadable slivers.
class BatchesTable extends StatefulWidget {
  const BatchesTable({
    super.key,
    required this.batches,
    required this.sort,
    required this.descending,
    required this.onSort,
    required this.onAction,
    required this.isBusy,
    this.selectedId,
  });

  final List<AdminBatch> batches;
  final BatchSort? sort;
  final bool descending;
  final ValueChanged<BatchSort> onSort;
  final void Function(BatchAction action, AdminBatch batch) onAction;

  /// True while that row has a status write in flight.
  final bool Function(int id) isBusy;

  final int? selectedId;

  /// Fourteen columns need real room; below this the table scrolls sideways.
  static const double _minWidth = 1960;

  @override
  State<BatchesTable> createState() => _BatchesTableState();
}

class _BatchesTableState extends State<BatchesTable> {
  /// Owned here rather than left to the PrimaryScrollController: a visible
  /// Scrollbar asserts without one, and the primary controller belongs to the
  /// vertical list this table sits inside.
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
        final overflows = constraints.maxWidth < BatchesTable._minWidth;
        final width = overflows ? BatchesTable._minWidth : constraints.maxWidth;

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
                children: [
                  _HeaderRow(
                    sort: widget.sort,
                    descending: widget.descending,
                    onSort: widget.onSort,
                  ),
                  ...widget.batches.map(
                    (batch) => _Row(
                      key: ValueKey<int>(batch.id),
                      batch: batch,
                      selected: batch.id == widget.selectedId,
                      busy: widget.isBusy(batch.id),
                      onAction: widget.onAction,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Column layout shared by the header and every row.
class _Columns {
  const _Columns._();

  /// Fixed rather than flexed: a thumbnail has one right size.
  static const double image = 60;

  static const int name = 18;
  static const int sport = 11;
  static const int coach = 12;
  static const int complex = 12;
  static const int schedule = 13;
  static const int days = 12;
  static const int dates = 13;
  static const int fees = 9;
  static const int seats = 12;
  static const int occupancy = 12;
  static const int status = 9;

  /// Wide enough for the View button plus the More menu at their real tap
  /// targets — a popup menu button will not shrink below 48.
  static const double actions = 100;
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.sort,
    required this.descending,
    required this.onSort,
  });

  final BatchSort? sort;
  final bool descending;
  final ValueChanged<BatchSort> onSort;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    Widget cell(String label, int flex, [BatchSort? column]) => _HeaderCell(
      label: label,
      flex: flex,
      column: column,
      sort: sort,
      descending: descending,
      onSort: onSort,
    );

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
          SizedBox(
            width: _Columns.image,
            child: Text(
              'Image',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          cell('Batch name', _Columns.name, BatchSort.name),
          cell('Sport', _Columns.sport, BatchSort.sport),
          cell('Coach', _Columns.coach, BatchSort.coach),
          cell('Sports complex', _Columns.complex, BatchSort.complex),
          cell('Schedule', _Columns.schedule),
          cell('Days', _Columns.days),
          cell('Start – End', _Columns.dates, BatchSort.startDate),
          cell('Fees', _Columns.fees, BatchSort.fees),
          cell('Seats', _Columns.seats, BatchSort.availableSeats),
          cell('Occupancy', _Columns.occupancy, BatchSort.occupancy),
          cell('Status', _Columns.status, BatchSort.status),
          const SizedBox(width: _Columns.actions),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatefulWidget {
  const _HeaderCell({
    required this.label,
    required this.flex,
    this.column,
    this.sort,
    this.descending = false,
    this.onSort,
  });

  final String label;
  final int flex;
  final BatchSort? column;
  final BatchSort? sort;
  final bool descending;
  final ValueChanged<BatchSort>? onSort;

  @override
  State<_HeaderCell> createState() => _HeaderCellState();
}

class _HeaderCellState extends State<_HeaderCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final sortable = widget.column != null && widget.onSort != null;
    final active = sortable && widget.sort == widget.column;

    final content = Row(
      children: [
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? tokens.accent : tokens.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (sortable)
          AnimatedOpacity(
            duration: AdminTokens.fast,
            opacity: active ? 1 : (_hovered ? 0.5 : 0),
            child: Icon(
              active && widget.descending
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 13,
              color: active ? tokens.accent : tokens.textMuted,
            ),
          ),
      ],
    );

    return Expanded(
      flex: widget.flex,
      child: Padding(
        padding: const EdgeInsets.only(right: AdminTokens.space3),
        child: sortable
            ? MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hovered = true),
                onExit: (_) => setState(() => _hovered = false),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => widget.onSort!(widget.column!),
                  child: content,
                ),
              )
            : content,
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({
    super.key,
    required this.batch,
    required this.selected,
    required this.busy,
    required this.onAction,
  });

  final AdminBatch batch;
  final bool selected;
  final bool busy;
  final void Function(BatchAction action, AdminBatch batch) onAction;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final batch = widget.batch;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onAction(BatchAction.view, batch),
        child: AnimatedContainer(
          duration: AdminTokens.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AdminTokens.space5,
            vertical: AdminTokens.space3,
          ),
          decoration: BoxDecoration(
            color: widget.selected
                ? tokens.accentSoft
                : (_hovered ? tokens.surfaceAlt : Colors.transparent),
            border: Border(bottom: BorderSide(color: tokens.border)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: _Columns.image,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: BatchThumb(batch: batch, size: 40),
                ),
              ),
              Expanded(
                flex: _Columns.name,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        batch.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if ((batch.ageGroup ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          'Ages ${batch.ageGroup!.trim()}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _TextCell(AdminFormat.text(batch.sportName), _Columns.sport),
              _TextCell(
                AdminFormat.text(batch.coachName),
                _Columns.coach,
                weight: FontWeight.w600,
              ),
              _TextCell(
                AdminFormat.text(batch.sportComplexName),
                _Columns.complex,
              ),
              _TextCell(batch.scheduleLabel, _Columns.schedule),
              Expanded(
                flex: _Columns.days,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: BatchDaysChip(batch: batch),
                  ),
                ),
              ),
              Expanded(
                flex: _Columns.dates,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AdminFormat.date(batch.startDate),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: batch.startDate == null
                              ? tokens.textMuted
                              : tokens.textSecondary,
                          fontSize: 12.5,
                        ),
                      ),
                      Text(
                        AdminFormat.date(batch.endDate),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ),
              _TextCell(
                AdminFormat.currency(batch.fees),
                _Columns.fees,
                weight: FontWeight.w600,
              ),
              Expanded(
                flex: _Columns.seats,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: BatchSeatsCell(batch: batch),
                  ),
                ),
              ),
              Expanded(
                flex: _Columns.occupancy,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OccupancyBar(
                      ratio: batch.occupancy,
                      label: OccupancyRing.describe(batch.occupancy),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: _Columns.status,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: widget.busy
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : BatchStatusBadge(batch: batch, dense: true),
                  ),
                ),
              ),
              SizedBox(
                width: _Columns.actions,
                child: BatchRowActions(
                  batch: batch,
                  onAction: widget.onAction,
                  visible: _hovered || widget.selected,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TextCell extends StatelessWidget {
  const _TextCell(this.value, this.flex, {this.weight = FontWeight.w400});

  final String value;
  final int flex;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: AdminTokens.space3),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: value == AdminFormat.dash
                  ? tokens.textMuted
                  : tokens.textSecondary,
              fontSize: 12.5,
              fontWeight: weight,
            ),
          ),
        ),
      ),
    );
  }
}

/// The batch photo, falling back to initials on a deterministic gradient — the
/// spec's "show a placeholder if the image is null", done the same way the rest
/// of the console does it.
class BatchThumb extends StatelessWidget {
  const BatchThumb({super.key, required this.batch, this.size = 40});

  final AdminBatch batch;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final gradient = tokens.avatarGradient('${batch.id}${batch.name ?? ''}');

    final fallback = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        batch.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    final url = batch.imageUrl;
    if (url == null) return fallback;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
      child: CachedNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, __) => fallback,
        // A broken URL silently becomes initials — never a broken-image glyph.
        errorWidget: (_, __, ___) => fallback,
      ),
    );
  }
}

/// The days the batch runs, abbreviated with the full list behind a tooltip.
class BatchDaysChip extends StatelessWidget {
  const BatchDaysChip({super.key, required this.batch});

  final AdminBatch batch;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final days = batch.days;

    if (days.isEmpty) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    // A schedule the day parser could not read is shown as written rather than
    // being squeezed into abbreviations it never said.
    final label = days.isCustom
        ? days.raw
        : days.days.map((day) => day.shortLabel).join(' · ');

    return Tooltip(
      message: days.raw,
      waitDuration: const Duration(milliseconds: 300),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AdminTokens.space2,
          vertical: 3,
        ),
        decoration: BoxDecoration(
          color: tokens.info.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
        ),
        child: Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tokens.info,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.1,
          ),
        ),
      ),
    );
  }
}

/// `12 / 20` plus the seats left, or an em dash when capacity is unknown.
class BatchSeatsCell extends StatelessWidget {
  const BatchSeatsCell({super.key, required this.batch});

  final AdminBatch batch;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final max = batch.maxStudents;
    final current = batch.currentStudents;
    final free = batch.availableSeats;

    if (max == null && current == null) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${AdminFormat.number(current)} / ${AdminFormat.number(max)}',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tokens.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          free == null
              ? 'Capacity not set'
              : (free == 0 ? 'Full' : '$free seat${free == 1 ? '' : 's'} left'),
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: free == 0 && max != null ? tokens.danger : tokens.textMuted,
            fontSize: 11,
            fontWeight: free == 0 && max != null
                ? FontWeight.w700
                : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class BatchStatusBadge extends StatelessWidget {
  const BatchStatusBadge({super.key, required this.batch, this.dense = false});

  final AdminBatch batch;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final color = tokens.statusColor(batch.status);
    final label = batch.statusLabel.isEmpty
        ? AdminFormat.dash
        : batch.statusLabel;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AdminTokens.space2 : AdminTokens.space3,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: AdminTokens.space2),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: dense ? 11 : 12,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// View / Edit / Delete, plus the status items behind "More".
class BatchRowActions extends StatelessWidget {
  const BatchRowActions({
    super.key,
    required this.batch,
    required this.onAction,
    required this.visible,
  });

  final AdminBatch batch;
  final void Function(BatchAction action, AdminBatch batch) onAction;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final isActive = batch.isActive;

    return AnimatedOpacity(
      // Always in the tree so the row height is stable and the menus stay
      // reachable where hover does not exist.
      duration: AdminTokens.fast,
      opacity: visible ? 1 : 0.35,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => onAction(BatchAction.view, batch),
            icon: const Icon(Icons.visibility_outlined, size: 17),
            tooltip: 'View details',
            color: tokens.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
          ),
          PopupMenuButton<BatchAction>(
            tooltip: 'More actions',
            icon: Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: tokens.textMuted,
            ),
            padding: EdgeInsets.zero,
            onSelected: (action) => onAction(action, batch),
            itemBuilder: (context) => <PopupMenuEntry<BatchAction>>[
              _item(
                BatchAction.edit,
                Icons.edit_outlined,
                'Edit batch',
                tokens.textPrimary,
              ),
              const PopupMenuDivider(),
              // Only the status it is not already in is offered, so the menu
              // never presents a no-op.
              if (!isActive)
                _item(
                  BatchAction.setActive,
                  Icons.check_circle_outline_rounded,
                  'Mark as Active',
                  tokens.success,
                ),
              if (isActive)
                _item(
                  BatchAction.setInactive,
                  Icons.pause_circle_outline_rounded,
                  'Mark as Inactive',
                  tokens.warning,
                ),
              const PopupMenuDivider(),
              _item(
                BatchAction.delete,
                Icons.delete_outline_rounded,
                'Delete batch',
                tokens.danger,
              ),
            ]
              .gatedBy(
                AdminModules.batches,
                isDestructive: (a) => a == BatchAction.delete,
                isReadOnly: (a) => a == BatchAction.view,
              ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<BatchAction> _item(
    BatchAction value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem<BatchAction>(
      value: value,
      height: 40,
      child: Row(
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: AdminTokens.space3),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

/// The mobile equivalent of a table row.
class BatchCard extends StatelessWidget {
  const BatchCard({
    super.key,
    required this.batch,
    required this.busy,
    required this.onAction,
  });

  final AdminBatch batch;
  final bool busy;
  final void Function(BatchAction action, AdminBatch batch) onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return InkWell(
      onTap: () => onAction(BatchAction.view, batch),
      child: Container(
        padding: const EdgeInsets.all(AdminTokens.space4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tokens.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                BatchThumb(batch: batch, size: 48),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        batch.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          AdminFormat.text(batch.sportName),
                          AdminFormat.text(batch.coachName),
                        ].where((part) => part != AdminFormat.dash).join(' · '),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                OccupancyRing(ratio: batch.occupancy, size: 44),
                BatchRowActions(
                  batch: batch,
                  onAction: onAction,
                  visible: true,
                ),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Wrap(
              spacing: AdminTokens.space2,
              runSpacing: AdminTokens.space2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (busy)
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  BatchStatusBadge(batch: batch, dense: true),
                BatchDaysChip(batch: batch),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Schedule',
                    value: batch.scheduleLabel,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Fees',
                    value: AdminFormat.currency(batch.fees),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Students',
                    value:
                        '${AdminFormat.number(batch.currentStudents)} / '
                        '${AdminFormat.number(batch.maxStudents)}',
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Seats left',
                    value: AdminFormat.number(batch.availableSeats),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Starts',
                    value: AdminFormat.date(batch.startDate),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
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
        const SizedBox(height: 2),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tokens.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
