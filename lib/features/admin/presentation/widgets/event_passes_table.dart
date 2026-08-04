import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/event_pass.dart';
import '../state/event_passes_controller.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';

/// What an event row can be asked to do.
enum EventAction { view, edit, delete, setActive, setInactive, book }

/// The events table and the bookings table live together: they are two views of
/// one module, share the same header cell and row chrome, and are never used
/// apart.

class EventPassesTable extends StatefulWidget {
  const EventPassesTable({
    super.key,
    required this.events,
    required this.sort,
    required this.descending,
    required this.onSort,
    required this.onAction,
    required this.isBusy,
    this.selectedId,
  });

  final List<AdminEventPass> events;
  final EventSort? sort;
  final bool descending;
  final ValueChanged<EventSort> onSort;
  final void Function(EventAction action, AdminEventPass event) onAction;
  final bool Function(int id) isBusy;
  final int? selectedId;

  static const double _minWidth = 1420;

  @override
  State<EventPassesTable> createState() => _EventPassesTableState();
}

class _EventPassesTableState extends State<EventPassesTable> {
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
        final overflows = constraints.maxWidth < EventPassesTable._minWidth;
        final width = overflows
            ? EventPassesTable._minWidth
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
                  ...widget.events.map(
                    (event) => _Row(
                      key: ValueKey<int>(event.id),
                      event: event,
                      selected: event.id == widget.selectedId,
                      busy: widget.isBusy(event.id),
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

  static const double image = 60;
  static const int title = 22;
  static const int complex = 16;
  static const int dates = 16;
  static const int slots = 11;
  static const int capacity = 11;
  static const int price = 13;
  static const int status = 11;
  static const double actions = 100;
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.sort,
    required this.descending,
    required this.onSort,
  });

  final EventSort? sort;
  final bool descending;
  final ValueChanged<EventSort> onSort;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    Widget cell(String label, int flex, [EventSort? column]) => EventHeaderCell(
      label: label,
      flex: flex,
      active: column != null && sort == column,
      descending: descending,
      onTap: column == null ? null : () => onSort(column),
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
          cell('Event', _Columns.title, EventSort.title),
          cell('Sports complex', _Columns.complex, EventSort.complex),
          cell('Dates', _Columns.dates, EventSort.starts),
          cell('Slots', _Columns.slots, EventSort.slots),
          cell('Capacity', _Columns.capacity, EventSort.capacity),
          cell('Price', _Columns.price),
          cell('Status', _Columns.status, EventSort.status),
          const SizedBox(width: _Columns.actions),
        ],
      ),
    );
  }
}

/// The sortable header cell both tables use.
class EventHeaderCell extends StatefulWidget {
  const EventHeaderCell({
    super.key,
    required this.label,
    required this.flex,
    this.active = false,
    this.descending = false,
    this.onTap,
  });

  final String label;
  final int flex;
  final bool active;
  final bool descending;
  final VoidCallback? onTap;

  @override
  State<EventHeaderCell> createState() => _EventHeaderCellState();
}

