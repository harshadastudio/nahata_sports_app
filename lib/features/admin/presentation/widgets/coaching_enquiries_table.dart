import 'package:flutter/material.dart';

import '../../domain/entities/coaching_enquiry.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'enquiry_status_chip.dart';

/// What an enquiry row can be asked to do.
enum EnquiryAction {
  view,
  edit,
  assignCoach,
  changeStatus,
  call,
  email,
  delete,
}

/// The desktop/tablet table — a hand-built header/row pair inside a horizontal
/// scroll, so the columns never squeeze.
class CoachingEnquiriesTable extends StatefulWidget {
  const CoachingEnquiriesTable({
    super.key,
    required this.enquiries,
    required this.onAction,
    this.selectedId,
  });

  final List<CoachingEnquiry> enquiries;
  final void Function(EnquiryAction action, CoachingEnquiry enquiry) onAction;
  final int? selectedId;

  static const double _minWidth = 1220;

  @override
  State<CoachingEnquiriesTable> createState() => _CoachingEnquiriesTableState();
}

class _CoachingEnquiriesTableState extends State<CoachingEnquiriesTable> {
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
        final overflows =
            constraints.maxWidth < CoachingEnquiriesTable._minWidth;
        final width = overflows
            ? CoachingEnquiriesTable._minWidth
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
                  ...widget.enquiries.map(
                    (enquiry) => _Row(
                      key: ValueKey<int>(enquiry.id),
                      enquiry: enquiry,
                      selected: enquiry.id == widget.selectedId,
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

  static const int customer = 22;
  static const int phone = 13;
  static const int email = 18;
  static const int sport = 14;
  static const int complex = 16;
  static const int coach = 14;
  static const int status = 12;
  static const int created = 13;
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
          _HeaderCell('Customer', _Columns.customer),
          _HeaderCell('Phone', _Columns.phone),
          _HeaderCell('Email', _Columns.email),
          _HeaderCell('Sport', _Columns.sport),
          _HeaderCell('Sport complex', _Columns.complex),
          _HeaderCell('Assigned coach', _Columns.coach),
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
    required this.enquiry,
    required this.selected,
    required this.onAction,
  });

