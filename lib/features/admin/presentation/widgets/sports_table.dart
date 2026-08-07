import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/sport.dart';
import '../state/sports_controller.dart';
import '../navigation/admin_module.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';

/// What a sport row can be asked to do.
///
/// Frontend visibility is deliberately not here: it is a switch in its own
/// column, not a menu item, so it reports through its own callback.
enum SportAction {
  view,
  edit,
  delete,
  setActive,
  setInactive,
  assignComplex,
}

/// The desktop/tablet table.
///
/// Same construction as the other console tables: a hand-built header/row pair
/// inside one horizontal scroll, so ten columns never squeeze into unreadable
/// slivers.
class SportsTable extends StatefulWidget {
  const SportsTable({
    super.key,
    required this.sports,
    required this.sort,
    required this.descending,
    required this.onSort,
    required this.onAction,
    required this.onToggleVisibility,
    required this.isBusy,
    this.selectedId,
  });

  final List<Sport> sports;
  final SportSort? sort;
  final bool descending;
  final ValueChanged<SportSort> onSort;
  final void Function(SportAction action, Sport sport) onAction;
  final void Function(Sport sport, bool showOnFrontend) onToggleVisibility;

  /// True while that row has a status, visibility or assignment write in
  /// flight.
  final bool Function(int id) isBusy;

  final int? selectedId;

  /// Ten columns need real room; below this the table scrolls sideways.
  static const double _minWidth = 1520;

  @override
  State<SportsTable> createState() => _SportsTableState();
}

