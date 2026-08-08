import 'package:flutter/material.dart';

import '../../domain/entities/contact_inquiry.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'contact_status_chip.dart';

/// What a contact-enquiry row can be asked to do.
///
/// Read-only by design: `GET /contact-us/admin` is the only route confirmed for
/// this module, so there is no edit, no status change and no delete. Replying
/// hands off to the device's mail app rather than pretending the console can
/// send it.
enum ContactEnquiryAction { view, email }

/// The desktop/tablet table — a hand-built header/row pair inside a horizontal
/// scroll, so the columns never squeeze.
class ContactEnquiriesTable extends StatefulWidget {
  const ContactEnquiriesTable({
    super.key,
    required this.enquiries,
    required this.onAction,
    this.selectedId,
  });

  final List<ContactInquiry> enquiries;
  final void Function(ContactEnquiryAction action, ContactInquiry enquiry)
  onAction;

  /// UUID string, not an int — see [ContactInquiry.id].
  final String? selectedId;

  static const double _minWidth = 1180;

  @override
  State<ContactEnquiriesTable> createState() => _ContactEnquiriesTableState();
}

class _ContactEnquiriesTableState extends State<ContactEnquiriesTable> {
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
        final overflows = constraints.maxWidth < ContactEnquiriesTable._minWidth;
        final width = overflows
            ? ContactEnquiriesTable._minWidth
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
                      key: ValueKey<String>(enquiry.id),
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

  static const int sender = 20;
  static const int email = 18;
  static const int subject = 24;
  static const int complex = 15;
  static const int status = 11;
  static const int created = 12;
  static const double actions = 52;
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
      child: const Row(
        children: [
          _HeaderCell('Sender', _Columns.sender),
          _HeaderCell('Email', _Columns.email),
          _HeaderCell('Subject & message', _Columns.subject),
          _HeaderCell('Sport complex', _Columns.complex),
          _HeaderCell('Status', _Columns.status),
          _HeaderCell('Received', _Columns.created),
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

  final ContactInquiry enquiry;
  final bool selected;
  final void Function(ContactEnquiryAction action, ContactInquiry enquiry)
  onAction;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final enquiry = widget.enquiry;
    final preview = enquiry.preview();

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onAction(ContactEnquiryAction.view, enquiry),
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
                flex: _Columns.sender,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Row(
                    children: [
                      ContactAvatar(enquiry: enquiry, size: 34),
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
              _TextCell(AdminFormat.text(enquiry.email), _Columns.email),
              Expanded(
                flex: _Columns.subject,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        enquiry.subjectLabel,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (preview.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          preview,
                          maxLines: 1,
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
                AdminFormat.text(
                  enquiry.sportComplexName.isEmpty
                      ? null
                      : enquiry.sportComplexName,
                ),
                _Columns.complex,
              ),
              Expanded(
                flex: _Columns.status,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ContactStatusChip(
                      statusRaw: enquiry.statusRaw,
                      dense: true,
                    ),
                  ),
                ),
              ),
              _TextCell(AdminFormat.date(enquiry.createdAt), _Columns.created),
              SizedBox(
                width: _Columns.actions,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    onPressed: () =>
                        widget.onAction(ContactEnquiryAction.view, enquiry),
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    tooltip: 'Open enquiry',
                    color: tokens.textMuted,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 34,
                      height: 34,
                    ),
                  ),
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
  const _TextCell(this.value, this.flex);

  final String value;
  final int flex;

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
          style: TextStyle(color: tokens.textSecondary, fontSize: 12.5),
        ),
      ),
    );
  }
}

/// The sender's initials. There is no avatar in the payload — a contact
/// enquiry comes from someone who may not have an account at all.
class ContactAvatar extends StatelessWidget {
  const ContactAvatar({super.key, required this.enquiry, this.size = 36});

  final ContactInquiry enquiry;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final status = enquiry.status;
    final color = tokens.contactStatusColor(status);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        _initials(enquiry.displayName),
        style: TextStyle(
          color: color,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }
}

/// The phone equivalent of a row.
class ContactEnquiryCard extends StatelessWidget {
  const ContactEnquiryCard({
    super.key,
    required this.enquiry,
    required this.onAction,
  });

  final ContactInquiry enquiry;
  final void Function(ContactEnquiryAction action, ContactInquiry enquiry)
  onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final preview = enquiry.preview(max: 140);

    return InkWell(
      onTap: () => onAction(ContactEnquiryAction.view, enquiry),
      child: Container(
        padding: const EdgeInsets.all(AdminTokens.space4),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: tokens.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ContactAvatar(enquiry: enquiry, size: 38),
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
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AdminFormat.text(enquiry.email),
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                ContactStatusChip(statusRaw: enquiry.statusRaw, dense: true),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Text(
              enquiry.subjectLabel,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (preview.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: tokens.textMuted, fontSize: 12),
              ),
            ],
            const SizedBox(height: AdminTokens.space3),
            Wrap(
              spacing: AdminTokens.space3,
              runSpacing: AdminTokens.space2,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (enquiry.sportComplexName.isNotEmpty)
                  _MetaChip(
                    icon: Icons.stadium_outlined,
                    label: enquiry.sportComplexLabel,
                  ),
                _MetaChip(
                  icon: Icons.schedule_rounded,
                  label: AdminFormat.relative(enquiry.createdAt),
                ),
                if ((enquiry.referenceNumber ?? '').trim().isNotEmpty)
                  _MetaChip(
                    icon: Icons.tag_rounded,
                    label: enquiry.referenceNumber!.trim(),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: tokens.textMuted),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: tokens.textMuted, fontSize: 11.5)),
      ],
    );
  }
}