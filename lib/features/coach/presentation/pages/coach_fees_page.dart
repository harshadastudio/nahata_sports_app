import 'package:flutter/material.dart';

import '../../core/coach_log.dart';
import '../../data/repositories/coach_dashboard_repository_impl.dart';
import '../../domain/entities/coach_fee.dart';
import '../../domain/repositories/coach_dashboard_repository.dart';
import '../state/coach_fees_controller.dart';
import '../state/coach_view_state.dart';
import '../theme/coach_theme.dart';
import '../utils/coach_gate_pass.dart';
import '../widgets/coach_fee_detail_sheet.dart';
import '../widgets/coach_payment_sheet.dart';
import '../widgets/coach_states.dart';

/// Which of the two fee screens this is.
enum CoachFeesMode {
  /// Fees Management — every fee record for the coach's students, with the
  /// payment actions.
  management,

  /// Fees Approval — the website's coach Fees Approval page.
  ///
  /// Every fee record, filtered by payment status, opened for editing, and —
  /// once an admin has signed a record off — carrying the student's gate pass
  /// and the WhatsApp hand-off.
  ///
  /// A coach still cannot approve or reject: `PATCH /fees/{id}/approve` and
  /// `/reject` are ADMIN / COMPLEX_ADMIN / EMPLOYEE only and answer 403, so
  /// the screen says who has to act instead of offering a button that fails.
  approval,
}

/// Fee records for the coach's own students.
///
/// The backend scopes `/fees` to the coach's batches, so nothing here filters
/// by coach — a coach cannot see another's records even by asking.
class CoachFeesPage extends StatefulWidget {
  const CoachFeesPage({
    super.key,
    this.mode = CoachFeesMode.management,
    this.repository,
  });

  final CoachFeesMode mode;
  final CoachDashboardRepository? repository;

  @override
  State<CoachFeesPage> createState() => _CoachFeesPageState();
}

class _CoachFeesPageState extends State<CoachFeesPage> {
  // Neither screen pins the approval filter: the website's Fees Approval page
  // lists every record and filters by *payment* status, so the coach can find
  // an approved record again to re-issue its gate pass.
  late final CoachFeesController _controller = CoachFeesController(
    widget.repository ?? CoachDashboardRepositoryImpl(),
  );

  final _scroll = ScrollController();
  final _search = TextEditingController();

  bool get _isApproval => widget.mode == CoachFeesMode.approval;

