import 'package:flutter/material.dart';

import '../../domain/entities/court.dart';
import '../../domain/entities/court_slot.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';

/// What a slot row can be asked to do.
///
/// Block/unblock is deliberately not here: it is a switch in its own column,
/// not a menu item, so it reports through its own callback.
enum SlotAction { edit, delete }

/// The slot schedule for one court.
///
/// Narrower than the module tables — six columns — so it lays out as a plain
/// list on a phone without needing a card variant of its own.
class SlotsTable extends StatefulWidget {
  const SlotsTable({
    super.key,
    required this.slots,
    required this.court,
    required this.onAction,
    required this.onToggle,
    required this.isBusy,
  });

  final List<CourtSlot> slots;

  /// The parent court, so a slot with no price override can show the rate it
  /// actually charges rather than an em dash.
  final Court court;

  final void Function(SlotAction action, CourtSlot slot) onAction;
  final void Function(CourtSlot slot) onToggle;
  final bool Function(int id) isBusy;

  static const double _minWidth = 1080;

  @override
  State<SlotsTable> createState() => _SlotsTableState();
}

class _SlotsTableState extends State<SlotsTable> {
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
        final overflows = constraints.maxWidth < SlotsTable._minWidth;
        final width = overflows ? SlotsTable._minWidth : constraints.maxWidth;

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
                  const _HeaderRow(),
                  ...widget.slots.map(
                    (slot) => _Row(
                      key: ValueKey<int>(slot.id),
                      slot: slot,
                      court: widget.court,
                      busy: widget.isBusy(slot.id),
                      onAction: widget.onAction,
                      onToggle: widget.onToggle,
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

  static const int window = 18;
  static const int days = 22;
  static const int type = 12;
  static const int price = 14;
  static const int status = 16;
  static const double actions = 96;
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    Widget cell(String label, int flex) => Expanded(
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
          cell('Start – End', _Columns.window),
          cell('Available days', _Columns.days),
          cell('Slot type', _Columns.type),
          cell('Price', _Columns.price),
          cell('Bookable', _Columns.status),
          const SizedBox(width: _Columns.actions),
        ],
      ),
    );
  }
}

class _Row extends StatefulWidget {
  const _Row({
    super.key,
    required this.slot,
    required this.court,
    required this.busy,
    required this.onAction,
    required this.onToggle,
  });

