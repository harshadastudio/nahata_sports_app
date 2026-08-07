import 'package:flutter/material.dart';

import '../../domain/entities/coupon.dart';
import '../navigation/admin_module.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'coupon_chips.dart';

/// What a coupon row can be asked to do.
enum CouponAction { view, edit, copyCode, validate, delete }

/// The desktop/tablet table — a hand-built header/row pair inside a horizontal
/// scroll, so the columns never squeeze.
class CouponsTable extends StatefulWidget {
  const CouponsTable({
    super.key,
    required this.coupons,
    required this.onAction,
    this.selectedId,
  });

  final List<AdminCoupon> coupons;
  final void Function(CouponAction action, AdminCoupon coupon) onAction;
  final int? selectedId;

  static const double _minWidth = 1240;

  @override
  State<CouponsTable> createState() => _CouponsTableState();
}

class _CouponsTableState extends State<CouponsTable> {
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
        final overflows = constraints.maxWidth < CouponsTable._minWidth;
        final width = overflows ? CouponsTable._minWidth : constraints.maxWidth;

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
                  ...widget.coupons.map(
                    (coupon) => _Row(
                      key: ValueKey<int>(coupon.id),
                      coupon: coupon,
                      selected: coupon.id == widget.selectedId,
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

  static const int code = 20;
  static const int discount = 13;
  static const int scope = 11;
  static const int platform = 11;
  static const int usage = 11;
  static const int validUntil = 13;
  static const int state = 12;
  static const int venue = 19;
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
          _HeaderCell('Coupon', _Columns.code),
          _HeaderCell('Discount', _Columns.discount),
          _HeaderCell('Applies to', _Columns.scope),
          _HeaderCell('Platform', _Columns.platform),
          _HeaderCell('Used', _Columns.usage),
          _HeaderCell('Valid until', _Columns.validUntil),
          _HeaderCell('State', _Columns.state),
          _HeaderCell('Sport / complex', _Columns.venue),
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
    required this.coupon,
    required this.selected,
    required this.onAction,
  });

  final AdminCoupon coupon;
  final bool selected;
  final void Function(CouponAction action, AdminCoupon coupon) onAction;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final coupon = widget.coupon;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onAction(CouponAction.view, coupon),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        coupon.displayCode,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                      ),
                      if ((coupon.description ?? '').trim().isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          coupon.description!.trim(),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: tokens.textMuted,
                            fontSize: 11.5,
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              _Cell(
                flex: _Columns.discount,
                child: CouponDiscountChip(coupon: coupon, dense: true),
              ),
              _Cell(
                flex: _Columns.scope,
                child: CouponScopeChip(coupon: coupon, dense: true),
              ),
              _Cell(
                flex: _Columns.platform,
                child: CouponPlatformChip(coupon: coupon, dense: true),
              ),
              _Cell(
                flex: _Columns.usage,
                child: CouponUsageLabel(coupon: coupon),
              ),
              _TextCell(
                AdminFormat.date(coupon.validUntil),
                _Columns.validUntil,
              ),
              _Cell(
                flex: _Columns.state,
                child: CouponStateChip(coupon: coupon, dense: true),
              ),
              _TextCell(
                coupon.scopeLabel,
                _Columns.venue,
                weight: FontWeight.w600,
              ),
              SizedBox(
                width: _Columns.actions,
                child: CouponRowActions(
                  coupon: coupon,
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
        child: Align(alignment: Alignment.centerLeft, child: child),
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

/// The row's overflow menu.
class CouponRowActions extends StatelessWidget {
  const CouponRowActions({
    super.key,
    required this.coupon,
    required this.onAction,
    required this.visible,
  });

  final AdminCoupon coupon;
  final void Function(CouponAction action, AdminCoupon coupon) onAction;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return AnimatedOpacity(
      // Always in the tree so the row height is stable and the menu stays
      // reachable where hover does not exist.
      duration: AdminTokens.fast,
      opacity: visible ? 1 : 0.35,
      child: PopupMenuButton<CouponAction>(
        tooltip: 'Actions',
        icon: Icon(Icons.more_horiz_rounded, size: 18, color: tokens.textMuted),
        padding: EdgeInsets.zero,
        onSelected: (action) => onAction(action, coupon),
        itemBuilder: (context) => <PopupMenuEntry<CouponAction>>[
          _item(
            CouponAction.view,
            Icons.visibility_outlined,
            'View coupon',
            tokens.textPrimary,
          ),
          _item(
            CouponAction.edit,
            Icons.edit_outlined,
            'Edit coupon',
            tokens.textPrimary,
          ),
          _item(
            CouponAction.copyCode,
            Icons.copy_rounded,
            'Copy code',
            tokens.textPrimary,
          ),
          _item(
            CouponAction.validate,
            Icons.calculate_outlined,
            'Test on an amount',
            tokens.textPrimary,
          ),
          const PopupMenuDivider(),
          _item(
            CouponAction.delete,
            Icons.delete_outline_rounded,
            'Delete coupon',
            tokens.danger,
          ),
        ]
              .gatedBy(
                AdminModules.coupons,
                isDestructive: (a) => a == CouponAction.delete,
                isReadOnly: (a) => a == CouponAction.view || a == CouponAction.copyCode,
              ),
      ),
    );
  }

  PopupMenuItem<CouponAction> _item(
    CouponAction value,
    IconData icon,
    String label,
    Color color,
  ) {
    return PopupMenuItem<CouponAction>(
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
class CouponCard extends StatelessWidget {
  const CouponCard({super.key, required this.coupon, required this.onAction});

  final AdminCoupon coupon;
  final void Function(CouponAction action, AdminCoupon coupon) onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return InkWell(
      onTap: () => onAction(CouponAction.view, coupon),
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
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: tokens.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
                  ),
                  child: Icon(
                    Icons.local_offer_outlined,
                    size: 20,
                    color: tokens.accent,
                  ),
                ),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        coupon.displayCode,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textPrimary,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        AdminFormat.text(coupon.description),
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
                CouponRowActions(
                  coupon: coupon,
                  onAction: onAction,
                  visible: true,
                ),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Wrap(
              spacing: AdminTokens.space2,
              runSpacing: AdminTokens.space2,
              children: [
                CouponDiscountChip(coupon: coupon, dense: true),
                CouponScopeChip(coupon: coupon, dense: true),
                CouponPlatformChip(coupon: coupon, dense: true),
                CouponStateChip(coupon: coupon, dense: true),
              ],
            ),
            const SizedBox(height: AdminTokens.space3),
            Row(
              children: [
                Icon(Icons.event_outlined, size: 13, color: tokens.textMuted),
                const SizedBox(width: AdminTokens.space2),
                Text(
                  'Until ${AdminFormat.date(coupon.validUntil)}',
                  style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                ),
                const SizedBox(width: AdminTokens.space4),
                Icon(
                  Icons.confirmation_number_outlined,
                  size: 13,
                  color: tokens.textMuted,
                ),
                const SizedBox(width: AdminTokens.space2),
                Expanded(
                  child: Text(
                    coupon.usageLimit == null || coupon.usageLimit! <= 0
                        ? 'Unlimited uses'
                        : '${coupon.usedCount ?? 0} of ${coupon.usageLimit} used',
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
