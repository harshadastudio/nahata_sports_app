import 'package:flutter/material.dart';

import '../../domain/entities/membership.dart';
import '../state/memberships_controller.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'membership_status_chip.dart';
import 'payment_status_chip.dart';

/// What a membership row can be asked to do.
enum MembershipAction {
  view,
  edit,
  renew,
  cancel,
  delete,
  setActive,
  setInactive,
  setExpired,
  markPaid,
  markPending,
  markFailed,
  markRefunded,
}

/// The memberships table.
class MembershipsTable extends StatefulWidget {
  const MembershipsTable({
    super.key,
    required this.memberships,
    required this.sort,
    required this.descending,
    required this.onSort,
    required this.onAction,
    required this.isBusy,
    this.selectedId,
  });

  final List<Membership> memberships;
  final MembershipSort? sort;
  final bool descending;
  final ValueChanged<MembershipSort> onSort;
  final void Function(MembershipAction action, Membership membership) onAction;
  final bool Function(String id) isBusy;
  final String? selectedId;

  static const double _minWidth = 1420;

  @override
  State<MembershipsTable> createState() => _MembershipsTableState();
}

class _MembershipsTableState extends State<MembershipsTable> {
  /// Owned here rather than left to the PrimaryScrollController: a visible
  /// Scrollbar asserts without one.
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
        final overflows = constraints.maxWidth < MembershipsTable._minWidth;
        final width = overflows
            ? MembershipsTable._minWidth
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
                  ...widget.memberships.map(
                    (membership) => _Row(
                      key: ValueKey<String>(membership.id),
                      membership: membership,
                      selected: membership.id == widget.selectedId,
                      busy: widget.isBusy(membership.id),
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

class _Columns {
  const _Columns._();

  static const double avatar = 52;
  static const int member = 20;
  static const int plan = 18;
  static const int price = 12;
  static const int validity = 18;
  static const int bookings = 10;
  static const int status = 11;
  static const int payment = 11;
  static const double actions = 100;
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.sort,
    required this.descending,
    required this.onSort,
  });

  final MembershipSort? sort;
  final bool descending;
  final ValueChanged<MembershipSort> onSort;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    Widget cell(String label, int flex, [MembershipSort? column]) =>
        MembershipHeaderCell(
          label: label,
          flex: flex,
          active: column != null && sort == column,
          descending: descending,
          onTap: column == null ? null : () => onSort(column),
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
          const SizedBox(width: _Columns.avatar),
          cell('Member', _Columns.member, MembershipSort.member),
          cell('Plan', _Columns.plan, MembershipSort.plan),
          cell('Amount', _Columns.price, MembershipSort.price),
          cell('Validity', _Columns.validity, MembershipSort.ends),
          cell('Bookings', _Columns.bookings),
          cell('Status', _Columns.status, MembershipSort.status),
          cell('Payment', _Columns.payment, MembershipSort.payment),
          const SizedBox(width: _Columns.actions),
        ],
      ),
    );
  }
}

/// The sortable header cell.
class MembershipHeaderCell extends StatefulWidget {
  const MembershipHeaderCell({
    super.key,
    required this.label,
    required this.flex,
    this.active = false,
    this.descending = false,
    this.onTap,
  });

  final String label;
  final int flex;
  final bool active;
  final bool descending;
  final VoidCallback? onTap;

  @override
  State<MembershipHeaderCell> createState() => _MembershipHeaderCellState();
}

