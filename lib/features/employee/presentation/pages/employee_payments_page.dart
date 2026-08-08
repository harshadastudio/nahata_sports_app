import 'package:flutter/material.dart';

import '../../data/repositories/employee_dashboard_repository_impl.dart';
import '../../domain/entities/employee_formats.dart';
import '../../domain/entities/employee_payment.dart';
import '../state/employee_payments_controller.dart';
import '../theme/employee_theme.dart';
import '../widgets/employee_forms.dart';
import '../widgets/employee_list_scaffold.dart';
import '../widgets/employee_stat_tile.dart';

/// Payments Management — every payment across courts, events and coaching.
///
/// Read-only: there is no employee endpoint that edits a payment. A correction
/// is made where the money was recorded — on the booking, or on the fee record.
class EmployeePaymentsPage extends StatefulWidget {
  const EmployeePaymentsPage({super.key});

  @override
  State<EmployeePaymentsPage> createState() => _EmployeePaymentsPageState();
}

class _EmployeePaymentsPageState extends State<EmployeePaymentsPage> {
  late final EmployeePaymentsController _controller =
      EmployeePaymentsController(EmployeeDashboardRepositoryImpl());

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wrapped so the empty-state copy tracks the filters.
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => EmployeeListScaffold<EmployeePayment>(
        title: 'Payments',
        controller: _controller,
        subtitle: () => '${_controller.total} payment'
            '${_controller.total == 1 ? '' : 's'}',
        scopeNotice: 'Court bookings, event passes and coaching fees for your '
            'complex, merged into one ledger.',
        header: _statsStrip(),
        filters: _filters(),
        itemBuilder: (context, payment) => _paymentCard(payment),
        emptyIcon: Icons.receipt_long_outlined,
        emptyTitle: 'No payments found',
        emptyMessage: _controller.isFiltered
            ? 'Nothing matches these filters. Try clearing one.'
            : 'Payments taken at your complex will show up here.',
      ),
    );
  }

  Widget _statsStrip() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final stats = _controller.stats;
        return EmployeeTileGrid(
          columns: 3,
          children: [
            EmployeeSummaryTile(
              label: 'Collected',
              value: stats.revenueLabel,
              icon: Icons.account_balance_wallet_outlined,
              color: EmployeeTokens.success,
            ),
            EmployeeSummaryTile(
              label: 'Successful',
              value: '${stats.successCount}',
              icon: Icons.check_circle_outline_rounded,
              color: EmployeeTokens.info,
            ),
            EmployeeSummaryTile(
              label: 'Pending',
              value: '${stats.pendingCount}',
              icon: Icons.hourglass_bottom_rounded,
              color: EmployeeTokens.warning,
            ),
          ],
        );
      },
    );
  }

  Widget _filters() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EmployeeFilterChips<String>(
            values: EmployeePaymentsController.statuses,
            selected: _controller.status,
            labelOf: (s) => s,
            allLabel: 'All statuses',
            onChanged: _controller.setStatus,
          ),
          const SizedBox(height: EmployeeTokens.space2),
          EmployeeFilterChips<String>(
            values: EmployeePaymentsController.types.keys.toList(),
            selected: _controller.type,
            labelOf: (t) => EmployeePaymentsController.types[t] ?? t,
            allLabel: 'All sources',
            onChanged: _controller.setType,
          ),
        ],
      ),
    );
  }

  Widget _paymentCard(EmployeePayment payment) {
    final tone = EmployeeTokens.paymentTypeColor(payment.type);

    return EmployeeCard(
      margin: const EdgeInsets.only(bottom: EmployeeTokens.space3),
      accentColor: tone,
      onTap: () => _openDetail(payment),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EmployeeAvatar(
                initial: payment.initial,
                radius: 19,
                color: tone,
              ),
              const SizedBox(width: EmployeeTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      payment.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: EmployeeTokens.textDark,
                      ),
                    ),
                    if (payment.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        payment.description,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: EmployeeTokens.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: EmployeeTokens.space2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    payment.amountLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: EmployeeTokens.textDark,
                    ),
                  ),
                  const SizedBox(height: 3),
                  EmployeeChip(label: payment.status, dense: true),
                ],
              ),
            ],
          ),
          const SizedBox(height: EmployeeTokens.space3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Source and method reflow on the left; the date keeps its place
              // on the right rather than being pushed out of the card.
              Expanded(
                child: Wrap(
                  spacing: EmployeeTokens.space2,
                  runSpacing: EmployeeTokens.space2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    EmployeeChip(
                      label: payment.typeLabel.isEmpty
                          ? (EmployeePaymentsController.types[payment.type] ??
                              '—')
                          : payment.typeLabel,
                      color: tone,
                      dense: true,
                    ),
                    if (payment.paymentMode.isNotEmpty)
                      Text(
                        payment.paymentMode,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: EmployeeTokens.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: EmployeeTokens.space2),
              Text(
                formatDay(payment.createdAt),
                style: const TextStyle(
                  fontSize: 11.5,
                  color: EmployeeTokens.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(EmployeePayment payment) {
    return showEmployeeSheet<void>(
      context: context,
      title: 'Payment details',
      // The composite id is the only stable handle on a merged row, so it is
      // shown rather than a prettified number that would collide across
      // sources.
      subtitle: payment.id,
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EmployeeChip(label: payment.status),
              const SizedBox(width: EmployeeTokens.space2),
              EmployeeChip(
                label: payment.typeLabel,
                color: EmployeeTokens.paymentTypeColor(payment.type),
              ),
            ],
          ),
          const SizedBox(height: EmployeeTokens.space5),
          EmployeeDetailRow(label: 'Name', value: payment.displayName),
          EmployeeDetailRow(label: 'Email', value: payment.userEmail),
          EmployeeDetailRow(label: 'Phone', value: payment.userPhone),
          const Divider(height: EmployeeTokens.space6),
          EmployeeDetailRow(
            label: 'Amount',
            value: payment.amountLabel,
            valueColor: EmployeeTokens.success,
          ),
          EmployeeDetailRow(label: 'Method', value: payment.paymentMode),
          EmployeeDetailRow(label: 'Description', value: payment.description),
          EmployeeDetailRow(label: 'Venue', value: payment.venue),
          EmployeeDetailRow(
            label: 'Recorded',
            value: formatDateTime(payment.createdAt),
          ),
          if ((payment.date ?? '').isNotEmpty)
            EmployeeDetailRow(label: 'For date', value: payment.date!),
          if ((payment.transactionId ?? '').isNotEmpty)
            EmployeeDetailRow(
              label: 'Transaction',
              value: payment.transactionId!,
              monospace: true,
            ),
          if ((payment.razorpayOrderId ?? '').isNotEmpty)
            EmployeeDetailRow(
              label: 'Order id',
              value: payment.razorpayOrderId!,
              monospace: true,
            ),
          if ((payment.razorpayPaymentId ?? '').isNotEmpty)
            EmployeeDetailRow(
              label: 'Payment id',
              value: payment.razorpayPaymentId!,
              monospace: true,
            ),
          const SizedBox(height: EmployeeTokens.space5),
          Container(
            padding: const EdgeInsets.all(EmployeeTokens.space3),
            decoration: BoxDecoration(
              color: EmployeeTokens.canvas,
              borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: EmployeeTokens.textMuted,
                ),
                SizedBox(width: EmployeeTokens.space2),
                Expanded(
                  child: Text(
                    'This ledger is read-only. To correct a payment, edit the '
                    'booking or the fee record it came from.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: EmployeeTokens.textBody,
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
