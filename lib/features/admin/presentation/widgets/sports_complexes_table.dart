import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/admin_sports_complex.dart';
import '../state/sports_complexes_controller.dart';
import '../navigation/admin_module.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';

/// What a sports complex row can be asked to do.
///
/// Frontend visibility is deliberately not here: it is a switch in its own
/// column, not a menu item, so it reports through its own callback.
enum SportsComplexAction { view, edit, delete, setActive, setInactive }

/// The desktop/tablet table.
///
/// Same construction as the employees and security guards tables: a hand-built
/// header/row pair inside one horizontal scroll, so eleven columns never
/// squeeze into unreadable slivers.
class SportsComplexesTable extends StatefulWidget {
  const SportsComplexesTable({
    super.key,
    required this.complexes,
    required this.sort,
    required this.descending,
    required this.onSort,
    required this.onAction,
    required this.onToggleVisibility,
    required this.isBusy,
    this.selectedId,
  });

  final List<AdminSportsComplex> complexes;
  final SportsComplexSort? sort;
  final bool descending;
  final ValueChanged<SportsComplexSort> onSort;
  final void Function(SportsComplexAction action, AdminSportsComplex complex)
  onAction;
  final void Function(AdminSportsComplex complex, bool showOnFrontend)
  onToggleVisibility;

  /// True while that row has a status or visibility write in flight.
  final bool Function(int id) isBusy;

  final int? selectedId;

  /// Eleven columns need real room; below this the table scrolls sideways.
  static const double _minWidth = 1560;

  @override
  State<SportsComplexesTable> createState() => _SportsComplexesTableState();
}

class _SportsComplexesTableState extends State<SportsComplexesTable> {
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
        final overflows = constraints.maxWidth < SportsComplexesTable._minWidth;
        final width = overflows
            ? SportsComplexesTable._minWidth
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
                  ...widget.complexes.map(
                    (complex) => _Row(
                      key: ValueKey<int>(complex.id),
                      complex: complex,
                      selected: complex.id == widget.selectedId,
                      busy: widget.isBusy(complex.id),
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

  static const int name = 20;
  static const int city = 11;
  static const int state = 11;
  static const int phone = 12;
  static const int email = 17;
  static const int hours = 12;
  static const int status = 10;
  static const int frontend = 12;
  static const int created = 11;

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

  final SportsComplexSort? sort;
  final bool descending;
  final ValueChanged<SportsComplexSort> onSort;

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
            label: 'Complex name',
            flex: _Columns.name,
            column: SportsComplexSort.name,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'City',
            flex: _Columns.city,
            column: SportsComplexSort.city,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'State',
            flex: _Columns.state,
            column: SportsComplexSort.state,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          const _HeaderCell(label: 'Contact phone', flex: _Columns.phone),
          const _HeaderCell(label: 'Contact email', flex: _Columns.email),
          const _HeaderCell(label: 'Opening hours', flex: _Columns.hours),
          _HeaderCell(
            label: 'Status',
            flex: _Columns.status,
            column: SportsComplexSort.status,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Show on frontend',
            flex: _Columns.frontend,
            column: SportsComplexSort.visibility,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Created',
            flex: _Columns.created,
            column: SportsComplexSort.created,
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
  final SportsComplexSort? column;
  final SportsComplexSort? sort;
  final bool descending;
  final ValueChanged<SportsComplexSort>? onSort;

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
    required this.complex,
    required this.selected,
    required this.busy,
    required this.onAction,
    required this.onToggleVisibility,
  });

  final AdminSportsComplex complex;
  final bool selected;
  final bool busy;
  final void Function(SportsComplexAction action, AdminSportsComplex complex)
  onAction;
  final void Function(AdminSportsComplex complex, bool showOnFrontend)
  onToggleVisibility;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final complex = widget.complex;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onAction(SportsComplexAction.view, complex),
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
                  child: ComplexThumb(complex: complex, size: 40),
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
                        complex.displayName,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if ((complex.address ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          complex.address!.trim(),
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
                AdminFormat.text(complex.city),
                _Columns.city,
                weight: FontWeight.w600,
              ),
              _TextCell(AdminFormat.text(complex.state), _Columns.state),
              _TextCell(AdminFormat.text(complex.contactPhone), _Columns.phone),
              _TextCell(AdminFormat.text(complex.contactEmail), _Columns.email),
              _TextCell(
                AdminFormat.text(complex.openingHours),
                _Columns.hours,
              ),
              Expanded(
                flex: _Columns.status,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ComplexStatusBadge(complex: complex, dense: true),
                  ),
                ),
              ),
              Expanded(
                flex: _Columns.frontend,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FrontendVisibilitySwitch(
                      complex: complex,
                      busy: widget.busy,
                      onChanged: (value) =>
                          widget.onToggleVisibility(complex, value),
                    ),
                  ),
                ),
              ),
              _TextCell(AdminFormat.date(complex.createdAt), _Columns.created),
              SizedBox(
                width: _Columns.actions,
                child: SportsComplexRowActions(
                  complex: complex,
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

/// The venue photo, falling back to initials on a deterministic gradient — the
/// same treatment the staff avatars use, so a venue with no image still reads
/// as a record rather than a hole in the table.
class ComplexThumb extends StatelessWidget {
  const ComplexThumb({super.key, required this.complex, this.size = 40});

  final AdminSportsComplex complex;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final gradient = tokens.avatarGradient('${complex.id}${complex.name ?? ''}');

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
        complex.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
        ),
      ),
    );

    final url = complex.imageUrl;
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

