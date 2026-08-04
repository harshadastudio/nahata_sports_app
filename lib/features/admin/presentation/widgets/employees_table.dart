import 'package:flutter/material.dart';

import '../../domain/entities/employee.dart';
import '../state/employees_controller.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';

/// What an employee row can be asked to do.
enum EmployeeAction { view, edit, delete, viewPassword, resetPassword }

/// The desktop/tablet table.
///
/// Same construction as the users and complex-admin tables: a hand-built
/// header/row pair inside one horizontal scroll, so twelve columns never
/// squeeze into unreadable slivers.
class EmployeesTable extends StatefulWidget {
  const EmployeesTable({
    super.key,
    required this.employees,
    required this.sort,
    required this.descending,
    required this.onSort,
    required this.onAction,
    this.selectedId,
  });

  final List<Employee> employees;
  final EmployeeSort? sort;
  final bool descending;
  final ValueChanged<EmployeeSort> onSort;
  final void Function(EmployeeAction action, Employee employee) onAction;
  final String? selectedId;

  /// Twelve columns need real room; below this the table scrolls sideways.
  static const double _minWidth = 1480;

  @override
  State<EmployeesTable> createState() => _EmployeesTableState();
}

class _EmployeesTableState extends State<EmployeesTable> {
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
        final overflows = constraints.maxWidth < EmployeesTable._minWidth;
        final width = overflows
            ? EmployeesTable._minWidth
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
                  ...widget.employees.map(
                    (employee) => _Row(
                      key: ValueKey<String>(employee.id),
                      employee: employee,
                      selected: employee.id == widget.selectedId,
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
  static const int department = 12;
  static const int designation = 11;
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

  final EmployeeSort? sort;
  final bool descending;
  final ValueChanged<EmployeeSort> onSort;

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
            label: 'Employee ID',
            flex: _Columns.code,
            column: EmployeeSort.code,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Name',
            flex: _Columns.name,
            column: EmployeeSort.name,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Email',
            flex: _Columns.email,
            column: EmployeeSort.email,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          const _HeaderCell(label: 'Phone', flex: _Columns.phone),
          const _HeaderCell(label: 'Sport complex', flex: _Columns.complex),
          _HeaderCell(
            label: 'Department',
            flex: _Columns.department,
            column: EmployeeSort.department,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Designation',
            flex: _Columns.designation,
            column: EmployeeSort.designation,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Shift',
            flex: _Columns.shift,
            column: EmployeeSort.shift,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Salary',
            flex: _Columns.salary,
            column: EmployeeSort.salary,
            sort: sort,
            descending: descending,
            onSort: onSort,
            alignEnd: true,
          ),
          _HeaderCell(
            label: 'Status',
            flex: _Columns.status,
            column: EmployeeSort.status,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Joined',
            flex: _Columns.joining,
            column: EmployeeSort.joining,
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
  final EmployeeSort? column;
  final EmployeeSort? sort;
  final bool descending;
  final ValueChanged<EmployeeSort>? onSort;
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
    required this.employee,
    required this.selected,
    required this.onAction,
  });

  final Employee employee;
  final bool selected;
  final void Function(EmployeeAction action, Employee employee) onAction;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final employee = widget.employee;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onAction(EmployeeAction.view, employee),
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
                    child: EmployeeCodeChip(employee: employee),
                  ),
                ),
              ),
              Expanded(
                flex: _Columns.name,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Row(
                    children: [
                      EmployeeAvatar(employee: employee, size: 32),
                      const SizedBox(width: AdminTokens.space3),
                      Expanded(
                        child: Text(
                          employee.displayName,
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
              _TextCell(AdminFormat.text(employee.email), _Columns.email),
              _TextCell(AdminFormat.text(employee.phone), _Columns.phone),
              _TextCell(
                AdminFormat.text(employee.sportComplexName),
                _Columns.complex,
                weight: FontWeight.w600,
              ),
              _TextCell(
                employee.departmentRaw == null
                    ? AdminFormat.dash
                    : employee.departmentLabel,
                _Columns.department,
              ),
              _TextCell(
                employee.designationRaw == null
                    ? AdminFormat.dash
                    : employee.designationLabel,
                _Columns.designation,
              ),
              Expanded(
                flex: _Columns.shift,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ShiftChip(employee: employee),
                  ),
                ),
              ),
              _TextCell(
                AdminFormat.currency(employee.salary),
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
                    child: EmployeeStatusBadge(employee: employee, dense: true),
                  ),
                ),
              ),
              _TextCell(
                AdminFormat.date(employee.joiningDate),
                _Columns.joining,
              ),
              SizedBox(
                width: _Columns.actions,
                child: EmployeeRowActions(
                  employee: employee,
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

/// The staff number, in a monospace chip so codes line up down the column.
class EmployeeCodeChip extends StatelessWidget {
  const EmployeeCodeChip({super.key, required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final code = (employee.employeeCode ?? '').trim();

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

/// Initials on a deterministic gradient — employees carry no picture.
class EmployeeAvatar extends StatelessWidget {
  const EmployeeAvatar({super.key, required this.employee, this.size = 36});

  final Employee employee;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final gradient = tokens.avatarGradient(
      employee.id.isEmpty ? employee.displayName : employee.id,
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
        employee.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Shift chip, coloured by time of day so a rota reads at a glance.
class ShiftChip extends StatelessWidget {
  const ShiftChip({super.key, required this.employee, this.dense = true});

  final Employee employee;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final raw = (employee.shiftRaw ?? '').trim();

    if (raw.isEmpty) {
      return Text(
        AdminFormat.dash,
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    final color = switch (employee.shift?.name) {
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
        employee.shiftLabel,
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

class EmployeeStatusBadge extends StatelessWidget {
  const EmployeeStatusBadge({
    super.key,
    required this.employee,
    this.dense = false,
  });

  final Employee employee;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final color = tokens.statusColor(employee.status);
    final label = employee.statusLabel.isEmpty
        ? AdminFormat.dash
        : employee.statusLabel;

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
class EmployeeRowActions extends StatelessWidget {
  const EmployeeRowActions({
    super.key,
    required this.employee,
    required this.onAction,
    required this.visible,
  });

  final Employee employee;
  final void Function(EmployeeAction action, Employee employee) onAction;
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
            onPressed: () => onAction(EmployeeAction.view, employee),
            icon: const Icon(Icons.visibility_outlined, size: 17),
            tooltip: 'View details',
            color: tokens.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
          ),
          PopupMenuButton<EmployeeAction>(
            tooltip: 'More actions',
            icon: Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: tokens.textMuted,
            ),
            padding: EdgeInsets.zero,
            onSelected: (action) => onAction(action, employee),
            itemBuilder: (context) => [
              _item(
                EmployeeAction.edit,
                Icons.edit_outlined,
                'Edit employee',
                tokens.textPrimary,
              ),
              const PopupMenuDivider(),
              _item(
                EmployeeAction.viewPassword,
                Icons.key_outlined,
                'View password',
                tokens.textPrimary,
              ),
              _item(
                EmployeeAction.resetPassword,
                Icons.lock_reset_rounded,
                'Reset password',
                tokens.textPrimary,
              ),
              const PopupMenuDivider(),
              _item(
                EmployeeAction.delete,
                Icons.delete_outline_rounded,
                'Delete employee',
                tokens.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<EmployeeAction> _item(
    EmployeeAction value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem<EmployeeAction>(
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
class EmployeeCard extends StatelessWidget {
  const EmployeeCard({
    super.key,
    required this.employee,
    required this.onAction,
  });

  final Employee employee;
  final void Function(EmployeeAction action, Employee employee) onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return InkWell(
      onTap: () => onAction(EmployeeAction.view, employee),
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
                EmployeeAvatar(employee: employee, size: 42),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        employee.displayName,
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
                        AdminFormat.text(employee.email),
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
                EmployeeRowActions(
                  employee: employee,
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
                EmployeeCodeChip(employee: employee),
                EmployeeStatusBadge(employee: employee, dense: true),
                ShiftChip(employee: employee),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Department',
                    value: employee.departmentRaw == null
                        ? AdminFormat.dash
                        : employee.departmentLabel,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Designation',
                    value: employee.designationRaw == null
                        ? AdminFormat.dash
                        : employee.designationLabel,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Salary',
                    value: AdminFormat.currency(employee.salary),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Joined',
                    value: AdminFormat.date(employee.joiningDate),
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
