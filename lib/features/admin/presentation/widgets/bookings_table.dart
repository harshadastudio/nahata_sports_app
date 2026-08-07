import 'package:flutter/material.dart';

import '../../domain/entities/booking.dart';
import '../state/bookings_controller.dart';
import '../navigation/admin_module.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'booking_chips.dart';

/// What a booking row can be asked to do.
enum BookingAction {
  view,
  edit,
  delete,
  markConfirmed,
  markCompleted,
  markCancelled,
  markPaid,
}

/// The desktop/tablet table.
class BookingsTable extends StatefulWidget {
  const BookingsTable({
    super.key,
    required this.bookings,
    required this.sort,
    required this.descending,
    required this.onSort,
    required this.onAction,
    required this.isBusy,
    this.selectedId,
  });

  final List<Booking> bookings;
  final BookingSort? sort;
  final bool descending;
  final ValueChanged<BookingSort> onSort;
  final void Function(BookingAction action, Booking booking) onAction;
  final bool Function(int id) isBusy;
  final int? selectedId;

  /// Thirteen columns need real room; below this the table scrolls sideways.
  static const double _minWidth = 2060;

  @override
  State<BookingsTable> createState() => _BookingsTableState();
}

class _BookingsTableState extends State<BookingsTable> {
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
        final overflows = constraints.maxWidth < BookingsTable._minWidth;
        final width = overflows
            ? BookingsTable._minWidth
            : constraints.maxWidth;

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
                  ...widget.bookings.map(
                    (booking) => _Row(
                      key: ValueKey<int>(booking.id),
                      booking: booking,
                      selected: booking.id == widget.selectedId,
                      busy: widget.isBusy(booking.id),
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

class _Columns {
  const _Columns._();

  static const int reference = 13;
  static const int customer = 16;
  static const int phone = 11;
  static const int sport = 10;
  static const int court = 11;
  static const int complex = 12;
  static const int date = 11;
  static const int time = 14;
  static const int duration = 9;
  static const int source = 11;
  static const int amount = 10;
  static const int payment = 11;
  static const int status = 11;
  static const int created = 11;
  static const double actions = 100;
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.sort,
    required this.descending,
    required this.onSort,
  });

  final BookingSort? sort;
  final bool descending;
  final ValueChanged<BookingSort> onSort;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    Widget cell(String label, int flex, [BookingSort? column]) => _HeaderCell(
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
          cell('Booking ID', _Columns.reference, BookingSort.reference),
          cell('Customer', _Columns.customer, BookingSort.customer),
          cell('Phone', _Columns.phone),
          cell('Sport', _Columns.sport, BookingSort.sport),
          cell('Court', _Columns.court, BookingSort.court),
          cell('Sports complex', _Columns.complex, BookingSort.complex),
          cell('Date', _Columns.date, BookingSort.date),
          cell('Time', _Columns.time),
          cell('Duration', _Columns.duration),
          cell('Source', _Columns.source),
          cell('Amount', _Columns.amount, BookingSort.amount),
          cell('Payment', _Columns.payment, BookingSort.payment),
          cell('Status', _Columns.status, BookingSort.status),
          cell('Created', _Columns.created, BookingSort.created),
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
  final BookingSort? column;
  final BookingSort? sort;
  final bool descending;
  final ValueChanged<BookingSort>? onSort;

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
    required this.booking,
    required this.selected,
    required this.busy,
    required this.onAction,
  });

