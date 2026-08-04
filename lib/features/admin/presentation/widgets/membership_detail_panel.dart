import 'package:flutter/material.dart';

import '../../domain/entities/membership.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'admin_states.dart';
import 'glass_card.dart';
import 'membership_status_chip.dart';
import 'memberships_table.dart';
import 'payment_status_chip.dart';

/// The right-side membership detail panel.
///
/// Everything the module lists is here: plan, member, price, validity, booking
/// limit, discount, features, access type, dates, status, payment status, auto
/// renew and total — plus the member's other plans, from
/// `/memberships/user/{userId}` and `/memberships/user/{userId}/active`.
class MembershipDetailPanel extends StatelessWidget {
  const MembershipDetailPanel({
    super.key,
    required this.membership,
    required this.state,
    required this.error,
    required this.onClose,
    required this.onAction,
    required this.onRetry,
    this.history = const [],
    this.activePlan,
    this.historyState = ViewState.idle,
    this.showCloseButton = true,
  });

  final Membership membership;
  final ViewState state;
  final String? error;
  final VoidCallback onClose;
  final void Function(MembershipAction action, Membership membership) onAction;
  final VoidCallback onRetry;

  final List<Membership> history;
  final Membership? activePlan;
  final ViewState historyState;

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
                  'Membership details',
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
          child: state.isFailed
              ? ErrorStateView(
                  compact: true,
                  title: 'Could not load this membership',
                  message: error ?? 'Please try again.',
                  onRetry: onRetry,
                )
              : ListView(
                  padding: const EdgeInsets.all(AdminTokens.space5),
                  children: [
                    _HeroCard(membership: membership),
                    const SizedBox(height: AdminTokens.space4),
                    _TermCard(membership: membership),
                    const SizedBox(height: AdminTokens.space4),
                    _PlanCard(membership: membership),
                    if (membership.features.isNotEmpty) ...[
                      const SizedBox(height: AdminTokens.space4),
                      _FeaturesCard(membership: membership),
                    ],
                    if ((membership.cancellationReason ?? '')
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(height: AdminTokens.space4),
                      _ReasonCard(
                        reason: membership.cancellationReason!.trim(),
                      ),
                    ],
                    const SizedBox(height: AdminTokens.space4),
                    _HistoryCard(
                      membership: membership,
                      history: history,
                      activePlan: activePlan,
                      state: historyState,
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
                  onPressed: () =>
                      onAction(MembershipAction.renew, membership),
                  icon: const Icon(Icons.autorenew_rounded, size: 18),
                  label: const Text('Renew'),
                ),
              ),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => onAction(MembershipAction.edit, membership),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.membership});

  final Membership membership;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MemberAvatar(membership: membership, size: 52),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      membership.displayUser,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      membership.displayPlan,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if ((membership.userEmail ?? '').trim().isNotEmpty ||
                        (membership.userPhone ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        [
                          if ((membership.userEmail ?? '').trim().isNotEmpty)
                            membership.userEmail!.trim(),
                          if ((membership.userPhone ?? '').trim().isNotEmpty)
                            membership.userPhone!.trim(),
                        ].join(' · '),
                        style: TextStyle(color: tokens.textMuted, fontSize: 12),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space4),
          Wrap(
            spacing: AdminTokens.space2,
            runSpacing: AdminTokens.space2,
            children: [
              MembershipStatusChip(membership: membership),
              MembershipPaymentChip(membership: membership),
              if (membership.autoRenew == true)
                StatusPill(
                  label: 'Auto renew on',
                  color: tokens.info,
                  icon: Icons.autorenew_rounded,
                ),
            ],
          ),
          const SizedBox(height: AdminTokens.space4),
          Row(
            children: [
              Expanded(
                child: _Figure(
                  label: 'Total amount',
                  value: AdminFormat.currency(membership.totalAmount),
                ),
              ),
              Expanded(
                child: _Figure(
                  label: 'Price',
                  value: AdminFormat.currency(membership.price),
                ),
              ),
              Expanded(
                child: _Figure(
                  label: 'Discount',
                  value: membership.discountPercent == null
                      ? AdminFormat.dash
                      : '${_plain(membership.discountPercent!)}%',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// `10` rather than `10.0` — a whole percentage should not grow a decimal.
String _plain(num value) => value == value.roundToDouble()
    ? value.round().toString()
    : value.toString();

class _TermCard extends StatelessWidget {
  const _TermCard({required this.membership});

  final Membership membership;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final progress = membership.progress();
    final days = membership.daysRemaining();

    return SolidCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_rounded, size: 16, color: tokens.accent),
              const SizedBox(width: AdminTokens.space2),
              Text(
                'Validity',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          Row(
            children: [
              Expanded(
                child: _Figure(
                  label: 'Starts',
                  value: AdminFormat.date(membership.startDate),
                ),
              ),
              Expanded(
                child: _Figure(
                  label: 'Ends',
                  value: AdminFormat.date(membership.endDate),
                ),
              ),
              Expanded(
                child: _Figure(
                  label: 'Validity',
                  value: membership.validityDays == null
                      ? AdminFormat.dash
                      : '${membership.validityDays} days',
                ),
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: AdminTokens.space4),
            ClipRRect(
              borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: tokens.surfaceAlt,
                valueColor: AlwaysStoppedAnimation<Color>(
                  membershipStatusColor(context, membership.status),
                ),
              ),
            ),
          ],
          const SizedBox(height: AdminTokens.space3),
          Text(
            // Never claims a term it cannot see: no end date means unknown,
            // not expired.
            days == null
                ? 'The end date was not reported, so the time left is unknown.'
                : (days < 0
                      ? 'This plan ended ${-days} day'
                            '${days == -1 ? '' : 's'} ago.'
                      : '$days day${days == 1 ? '' : 's'} left of the term.'),
            style: TextStyle(color: tokens.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.membership});

  final Membership membership;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.workspace_premium_outlined,
                size: 16,
                color: tokens.accent,
              ),
              const SizedBox(width: AdminTokens.space2),
              Text(
                'Plan',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          _Line(label: 'Plan code', value: AdminFormat.text(membership.planId)),
          _Line(label: 'Plan name', value: membership.displayPlan),
          _Line(
            label: 'Access type',
            value: AdminFormat.text(membership.accessType),
          ),
          _Line(
            label: 'Booking limit',
            value: membership.bookingLimit == null
                ? AdminFormat.dash
                : '${membership.bookingLimit} bookings',
          ),
          if (membership.bookingsUsed != null)
            _Line(
              label: 'Bookings used',
              value: '${membership.bookingsUsed}',
            ),
          _Line(
            label: 'Discount applied',
            value: AdminFormat.currency(membership.discountApplied),
          ),
          _Line(
            label: 'Auto renew',
            value: membership.autoRenew == null
                ? AdminFormat.dash
                : (membership.autoRenew! ? 'On' : 'Off'),
          ),
          _Line(label: 'Membership ID', value: membership.id),
          _Line(label: 'Member ID', value: AdminFormat.text(membership.userId)),
          _Line(
            label: 'Created',
            value: AdminFormat.dateTime(membership.createdAt),
          ),
        ],
      ),
    );
  }
}

class _FeaturesCard extends StatelessWidget {
  const _FeaturesCard({required this.membership});

  final Membership membership;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: 16,
                color: tokens.success,
              ),
              const SizedBox(width: AdminTokens.space2),
              Text(
                'Features',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          for (final feature in membership.features)
            Padding(
              padding: const EdgeInsets.only(bottom: AdminTokens.space2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.done_rounded, size: 15, color: tokens.success),
                  const SizedBox(width: AdminTokens.space2),
                  Expanded(
                    child: Text(
                      feature,
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReasonCard extends StatelessWidget {
  const _ReasonCard({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      color: tokens.danger.withValues(alpha: 0.06),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.cancel_outlined, size: 16, color: tokens.danger),
              const SizedBox(width: AdminTokens.space2),
              Text(
                'Cancellation reason',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space2),
          Text(
            reason,
            style: TextStyle(
              color: tokens.textSecondary,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

/// The member's other plans.
class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.membership,
    required this.history,
    required this.activePlan,
    required this.state,
  });

  final Membership membership;
  final List<Membership> history;
  final Membership? activePlan;
  final ViewState state;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final others = history
        .where((row) => row.id != membership.id)
        .toList(growable: false);

    return SolidCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 16, color: tokens.info),
              const SizedBox(width: AdminTokens.space2),
              Expanded(
                child: Text(
                  "This member's plans",
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (state.isLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: AdminTokens.space3),
          if (activePlan != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AdminTokens.space3),
              child: Row(
                children: [
                  Icon(Icons.verified_rounded, size: 15, color: tokens.success),
                  const SizedBox(width: AdminTokens.space2),
                  Expanded(
                    child: Text(
                      activePlan!.id == membership.id
                          ? 'This is the plan currently in force.'
                          : 'In force now: ${activePlan!.displayPlan}',
                      style: TextStyle(
                        color: tokens.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (state.isFailed)
            Text(
              'Could not load this member’s other plans.',
              style: TextStyle(color: tokens.textMuted, fontSize: 12),
            )
          else if (others.isEmpty && !state.isLoading)
            Text(
              activePlan == null
                  ? 'No other plans were returned for this member.'
                  : 'This is the only plan on record for this member.',
              style: TextStyle(color: tokens.textMuted, fontSize: 12),
            )
          else
            for (final row in others)
              Padding(
                padding: const EdgeInsets.only(bottom: AdminTokens.space2),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        row.displayPlan,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: AdminTokens.space2),
                    Text(
                      AdminFormat.date(row.endDate),
                      style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
                    ),
                    const SizedBox(width: AdminTokens.space2),
                    MembershipStatusChip(membership: row, dense: true),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

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
        const SizedBox(height: 3),
        Text(
          value,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: value == AdminFormat.dash
                ? tokens.textMuted
                : tokens.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AdminTokens.space2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(color: tokens.textMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: value == AdminFormat.dash
                    ? tokens.textMuted
                    : tokens.textSecondary,
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