class ComplexStatusBadge extends StatelessWidget {
  const ComplexStatusBadge({
    super.key,
    required this.complex,
    this.dense = false,
  });

  final AdminSportsComplex complex;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final color = tokens.statusColor(complex.status);
    final label = complex.statusLabel.isEmpty
        ? AdminFormat.dash
        : complex.statusLabel;

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
/// A venue whose payload never said is shown as an em dash beside an off
/// switch — flipping it on is still a legitimate write, so the control stays
/// live rather than being disabled on missing data.
class FrontendVisibilitySwitch extends StatelessWidget {
  const FrontendVisibilitySwitch({
    super.key,
    required this.complex,
    required this.busy,
    required this.onChanged,
    this.showLabel = true,
  });

  final AdminSportsComplex complex;
  final bool busy;
  final ValueChanged<bool> onChanged;
  final bool showLabel;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final value = complex.showOnFrontend;
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

/// View / Edit / Delete, plus the status submenu behind "More".
class SportsComplexRowActions extends StatelessWidget {
  const SportsComplexRowActions({
    super.key,
    required this.complex,
    required this.onAction,
    required this.visible,
  });

  final AdminSportsComplex complex;
  final void Function(SportsComplexAction action, AdminSportsComplex complex)
  onAction;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final isActive = complex.isActive;

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
            onPressed: () => onAction(SportsComplexAction.view, complex),
            icon: const Icon(Icons.visibility_outlined, size: 17),
            tooltip: 'View details',
            color: tokens.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
          ),
          PopupMenuButton<SportsComplexAction>(
            tooltip: 'More actions',
            icon: Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: tokens.textMuted,
            ),
            padding: EdgeInsets.zero,
            onSelected: (action) => onAction(action, complex),
            itemBuilder: (context) => <PopupMenuEntry<SportsComplexAction>>[
              _item(
                SportsComplexAction.edit,
                Icons.edit_outlined,
                'Edit complex',
                tokens.textPrimary,
              ),
              const PopupMenuDivider(),
              // Only the status it is not already in is offered, so the menu
              // never presents a no-op.
              if (!isActive)
                _item(
                  SportsComplexAction.setActive,
                  Icons.check_circle_outline_rounded,
                  'Mark as Active',
                  tokens.success,
                ),
              if (isActive)
                _item(
                  SportsComplexAction.setInactive,
                  Icons.pause_circle_outline_rounded,
                  'Mark as Inactive',
                  tokens.warning,
                ),
              const PopupMenuDivider(),
              _item(
                SportsComplexAction.delete,
                Icons.delete_outline_rounded,
                'Delete complex',
                tokens.danger,
              ),
            ]
              .gatedBy(
                AdminModules.sportsComplex,
                isDestructive: (a) => a == SportsComplexAction.delete,
                isReadOnly: (a) => a == SportsComplexAction.view,
              ),
          ),
        ],
      ),
    );
  }

  PopupMenuItem<SportsComplexAction> _item(
    SportsComplexAction value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem<SportsComplexAction>(
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
class SportsComplexCard extends StatelessWidget {
  const SportsComplexCard({
    super.key,
    required this.complex,
    required this.busy,
    required this.onAction,
    required this.onToggleVisibility,
  });

  final AdminSportsComplex complex;
  final bool busy;
  final void Function(SportsComplexAction action, AdminSportsComplex complex)
  onAction;
  final void Function(AdminSportsComplex complex, bool showOnFrontend)
  onToggleVisibility;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return InkWell(
      onTap: () => onAction(SportsComplexAction.view, complex),
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
                ComplexThumb(complex: complex, size: 48),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        complex.displayName,
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
                          if ((complex.city ?? '').trim().isNotEmpty)
                            complex.city!.trim(),
                          if ((complex.state ?? '').trim().isNotEmpty)
                            complex.state!.trim(),
                        ].join(', '),
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
                SportsComplexRowActions(
                  complex: complex,
                  onAction: onAction,
                  visible: true,
                ),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Row(
              children: [
                ComplexStatusBadge(complex: complex, dense: true),
                const Spacer(),
                FrontendVisibilitySwitch(
                  complex: complex,
                  busy: busy,
                  onChanged: (value) => onToggleVisibility(complex, value),
                ),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Phone',
                    value: AdminFormat.text(complex.contactPhone),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Hours',
                    value: AdminFormat.text(complex.openingHours),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Created',
                    value: AdminFormat.date(complex.createdAt),
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