  /// The website's Fees Approval dropdown offers All / Pending / Paid; the
  /// management screen keeps all four.
  List<CoachPaymentStatus> get _statusFilters => _isApproval
      ? const [CoachPaymentStatus.pending, CoachPaymentStatus.paid]
      : CoachPaymentStatus.values;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _scroll.addListener(_onScroll);
    _controller.load();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final remaining = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    if (remaining < 400) _controller.loadMore();
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _recordPayment(CoachFee fee) async {
    CoachLog.ui('Record payment for fee ${fee.id}');

    final saved = await showCoachPaymentSheet(
      context: context,
      fee: fee,
      onSubmit: (draft) =>
          _controller.recordPayment(id: fee.id, draft: draft),
    );

    if (!mounted || !saved) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment recorded — sent for admin approval'),
        backgroundColor: CoachTokens.success,
        duration: Duration(seconds: 4),
      ),
    );
  }

  /// The record's details, its edit form, and — once approved — its gate pass.
  Future<void> _openDetail(CoachFee fee) async {
    CoachLog.ui('Open fee record ${fee.id}');

    final saved = await showCoachFeeDetailSheet(
      context: context,
      fee: fee,
      onSave: (edit) => _controller.updateRecord(id: fee.id, edit: edit),
    );

    if (!mounted || !saved) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Record updated — sent for admin approval'),
        backgroundColor: CoachTokens.success,
        duration: Duration(seconds: 4),
      ),
    );
  }

  Future<void> _sendGatePass(CoachFee fee) async {
    final message = await CoachGatePass.sendToWhatsApp(fee);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: message == CoachGatePass.opening
            ? CoachTokens.success
            : CoachTokens.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoachTokens.canvas,
      appBar: AppBar(
        backgroundColor: CoachTokens.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          _isApproval ? 'Fees Approval' : 'Fees Management',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: CoachRefreshLine(visible: _controller.refreshing),
        ),
      ),
      body: Column(
        children: [
          _filters(),
          Expanded(
            child: RefreshIndicator(
              color: CoachTokens.brand,
              onRefresh: _controller.refresh,
              child: _list(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Filters
  // ---------------------------------------------------------------------------

  Widget _filters() {
    return Container(
      color: CoachTokens.surface,
      padding: const EdgeInsets.fromLTRB(
        CoachTokens.space4,
        CoachTokens.space3,
        CoachTokens.space4,
        CoachTokens.space2,
      ),
      child: Column(
        children: [
          TextField(
            controller: _search,
            onChanged: _controller.onSearchChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(fontSize: 14.5),
            decoration: InputDecoration(
              hintText: 'Search by student name',
              hintStyle: const TextStyle(
                fontSize: 14,
                color: CoachTokens.textMuted,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 20,
                color: CoachTokens.textMuted,
              ),
              suffixIcon: _controller.search.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: CoachTokens.textMuted,
                      onPressed: () {
                        _search.clear();
                        _controller.clearSearch();
                      },
                    ),
              filled: true,
              fillColor: CoachTokens.canvas,
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                vertical: CoachTokens.space3,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
                borderSide: const BorderSide(color: CoachTokens.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
                borderSide: const BorderSide(color: CoachTokens.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
                borderSide: const BorderSide(
                  color: CoachTokens.brand,
                  width: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: CoachTokens.space2),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final status in _statusFilters)
                  Padding(
                    padding: const EdgeInsets.only(right: CoachTokens.space2),
                    child: FilterChip(
                      label: Text(status.label),
                      selected: _controller.paymentStatus == status,
                      onSelected: (_) => _controller.setPaymentStatus(status),
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _controller.paymentStatus == status
                            ? CoachTokens.statusColor(status.slug)
                            : CoachTokens.textBody,
                      ),
                      backgroundColor: CoachTokens.canvas,
                      selectedColor: CoachTokens.statusColor(status.slug)
                          .withValues(alpha: 0.14),
                      side: BorderSide(
                        color: _controller.paymentStatus == status
                            ? CoachTokens.statusColor(status.slug)
                            : CoachTokens.border,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(CoachTokens.radiusPill),
                      ),
                    ),
                  ),
                if (_controller.isFiltered)
                  TextButton.icon(
                    onPressed: () {
                      _search.clear();
                      _controller.clearFilters();
                    },
                    icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                      foregroundColor: CoachTokens.textMuted,
                      textStyle: const TextStyle(fontSize: 12.5),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // List
  // ---------------------------------------------------------------------------

  Widget _list() {
    if (_controller.state.isLoading && _controller.fees.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(CoachTokens.space4),
        children: const [
          CoachStatsShimmer(tiles: 4),
          SizedBox(height: CoachTokens.space5),
          CoachListShimmer(rows: 3),
        ],
      );
    }

    if (_controller.state.isFailed && _controller.fees.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: CoachTokens.space8),
          CoachErrorView(
            message: _controller.error ?? 'Could not load fee records.',
            onRetry: _controller.load,
          ),
        ],
      );
    }

    if (_controller.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: CoachTokens.space8),
          if (_controller.isFiltered)
            CoachEmptyView(
              icon: Icons.search_off_rounded,
              title: 'Nothing matches',
              message: 'No fee record matches those filters.',
              actionLabel: 'Clear filters',
              onAction: () {
                _search.clear();
                _controller.clearFilters();
              },
            )
          else if (_isApproval)
            const CoachEmptyView(
              icon: Icons.verified_outlined,
              title: 'No fee records',
              message:
                  'Records appear here as students enrol in your batches and '
                  'their fees are collected.',
            )
          else
            const CoachEmptyView(
              icon: Icons.account_balance_wallet_outlined,
              title: 'No fee records',
              message:
                  'Fee records appear here once students are enrolled in your '
                  'batches.',
            ),
        ],
      );
    }

    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        CoachTokens.space4,
        CoachTokens.space4,
        CoachTokens.space4,
        CoachTokens.space8,
      ),
      itemCount: _controller.fees.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) return _header();
        if (index == _controller.fees.length + 1) return _footer();
        return _feeCard(_controller.fees[index - 1]);
      },
    );
  }

  Widget _header() {
    final stats = _controller.stats;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_isApproval) ...[
          _approvalStats(stats),
          const SizedBox(height: CoachTokens.space4),
          _approvalNotice(),
        ] else
          _statsGrid(stats),
        const SizedBox(height: CoachTokens.space4),
        Text(
          'Showing ${_controller.fees.length} of ${_controller.total} '
          'record${_controller.total == 1 ? '' : 's'}',
          style: const TextStyle(fontSize: 12, color: CoachTokens.textMuted),
        ),
        const SizedBox(height: CoachTokens.space3),
      ],
    );
  }

  /// The website's three approval cards — pending payments, total paid, total
  /// students — in the same order, over the same numbers.
  Widget _approvalStats(CoachFeeStats stats) {
    // IntrinsicHeight, not CrossAxisAlignment.stretch: these sit in a
    // ListView, where the incoming height is unbounded and stretch would ask
    // each tile to be infinitely tall. The intrinsic pass measures the tallest
    // tile first, so all three end up level and the accent stripes run the
    // full height.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _compactTile(
              'Pending payments',
              '${stats.unpaid}',
              Icons.error_outline_rounded,
              CoachTokens.danger,
            ),
          ),
          const SizedBox(width: CoachTokens.space3),
          Expanded(
            child: _compactTile(
              'Total paid',
              '${stats.paid}',
              Icons.check_circle_outline_rounded,
              CoachTokens.success,
            ),
          ),
          const SizedBox(width: CoachTokens.space3),
          Expanded(
            child: _compactTile(
              'Total students',
              '${stats.total}',
              Icons.people_alt_outlined,
              CoachTokens.info,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactTile(String label, String value, IconData icon, Color tone) {
    return CoachCard(
      padding: const EdgeInsets.symmetric(
        horizontal: CoachTokens.space2,
        vertical: CoachTokens.space4,
      ),
      accentColor: tone,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 21, color: tone),
          const SizedBox(height: CoachTokens.space2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: CoachTokens.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 10.5,
              height: 1.25,
              color: CoachTokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _statsGrid(CoachFeeStats stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: CoachTokens.space3,
      crossAxisSpacing: CoachTokens.space3,
      childAspectRatio: 2.4,
      children: [
        _statTile('Paid', '${stats.paid}', Icons.check_circle_outline_rounded,
            CoachTokens.success),
        _statTile('Pending', '${stats.unpaid}',
            Icons.hourglass_bottom_rounded, CoachTokens.warning),
        _statTile('Overdue', '${stats.overdue}',
            Icons.error_outline_rounded, CoachTokens.danger),
        _statTile('Awaiting approval', '${stats.pendingApproval}',
            Icons.verified_outlined, CoachTokens.info),
      ],
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color tone) {
    return CoachCard(
      padding: const EdgeInsets.symmetric(
        horizontal: CoachTokens.space3,
        vertical: CoachTokens.space3,
      ),
      accentColor: tone,
      child: Row(
        children: [
          Icon(icon, size: 19, color: tone),
          const SizedBox(width: CoachTokens.space2 + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 18,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: CoachTokens.textDark,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    color: CoachTokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// How many records are still waiting, and why this screen has no approve
  /// button on it.
  Widget _approvalNotice() {
    final waiting = _controller.stats.pendingApproval;
    final tone = waiting > 0 ? CoachTokens.warning : CoachTokens.info;

    return Container(
      padding: const EdgeInsets.all(CoachTokens.space4),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(CoachTokens.radiusMd),
        border: Border.all(color: tone.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            waiting > 0
                ? Icons.pending_actions_rounded
                : Icons.info_outline_rounded,
            size: 19,
            color: tone,
          ),
          const SizedBox(width: CoachTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (waiting > 0) ...[
                  Text(
                    '$waiting payment${waiting == 1 ? '' : 's'} awaiting '
                    'approval',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: tone,
                    ),
                  ),
                  const SizedBox(height: 3),
                ],
                const Text(
                  'Only an admin or employee can approve a payment, and until '
                  "they do the student's gate pass will not open. Open a "
                  'record to edit it, or to send an approved pass on WhatsApp.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: CoachTokens.textBody,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    if (_controller.loadingMore) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: CoachTokens.space5),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: CoachTokens.brand,
            ),
          ),
        ),
      );
    }

    if (_controller.error != null && _controller.hasMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: CoachTokens.space4),
        child: Center(
          child: TextButton.icon(
            onPressed: _controller.loadMore,
            icon: const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Load more'),
            style: TextButton.styleFrom(foregroundColor: CoachTokens.brand),
          ),
        ),
      );
    }

    return const SizedBox(height: CoachTokens.space4);
  }

  Widget _feeCard(CoachFee fee) {
    final tone = CoachTokens.statusColor(fee.paymentLabel);

    return CoachCard(
      margin: const EdgeInsets.only(bottom: CoachTokens.space3),
      accentColor: tone,
      onTap: () => _openDetail(fee),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoachAvatar(initial: fee.initial, radius: 19, color: tone),
              const SizedBox(width: CoachTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fee.displayName,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: CoachTokens.textDark,
                      ),
                    ),
                    if (fee.contextLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        fee.contextLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: CoachTokens.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: CoachTokens.space2),
              Text(
                fee.amountLabel,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: tone,
                ),
              ),
            ],
          ),
          const SizedBox(height: CoachTokens.space3),
          Wrap(
            spacing: CoachTokens.space2,
            runSpacing: CoachTokens.space2,
            children: [
              CoachStatusChip(label: fee.paymentLabel, color: tone),
              CoachStatusChip(
                label: fee.approvalLabel,
                color: fee.isApproved
                    ? CoachTokens.success
                    : fee.isRejected
                        ? CoachTokens.danger
                        : CoachTokens.warning,
                icon: fee.isApproved
                    ? Icons.verified_rounded
                    : Icons.hourglass_bottom_rounded,
              ),
              if (fee.paymentMode != null)
                CoachStatusChip(
                  label: fee.paymentMode!.label,
                  color: CoachTokens.textMuted,
                ),
            ],
          ),
          // The state a coach most needs to notice: money collected, but the
          // student still cannot get in.
          if (fee.paidButUnapproved) ...[
            const SizedBox(height: CoachTokens.space3),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.lock_clock_rounded,
                  size: 15,
                  color: CoachTokens.warning,
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text(
                    'Paid, but the gate pass is locked until an admin '
                    'approves it.',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: CoachTokens.warning,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if ((fee.validTill ?? '').isNotEmpty) ...[
            const SizedBox(height: CoachTokens.space2 + 2),
            Text(
              'Valid till ${fee.validTill}',
              style: const TextStyle(
                fontSize: 11,
                color: CoachTokens.textMuted,
              ),
            ),
          ],
          const SizedBox(height: CoachTokens.space3),
          // Approving is admin-only, so the approval screen offers what a coach
          // *can* do with a record: open it, and hand an approved pass over.
          if (_isApproval)
            Row(
              children: [
                Expanded(
                  child: _cardAction(
                    label: 'View details',
                    icon: Icons.visibility_outlined,
                    tone: CoachTokens.brand,
                    onPressed: () => _openDetail(fee),
                  ),
                ),
                if (fee.isApproved) ...[
                  const SizedBox(width: CoachTokens.space2),
                  Expanded(
                    child: _cardAction(
                      label: 'Send pass',
                      icon: Icons.chat_rounded,
                      tone: const Color(0xFF25D366),
                      onPressed: () => _sendGatePass(fee),
                    ),
                  ),
                ],
              ],
            )
          else
            _cardAction(
              label: fee.isPaid ? 'Update payment' : 'Record payment',
              icon: Icons.payments_outlined,
              tone: CoachTokens.brand,
              onPressed: () => _recordPayment(fee),
            ),
        ],
      ),
    );
  }

  Widget _cardAction({
    required String label,
    required IconData icon,
    required Color tone,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17),
        label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        style: OutlinedButton.styleFrom(
          foregroundColor: tone,
          side: const BorderSide(color: CoachTokens.border),
          padding: const EdgeInsets.symmetric(vertical: CoachTokens.space3),
          textStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
          ),
        ),
      ),
    );
  }
}