class _MembershipHeaderCellState extends State<MembershipHeaderCell> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final sortable = widget.onTap != null;

    final content = Row(
      children: [
        Flexible(
          child: Text(
            widget.label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: widget.active ? tokens.accent : tokens.textSecondary,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (sortable)
          AnimatedOpacity(
            duration: AdminTokens.fast,
            opacity: widget.active ? 1 : (_hovered ? 0.5 : 0),
            child: Icon(
              widget.active && widget.descending
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 13,
              color: widget.active ? tokens.accent : tokens.textMuted,
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
                  onTap: widget.onTap,
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
    required this.membership,
    required this.selected,
    required this.busy,
    required this.onAction,
  });

  final Membership membership;
  final bool selected;
  final bool busy;
  final void Function(MembershipAction action, Membership membership) onAction;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final membership = widget.membership;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onAction(MembershipAction.view, membership),
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
                width: _Columns.avatar,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: MemberAvatar(membership: membership, size: 38),
                ),
              ),
              Expanded(
                flex: _Columns.member,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        membership.displayUser,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AdminFormat.text(
                          membership.userEmail ?? membership.userPhone,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                flex: _Columns.plan,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        membership.displayPlan,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AdminFormat.text(membership.accessType),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              MembershipTextCell(
                membership.totalAmount == null && membership.price == null
                    ? AdminFormat.dash
                    : AdminFormat.currency(
                        membership.totalAmount ?? membership.price,
                      ),
                _Columns.price,
                weight: FontWeight.w700,
              ),
              Expanded(
                flex: _Columns.validity,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: MembershipValidityCell(membership: membership),
                ),
              ),
              MembershipTextCell(
                _bookingsLabel(membership),
                _Columns.bookings,
                weight: FontWeight.w600,
              ),
              Expanded(
                flex: _Columns.status,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: widget.busy
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : MembershipStatusChip(
                            membership: membership,
                            dense: true,
                          ),
                  ),
                ),
              ),
              Expanded(
                flex: _Columns.payment,
                child: Padding(
                  padding: const EdgeInsets.only(right: AdminTokens.space3),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: MembershipPaymentChip(
                      membership: membership,
                      dense: true,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: _Columns.actions,
                child: MembershipRowActions(
                  membership: membership,
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

/// `12 left of 50`, or just the limit when usage was not reported.
String _bookingsLabel(Membership membership) {
  final limit = membership.bookingLimit;
  if (limit == null) return AdminFormat.dash;
  final left = membership.bookingsRemaining;
  if (left == null) return '$limit';
  return '$left / $limit';
}

class MembershipTextCell extends StatelessWidget {
  const MembershipTextCell(
    this.value,
    this.flex, {
    super.key,
    this.weight = FontWeight.w400,
  });

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

/// The term, and how much of it is left.
///
/// "Expires in 12 days" is only shown when an end date exists — a plan with no
/// end date is unknown, and saying "expired" of it would be a fabrication.
class MembershipValidityCell extends StatelessWidget {
  const MembershipValidityCell({super.key, required this.membership});

  final Membership membership;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final days = membership.daysRemaining();

    final String note;
    final Color noteColor;

    if (days == null) {
      note = 'End date not reported';
      noteColor = tokens.textMuted;
    } else if (days < 0) {
      note = 'Ended ${-days} day${days == -1 ? '' : 's'} ago';
      noteColor = tokens.danger;
    } else if (days == 0) {
      note = 'Ends today';
      noteColor = tokens.warning;
    } else if (days <= MembershipsController.expiringSoonDays) {
      note = 'Ends in $days day${days == 1 ? '' : 's'}';
      noteColor = tokens.warning;
    } else {
      note = 'Ends in $days days';
      noteColor = tokens.textMuted;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${AdminFormat.date(membership.startDate)} → '
          '${AdminFormat.date(membership.endDate)}',
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: tokens.textSecondary, fontSize: 12.5),
        ),
        const SizedBox(height: 2),
        Text(
          note,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: noteColor,
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

/// The member's initials on a deterministic gradient.
class MemberAvatar extends StatelessWidget {
  const MemberAvatar({super.key, required this.membership, this.size = 38});

  final Membership membership;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final gradient = tokens.avatarGradient(
      '${membership.userId ?? membership.id}${membership.userName ?? ''}',
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
        membership.initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// View, plus the overflow menu every write hangs off.
class MembershipRowActions extends StatelessWidget {
  const MembershipRowActions({
    super.key,
    required this.membership,
    required this.onAction,
    required this.visible,
  });

  final Membership membership;
  final void Function(MembershipAction action, Membership membership) onAction;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final status = membership.status;
    final payment = membership.paymentStatus;

    return AnimatedOpacity(
      duration: AdminTokens.fast,
      opacity: visible ? 1 : 0.35,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            onPressed: () => onAction(MembershipAction.view, membership),
            icon: const Icon(Icons.visibility_outlined, size: 17),
            tooltip: 'View details',
            color: tokens.textMuted,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 30, height: 30),
          ),
          PopupMenuButton<MembershipAction>(
            tooltip: 'More actions',
            icon: Icon(
              Icons.more_horiz_rounded,
              size: 18,
              color: tokens.textMuted,
            ),
            padding: EdgeInsets.zero,
            onSelected: (action) => onAction(action, membership),
            itemBuilder: (context) => [
              _item(
                MembershipAction.edit,
                Icons.edit_outlined,
                'Edit membership',
                tokens.textPrimary,
              ),
              _item(
                MembershipAction.renew,
                Icons.autorenew_rounded,
                'Renew',
                tokens.textPrimary,
              ),
              const PopupMenuDivider(),
              if (status != MembershipStatus.active)
                _item(
                  MembershipAction.setActive,
                  Icons.verified_rounded,
                  'Mark as Active',
                  tokens.success,
                ),
              if (status != MembershipStatus.inactive)
                _item(
                  MembershipAction.setInactive,
                  Icons.pause_circle_outline_rounded,
                  'Mark as Inactive',
                  tokens.textSecondary,
                ),
              if (status != MembershipStatus.expired)
                _item(
                  MembershipAction.setExpired,
                  Icons.event_busy_rounded,
                  'Mark as Expired',
                  tokens.warning,
                ),
              const PopupMenuDivider(),
              if (payment != MembershipPaymentStatus.paid)
                _item(
                  MembershipAction.markPaid,
                  Icons.payments_rounded,
                  'Payment: Paid',
                  tokens.success,
                ),
              if (payment != MembershipPaymentStatus.pending)
                _item(
                  MembershipAction.markPending,
                  Icons.hourglass_empty_rounded,
                  'Payment: Pending',
                  tokens.warning,
                ),
              if (payment != MembershipPaymentStatus.failed)
                _item(
                  MembershipAction.markFailed,
                  Icons.error_outline_rounded,
                  'Payment: Failed',
                  tokens.danger,
                ),
              if (payment != MembershipPaymentStatus.refunded)
                _item(
                  MembershipAction.markRefunded,
                  Icons.undo_rounded,
                  'Payment: Refunded',
                  tokens.info,
                ),
              const PopupMenuDivider(),
              // Cancelling keeps the record; deleting does not. They are
              // deliberately separate actions.
              if (!membership.isCancelled)
                _item(
                  MembershipAction.cancel,
                  Icons.cancel_outlined,
                  'Cancel membership',
                  tokens.warning,
                ),
              _item(
                MembershipAction.delete,
                Icons.delete_outline_rounded,
                'Delete membership',
                tokens.danger,
              ),
            ],
          ),
        ],
      ),
    );
  }

  PopupMenuItem<MembershipAction> _item(
    MembershipAction value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem<MembershipAction>(
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

/// The mobile equivalent of a membership row.
class MembershipCard extends StatelessWidget {
  const MembershipCard({
    super.key,
    required this.membership,
    required this.busy,
    required this.onAction,
  });

  final Membership membership;
  final bool busy;
  final void Function(MembershipAction action, Membership membership) onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return InkWell(
      onTap: () => onAction(MembershipAction.view, membership),
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
                MemberAvatar(membership: membership, size: 44),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        membership.displayUser,
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
                        membership.displayPlan,
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
                MembershipRowActions(
                  membership: membership,
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
                if (busy)
                  const SizedBox(
                    width: 15,
                    height: 15,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  MembershipStatusChip(membership: membership, dense: true),
                MembershipPaymentChip(membership: membership, dense: true),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Row(
              children: [
                Expanded(
                  child: MembershipMiniStat(
                    label: 'Amount',
                    value: membership.totalAmount == null &&
                            membership.price == null
                        ? AdminFormat.dash
                        : AdminFormat.currency(
                            membership.totalAmount ?? membership.price,
                          ),
                  ),
                ),
                Expanded(
                  child: MembershipMiniStat(
                    label: 'Ends',
                    value: AdminFormat.date(membership.endDate),
                  ),
                ),
                Expanded(
                  child: MembershipMiniStat(
                    label: 'Bookings',
                    value: _bookingsLabel(membership),
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

class MembershipMiniStat extends StatelessWidget {
  const MembershipMiniStat({
    super.key,
    required this.label,
    required this.value,
  });

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
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: value == AdminFormat.dash
                ? tokens.textMuted
                : tokens.textPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
