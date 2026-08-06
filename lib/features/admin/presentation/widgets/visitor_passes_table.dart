import 'package:flutter/material.dart';

import '../../domain/entities/visitor_pass.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'visitor_pass_status_chip.dart';

/// What a visitor-pass row can be asked to do.
enum VisitorPassAction {
  view,
  checkIn,
  checkOut,
  share,
  whatsapp,
  email,
  delete,
}

/// The desktop/tablet table — a hand-built header/row pair inside a horizontal
/// scroll, so the columns never squeeze.
class VisitorPassesTable extends StatefulWidget {
  const VisitorPassesTable({
    super.key,
    required this.passes,
    required this.onAction,
    required this.canDelete,
    this.selectedKey,
  });

  final List<VisitorPass> passes;
  final void Function(VisitorPassAction action, VisitorPass pass) onAction;

  /// Delete is ADMIN / COMPLEX_ADMIN only; other roles never see the item.
  final bool canDelete;

  final String? selectedKey;

  static const double _minWidth = 1180;

  @override
  State<VisitorPassesTable> createState() => _VisitorPassesTableState();
}

class _VisitorPassesTableState extends State<VisitorPassesTable> {
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
        final overflows = constraints.maxWidth < VisitorPassesTable._minWidth;
        final width = overflows
            ? VisitorPassesTable._minWidth
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
                  ...widget.passes.map(
                    (pass) => _Row(
                      key: ValueKey<String>(pass.key),
                      pass: pass,
                      selected: pass.key == widget.selectedKey,
                      canDelete: widget.canDelete,
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

  static const int visitor = 22;
  static const int phone = 13;
  static const int purpose = 19;
  static const int code = 14;
  static const int complex = 17;
  static const int created = 14;
  static const int status = 13;
  static const int qr = 9;
  static const int createdBy = 14;
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
          _HeaderCell('Visitor', _Columns.visitor),
          _HeaderCell('Phone', _Columns.phone),
          _HeaderCell('Purpose', _Columns.purpose),
          _HeaderCell('Pass code', _Columns.code),
          _HeaderCell('Sport complex', _Columns.complex),
          _HeaderCell('Generated', _Columns.created),
          _HeaderCell('Created by', _Columns.createdBy),
          _HeaderCell('Status', _Columns.status),
          _HeaderCell('QR', _Columns.qr),
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
    required this.pass,
    required this.selected,
    required this.canDelete,
    required this.onAction,
  });

  final VisitorPass pass;
  final bool selected;
  final bool canDelete;
  final void Function(VisitorPassAction action, VisitorPass pass) onAction;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final pass = widget.pass;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onAction(VisitorPassAction.view, pass),
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
                flex: _Columns.visitor,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Row(
                    children: [
                      VisitorAvatar(pass: pass, size: 34),
                      const SizedBox(width: AdminTokens.space3),
                      Expanded(
                        child: Text(
                          pass.displayName,
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
              _TextCell(AdminFormat.text(pass.phoneNumber), _Columns.phone),
              _TextCell(AdminFormat.text(pass.visitPurpose), _Columns.purpose),
              _TextCell(
                AdminFormat.text(pass.passCode),
                _Columns.code,
                weight: FontWeight.w700,
                mono: true,
              ),
              _TextCell(
                AdminFormat.text(pass.sportComplexName),
                _Columns.complex,
                weight: FontWeight.w600,
              ),
              _TextCell(AdminFormat.dateTime(pass.createdAt), _Columns.created),
              _TextCell(
                AdminFormat.text(pass.createdByName),
                _Columns.createdBy,
              ),
              Expanded(
                flex: _Columns.status,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: VisitorPassStatusChip(pass: pass, dense: true),
                  ),
                ),
              ),
              Expanded(
                flex: _Columns.qr,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: VisitorQrIndicator(pass: pass),
                  ),
                ),
              ),
              SizedBox(
                width: _Columns.actions,
                child: VisitorPassRowActions(
                  pass: pass,
                  canDelete: widget.canDelete,
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
    this.weight = FontWeight.w400,
    this.mono = false,
  });

  final String value;
  final int flex;
  final FontWeight weight;

  /// Pass codes are read out and typed in by hand, so they are spaced for
  /// legibility rather than set in the body font.
  final bool mono;

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
            letterSpacing: mono ? 0.6 : 0,
          ),
        ),
      ),
    );
  }
}

/// Whether the pass carries something that can be rendered as a QR.
class VisitorQrIndicator extends StatelessWidget {
  const VisitorQrIndicator({super.key, required this.pass});

  final VisitorPass pass;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final available = pass.hasQrPayload;
    final color = available ? tokens.success : tokens.textMuted;

