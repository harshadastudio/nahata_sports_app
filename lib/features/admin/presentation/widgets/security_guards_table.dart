import 'package:flutter/material.dart';

import '../../domain/entities/security_guard.dart';
import '../state/security_guards_controller.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';

/// What a security guard row can be asked to do.
enum SecurityGuardAction { view, edit, delete, viewPassword, resetPassword }

/// The desktop/tablet table.
///
/// Same construction as the employees table: a hand-built header/row pair
/// inside one horizontal scroll, so eleven columns never squeeze into
/// unreadable slivers.
class SecurityGuardsTable extends StatefulWidget {
  const SecurityGuardsTable({
    super.key,
    required this.guards,
    required this.sort,
    required this.descending,
    required this.onSort,
    required this.onAction,
    this.selectedId,
  });

  final List<SecurityGuard> guards;
  final SecurityGuardSort? sort;
  final bool descending;
  final ValueChanged<SecurityGuardSort> onSort;
  final void Function(SecurityGuardAction action, SecurityGuard guard) onAction;
  final String? selectedId;

  /// Eleven columns need real room; below this the table scrolls sideways.
  static const double _minWidth = 1480;

  @override
  State<SecurityGuardsTable> createState() => _SecurityGuardsTableState();
}

class _SecurityGuardsTableState extends State<SecurityGuardsTable> {
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
        final overflows = constraints.maxWidth < SecurityGuardsTable._minWidth;
        final width = overflows
            ? SecurityGuardsTable._minWidth
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
                  ...widget.guards.map(
                    (guard) => _Row(
                      key: ValueKey<String>(guard.id),
                      guard: guard,
                      selected: guard.id == widget.selectedId,
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

  static const int code = 9;
  static const int name = 18;
  static const int email = 17;
  static const int phone = 11;
  static const int complex = 14;
  static const int area = 13;
  static const int shift = 9;
  static const int salary = 10;
  static const int status = 9;
  static const int joining = 10;

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

  final SecurityGuardSort? sort;
  final bool descending;
  final ValueChanged<SecurityGuardSort> onSort;

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
          _HeaderCell(
            label: 'Guard ID',
            flex: _Columns.code,
            column: SecurityGuardSort.code,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Guard name',
            flex: _Columns.name,
            column: SecurityGuardSort.name,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Email',
            flex: _Columns.email,
            column: SecurityGuardSort.email,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          const _HeaderCell(label: 'Phone number', flex: _Columns.phone),
          const _HeaderCell(label: 'Sport complex', flex: _Columns.complex),
          _HeaderCell(
            label: 'Assigned area',
            flex: _Columns.area,
            column: SecurityGuardSort.area,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Shift',
            flex: _Columns.shift,
            column: SecurityGuardSort.shift,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Salary',
            flex: _Columns.salary,
            column: SecurityGuardSort.salary,
            sort: sort,
            descending: descending,
            onSort: onSort,
            alignEnd: true,
          ),
          _HeaderCell(
            label: 'Status',
            flex: _Columns.status,
            column: SecurityGuardSort.status,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Joining date',
            flex: _Columns.joining,
            column: SecurityGuardSort.joining,
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
    this.alignEnd = false,
  });

  final String label;
  final int flex;
  final SecurityGuardSort? column;
  final SecurityGuardSort? sort;
  final bool descending;
  final ValueChanged<SecurityGuardSort>? onSort;
  final bool alignEnd;

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
      mainAxisAlignment: widget.alignEnd
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
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
    required this.guard,
    required this.selected,
    required this.onAction,
  });

  final SecurityGuard guard;
  final bool selected;
  final void Function(SecurityGuardAction action, SecurityGuard guard) onAction;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final guard = widget.guard;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onAction(SecurityGuardAction.view, guard),
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
                flex: _Columns.code,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GuardCodeChip(guard: guard),
                  ),
                ),
              ),
              Expanded(
                flex: _Columns.name,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Row(
                    children: [
                      GuardAvatar(guard: guard, size: 32),
                      const SizedBox(width: AdminTokens.space3),
                      Expanded(
                        child: Text(
                          guard.displayName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _TextCell(AdminFormat.text(guard.email), _Columns.email),
              _TextCell(AdminFormat.text(guard.phone), _Columns.phone),
              _TextCell(
                AdminFormat.text(guard.sportComplexName),
                _Columns.complex,
                weight: FontWeight.w600,
              ),
              Expanded(
                flex: _Columns.area,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: AssignedAreaChip(guard: guard),
                  ),
                ),
              ),
              Expanded(
                flex: _Columns.shift,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GuardShiftChip(guard: guard),
                  ),
                ),
              ),
              _TextCell(
                AdminFormat.currency(guard.salary),
                _Columns.salary,
                alignEnd: true,
                weight: FontWeight.w600,
              ),
              Expanded(
                flex: _Columns.status,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: GuardStatusBadge(guard: guard, dense: true),
                  ),
                ),
              ),
              _TextCell(AdminFormat.date(guard.joiningDate), _Columns.joining),
              SizedBox(
                width: _Columns.actions,
                child: SecurityGuardRowActions(
                  guard: guard,
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
  const _TextCell(
    this.value,
    this.flex, {
    this.alignEnd = false,
    this.weight = FontWeight.w400,
  });

  final String value;
  final int flex;
  final bool alignEnd;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: AdminTokens.space3),
        child: Align(
          alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
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

/// The badge number, in a monospace chip so codes line up down the column.
class GuardCodeChip extends StatelessWidget {
  const GuardCodeChip({super.key, required this.guard});

  final SecurityGuard guard;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final code = (guard.guardCode ?? '').trim();

    if (code.isEmpty) {
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
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
        border: Border.all(color: tokens.border),
      ),
      child: Text(
        code,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: tokens.textSecondary,
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          fontFamily: 'monospace',
          height: 1.2,
        ),
      ),
    );
  }
}