  final Booking booking;
  final bool selected;
  final bool busy;
  final void Function(BookingAction action, Booking booking) onAction;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final booking = widget.booking;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onAction(BookingAction.view, booking),
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
              Expanded(
                flex: _Columns.reference,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Text(
                    booking.displayReference,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: _Columns.customer,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Row(
                    children: [
                      CustomerAvatar(booking: booking, size: 30),
                      const SizedBox(width: AdminTokens.space2),
                      Expanded(
                        child: Text(
                          booking.displayCustomer,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _TextCell(AdminFormat.text(booking.customerPhone), _Columns.phone),
              _TextCell(AdminFormat.text(booking.sportName), _Columns.sport),
              _TextCell(
                AdminFormat.text(booking.courtName),
                _Columns.court,
                weight: FontWeight.w600,
              ),
              _TextCell(
                AdminFormat.text(booking.sportComplexName),
                _Columns.complex,
              ),
              _TextCell(AdminFormat.date(booking.date), _Columns.date),
              _TextCell(booking.windowLabel, _Columns.time),
              _TextCell(booking.durationLabel, _Columns.duration),
              Expanded(
                flex: _Columns.source,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: BookingSourceChip(booking: booking),
                  ),
                ),
              ),
              _TextCell(
                AdminFormat.currency(booking.amount),
                _Columns.amount,
                weight: FontWeight.w700,
              ),
              Expanded(
                flex: _Columns.payment,
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
                        : PaymentStatusChip(booking: booking, dense: true),
                  ),
                ),
              ),
              Expanded(
                flex: _Columns.status,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: BookingStatusChip(booking: booking, dense: true),
                  ),
                ),
              ),
              _TextCell(AdminFormat.date(booking.createdAt), _Columns.created),
              SizedBox(
                width: _Columns.actions,
                child: BookingRowActions(
                  booking: booking,
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

/// View / Edit / Delete, plus the status shortcuts behind "More".
class BookingRowActions extends StatelessWidget {
  const BookingRowActions({
    super.key,
    required this.booking,
    required this.onAction,
    required this.visible,
  });

  final Booking booking;
  final void Function(BookingAction action, Booking booking) onAction;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return AnimatedOpacity(
      duration: AdminTokens.fast,
      opacity: visible ? 1 : 0.35,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => onAction(BookingAction.view, booking),
            icon: const Icon(Icons.visibility_outlined, size: 17),
            tooltip: 'View details',
            color: tokens.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
          ),
          PopupMenuButton<BookingAction>(
            tooltip: 'More actions',
            icon: Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: tokens.textMuted,
            ),
            padding: EdgeInsets.zero,
            onSelected: (action) => onAction(action, booking),
            itemBuilder: (context) => <PopupMenuEntry<BookingAction>>[
              _item(
                BookingAction.edit,
                Icons.edit_outlined,
                'Edit booking',
                tokens.textPrimary,
              ),
              const PopupMenuDivider(),
              // Only the transitions that are not already true are offered, so
              // the menu never presents a no-op.
              if (booking.status != BookingStatus.confirmed)
                _item(
                  BookingAction.markConfirmed,
                  Icons.check_circle_outline_rounded,
                  'Mark as Confirmed',
                  tokens.success,
                ),
              if (booking.status != BookingStatus.completed)
                _item(
                  BookingAction.markCompleted,
                  Icons.task_alt_rounded,
                  'Mark as Completed',
                  tokens.info,
                ),
              if (booking.status != BookingStatus.cancelled)
                _item(
                  BookingAction.markCancelled,
                  Icons.cancel_outlined,
                  'Cancel booking',
                  tokens.warning,
                ),
              if (booking.payment != PaymentStatus.paid)
                _item(
                  BookingAction.markPaid,
                  Icons.payments_rounded,
                  'Mark as Paid',
                  tokens.success,
                ),
              const PopupMenuDivider(),
              _item(
                BookingAction.delete,
                Icons.delete_outline_rounded,
                'Delete booking',
                tokens.danger,
              ),
            ]
              .gatedBy(
                AdminModules.bookings,
                isDestructive: (a) => a == BookingAction.delete,
                isReadOnly: (a) => a == BookingAction.view,
              ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<BookingAction> _item(
    BookingAction value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem<BookingAction>(
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
class BookingCard extends StatelessWidget {
  const BookingCard({
    super.key,
    required this.booking,
    required this.busy,
    required this.onAction,
  });

  final Booking booking;
  final bool busy;
  final void Function(BookingAction action, Booking booking) onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return InkWell(
      onTap: () => onAction(BookingAction.view, booking),
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
                CustomerAvatar(booking: booking, size: 44),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        booking.displayCustomer,
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
                        booking.displayReference,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 11.5,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ],
                  ),
                ),
                BookingRowActions(
                  booking: booking,
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
                BookingStatusChip(booking: booking, dense: true),
                if (busy)
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  PaymentStatusChip(booking: booking, dense: true),
                BookingSourceChip(booking: booking),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Court',
                    value: AdminFormat.text(booking.courtName),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Date',
                    value: AdminFormat.date(booking.date),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(label: 'Time', value: booking.windowLabel),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Amount',
                    value: AdminFormat.currency(booking.amount),
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