    return Tooltip(
      message: available ? 'QR available' : 'No QR for this pass',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            available ? Icons.qr_code_2_rounded : Icons.qr_code_2_outlined,
            size: 16,
            color: color,
          ),
          const SizedBox(width: AdminTokens.space2),
          Text(
            available ? 'Ready' : AdminFormat.dash,
            style: TextStyle(
              color: color,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Initials on a deterministic gradient — visitors carry no picture.
class VisitorAvatar extends StatelessWidget {
  const VisitorAvatar({super.key, required this.pass, this.size = 36});

  final VisitorPass pass;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final gradient = tokens.avatarGradient(
      pass.hasReference ? pass.reference : pass.displayName,
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
        pass.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// The row's overflow menu.
///
/// Check in and check out are offered only for the leg the pass is actually
/// waiting on: a checked-out pass is spent, and offering to scan it again
/// would be inviting a guaranteed rejection.
class VisitorPassRowActions extends StatelessWidget {
  const VisitorPassRowActions({
    super.key,
    required this.pass,
    required this.canDelete,
    required this.onAction,
    required this.visible,
  });

  final VisitorPass pass;
  final bool canDelete;
  final void Function(VisitorPassAction action, VisitorPass pass) onAction;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return AnimatedOpacity(
      // Always in the tree so the row height is stable and the menu stays
      // reachable where hover does not exist.
      duration: AdminTokens.fast,
      opacity: visible ? 1 : 0.35,
      child: PopupMenuButton<VisitorPassAction>(
        tooltip: 'Actions',
        icon: Icon(Icons.more_horiz_rounded, size: 18, color: tokens.textMuted),
        padding: EdgeInsets.zero,
        onSelected: (action) => onAction(action, pass),
        itemBuilder: (context) => [
          _item(
            VisitorPassAction.view,
            Icons.visibility_outlined,
            'View pass',
            tokens.textPrimary,
          ),
          if (pass.canCheckIn)
            _item(
              VisitorPassAction.checkIn,
              Icons.login_rounded,
              'Check in',
              tokens.success,
            ),
          if (pass.canCheckOut)
            _item(
              VisitorPassAction.checkOut,
              Icons.logout_rounded,
              'Check out',
              tokens.info,
            ),
          const PopupMenuDivider(),
          _item(
            VisitorPassAction.share,
            Icons.ios_share_rounded,
            'Share pass',
            tokens.textPrimary,
          ),
          _item(
            VisitorPassAction.whatsapp,
            Icons.chat_bubble_outline_rounded,
            'Send on WhatsApp',
            tokens.textPrimary,
          ),
          _item(
            VisitorPassAction.email,
            Icons.mail_outline_rounded,
            'Send by email',
            tokens.textPrimary,
          ),
          if (canDelete) ...[
            const PopupMenuDivider(),
            _item(
              VisitorPassAction.delete,
              Icons.delete_outline_rounded,
              'Delete pass',
              tokens.danger,
            ),
          ],
        ],
      ),
    );
  }

  PopupMenuItem<VisitorPassAction> _item(
    VisitorPassAction value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem<VisitorPassAction>(
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
class VisitorPassCard extends StatelessWidget {
  const VisitorPassCard({
    super.key,
    required this.pass,
    required this.canDelete,
    required this.onAction,
  });

  final VisitorPass pass;
  final bool canDelete;
  final void Function(VisitorPassAction action, VisitorPass pass) onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return InkWell(
      onTap: () => onAction(VisitorPassAction.view, pass),
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
                VisitorAvatar(pass: pass, size: 42),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        pass.displayName,
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
                        AdminFormat.text(pass.visitPurpose),
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
                VisitorPassRowActions(
                  pass: pass,
                  canDelete: canDelete,
                  onAction: onAction,
                  visible: true,
                ),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Row(
              children: [
                Icon(
                  Icons.qr_code_2_rounded,
                  size: 14,
                  color: tokens.textMuted,
                ),
                const SizedBox(width: AdminTokens.space2),
                Expanded(
                  child: Text(
                    AdminFormat.text(pass.passCode),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                const SizedBox(width: AdminTokens.space3),
                VisitorPassStatusChip(pass: pass, dense: true),
              ],
            ),
            const SizedBox(height: AdminTokens.space2),
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 13, color: tokens.textMuted),
                const SizedBox(width: AdminTokens.space2),
                Text(
                  AdminFormat.text(pass.phoneNumber),
                  style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                ),
                const SizedBox(width: AdminTokens.space4),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 12,
                  color: tokens.textMuted,
                ),
                const SizedBox(width: AdminTokens.space2),
                Expanded(
                  child: Text(
                    AdminFormat.dateTime(pass.createdAt),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                  ),
                ),
              ],
            ),
            if ((pass.sportComplexName ?? '').trim().isNotEmpty) ...[
              const SizedBox(height: AdminTokens.space2),
              Row(
                children: [
                  Icon(
                    Icons.stadium_outlined,
                    size: 13,
                    color: tokens.textMuted,
                  ),
                  const SizedBox(width: AdminTokens.space2),
                  Expanded(
                    child: Text(
                      pass.sportComplexName!.trim(),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