/// Initials on a deterministic gradient — guards carry no picture.
class GuardAvatar extends StatelessWidget {
  const GuardAvatar({super.key, required this.guard, this.size = 36});

  final SecurityGuard guard;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final gradient = tokens.avatarGradient(
      guard.id.isEmpty ? guard.displayName : guard.id,
    );

    return Container(
      width: size,
      height: size,
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
        guard.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The patrol area, in a neutral chip so it reads as a posting rather than an
/// ordinary text cell.
class AssignedAreaChip extends StatelessWidget {
  const AssignedAreaChip({super.key, required this.guard});

  final SecurityGuard guard;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    // Through the vocabulary, so a row stored as `parking` still reads as
    // `Parking` and an unknown value is title-cased rather than shown raw.
    final area = guard.assignedArea == null ? '' : guard.assignedAreaLabel;

    if (area.isEmpty) {
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
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.place_outlined, size: 12, color: tokens.textMuted),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              area,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shift chip, coloured by time of day so a rota reads at a glance.
class GuardShiftChip extends StatelessWidget {
  const GuardShiftChip({super.key, required this.guard, this.dense = true});

  final SecurityGuard guard;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final raw = (guard.shiftRaw ?? '').trim();

    if (raw.isEmpty) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    final color = switch (guard.shift?.name) {
      'morning' => tokens.warning,
      'evening' => const Color(0xFF8B5CF6),
      'night' => tokens.info,
      'rotational' => tokens.success,
      _ => tokens.textMuted,
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
      child: Text(
        guard.shiftLabel,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: dense ? 11 : 12,
          fontWeight: FontWeight.w600,
          height: 1.1,
        ),
      ),
    );
  }
}

class GuardStatusBadge extends StatelessWidget {
  const GuardStatusBadge({super.key, required this.guard, this.dense = false});

  final SecurityGuard guard;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final color = tokens.statusColor(guard.status);
    final label = guard.statusLabel.isEmpty
        ? AdminFormat.dash
        : guard.statusLabel;

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

/// View / Edit / Delete, plus the password submenu behind "More".
class SecurityGuardRowActions extends StatelessWidget {
  const SecurityGuardRowActions({
    super.key,
    required this.guard,
    required this.onAction,
    required this.visible,
  });

  final SecurityGuard guard;
  final void Function(SecurityGuardAction action, SecurityGuard guard) onAction;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

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
            onPressed: () => onAction(SecurityGuardAction.view, guard),
            icon: const Icon(Icons.visibility_outlined, size: 17),
            tooltip: 'View details',
            color: tokens.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
          ),
          PopupMenuButton<SecurityGuardAction>(
            tooltip: 'More actions',
            icon: Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: tokens.textMuted,
            ),
            padding: EdgeInsets.zero,
            onSelected: (action) => onAction(action, guard),
            itemBuilder: (context) => [
              _item(
                SecurityGuardAction.edit,
                Icons.edit_outlined,
                'Edit guard',
                tokens.textPrimary,
              ),
              const PopupMenuDivider(),
              _item(
                SecurityGuardAction.viewPassword,
                Icons.key_outlined,
                'View password',
                tokens.textPrimary,
              ),
              _item(
                SecurityGuardAction.resetPassword,
                Icons.lock_reset_rounded,
                'Reset password',
                tokens.textPrimary,
              ),
              const PopupMenuDivider(),
              _item(
                SecurityGuardAction.delete,
                Icons.delete_outline_rounded,
                'Delete guard',
                tokens.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<SecurityGuardAction> _item(
    SecurityGuardAction value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem<SecurityGuardAction>(
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
class SecurityGuardCard extends StatelessWidget {
  const SecurityGuardCard({
    super.key,
    required this.guard,
    required this.onAction,
  });

  final SecurityGuard guard;
  final void Function(SecurityGuardAction action, SecurityGuard guard) onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return InkWell(
      onTap: () => onAction(SecurityGuardAction.view, guard),
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
                GuardAvatar(guard: guard, size: 42),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        guard.displayName,
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
                        AdminFormat.text(guard.email),
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
                SecurityGuardRowActions(
                  guard: guard,
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
                GuardCodeChip(guard: guard),
                GuardStatusBadge(guard: guard, dense: true),
                GuardShiftChip(guard: guard),
                AssignedAreaChip(guard: guard),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Complex',
                    value: AdminFormat.text(guard.sportComplexName),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Phone',
                    value: AdminFormat.text(guard.phone),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Salary',
                    value: AdminFormat.currency(guard.salary),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Joined',
                    value: AdminFormat.date(guard.joiningDate),
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
