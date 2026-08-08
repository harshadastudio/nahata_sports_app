import 'package:flutter/material.dart';

import '../../data/repositories/employee_dashboard_repository_impl.dart';
import '../../domain/entities/employee_fee.dart';
import '../state/employee_fees_controller.dart';
import '../theme/employee_theme.dart';
import '../widgets/employee_forms.dart';
import '../widgets/employee_list_scaffold.dart';
import '../widgets/employee_stat_tile.dart';

/// Fees Approval — sign off what a coach collected, which unlocks the student's
/// gate pass.
///
/// Opens on the Pending filter, and an approved row leaves the queue: the point
/// of the screen is getting the queue to empty.
class EmployeeFeesApprovalPage extends StatefulWidget {
  const EmployeeFeesApprovalPage({super.key});

  @override
  State<EmployeeFeesApprovalPage> createState() =>
      _EmployeeFeesApprovalPageState();
}

class _EmployeeFeesApprovalPageState extends State<EmployeeFeesApprovalPage> {
  late final EmployeeFeesApprovalController _controller =
      EmployeeFeesApprovalController(EmployeeDashboardRepositoryImpl());
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wrapped so the empty-state copy tracks the filter — "all caught up" is
    // only true while the queue is filtered to Pending.
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => EmployeeListScaffold<EmployeeFee>(
        title: 'Fees approval',
        controller: _controller,
        subtitle: () => '${_controller.total} record'
            '${_controller.total == 1 ? '' : 's'}',
        header: _statsStrip(),
        filters: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EmployeeSearchBar(
              controller: _search,
              hintText: 'Search by student name',
              onChanged: _controller.onSearchChanged,
              onClear: () => _controller.onSearchChanged(''),
            ),
            const SizedBox(height: EmployeeTokens.space3),
            EmployeeFilterChips<String>(
              values: EmployeeFeesApprovalController.approvalStatuses,
              selected: _controller.approvalStatus,
              labelOf: (s) => s == 'Pending' ? 'Awaiting approval' : s,
              allLabel: 'All records',
              onChanged: _controller.setApprovalStatus,
            ),
          ],
        ),
        itemBuilder: (context, fee) => _feeCard(fee),
        emptyIcon: Icons.verified_outlined,
        emptyTitle: _controller.approvalStatus == 'Pending'
            ? 'All caught up'
            : 'No fee records found',
        emptyMessage: _controller.approvalStatus == 'Pending'
            ? 'Nothing is waiting on you right now.'
            : 'No fee record matches this filter.',
        exhaustedLabel: 'End of the queue',
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
              label: 'Awaiting approval',
              value: '${stats.pendingApproval}',
              icon: Icons.pending_actions_rounded,
              color: EmployeeTokens.danger,
              onTap: () => _controller.setApprovalStatus('Pending'),
            ),
            EmployeeSummaryTile(
              label: 'Paid',
              value: '${stats.paid}',
              icon: Icons.check_circle_outline_rounded,
              color: EmployeeTokens.success,
            ),
            EmployeeSummaryTile(
              label: 'Fee records',
              value: '${stats.total}',
              icon: Icons.folder_outlined,
              color: EmployeeTokens.info,
            ),
          ],
        );
      },
    );
  }

  Widget _feeCard(EmployeeFee fee) {
    return EmployeeCard(
      margin: const EdgeInsets.only(bottom: EmployeeTokens.space3),
      accentColor: EmployeeTokens.statusColor(fee.approvalStatus),
      onTap: () => _openDetail(fee),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EmployeeAvatar(initial: fee.initial, radius: 19),
              const SizedBox(width: EmployeeTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fee.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: EmployeeTokens.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        fee.displayBatch,
                        if (fee.sportName.isNotEmpty) fee.sportName,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: EmployeeTokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: EmployeeTokens.space2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    fee.paidLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: EmployeeTokens.success,
                    ),
                  ),
                  if (fee.batchFeesLabel != null)
                    Text(
                      'of ${fee.batchFeesLabel}',
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: EmployeeTokens.textMuted,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: EmployeeTokens.space3),
          Wrap(
            spacing: EmployeeTokens.space2,
            runSpacing: EmployeeTokens.space2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              EmployeeChip(label: fee.approvalStatus, dense: true),
              EmployeeChip(label: fee.paymentStatus, dense: true),
              if ((fee.paymentMode ?? '').isNotEmpty)
                Text(
                  fee.paymentMode!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: EmployeeTokens.textMuted,
                  ),
                ),
            ],
          ),
          if (fee.isAwaitingApproval) ...[
            const SizedBox(height: EmployeeTokens.space3),
            Row(
              children: [
                Expanded(
                  child: _quickAction(
                    label: 'Approve',
                    icon: Icons.check_rounded,
                    color: EmployeeTokens.success,
                    onTap: () => _approve(fee),
                  ),
                ),
                const SizedBox(width: EmployeeTokens.space2),
                Expanded(
                  child: _quickAction(
                    label: 'Reject',
                    icon: Icons.close_rounded,
                    color: EmployeeTokens.danger,
                    onTap: () => _reject(fee),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _quickAction({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(
        label,
        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(vertical: EmployeeTokens.space2 + 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
        ),
      ),
    );
  }

  Future<void> _approve(EmployeeFee fee) async {
    final ok = await confirmEmployeeAction(
      context,
      title: 'Approve this payment?',
      message: 'Approving ${fee.paidLabel} for ${fee.displayName} unlocks '
          'their gate pass.',
      confirmLabel: 'Approve',
    );
    if (!ok || !mounted) return;

    final error = await _controller.approve(fee);
    if (!mounted) return;

    showEmployeeToast(
      context,
      error ?? 'Approved — gate pass unlocked',
      isError: error != null,
    );
  }

  Future<void> _reject(EmployeeFee fee) async {
    final ok = await confirmEmployeeAction(
      context,
      title: 'Reject this payment?',
      message: "The student's gate pass stays locked until a new collection is "
          'recorded and approved.',
      confirmLabel: 'Reject',
      destructive: true,
    );
    if (!ok || !mounted) return;

    final error = await _controller.reject(fee);
    if (!mounted) return;

    showEmployeeToast(
      context,
      error ?? 'Payment rejected',
      isError: error != null,
    );
  }

  Future<void> _openDetail(EmployeeFee fee) {
    return showEmployeeSheet<void>(
      context: context,
      title: fee.displayName,
      subtitle: 'Fee record #${fee.id}',
      builder: (sheetContext) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EmployeeChip(label: fee.approvalStatus),
              const SizedBox(width: EmployeeTokens.space2),
              EmployeeChip(label: fee.paymentStatus),
            ],
          ),
          const SizedBox(height: EmployeeTokens.space5),
          EmployeeDetailRow(label: 'Student', value: fee.displayName),
          EmployeeDetailRow(label: 'Phone', value: fee.studentPhone),
          EmployeeDetailRow(label: 'Batch', value: fee.displayBatch),
          EmployeeDetailRow(label: 'Sport', value: fee.sportName),
          const Divider(height: EmployeeTokens.space6),
          EmployeeDetailRow(
            label: 'Collected',
            value: fee.paidLabel,
            valueColor: EmployeeTokens.success,
          ),
          if (fee.batchFeesLabel != null)
            EmployeeDetailRow(label: 'Batch fee', value: fee.batchFeesLabel!),
          EmployeeDetailRow(label: 'Mode', value: fee.paymentMode ?? ''),
          EmployeeDetailRow(label: 'Enrolled', value: fee.enrolledLabel),
          if ((fee.notes ?? '').isNotEmpty)
            EmployeeDetailRow(label: 'Notes', value: fee.notes!),

          if (fee.isApproved) ...[
            const SizedBox(height: EmployeeTokens.space5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(EmployeeTokens.space4),
              decoration: BoxDecoration(
                color: EmployeeTokens.success.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(EmployeeTokens.radiusMd),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.qr_code_2_rounded,
                    size: 26,
                    color: EmployeeTokens.success,
                  ),
                  const SizedBox(height: EmployeeTokens.space2),
                  const Text(
                    'Gate pass unlocked',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: EmployeeTokens.success,
                    ),
                  ),
                  const SizedBox(height: EmployeeTokens.space2),
                  SelectableText(
                    fee.gatePassCode,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontFamily: 'monospace',
                      letterSpacing: 0.8,
                      color: EmployeeTokens.textDark,
                    ),
                  ),
                  const SizedBox(height: EmployeeTokens.space2),
                  const Text(
                    'The student sees this pass in their own app. Ask them to '
                    'open My Bookings if they cannot find it.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: EmployeeTokens.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (fee.isAwaitingApproval) ...[
            const SizedBox(height: EmployeeTokens.space5),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await _approve(fee);
                    },
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Approve'),
                    style: FilledButton.styleFrom(
                      backgroundColor: EmployeeTokens.success,
                      padding: const EdgeInsets.symmetric(
                        vertical: EmployeeTokens.space4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(EmployeeTokens.radiusSm),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: EmployeeTokens.space3),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await _reject(fee);
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                    label: const Text('Reject'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: EmployeeTokens.danger,
                      side: const BorderSide(color: EmployeeTokens.border),
                      padding: const EdgeInsets.symmetric(
                        vertical: EmployeeTokens.space4,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(EmployeeTokens.radiusSm),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