  final CourtSlot slot;
  final Court court;
  final bool busy;
  final void Function(SlotAction action, CourtSlot slot) onAction;
  final void Function(CourtSlot slot) onToggle;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final slot = widget.slot;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AdminTokens.fast,
        padding: const EdgeInsets.symmetric(
          horizontal: AdminTokens.space5,
          vertical: AdminTokens.space3,
        ),
        decoration: BoxDecoration(
          color: _hovered ? tokens.surfaceAlt : Colors.transparent,
          border: Border(bottom: BorderSide(color: tokens.border)),
        ),
        child: Row(
          children: [
            Expanded(
              flex: _Columns.window,
              child: Padding(
                padding: const EdgeInsets.only(right: AdminTokens.space3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      slot.windowLabel,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (slot.durationMinutes != null &&
                        slot.durationMinutes != 60) ...[
                      const SizedBox(height: 2),
                      // Flagged, because the module's own rule is one hour: a
                      // row that breaks it was written elsewhere.
                      Text(
                        'Not one hour',
                        style: TextStyle(
                          color: tokens.warning,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              flex: _Columns.days,
              child: Padding(
                padding: const EdgeInsets.only(right: AdminTokens.space3),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SlotDaysChip(slot: slot),
                ),
              ),
            ),
            Expanded(
              flex: _Columns.type,
              child: Padding(
                padding: const EdgeInsets.only(right: AdminTokens.space3),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SlotTypeChip(slot: slot),
                ),
              ),
            ),
            Expanded(
              flex: _Columns.price,
              child: Padding(
                padding: const EdgeInsets.only(right: AdminTokens.space3),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SlotPriceCell(slot: slot, court: widget.court),
                ),
              ),
            ),
            Expanded(
              flex: _Columns.status,
              child: Padding(
                padding: const EdgeInsets.only(right: AdminTokens.space3),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SlotBookableSwitch(
                    slot: slot,
                    busy: widget.busy,
                    onChanged: () => widget.onToggle(slot),
                  ),
                ),
              ),
            ),
            SizedBox(
              width: _Columns.actions,
              child: SlotRowActions(
                slot: slot,
                onAction: widget.onAction,
                visible: _hovered,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The days the slot runs, abbreviated with the full list behind a tooltip.
class SlotDaysChip extends StatelessWidget {
  const SlotDaysChip({super.key, required this.slot});

  final CourtSlot slot;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final days = slot.days;

    if (days.isEmpty) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    // A schedule the day parser could not read is shown as written rather than
    // squeezed into abbreviations it never said.
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

class SlotTypeChip extends StatelessWidget {
  const SlotTypeChip({super.key, required this.slot});

  final CourtSlot slot;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final raw = (slot.slotTypeRaw ?? '').trim();

    if (raw.isEmpty) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    final color = switch (slot.slotType) {
      SlotType.premium => const Color(0xFF8B5CF6),
      SlotType.coaching => tokens.info,
      SlotType.practice => tokens.success,
      SlotType.regular => tokens.textSecondary,
      null => tokens.textMuted,
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.space2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
      ),
      child: Text(
        slot.slotTypeLabel,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}

/// The price the slot actually charges: its override, or the court's rate.
class SlotPriceCell extends StatelessWidget {
  const SlotPriceCell({super.key, required this.slot, required this.court});

  final CourtSlot slot;
  final Court court;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    if (!slot.hasPriceOverride) {
      final rate = court.hourlyRate;
      return Text(
        rate == null ? AdminFormat.dash : AdminFormat.currency(rate),
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: rate == null ? tokens.textMuted : tokens.textSecondary,
          fontSize: 12.5,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            AdminFormat.currency(slot.priceOverride),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Tooltip(
          message: 'Overrides the court rate',
          child: Icon(
            Icons.price_change_outlined,
            size: 13,
            color: tokens.warning,
          ),
        ),
      ],
    );
  }
}

/// Active = bookable, Inactive = blocked — the spec's own wording.
class SlotBookableSwitch extends StatelessWidget {
  const SlotBookableSwitch({
    super.key,
    required this.slot,
    required this.busy,
    required this.onChanged,
  });

  final CourtSlot slot;
  final bool busy;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final bookable = slot.isBookable;
    final unknown = slot.status == null;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 26,
          child: FittedBox(
            fit: BoxFit.fitHeight,
            child: Switch(
              value: bookable,
              onChanged: busy ? null : (_) => onChanged(),
              activeThumbColor: Colors.white,
              activeTrackColor: tokens.success,
            ),
          ),
        ),
        const SizedBox(width: AdminTokens.space2),
        Flexible(
          child: busy
              ? const SizedBox(
                  width: 13,
                  height: 13,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  unknown
                      ? AdminFormat.dash
                      : (bookable ? 'Bookable' : 'Blocked'),
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: unknown
                        ? tokens.textMuted
                        : (bookable ? tokens.success : tokens.danger),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
        ),
      ],
    );
  }
}

class SlotRowActions extends StatelessWidget {
  const SlotRowActions({
    super.key,
    required this.slot,
    required this.onAction,
    required this.visible,
  });

  final CourtSlot slot;
  final void Function(SlotAction action, CourtSlot slot) onAction;
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
            onPressed: () => onAction(SlotAction.edit, slot),
            icon: const Icon(Icons.edit_outlined, size: 17),
            tooltip: 'Edit slot',
            color: tokens.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          ),
          IconButton(
            onPressed: () => onAction(SlotAction.delete, slot),
            icon: const Icon(Icons.delete_outline_rounded, size: 17),
            tooltip: 'Delete slot',
            color: tokens.danger,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          ),
        ],
      ),
    );
  }
}

/// The mobile equivalent of a slot row.
class SlotCard extends StatelessWidget {
  const SlotCard({
    super.key,
    required this.slot,
    required this.court,
    required this.busy,
    required this.onAction,
    required this.onToggle,
  });

  final CourtSlot slot;
  final Court court;
  final bool busy;
  final void Function(SlotAction action, CourtSlot slot) onAction;
  final void Function(CourtSlot slot) onToggle;

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
                  slot.windowLabel,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              SlotRowActions(
                slot: slot,
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
              SlotTypeChip(slot: slot),
              SlotDaysChip(slot: slot),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          Row(
            children: [
              SlotPriceCell(slot: slot, court: court),
              const Spacer(),
              SlotBookableSwitch(
                slot: slot,
                busy: busy,
                onChanged: () => onToggle(slot),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