  final CoachingEnquiry enquiry;
  final bool selected;
  final void Function(EnquiryAction action, CoachingEnquiry enquiry) onAction;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final enquiry = widget.enquiry;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onAction(EnquiryAction.view, enquiry),
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
                flex: _Columns.customer,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Row(
                    children: [
                      EnquirerAvatar(enquiry: enquiry, size: 34),
                      const SizedBox(width: AdminTokens.space3),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              enquiry.displayName,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: tokens.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if ((enquiry.referenceNumber ?? '')
                                .trim()
                                .isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                enquiry.referenceNumber!.trim(),
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: tokens.textMuted,
                                  fontSize: 11,
                                  letterSpacing: 0.4,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _TextCell(AdminFormat.text(enquiry.phone), _Columns.phone),
              _TextCell(AdminFormat.text(enquiry.email), _Columns.email),
              _TextCell(
                AdminFormat.text(enquiry.sportName),
                _Columns.sport,
                weight: FontWeight.w600,
              ),
              _TextCell(
                AdminFormat.text(enquiry.sportComplexName),
                _Columns.complex,
              ),
              Expanded(
                flex: _Columns.coach,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: enquiry.isAssigned
                      ? Text(
                          AdminFormat.text(enquiry.assignedCoachName),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : Text(
                          'Unassigned',
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                ),
              ),
              Expanded(
                flex: _Columns.status,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: EnquiryStatusChip(
                      statusRaw: enquiry.statusRaw,
                      dense: true,
                    ),
                  ),
                ),
              ),
              _TextCell(AdminFormat.date(enquiry.createdAt), _Columns.created),
              SizedBox(
                width: _Columns.actions,
                child: EnquiryRowActions(
                  enquiry: enquiry,
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

/// Initials on a deterministic gradient — enquiries carry no picture.
class EnquirerAvatar extends StatelessWidget {
  const EnquirerAvatar({super.key, required this.enquiry, this.size = 36});

  final CoachingEnquiry enquiry;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final gradient = tokens.avatarGradient(enquiry.id.toString());

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
        enquiry.initials,
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
class EnquiryRowActions extends StatelessWidget {
  const EnquiryRowActions({
    super.key,
    required this.enquiry,
    required this.onAction,
    required this.visible,
  });

  final CoachingEnquiry enquiry;
  final void Function(EnquiryAction action, CoachingEnquiry enquiry) onAction;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    final hasPhone = (enquiry.phone ?? '').trim().isNotEmpty;
    final hasEmail = (enquiry.email ?? '').trim().isNotEmpty;

    return AnimatedOpacity(
      // Always in the tree so the row height is stable and the menu stays
      // reachable where hover does not exist.
      duration: AdminTokens.fast,
      opacity: visible ? 1 : 0.35,
      child: PopupMenuButton<EnquiryAction>(
        tooltip: 'Actions',
        icon: Icon(Icons.more_horiz_rounded, size: 18, color: tokens.textMuted),
        padding: EdgeInsets.zero,
        onSelected: (action) => onAction(action, enquiry),
        itemBuilder: (context) => [
          _item(
            EnquiryAction.view,
            Icons.visibility_outlined,
            'View enquiry',
            tokens.textPrimary,
          ),
          _item(
            EnquiryAction.changeStatus,
            Icons.flag_outlined,
            'Change status',
            tokens.textPrimary,
          ),
          _item(
            EnquiryAction.assignCoach,
            Icons.person_add_alt_1_outlined,
            enquiry.isAssigned ? 'Reassign coach' : 'Assign coach',
            tokens.textPrimary,
          ),
          _item(
            EnquiryAction.edit,
            Icons.edit_note_rounded,
            'Update remarks',
            tokens.textPrimary,
          ),
          if (hasPhone || hasEmail) const PopupMenuDivider(),
          if (hasPhone)
            _item(
              EnquiryAction.call,
              Icons.call_outlined,
              'Call',
              tokens.textPrimary,
            ),
          if (hasEmail)
            _item(
              EnquiryAction.email,
              Icons.mail_outline_rounded,
              'Email',
              tokens.textPrimary,
            ),
          const PopupMenuDivider(),
          _item(
            EnquiryAction.delete,
            Icons.delete_outline_rounded,
            'Delete enquiry',
            tokens.danger,
          ),
        ],
      ),
    );
  }

  PopupMenuItem<EnquiryAction> _item(
    EnquiryAction value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem<EnquiryAction>(
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
class CoachingEnquiryCard extends StatelessWidget {
  const CoachingEnquiryCard({
    super.key,
    required this.enquiry,
    required this.onAction,
  });

  final CoachingEnquiry enquiry;
  final void Function(EnquiryAction action, CoachingEnquiry enquiry) onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return InkWell(
      onTap: () => onAction(EnquiryAction.view, enquiry),
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
                EnquirerAvatar(enquiry: enquiry, size: 42),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        enquiry.displayName,
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
                        enquiry.interestLabel.isEmpty
                            ? AdminFormat.text(enquiry.email)
                            : enquiry.interestLabel,
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
                EnquiryRowActions(
                  enquiry: enquiry,
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
                        Icons.sports_outlined,
                        size: 14,
                        color: tokens.textMuted,
                      ),
                      const SizedBox(width: AdminTokens.space2),
                      Expanded(
                        child: Text(
                          enquiry.isAssigned
                              ? enquiry.assignedCoachName ?? 'Assigned'
                              : 'Unassigned',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: enquiry.isAssigned
                                ? tokens.textSecondary
                                : tokens.textMuted,
                            fontSize: 12,
                            fontWeight: enquiry.isAssigned
                                ? FontWeight.w600
                                : FontWeight.w400,
                            fontStyle: enquiry.isAssigned
                                ? FontStyle.normal
                                : FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AdminTokens.space3),
                EnquiryStatusChip(statusRaw: enquiry.statusRaw, dense: true),
              ],
            ),
            const SizedBox(height: AdminTokens.space2),
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 13, color: tokens.textMuted),
                const SizedBox(width: AdminTokens.space2),
                Text(
                  AdminFormat.text(enquiry.phone),
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
                    AdminFormat.date(enquiry.createdAt),
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
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
