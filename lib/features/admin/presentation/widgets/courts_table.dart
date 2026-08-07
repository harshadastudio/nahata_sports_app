import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/court.dart';
import '../state/courts_controller.dart';
import '../navigation/admin_module.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';

/// What a court row can be asked to do.
///
/// Frontend visibility is deliberately not here: it is a switch in its own
/// column, not a menu item, so it reports through its own callback.
enum CourtAction { view, edit, manageSlots, delete, setActive, setInactive }

/// The desktop/tablet table.
///
/// Same construction as the other console tables: a hand-built header/row pair
/// inside one horizontal scroll, so twelve columns never squeeze into
/// unreadable slivers.
class CourtsTable extends StatefulWidget {
  const CourtsTable({
    super.key,
    required this.courts,
    required this.sort,
    required this.descending,
    required this.onSort,
    required this.onAction,
    required this.onToggleVisibility,
    required this.isBusy,
    this.selectedId,
  });

  final List<Court> courts;
  final CourtSort? sort;
  final bool descending;
  final ValueChanged<CourtSort> onSort;
  final void Function(CourtAction action, Court court) onAction;
  final void Function(Court court, bool showOnFrontend) onToggleVisibility;

  /// True while that row has a status or visibility write in flight.
  final bool Function(int id) isBusy;

  final int? selectedId;

  /// Twelve columns need real room; below this the table scrolls sideways.
  static const double _minWidth = 1820;

  @override
  State<CourtsTable> createState() => _CourtsTableState();
}

