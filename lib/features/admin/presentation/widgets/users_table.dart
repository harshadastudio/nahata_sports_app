import 'package:flutter/material.dart';

import '../../domain/entities/admin_user.dart';
import '../state/admin_users_controller.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'admin_badges.dart';

/// What each row can be asked to do.
enum UserRowAction { view, edit, delete }

/// The desktop/tablet data table.
///
/// A hand-built table rather than [DataTable]: the design needs per-cell
/// widgets, hover states, a sticky header and a horizontal scroll that keeps
/// the header aligned with the body, none of which `DataTable` gives cheaply.
///
/// Below [_minWidth] the whole table scrolls sideways as one unit, so columns
/// never squeeze into unreadable slivers.
class UsersTable extends StatefulWidget {
  const UsersTable({
    super.key,
    required this.users,
    required this.sort,
    required this.descending,
    required this.onSort,
    required this.onAction,
    this.selectedId,
  });

  final List<AdminUser> users;
  final UserSort? sort;
  final bool descending;
  final ValueChanged<UserSort> onSort;
  final void Function(UserRowAction action, AdminUser user) onAction;
  final String? selectedId;

  static const double _minWidth = 1180;

  @override
  State<UsersTable> createState() => _UsersTableState();
}

class _UsersTableState extends State<UsersTable> {
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
        final overflows = constraints.maxWidth < UsersTable._minWidth;
        final width = overflows ? UsersTable._minWidth : constraints.maxWidth;

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
                  ...widget.users.map(
                    (user) => _UserRow(
                      key: ValueKey<String>(user.id),
                      user: user,
                      selected: user.id == widget.selectedId,
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

/// Column layout, shared by the header and every row so they cannot drift.
class _Columns {
  const _Columns._();

  static const int name = 26; // includes the avatar
  static const int email = 19;
  static const int phone = 12;
  static const int role = 11;
  static const int membership = 10;
  static const int bookings = 7;
  static const int status = 9;
  static const int joined = 10;
  static const int lastActive = 10;
  static const double actions = 56;
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.sort,
    required this.descending,
    required this.onSort,
  });

  final UserSort? sort;
  final bool descending;
  final ValueChanged<UserSort> onSort;

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
            label: 'User',
            flex: _Columns.name,
            column: UserSort.name,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Email',
            flex: _Columns.email,
            column: UserSort.email,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          const _HeaderCell(label: 'Phone', flex: _Columns.phone),
          _HeaderCell(
            label: 'Role',
            flex: _Columns.role,
            column: UserSort.role,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Membership',
            flex: _Columns.membership,
            column: UserSort.membership,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Bookings',
            flex: _Columns.bookings,
            column: UserSort.bookings,
            sort: sort,
            descending: descending,
            onSort: onSort,
            alignEnd: true,
          ),
          _HeaderCell(
            label: 'Status',
            flex: _Columns.status,
            column: UserSort.status,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Joined',
            flex: _Columns.joined,
            column: UserSort.joined,
            sort: sort,
            descending: descending,
            onSort: onSort,
          ),
          _HeaderCell(
            label: 'Last active',
            flex: _Columns.lastActive,
            column: UserSort.lastActive,
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
  final UserSort? column;
  final UserSort? sort;
  final bool descending;
  final ValueChanged<UserSort>? onSort;
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

class _UserRow extends StatefulWidget {
  const _UserRow({
    super.key,
    required this.user,
    required this.selected,
    required this.onAction,
  });

  final AdminUser user;
  final bool selected;
  final void Function(UserRowAction action, AdminUser user) onAction;

  @override
  State<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends State<_UserRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final user = widget.user;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onAction(UserRowAction.view, user),
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
                flex: _Columns.name,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Row(
                    children: [
                      AdminAvatar(user: user, size: 34),
                      const SizedBox(width: AdminTokens.space3),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                                height: 1.25,
                              ),
                            ),
                            if (user.isEmployeeLike &&
                                (user.employeeId ?? '').isNotEmpty)
                              Text(
                                'ID ${user.employeeId}',
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _TextCell(AdminFormat.text(user.email), flex: _Columns.email),
              _TextCell(AdminFormat.text(user.phone), flex: _Columns.phone),
              _Cell(
                flex: _Columns.role,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: RoleChip(roleRaw: user.roleRaw, dense: true),
                ),
              ),
              _Cell(
                flex: _Columns.membership,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: MembershipChip(
                    membership: user.membership,
                    dense: true,
                  ),
                ),
              ),
              _TextCell(
                AdminFormat.number(user.totalBookings),
                flex: _Columns.bookings,
                alignEnd: true,
                weight: FontWeight.w600,
              ),
              _Cell(
                flex: _Columns.status,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: StatusBadge(user: user, dense: true),
                ),
              ),
              _TextCell(AdminFormat.date(user.joinedAt), flex: _Columns.joined),
              _Cell(
                flex: _Columns.lastActive,
                child: Tooltip(
                  message: AdminFormat.dateTime(user.lastActiveAt),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      AdminFormat.relative(user.lastActiveAt),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: _Columns.actions,
                child: _RowActions(
                  user: user,
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

class _Cell extends StatelessWidget {
  const _Cell({required this.flex, required this.child});

  final int flex;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(right: AdminTokens.space3),
        child: child,
      ),
    );
  }
}

class _TextCell extends StatelessWidget {
  const _TextCell(
    this.value, {
    required this.flex,
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
    return _Cell(
      flex: flex,
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
    );
  }
}

class _RowActions extends StatelessWidget {
  const _RowActions({
    required this.user,
    required this.onAction,
    required this.visible,
  });

  final AdminUser user;
  final void Function(UserRowAction action, AdminUser user) onAction;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return AnimatedOpacity(
      // Kept in the tree at all times so the row height never shifts, and so
      // the menu stays reachable by keyboard/touch where hover does not exist.
      duration: AdminTokens.fast,
      opacity: visible ? 1 : 0.35,
      child: PopupMenuButton<UserRowAction>(
        tooltip: 'Actions',
        icon: Icon(Icons.more_horiz_rounded, size: 18, color: tokens.textMuted),
        padding: EdgeInsets.zero,
        onSelected: (action) => onAction(action, user),
        itemBuilder: (context) => [
          _menuItem(
            context,
            UserRowAction.view,
            Icons.visibility_outlined,
            'View details',
            tokens.textPrimary,
          ),
          _menuItem(
            context,
            UserRowAction.edit,
            Icons.edit_outlined,
            'Edit user',
            tokens.textPrimary,
          ),
          const PopupMenuDivider(),
          _menuItem(
            context,
            UserRowAction.delete,
            Icons.delete_outline_rounded,
            'Delete user',
            tokens.danger,
          ),
        ],
      ),
    );
  }

  PopupMenuItem<UserRowAction> _menuItem(
    BuildContext context,
    UserRowAction value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem<UserRowAction>(
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
class UserCard extends StatelessWidget {
  const UserCard({super.key, required this.user, required this.onAction});

  final AdminUser user;
  final void Function(UserRowAction action, AdminUser user) onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return InkWell(
      onTap: () => onAction(UserRowAction.view, user),
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
                AdminAvatar(user: user, size: 42),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user.displayName,
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
                        AdminFormat.text(user.email),
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
                _RowActions(user: user, onAction: onAction, visible: true),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Wrap(
              spacing: AdminTokens.space2,
              runSpacing: AdminTokens.space2,
              children: [
                RoleChip(roleRaw: user.roleRaw, dense: true),
                StatusBadge(user: user, dense: true),
                if ((user.membership ?? '').isNotEmpty)
                  MembershipChip(membership: user.membership, dense: true),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    label: 'Phone',
                    value: AdminFormat.text(user.phone),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Bookings',
                    value: AdminFormat.number(user.totalBookings),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Joined',
                    value: AdminFormat.date(user.joinedAt),
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Active',
                    value: AdminFormat.relative(user.lastActiveAt),
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