class _SportsTableState extends State<SportsTable> {
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
        final overflows = constraints.maxWidth < SportsTable._minWidth;
        final width = overflows ? SportsTable._minWidth : constraints.maxWidth;

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
                  ...widget.sports.map(
                    (sport) => _Row(
                      key: ValueKey<int>(sport.id),
                      sport: sport,
                      selected: sport.id == widget.selectedId,
                      busy: widget.isBusy(sport.id),
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

  static const int name = 19;
  static const int complex = 15;
  static const int category = 11;
  static const int members = 11;
  static const int programs = 13;
  static const int courts = 12;
  static const int status = 10;
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

  final SportSort? sort;
  final bool descending;
  final ValueChanged<SportSort> onSort;

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
          _HeaderCell(
            label: 'Sport name',
            flex: _Columns.name,
            column: SportSort.name,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Sports complex',
            flex: _Columns.complex,
            column: SportSort.complex,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Category',
            flex: _Columns.category,
            column: SportSort.category,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Allowed members',
            flex: _Columns.members,
            column: SportSort.members,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Programs',
            flex: _Columns.programs,
            column: SportSort.programs,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Courts',
            flex: _Columns.courts,
            column: SportSort.courts,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Status',
            flex: _Columns.status,
            column: SportSort.status,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Show on frontend',
            flex: _Columns.frontend,
            column: SportSort.visibility,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
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
  final SportSort? column;
  final SportSort? sort;
  final bool descending;
  final ValueChanged<SportSort>? onSort;

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
    required this.sport,
    required this.selected,
    required this.busy,
    required this.onAction,
    required this.onToggleVisibility,
  });

  final Sport sport;
  final bool selected;
  final bool busy;
  final void Function(SportAction action, Sport sport) onAction;
  final void Function(Sport sport, bool showOnFrontend) onToggleVisibility;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final sport = widget.sport;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onAction(SportAction.view, sport),
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
                  child: SportThumb(sport: sport, size: 40),
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
                        sport.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (sport.minAge != null || sport.maxAge != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          sport.ageRangeLabel,
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
              _TextCell(
                AdminFormat.text(sport.sportComplexName),
                _Columns.complex,
                weight: FontWeight.w600,
              ),
              Expanded(
                flex: _Columns.category,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SportCategoryChip(sport: sport),
                  ),
                ),
              ),
              _TextCell(
                AdminFormat.number(sport.allowedMembers),
                _Columns.members,
                weight: FontWeight.w600,
              ),
              Expanded(
                flex: _Columns.programs,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ProgramCountBadge(sport: sport),
                  ),
                ),
              ),
              Expanded(
                flex: _Columns.courts,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: CourtCountBadge(sport: sport),
                  ),
                ),
              ),
              Expanded(
                flex: _Columns.status,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SportStatusBadge(sport: sport, dense: true),
                  ),
                ),
              ),
              Expanded(
                flex: _Columns.frontend,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: SportVisibilitySwitch(
                      sport: sport,
                      busy: widget.busy,
                      onChanged: (value) =>
                          widget.onToggleVisibility(sport, value),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: _Columns.actions,
                child: SportRowActions(
                  sport: sport,
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

/// The sport photo, falling back to initials on a deterministic gradient — the
/// same treatment the venue thumbnails use, so a sport with no image still
/// reads as a record rather than a hole in the table.
class SportThumb extends StatelessWidget {
  const SportThumb({super.key, required this.sport, this.size = 40});

  final Sport sport;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final gradient = tokens.avatarGradient('${sport.id}${sport.name ?? ''}');

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
        sport.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    final url = sport.imageUrl;
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

/// Indoor / Outdoor, coloured so the two read apart at a glance.
class SportCategoryChip extends StatelessWidget {
  const SportCategoryChip({super.key, required this.sport, this.dense = true});

  final Sport sport;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final raw = (sport.categoryRaw ?? '').trim();

    if (raw.isEmpty) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    final indoor = sport.isIndoor;
    final color = switch (sport.category) {
      SportCategory.indoor => const Color(0xFF8B5CF6),
      SportCategory.outdoor => tokens.success,
      null => tokens.textMuted,
    };

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AdminTokens.space2 : AdminTokens.space3,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            indoor ? Icons.home_work_outlined : Icons.park_outlined,
            size: dense ? 12 : 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              sport.categoryLabel,
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

/// Programme count, with the names behind a tooltip when the payload sent them.
class ProgramCountBadge extends StatelessWidget {
  const ProgramCountBadge({super.key, required this.sport});

  final Sport sport;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final count = sport.programCount;

    if (count == null) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    final badge = Container(
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
          Icon(Icons.school_outlined, size: 12, color: tokens.info),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              color: tokens.info,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          if (sport.programNames.isNotEmpty) ...[
            const SizedBox(width: 4),
            Icon(
              Icons.info_outline_rounded,
              size: 11,
              color: tokens.info.withValues(alpha: 0.7),
            ),
          ],
        ],
      ),
    );

    if (sport.programNames.isEmpty) return badge;

    return Tooltip(
      message: sport.programNames.join('\n'),
      waitDuration: const Duration(milliseconds: 300),
      child: badge,
    );
  }
}

/// Court count, with the available figure beside it when the payload sent one.
class CourtCountBadge extends StatelessWidget {
  const CourtCountBadge({super.key, required this.sport});

  final Sport sport;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final count = sport.courtCount;

    if (count == null) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    final available = sport.availableCourts;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AdminTokens.space2,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: tokens.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.grid_view_rounded, size: 12, color: tokens.accent),
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  color: tokens.accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
        if (available != null) ...[
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              '$available free',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: available > 0 ? tokens.success : tokens.textMuted,
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class SportStatusBadge extends StatelessWidget {
  const SportStatusBadge({super.key, required this.sport, this.dense = false});

  final Sport sport;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final color = tokens.statusColor(sport.status);
    final label = sport.statusLabel.isEmpty
        ? AdminFormat.dash
        : sport.statusLabel;

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
/// A sport whose payload never said is shown as an em dash beside an off
/// switch — flipping it on is still a legitimate write, so the control stays
/// live rather than being disabled on missing data.
class SportVisibilitySwitch extends StatelessWidget {
  const SportVisibilitySwitch({
    super.key,
    required this.sport,
    required this.busy,
    required this.onChanged,
    this.showLabel = true,
  });

  final Sport sport;
  final bool busy;
  final ValueChanged<bool> onChanged;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final value = sport.showOnFrontend;
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

/// View / Edit / Delete, plus the status and assignment items behind "More".
class SportRowActions extends StatelessWidget {
  const SportRowActions({
    super.key,
    required this.sport,
    required this.onAction,
    required this.visible,
  });

  final Sport sport;
  final void Function(SportAction action, Sport sport) onAction;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final isActive = sport.isActive;

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
            onPressed: () => onAction(SportAction.view, sport),
            icon: const Icon(Icons.visibility_outlined, size: 17),
            tooltip: 'View details',
            color: tokens.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
          ),
          PopupMenuButton<SportAction>(
            tooltip: 'More actions',
            icon: Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: tokens.textMuted,
            ),
            padding: EdgeInsets.zero,
            onSelected: (action) => onAction(action, sport),
            itemBuilder: (context) => <PopupMenuEntry<SportAction>>[
              _item(
                SportAction.edit,
                Icons.edit_outlined,
                'Edit sport',
                tokens.textPrimary,
              ),
              _item(
                SportAction.assignComplex,
                Icons.swap_horiz_rounded,
                'Assign complex',
                tokens.textPrimary,
              ),
              const PopupMenuDivider(),
              // Only the status it is not already in is offered, so the menu
              // never presents a no-op.
              if (!isActive)
                _item(
                  SportAction.setActive,
                  Icons.check_circle_outline_rounded,
                  'Mark as Active',
                  tokens.success,
                ),
              if (isActive)
                _item(
                  SportAction.setInactive,
                  Icons.pause_circle_outline_rounded,
                  'Mark as Inactive',
                  tokens.warning,
                ),
              const PopupMenuDivider(),
              _item(
                SportAction.delete,
                Icons.delete_outline_rounded,
                'Delete sport',
                tokens.danger,
              ),
            ]
              .gatedBy(
                AdminModules.sports,
                isDestructive: (a) => a == SportAction.delete,
                isReadOnly: (a) => a == SportAction.view,
              ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<SportAction> _item(
    SportAction value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem<SportAction>(
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
class SportCard extends StatelessWidget {
  const SportCard({
    super.key,
    required this.sport,
    required this.busy,
    required this.onAction,
    required this.onToggleVisibility,
  });

  final Sport sport;
  final bool busy;
  final void Function(SportAction action, Sport sport) onAction;
  final void Function(Sport sport, bool showOnFrontend) onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return InkWell(
      onTap: () => onAction(SportAction.view, sport),
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
                SportThumb(sport: sport, size: 48),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        sport.displayName,
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
                        AdminFormat.text(sport.sportComplexName),
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
                SportRowActions(
                  sport: sport,
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
                SportStatusBadge(sport: sport, dense: true),
                SportCategoryChip(sport: sport),
                ProgramCountBadge(sport: sport),
                CourtCountBadge(sport: sport),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Members',
                    value: AdminFormat.number(sport.allowedMembers),
                  ),
                ),
                Expanded(
                  child: _MiniStat(label: 'Ages', value: sport.ageRangeLabel),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Duration',
                    value: AdminFormat.text(sport.duration),
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
                SportVisibilitySwitch(
                  sport: sport,
                  busy: busy,
                  onChanged: (value) => onToggleVisibility(sport, value),
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