class _CourtsTableState extends State<CourtsTable> {
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
        final overflows = constraints.maxWidth < CourtsTable._minWidth;
        final width = overflows ? CourtsTable._minWidth : constraints.maxWidth;

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
                  ...widget.courts.map(
                    (court) => _Row(
                      key: ValueKey<int>(court.id),
                      court: court,
                      selected: court.id == widget.selectedId,
                      busy: widget.isBusy(court.id),
                      onAction: widget.onAction,
                      onToggleVisibility: widget.onToggleVisibility,
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

  static const int name = 16;
  static const int sport = 11;
  static const int complex = 13;
  static const int surface = 11;
  static const int capacity = 9;
  static const int rate = 10;
  static const int lighting = 10;
  static const int equipment = 12;
  static const int status = 9;
  static const int frontend = 12;

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

  final CourtSort? sort;
  final bool descending;
  final ValueChanged<CourtSort> onSort;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    Widget cell(String label, int flex, [CourtSort? column]) => _HeaderCell(
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
          cell('Court name', _Columns.name, CourtSort.name),
          cell('Sport', _Columns.sport, CourtSort.sport),
          cell('Sports complex', _Columns.complex, CourtSort.complex),
          cell('Surface', _Columns.surface, CourtSort.surface),
          cell('Capacity', _Columns.capacity, CourtSort.capacity),
          cell('Hourly rate', _Columns.rate, CourtSort.rate),
          cell('Lighting', _Columns.lighting),
          cell('Equipment', _Columns.equipment),
          cell('Status', _Columns.status, CourtSort.status),
          cell('Show on frontend', _Columns.frontend, CourtSort.visibility),
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
  final CourtSort? column;
  final CourtSort? sort;
  final bool descending;
  final ValueChanged<CourtSort>? onSort;

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
    required this.court,
    required this.selected,
    required this.busy,
    required this.onAction,
    required this.onToggleVisibility,
  });

  final Court court;
  final bool selected;
  final bool busy;
  final void Function(CourtAction action, Court court) onAction;
  final void Function(Court court, bool showOnFrontend) onToggleVisibility;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final court = widget.court;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onAction(CourtAction.view, court),
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
                  child: CourtThumb(court: court, size: 40),
                ),
              ),
              Expanded(
                flex: _Columns.name,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Text(
                    court.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              _TextCell(AdminFormat.text(court.sportName), _Columns.sport),
              _TextCell(
                AdminFormat.text(court.sportComplexName),
                _Columns.complex,
                weight: FontWeight.w600,
              ),
              Expanded(
                flex: _Columns.surface,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SurfaceChip(court: court),
                  ),
                ),
              ),
              _TextCell(
                AdminFormat.number(court.capacity),
                _Columns.capacity,
                weight: FontWeight.w600,
              ),
              _TextCell(
                AdminFormat.currency(court.hourlyRate),
                _Columns.rate,
                weight: FontWeight.w600,
              ),
              Expanded(
                flex: _Columns.lighting,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: LightingChip(court: court),
                  ),
                ),
              ),
              _TextCell(
                AdminFormat.text(court.equipmentAvailable),
                _Columns.equipment,
              ),
              Expanded(
                flex: _Columns.status,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: CourtStatusBadge(court: court, dense: true),
                  ),
                ),
              ),
              Expanded(
                flex: _Columns.frontend,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: CourtVisibilitySwitch(
                      court: court,
                      busy: widget.busy,
                      onChanged: (value) =>
                          widget.onToggleVisibility(court, value),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: _Columns.actions,
                child: CourtRowActions(
                  court: court,
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

/// The court photo, falling back to initials on a deterministic gradient.
class CourtThumb extends StatelessWidget {
  const CourtThumb({super.key, required this.court, this.size = 40});

  final Court court;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final gradient = tokens.avatarGradient('${court.id}${court.name ?? ''}');

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
        court.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    final url = court.imageUrl;
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

/// The surface type, as stored. Not colour-coded by value: the vocabulary is
/// the backend's and this app cannot enumerate it.
class SurfaceChip extends StatelessWidget {
  const SurfaceChip({super.key, required this.court});

  final Court court;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final surface = (court.surfaceType ?? '').trim();

    if (surface.isEmpty) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.space2,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: tokens.info.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
      ),
      child: Text(
        surface,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: tokens.info,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}

/// Lit / unlit. A court whose payload never said is an em dash, not "unlit".
class LightingChip extends StatelessWidget {
  const LightingChip({super.key, required this.court});

  final Court court;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final lit = court.lightingAvailable;

    if (lit == null) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    final color = lit ? tokens.warning : tokens.textMuted;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          lit ? Icons.light_mode_rounded : Icons.dark_mode_outlined,
          size: 14,
          color: color,
        ),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            lit ? 'Lit' : 'No lights',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class CourtStatusBadge extends StatelessWidget {
  const CourtStatusBadge({super.key, required this.court, this.dense = false});

  final Court court;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final color = tokens.statusColor(court.status);
    final label = court.statusLabel.isEmpty
        ? AdminFormat.dash
        : court.statusLabel;

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

/// The storefront visibility toggle.
///
/// A court whose payload never said is shown as an em dash beside an off
/// switch — flipping it on is still a legitimate write, so the control stays
/// live rather than being disabled on missing data.
class CourtVisibilitySwitch extends StatelessWidget {
  const CourtVisibilitySwitch({
    super.key,
    required this.court,
    required this.busy,
    required this.onChanged,
    this.showLabel = true,
  });

  final Court court;
  final bool busy;
  final ValueChanged<bool> onChanged;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final value = court.showOnFrontend;
    final on = value == true;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 26,
          child: FittedBox(
            fit: BoxFit.fitHeight,
            child: Switch(
              value: on,
              onChanged: busy ? null : onChanged,
              activeThumbColor: Colors.white,
              activeTrackColor: tokens.success,
            ),
          ),
        ),
        if (showLabel) ...[
          const SizedBox(width: AdminTokens.space2),
          Flexible(
            child: busy
                ? const SizedBox(
                    width: 13,
                    height: 13,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    value == null
                        ? AdminFormat.dash
                        : (on ? 'Shown' : 'Hidden'),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: value == null
                          ? tokens.textMuted
                          : (on ? tokens.success : tokens.textMuted),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}

/// View / Edit / Manage slots, plus the status items behind "More".
class CourtRowActions extends StatelessWidget {
  const CourtRowActions({
    super.key,
    required this.court,
    required this.onAction,
    required this.visible,
  });

  final Court court;
  final void Function(CourtAction action, Court court) onAction;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final isActive = court.isActive;

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
            onPressed: () => onAction(CourtAction.manageSlots, court),
            icon: const Icon(Icons.schedule_rounded, size: 17),
            tooltip: 'Manage slots',
            color: tokens.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
          ),
          PopupMenuButton<CourtAction>(
            tooltip: 'More actions',
            icon: Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: tokens.textMuted,
            ),
            padding: EdgeInsets.zero,
            onSelected: (action) => onAction(action, court),
            itemBuilder: (context) => <PopupMenuEntry<CourtAction>>[
              _item(
                CourtAction.view,
                Icons.visibility_outlined,
                'View details',
                tokens.textPrimary,
              ),
              _item(
                CourtAction.edit,
                Icons.edit_outlined,
                'Edit court',
                tokens.textPrimary,
              ),
              _item(
                CourtAction.manageSlots,
                Icons.schedule_rounded,
                'Manage slots',
                tokens.textPrimary,
              ),
              const PopupMenuDivider(),
              // Only the status it is not already in is offered, so the menu
              // never presents a no-op.
              if (!isActive)
                _item(
                  CourtAction.setActive,
                  Icons.check_circle_outline_rounded,
                  'Mark as Active',
                  tokens.success,
                ),
              if (isActive)
                _item(
                  CourtAction.setInactive,
                  Icons.pause_circle_outline_rounded,
                  'Mark as Inactive',
                  tokens.warning,
                ),
              const PopupMenuDivider(),
              _item(
                CourtAction.delete,
                Icons.delete_outline_rounded,
                'Delete court',
                tokens.danger,
              ),
            ]
              .gatedBy(
                AdminModules.courts,
                isDestructive: (a) => a == CourtAction.delete,
                isReadOnly: (a) => a == CourtAction.view,
              ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<CourtAction> _item(
    CourtAction value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem<CourtAction>(
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
class CourtCard extends StatelessWidget {
  const CourtCard({
    super.key,
    required this.court,
    required this.busy,
    required this.onAction,
    required this.onToggleVisibility,
  });

  final Court court;
  final bool busy;
  final void Function(CourtAction action, Court court) onAction;
  final void Function(Court court, bool showOnFrontend) onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return InkWell(
      onTap: () => onAction(CourtAction.view, court),
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
                CourtThumb(court: court, size: 48),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        court.displayName,
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
                          AdminFormat.text(court.sportName),
                          AdminFormat.text(court.sportComplexName),
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
                CourtRowActions(
                  court: court,
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
                CourtStatusBadge(court: court, dense: true),
                SurfaceChip(court: court),
                LightingChip(court: court),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Capacity',
                    value: AdminFormat.number(court.capacity),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Hourly rate',
                    value: AdminFormat.currency(court.hourlyRate),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Equipment',
                    value: AdminFormat.text(court.equipmentAvailable),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Row(
              children: [
                Text(
                  'Show on frontend',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                CourtVisibilitySwitch(
                  court: court,
                  busy: busy,
                  onChanged: (value) => onToggleVisibility(court, value),
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
