import 'package:flutter/material.dart';

import '../../domain/entities/complex_admin.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';

/// What a complex-admin row can be asked to do.
enum ComplexAdminAction { view, edit, delete }

/// The desktop/tablet table. Same construction as the users table — a hand-built
/// header/row pair inside a horizontal scroll, so columns never squeeze.
class ComplexAdminsTable extends StatefulWidget {
  const ComplexAdminsTable({
    super.key,
    required this.admins,
    required this.onAction,
    this.selectedId,
  });

  final List<ComplexAdmin> admins;
  final void Function(ComplexAdminAction action, ComplexAdmin admin) onAction;
  final String? selectedId;

  static const double _minWidth = 980;

  @override
  State<ComplexAdminsTable> createState() => _ComplexAdminsTableState();
}

class _ComplexAdminsTableState extends State<ComplexAdminsTable> {
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
        final overflows = constraints.maxWidth < ComplexAdminsTable._minWidth;
        final width = overflows
            ? ComplexAdminsTable._minWidth
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
                  const _HeaderRow(),
                  ...widget.admins.map(
                    (admin) => _Row(
                      key: ValueKey<String>(admin.id),
                      admin: admin,
                      selected: admin.id == widget.selectedId,
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

/// Column widths shared by the header and every row.
class _Columns {
  const _Columns._();

  static const int name = 24;
  static const int email = 20;
  static const int phone = 13;
  static const int complex = 20;
  static const int city = 12;
  static const int status = 11;
  static const int created = 12;
  static const double actions = 56;
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow();

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
        children: const [
          _HeaderCell('Name', _Columns.name),
          _HeaderCell('Email', _Columns.email),
          _HeaderCell('Phone', _Columns.phone),
          _HeaderCell('Sport complex', _Columns.complex),
          _HeaderCell('City', _Columns.city),
          _HeaderCell('Status', _Columns.status),
          _HeaderCell('Created', _Columns.created),
          SizedBox(width: _Columns.actions),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  const _HeaderCell(this.label, this.flex);

  final String label;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Expanded(
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
  }
}

class _Row extends StatefulWidget {
  const _Row({
    super.key,
    required this.admin,
    required this.selected,
    required this.onAction,
  });

  final ComplexAdmin admin;
  final bool selected;
  final void Function(ComplexAdminAction action, ComplexAdmin admin) onAction;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final admin = widget.admin;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onAction(ComplexAdminAction.view, admin),
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
                      ComplexAdminAvatar(admin: admin, size: 34),
                      const SizedBox(width: AdminTokens.space3),
                      Expanded(
                        child: Text(
                          admin.displayName,
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
              _TextCell(AdminFormat.text(admin.email), _Columns.email),
              _TextCell(AdminFormat.text(admin.phone), _Columns.phone),
              _TextCell(
                AdminFormat.text(admin.sportComplexName),
                _Columns.complex,
                weight: FontWeight.w600,
              ),
              _TextCell(AdminFormat.text(admin.city), _Columns.city),
              Expanded(
                flex: _Columns.status,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ComplexAdminStatusBadge(admin: admin, dense: true),
                  ),
                ),
              ),
              _TextCell(AdminFormat.date(admin.createdAt), _Columns.created),
              SizedBox(
                width: _Columns.actions,
                child: ComplexAdminRowActions(
                  admin: admin,
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

/// Initials on a deterministic gradient — complex admins carry no picture.
class ComplexAdminAvatar extends StatelessWidget {
  const ComplexAdminAvatar({super.key, required this.admin, this.size = 36});

  final ComplexAdmin admin;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final gradient = tokens.avatarGradient(
      admin.id.isEmpty ? admin.displayName : admin.id,
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
        admin.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class ComplexAdminStatusBadge extends StatelessWidget {
  const ComplexAdminStatusBadge({
    super.key,
    required this.admin,
    this.dense = false,
  });

  final ComplexAdmin admin;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final color = tokens.statusColor(admin.status);
    final label = admin.statusLabel.isEmpty
        ? AdminFormat.dash
        : admin.statusLabel;

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

class ComplexAdminRowActions extends StatelessWidget {
  const ComplexAdminRowActions({
    super.key,
    required this.admin,
    required this.onAction,
    required this.visible,
  });

  final ComplexAdmin admin;
  final void Function(ComplexAdminAction action, ComplexAdmin admin) onAction;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return AnimatedOpacity(
      // Always in the tree so the row height is stable and the menu stays
      // reachable where hover does not exist.
      duration: AdminTokens.fast,
      opacity: visible ? 1 : 0.35,
      child: PopupMenuButton<ComplexAdminAction>(
        tooltip: 'Actions',
        icon: Icon(Icons.more_horiz_rounded, size: 18, color: tokens.textMuted),
        padding: EdgeInsets.zero,
        onSelected: (action) => onAction(action, admin),
        itemBuilder: (context) => [
          _item(
            ComplexAdminAction.view,
            Icons.visibility_outlined,
            'View details',
            tokens.textPrimary,
          ),
          _item(
            ComplexAdminAction.edit,
            Icons.edit_outlined,
            'Edit admin',
            tokens.textPrimary,
          ),
          const PopupMenuDivider(),
          _item(
            ComplexAdminAction.delete,
            Icons.delete_outline_rounded,
            'Delete admin',
            tokens.danger,
          ),
        ],
      ),
    );
  }

  PopupMenuItem<ComplexAdminAction> _item(
    ComplexAdminAction value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem<ComplexAdminAction>(
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
class ComplexAdminCard extends StatelessWidget {
  const ComplexAdminCard({
    super.key,
    required this.admin,
    required this.onAction,
  });

  final ComplexAdmin admin;
  final void Function(ComplexAdminAction action, ComplexAdmin admin) onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return InkWell(
      onTap: () => onAction(ComplexAdminAction.view, admin),
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
                ComplexAdminAvatar(admin: admin, size: 42),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        admin.displayName,
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
                        AdminFormat.text(admin.email),
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
                ComplexAdminRowActions(
                  admin: admin,
                  onAction: onAction,
                  visible: true,
                ),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.stadium_outlined,
                        size: 14,
                        color: tokens.textMuted,
                      ),
                      const SizedBox(width: AdminTokens.space2),
                      Expanded(
                        child: Text(
                          admin.venueLabel.isEmpty
                              ? AdminFormat.dash
                              : admin.venueLabel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AdminTokens.space3),
                ComplexAdminStatusBadge(admin: admin, dense: true),
              ],
            ),
            const SizedBox(height: AdminTokens.space2),
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 13, color: tokens.textMuted),
                const SizedBox(width: AdminTokens.space2),
                Text(
                  AdminFormat.text(admin.phone),
                  style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                ),
                const SizedBox(width: AdminTokens.space4),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 12,
                  color: tokens.textMuted,
                ),
                const SizedBox(width: AdminTokens.space2),
                Text(
                  AdminFormat.date(admin.createdAt),
                  style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
