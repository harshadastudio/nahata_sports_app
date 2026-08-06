import 'package:flutter/material.dart';

import '../../domain/entities/coupon.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'admin_states.dart';
import 'coupon_chips.dart';
import 'coupons_table.dart';
import 'glass_card.dart';

/// The right-side detail panel for a coupon.
///
/// The list row carries most of the record, so the panel opens on it and fills
/// in as `GET /admin/coupons/{id}` lands — [state] drives the thin progress
/// line rather than a spinner that would hide what is already readable.
class CouponDetailPanel extends StatelessWidget {
  const CouponDetailPanel({
    super.key,
    required this.coupon,
    required this.state,
    required this.onClose,
    required this.onAction,
    this.showCloseButton = true,
  });

  final AdminCoupon coupon;
  final ViewState state;
  final VoidCallback onClose;
  final void Function(CouponAction action, AdminCoupon coupon) onAction;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(
            AdminTokens.space5,
            AdminTokens.space4,
            AdminTokens.space3,
            AdminTokens.space4,
          ),
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border(bottom: BorderSide(color: tokens.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Coupon',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (showCloseButton)
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Close',
                  color: tokens.textMuted,
                ),
            ],
          ),
        ),
        RefreshLine(visible: state.isLoading),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AdminTokens.space5),
            children: [
              _HeadlineCard(
                coupon: coupon,
                onCopy: () => onAction(CouponAction.copyCode, coupon),
              ),
              const SizedBox(height: AdminTokens.space4),
              _Card(
                icon: Icons.percent_rounded,
                title: 'Discount',
                rows: [
                  _Row('Type', AdminFormat.text(coupon.discountTypeRaw)),
                  _Row(
                    'Value',
                    coupon.discountLabel.isEmpty
                        ? AdminFormat.dash
                        : coupon.discountLabel,
                  ),
                  _Row(
                    'Maximum discount',
                    coupon.maxDiscount == null
                        ? AdminFormat.dash
                        : AdminFormat.currency(coupon.maxDiscount),
                  ),
                  if (coupon.minOrderAmount != null)
                    _Row(
                      'Minimum order',
                      AdminFormat.currency(coupon.minOrderAmount),
                    ),
                ],
              ),
              const SizedBox(height: AdminTokens.space4),
              _Card(
                icon: Icons.tune_rounded,
                title: 'Where it applies',
                rows: [
                  _Row('Applies to', AdminFormat.text(coupon.appliesToLabel)),
                  _Row('Platform', AdminFormat.text(coupon.platformLabel)),
                  _Row(
                    'Sport complex',
                    AdminFormat.text(coupon.sportComplexName),
                  ),
                  _Row('Sport', AdminFormat.text(coupon.sportName)),
                  _Row('Event pass', AdminFormat.text(coupon.eventPassTitle)),
                ],
              ),
              const SizedBox(height: AdminTokens.space4),
              _Card(
                icon: Icons.event_available_outlined,
                title: 'Validity and use',
                rows: [
                  _Row('Valid from', AdminFormat.date(coupon.validFrom)),
                  _Row('Valid until', AdminFormat.date(coupon.validUntil)),
                  _Row('Status', AdminFormat.text(coupon.statusLabel)),
                  _Row(
                    'Usage limit',
                    coupon.usageLimit == null || coupon.usageLimit! <= 0
                        ? 'Unlimited'
                        : AdminFormat.number(coupon.usageLimit),
                  ),
                  _Row('Times used', AdminFormat.number(coupon.usedCount ?? 0)),
                  _Row(
                    'Remaining',
                    coupon.remainingUses == null
                        ? 'Unlimited'
                        : AdminFormat.number(coupon.remainingUses),
                  ),
                  _Row('Created', AdminFormat.date(coupon.createdAt)),
                ],
              ),
              if (state.isFailed) ...[
                const SizedBox(height: AdminTokens.space4),
                const _StaleNotice(),
              ],
              const SizedBox(height: AdminTokens.space5),
              OutlinedButton.icon(
                onPressed: () => onAction(CouponAction.validate, coupon),
                icon: const Icon(Icons.calculate_outlined, size: 18),
                label: const Text('Test this coupon on an amount'),
              ),
              const SizedBox(height: AdminTokens.space6),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(AdminTokens.space4),
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border(top: BorderSide(color: tokens.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onAction(CouponAction.delete, coupon),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.danger,
                    side: BorderSide(
                      color: tokens.danger.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => onAction(CouponAction.edit, coupon),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit coupon'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeadlineCard extends StatelessWidget {
  const _HeadlineCard({required this.coupon, required this.onCopy});

  final AdminCoupon coupon;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
            ),
            child: Icon(
              Icons.local_offer_outlined,
              size: 28,
              color: tokens.accent,
            ),
          ),
          const SizedBox(height: AdminTokens.space4),
          // Tappable because a coupon code exists to be passed on.
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AdminTokens.space3,
                vertical: AdminTokens.space1,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      coupon.displayCode,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: AdminTokens.space2),
                  Icon(Icons.copy_rounded, size: 15, color: tokens.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: AdminTokens.space1),
          Text(
            AdminFormat.text(coupon.description),
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.textMuted, fontSize: 13),
          ),
          const SizedBox(height: AdminTokens.space4),
          Wrap(
            spacing: AdminTokens.space2,
            runSpacing: AdminTokens.space2,
            alignment: WrapAlignment.center,
            children: [
              CouponDiscountChip(coupon: coupon),
              CouponScopeChip(coupon: coupon),
              CouponPlatformChip(coupon: coupon),
              CouponStateChip(coupon: coupon),
            ],
          ),
        ],
      ),
    );
  }
}

class _StaleNotice extends StatelessWidget {
  const _StaleNotice();

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space3),
      decoration: BoxDecoration(
        color: tokens.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: tokens.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.cloud_off_rounded, size: 16, color: tokens.warning),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              'Showing what the list returned — the full coupon could not be '
              'loaded, so some fields may be missing.',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 11.5,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.title, required this.rows});

  final IconData icon;
  final String title;
  final List<_Row> rows;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: tokens.accent),
              const SizedBox(width: AdminTokens.space2),
              Text(
                title,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          ...rows,
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: value == AdminFormat.dash
                    ? tokens.textMuted
                    : tokens.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