class _EventHeaderCellState extends State<EventHeaderCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final sortable = widget.onTap != null;

    final content = Row(
      children: [
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: widget.active ? tokens.accent : tokens.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (sortable)
          AnimatedOpacity(
            duration: AdminTokens.fast,
            opacity: widget.active ? 1 : (_hovered ? 0.5 : 0),
            child: Icon(
              widget.active && widget.descending
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 13,
              color: widget.active ? tokens.accent : tokens.textMuted,
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
                  onTap: widget.onTap,
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
    required this.event,
    required this.selected,
    required this.busy,
    required this.onAction,
  });

  final AdminEventPass event;
  final bool selected;
  final bool busy;
  final void Function(EventAction action, AdminEventPass event) onAction;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final event = widget.event;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onAction(EventAction.view, event),
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
                  child: EventThumb(event: event, size: 40),
                ),
              ),
              Expanded(
                flex: _Columns.title,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        event.displayTitle,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if ((event.description ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          event.description!.trim(),
                          maxLines: 1,
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
              EventTextCell(
                AdminFormat.text(event.sportComplexName),
                _Columns.complex,
                weight: FontWeight.w600,
              ),
              Expanded(
                flex: _Columns.dates,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: EventDatesCell(event: event),
                ),
              ),
              Expanded(
                flex: _Columns.slots,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: EventSlotsBadge(event: event),
                  ),
                ),
              ),
              EventTextCell(
                AdminFormat.number(event.totalCapacity),
                _Columns.capacity,
                weight: FontWeight.w600,
              ),
              EventTextCell(_priceLabel(event), _Columns.price),
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
                        : EventStatusBadge(event: event, dense: true),
                  ),
                ),
              ),
              SizedBox(
                width: _Columns.actions,
                child: EventRowActions(
                  event: event,
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

/// `₹300` for a single price, `₹300 – ₹500` for a range, an em dash for none.
String _priceLabel(AdminEventPass event) {
  final range = event.priceRange;
  if (range == null) return AdminFormat.dash;
  final (low, high) = range;
  if (low == high) return AdminFormat.currency(low);
  return '${AdminFormat.currency(low)} – ${AdminFormat.currency(high)}';
}

class EventTextCell extends StatelessWidget {
  const EventTextCell(
    this.value,
    this.flex, {
    super.key,
    this.weight = FontWeight.w400,
  });

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

/// The event banner, falling back to initials on a deterministic gradient.
class EventThumb extends StatelessWidget {
  const EventThumb({super.key, required this.event, this.size = 40});

  final AdminEventPass event;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final gradient = tokens.avatarGradient('${event.id}${event.title ?? ''}');

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
        event.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    final url = event.imageUrl;
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

/// The first and last dates the event runs.
class EventDatesCell extends StatelessWidget {
  const EventDatesCell({super.key, required this.event, this.now});

  final AdminEventPass event;

  /// Injectable so a test can pin "today".
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final first = event.firstDate;
    final last = event.lastDate;

    if (first == null) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text(
          AdminFormat.dash,
          style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
        ),
      );
    }

    final finished = event.hasFinished(now ?? DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AdminFormat.date(first),
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: tokens.textSecondary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (last != null && last != first)
          Text(
            'to ${AdminFormat.date(last)}',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
          ),
        // An event whose every slot is in the past is finished whatever its
        // status column says.
        if (finished)
          Text(
            'Finished',
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
      ],
    );
  }
}

class EventSlotsBadge extends StatelessWidget {
  const EventSlotsBadge({super.key, required this.event});

  final AdminEventPass event;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    if (event.slotCount == 0) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    return Tooltip(
      message: event.slots
          .map((slot) => '${slot.displayName} · ${slot.windowLabel}')
          .join('\n'),
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
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.event_note_rounded, size: 12, color: tokens.info),
            const SizedBox(width: 4),
            Text(
              '${event.slotCount}',
              style: TextStyle(
                color: tokens.info,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EventStatusBadge extends StatelessWidget {
  const EventStatusBadge({super.key, required this.event, this.dense = false});

  final AdminEventPass event;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final color = tokens.statusColor(event.status);
    final label = event.statusLabel.isEmpty
        ? AdminFormat.dash
        : event.statusLabel;

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

class EventRowActions extends StatelessWidget {
  const EventRowActions({
    super.key,
    required this.event,
    required this.onAction,
    required this.visible,
  });

  final AdminEventPass event;
  final void Function(EventAction action, AdminEventPass event) onAction;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final isActive = event.isActive;

    return AnimatedOpacity(
      duration: AdminTokens.fast,
      opacity: visible ? 1 : 0.35,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => onAction(EventAction.view, event),
            icon: const Icon(Icons.visibility_outlined, size: 17),
            tooltip: 'View details',
            color: tokens.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
          ),
          PopupMenuButton<EventAction>(
            tooltip: 'More actions',
            icon: Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: tokens.textMuted,
            ),
            padding: EdgeInsets.zero,
            onSelected: (action) => onAction(action, event),
            itemBuilder: (context) => [
              _item(
                EventAction.edit,
                Icons.edit_outlined,
                'Edit event',
                tokens.textPrimary,
              ),
              // Only offered where there is a slot to book onto.
              if (event.slotCount > 0)
                _item(
                  EventAction.book,
                  Icons.confirmation_number_outlined,
                  'Book passes',
                  tokens.textPrimary,
                ),
              const PopupMenuDivider(),
              if (!isActive)
                _item(
                  EventAction.setActive,
                  Icons.check_circle_outline_rounded,
                  'Mark as Active',
                  tokens.success,
                ),
              if (isActive)
                _item(
                  EventAction.setInactive,
                  Icons.pause_circle_outline_rounded,
                  'Mark as Inactive',
                  tokens.warning,
                ),
              const PopupMenuDivider(),
              _item(
                EventAction.delete,
                Icons.delete_outline_rounded,
                'Delete event',
                tokens.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<EventAction> _item(
    EventAction value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem<EventAction>(
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

/// The mobile equivalent of an event row.
class EventPassCard extends StatelessWidget {
  const EventPassCard({
    super.key,
    required this.event,
    required this.busy,
    required this.onAction,
  });

  final AdminEventPass event;
  final bool busy;
  final void Function(EventAction action, AdminEventPass event) onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return InkWell(
      onTap: () => onAction(EventAction.view, event),
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
                EventThumb(event: event, size: 48),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        event.displayTitle,
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
                        AdminFormat.text(event.sportComplexName),
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
                EventRowActions(
                  event: event,
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
                  EventStatusBadge(event: event, dense: true),
                EventSlotsBadge(event: event),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Starts',
                    value: AdminFormat.date(event.firstDate),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Capacity',
                    value: AdminFormat.number(event.totalCapacity),
                  ),
                ),
                Expanded(
                  child: _MiniStat(label: 'Price', value: _priceLabel(event)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Event bookings
// -----------------------------------------------------------------------------

/// `GET /event-passes/bookings/all`, as a table.
class EventBookingsTable extends StatefulWidget {
  const EventBookingsTable({super.key, required this.bookings});

  final List<EventPassBookingRow> bookings;

  static const double _minWidth = 1500;

  @override
  State<EventBookingsTable> createState() => _EventBookingsTableState();
}

class _EventBookingsTableState extends State<EventBookingsTable> {
  final _horizontal = ScrollController();

  @override
  void dispose() {
    _horizontal.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final overflows = constraints.maxWidth < EventBookingsTable._minWidth;
        final width = overflows
            ? EventBookingsTable._minWidth
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AdminTokens.space5,
                      vertical: AdminTokens.space3,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.surfaceAlt,
                      border: Border(bottom: BorderSide(color: tokens.border)),
                    ),
                    child: const Row(
                      children: [
                        EventHeaderCell(label: 'Booking', flex: 10),
                        EventHeaderCell(label: 'Customer', flex: 18),
                        EventHeaderCell(label: 'Contact', flex: 18),
                        EventHeaderCell(label: 'Event', flex: 20),
                        EventHeaderCell(label: 'Slot', flex: 14),
                        EventHeaderCell(label: 'Passes', flex: 10),
                        EventHeaderCell(label: 'Amount', flex: 12),
                        EventHeaderCell(label: 'Scanned in', flex: 12),
                        EventHeaderCell(label: 'Booked', flex: 12),
                      ],
                    ),
                  ),
                  ...widget.bookings.map(
                    (booking) => _BookingRow(
                      key: ValueKey<int>(booking.id),
                      booking: booking,
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

class _BookingRow extends StatelessWidget {
  const _BookingRow({super.key, required this.booking});

  final EventPassBookingRow booking;

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
          EventTextCell('#${booking.id}', 10, weight: FontWeight.w700),
          Expanded(
            flex: 18,
            child: Padding(
              padding: const EdgeInsets.only(right: AdminTokens.space3),
              child: Row(
                children: [
                  _Avatar(booking: booking),
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
          Expanded(
            flex: 18,
            child: Padding(
              padding: const EdgeInsets.only(right: AdminTokens.space3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AdminFormat.text(booking.customerPhone),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 12.5,
                    ),
                  ),
                  Text(
                    AdminFormat.text(booking.customerEmail),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ),
          EventTextCell(booking.displayEvent, 20, weight: FontWeight.w600),
          EventTextCell(
            booking.slotName ??
                (booking.slotDate == null
                    ? AdminFormat.dash
                    : AdminFormat.date(booking.slotDate)),
            14,
          ),
          EventTextCell(
            AdminFormat.number(booking.numberOfPasses),
            10,
            weight: FontWeight.w700,
          ),
          EventTextCell(
            AdminFormat.currency(booking.totalAmount),
            12,
            weight: FontWeight.w700,
          ),
          Expanded(
            flex: 12,
            child: Padding(
              padding: const EdgeInsets.only(right: AdminTokens.space3),
              child: Align(
                alignment: Alignment.centerLeft,
                child: _ScannedCell(booking: booking),
              ),
            ),
          ),
          EventTextCell(AdminFormat.date(booking.createdAt), 12),
        ],
      ),
    );
  }
}

/// `2 / 4` scanned in, or an em dash when the payload carried no pass detail.
class _ScannedCell extends StatelessWidget {
  const _ScannedCell({required this.booking});

  final EventPassBookingRow booking;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final scanned = booking.scannedInCount;

    if (scanned == null) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    final total = booking.numberOfPasses;
    final complete = total != null && scanned >= total && total > 0;

    return Text(
      total == null ? '$scanned' : '$scanned / $total',
      style: TextStyle(
        color: complete ? tokens.success : tokens.textSecondary,
        fontSize: 12.5,
        fontWeight: complete ? FontWeight.w700 : FontWeight.w600,
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.booking});

  final EventPassBookingRow booking;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final gradient = tokens.avatarGradient(
      '${booking.userId ?? booking.id}${booking.customerName ?? ''}',
    );

    return Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: gradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Text(
        booking.initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The mobile equivalent of a booking row.
class EventBookingCard extends StatelessWidget {
  const EventBookingCard({super.key, required this.booking});

  final EventPassBookingRow booking;

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
              _Avatar(booking: booking),
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
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      booking.displayEvent,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                AdminFormat.currency(booking.totalAmount),
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  label: 'Passes',
                  value: AdminFormat.number(booking.numberOfPasses),
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Slot',
                  value:
                      booking.slotName ??
                      (booking.slotDate == null
                          ? AdminFormat.dash
                          : AdminFormat.date(booking.slotDate)),
                ),
              ),
              Expanded(
                child: _MiniStat(
                  label: 'Booked',
                  value: AdminFormat.date(booking.createdAt),
                ),
              ),
            ],
          ),
        ],
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
