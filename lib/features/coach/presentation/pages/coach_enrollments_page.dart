import 'package:flutter/material.dart';

import '../../data/repositories/coach_dashboard_repository_impl.dart';
import '../../domain/entities/coach_enrollment.dart';
import '../../domain/repositories/coach_dashboard_repository.dart';
import '../state/coach_enrollments_controller.dart';
import '../state/coach_view_state.dart';
import '../theme/coach_theme.dart';
import '../widgets/coach_states.dart';

/// Student Enrollments — one month's roster, grouped batch-wise.
///
/// A student is listed in **every** month their enrollment is live, not only
/// the month they joined, so each row says whether they are new this month or
/// carried over, and whether their validity runs out inside it.
class CoachEnrollmentsPage extends StatefulWidget {
  const CoachEnrollmentsPage({super.key, this.repository});

  final CoachDashboardRepository? repository;

  @override
  State<CoachEnrollmentsPage> createState() => _CoachEnrollmentsPageState();
}

class _CoachEnrollmentsPageState extends State<CoachEnrollmentsPage> {
  late final CoachEnrollmentsController _controller =
      CoachEnrollmentsController(
    widget.repository ?? CoachDashboardRepositoryImpl(),
  );

  final _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _controller.load();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onChanged);
    _controller.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoachTokens.canvas,
      appBar: AppBar(
        backgroundColor: CoachTokens.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Student Enrollments',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_controller.batches.isNotEmpty)
            IconButton(
              tooltip: 'Collapse all',
              onPressed: _controller.collapseAll,
              icon: const Icon(Icons.unfold_less_rounded),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: CoachRefreshLine(visible: _controller.refreshing),
        ),
      ),
      body: Column(
        children: [
          _controls(),
          Expanded(
            child: RefreshIndicator(
              color: CoachTokens.brand,
              onRefresh: _controller.refresh,
              child: _body(),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Controls
  // ---------------------------------------------------------------------------

  Widget _controls() {
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
          Row(
            children: [
              Expanded(child: _monthPicker()),
              const SizedBox(width: CoachTokens.space3),
              Expanded(child: _searchField()),
            ],
          ),
          const SizedBox(height: CoachTokens.space2),
          SizedBox(
            height: 38,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final status in CoachEnrollmentsController.statusFilters)
                  Padding(
                    padding: const EdgeInsets.only(right: CoachTokens.space2),
                    child: FilterChip(
                      label: Text(status),
                      selected: _controller.status == status,
                      onSelected: (_) => _controller.setStatus(status),
                      showCheckmark: false,
                      labelStyle: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _controller.status == status
                            ? CoachTokens.brand
                            : CoachTokens.textBody,
                      ),
                      backgroundColor: CoachTokens.canvas,
                      selectedColor: CoachTokens.brandSoft,
                      side: BorderSide(
                        color: _controller.status == status
                            ? CoachTokens.brand
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

  /// Built from the month index the same response carries, so changing month
  /// costs one request rather than two.
  Widget _monthPicker() {
    final months = _controller.months;

    if (months.isEmpty) {
      return InputDecorator(
        decoration: _fieldDecoration('Month', Icons.calendar_month_outlined),
        child: Text(
          _controller.monthLabel.isEmpty ? '—' : _controller.monthLabel,
          style: const TextStyle(fontSize: 13.5, color: CoachTokens.textDark),
        ),
      );
    }

    // The backend can answer with a month that is not in the index (it falls
    // back to the current month even when that month is empty), and a
    // DropdownButton throws on a value with no matching item.
    final selected =
        months.any((m) => m.month == _controller.month) ? _controller.month : null;

    return DropdownButtonFormField<String>(
      initialValue: selected,
      isExpanded: true,
      style: const TextStyle(fontSize: 13.5, color: CoachTokens.textDark),
      decoration: _fieldDecoration('Month', Icons.calendar_month_outlined),
      items: months
          .map(
            (m) => DropdownMenuItem(
              value: m.month,
              child: Text(
                '${m.displayLabel}  (${m.count})',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) _controller.setMonth(value);
      },
    );
  }

  Widget _searchField() {
    return TextField(
      controller: _search,
      onChanged: _controller.onSearchChanged,
      textInputAction: TextInputAction.search,
      style: const TextStyle(fontSize: 13.5),
      decoration: _fieldDecoration('Search', Icons.search_rounded).copyWith(
        suffixIcon: _controller.search.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 17),
                color: CoachTokens.textMuted,
                onPressed: () {
                  _search.clear();
                  _controller.clearSearch();
                },
              ),
      ),
    );
  }

  InputDecoration _fieldDecoration(String label, IconData icon) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
        fontSize: 12.5,
        color: CoachTokens.textMuted,
      ),
      prefixIcon: Icon(icon, size: 18, color: CoachTokens.textMuted),
      filled: true,
      fillColor: CoachTokens.canvas,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: CoachTokens.space2,
        vertical: CoachTokens.space3 + 2,
      ),
      border: border(CoachTokens.border),
      enabledBorder: border(CoachTokens.border),
      focusedBorder: border(CoachTokens.brand, 1.4),
    );
  }

  // ---------------------------------------------------------------------------
  // Body
  // ---------------------------------------------------------------------------

  Widget _body() {
    if (_controller.state.isLoading && _controller.batches.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(CoachTokens.space4),
        children: const [
          CoachStatsShimmer(tiles: 4),
          SizedBox(height: CoachTokens.space5),
          CoachListShimmer(rows: 3),
        ],
      );
    }

    if (_controller.state.isFailed && _controller.batches.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: CoachTokens.space8),
          CoachErrorView(
            message: _controller.error ?? 'Could not load enrollments.',
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
          if (_controller.hasNoHistory)
            const CoachEmptyView(
              icon: Icons.calendar_month_outlined,
              title: 'No enrollments yet',
              message:
                  'Once students are enrolled in your batches, this shows who '
                  'was on the roster in each month.',
            )
          else if (_controller.isFiltered)
            CoachEmptyView(
              icon: Icons.search_off_rounded,
              title: 'Nothing matches',
              message:
                  'No enrollment in ${_controller.monthLabel} matches those '
                  'filters.',
              actionLabel: 'Clear filters',
              onAction: () {
                _search.clear();
                _controller.clearFilters();
              },
            )
          else
            CoachEmptyView(
              icon: Icons.event_busy_outlined,
              title: 'Nobody in ${_controller.monthLabel}',
              message: 'Pick another month to see who was enrolled then.',
            ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        CoachTokens.space4,
        CoachTokens.space4,
        CoachTokens.space4,
        CoachTokens.space8,
      ),
      itemCount: _controller.batches.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) return _summary();
        return _groupCard(_controller.batches[index - 1]);
      },
    );
  }

  Widget _summary() {
    final summary = _controller.summary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _controller.monthLabel,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: CoachTokens.textDark,
          ),
        ),
        const SizedBox(height: CoachTokens.space3),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: CoachTokens.space3,
          crossAxisSpacing: CoachTokens.space3,
          childAspectRatio: 2.4,
          children: [
            _summaryTile(
              'Students',
              '${summary.totalStudents}',
              Icons.people_alt_outlined,
              CoachTokens.info,
            ),
            _summaryTile(
              'New this month',
              '${summary.newThisMonth}',
              Icons.person_add_alt_outlined,
              CoachTokens.success,
            ),
            _summaryTile(
              'Expiring',
              '${summary.expiring}',
              Icons.hourglass_bottom_rounded,
              CoachTokens.warning,
            ),
            _summaryTile(
              'Fees pending',
              '${summary.pending}',
              Icons.account_balance_wallet_outlined,
              CoachTokens.danger,
            ),
          ],
        ),
        const SizedBox(height: CoachTokens.space5),
        Text(
          '${summary.totalBatches} batch'
          '${summary.totalBatches == 1 ? '' : 'es'}',
          style: const TextStyle(fontSize: 12, color: CoachTokens.textMuted),
        ),
        const SizedBox(height: CoachTokens.space2),
      ],
    );
  }

  Widget _summaryTile(String label, String value, IconData icon, Color tone) {
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

  Widget _groupCard(CoachEnrollmentGroup group) {
    final collapsed = _controller.isCollapsed(group.batchId);

    return CoachCard(
      margin: const EdgeInsets.only(bottom: CoachTokens.space3),
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => _controller.toggleGroup(group.batchId),
            child: Padding(
              padding: const EdgeInsets.all(CoachTokens.space4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          group.displayName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: CoachTokens.textDark,
                          ),
                        ),
                        if (group.timingLabel.isNotEmpty ||
                            (group.sportName ?? '').isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            [
                              if ((group.sportName ?? '').trim().isNotEmpty &&
                                  group.sportName!.trim() != '—')
                                group.sportName!.trim(),
                              if (group.timingLabel.isNotEmpty)
                                group.timingLabel,
                            ].join(' · '),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: CoachTokens.textBody,
                            ),
                          ),
                        ],
                        const SizedBox(height: CoachTokens.space3),
                        Wrap(
                          spacing: CoachTokens.space2,
                          runSpacing: CoachTokens.space2,
                          children: [
                            CoachStatusChip(
                              label: '${group.count} student'
                                  '${group.count == 1 ? '' : 's'}',
                              color: CoachTokens.info,
                              icon: Icons.people_outline_rounded,
                            ),
                            if (group.newCount > 0)
                              CoachStatusChip(
                                label: '${group.newCount} new',
                                color: CoachTokens.success,
                                icon: Icons.person_add_alt_outlined,
                              ),
                            if (group.expiringCount > 0)
                              CoachStatusChip(
                                label: '${group.expiringCount} expiring',
                                color: CoachTokens.warning,
                                icon: Icons.hourglass_bottom_rounded,
                              ),
                            if (group.unpaidCount > 0)
                              CoachStatusChip(
                                label: '${group.unpaidCount} unpaid',
                                color: CoachTokens.danger,
                                icon: Icons.currency_rupee_rounded,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    collapsed
                        ? Icons.expand_more_rounded
                        : Icons.expand_less_rounded,
                    size: 22,
                    color: CoachTokens.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (!collapsed) ...[
            const Divider(height: 1, color: CoachTokens.border),
            ...group.students.asMap().entries.map(
                  (e) => _enrollmentRow(
                    e.value,
                    // No rule under the last student — the card edge already
                    // closes the group.
                    isLast: e.key == group.students.length - 1,
                  ),
                ),
            const SizedBox(height: CoachTokens.space3),
          ],
        ],
      ),
    );
  }

  Widget _enrollmentRow(CoachEnrollment enrollment, {required bool isLast}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CoachTokens.space4,
        CoachTokens.space3,
        CoachTokens.space4,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoachAvatar(
            initial: enrollment.initial,
            radius: 16,
            color: enrollment.isNew ? CoachTokens.success : CoachTokens.brand,
          ),
          const SizedBox(width: CoachTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        enrollment.displayName,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: CoachTokens.textDark,
                        ),
                      ),
                    ),
                    if (enrollment.isNew) ...[
                      const SizedBox(width: CoachTokens.space2),
                      const CoachStatusChip(
                        label: 'New',
                        color: CoachTokens.success,
                      ),
                    ],
                  ],
                ),
                if (enrollment.contactLabel.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    enrollment.contactLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: CoachTokens.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: CoachTokens.space2),
                Wrap(
                  spacing: CoachTokens.space2,
                  runSpacing: CoachTokens.space1,
                  children: [
                    CoachStatusChip(label: enrollment.statusLabel),
                    if (enrollment.paymentLabel.isNotEmpty)
                      CoachStatusChip(
                        label: enrollment.paymentLabel,
                        color: enrollment.isPaid
                            ? CoachTokens.success
                            : CoachTokens.danger,
                      ),
                    // A pass only opens the gate once the enrollment is
                    // Approved, so anything else is worth flagging.
                    if (enrollment.approvalLabel.isNotEmpty &&
                        !enrollment.isApproved)
                      CoachStatusChip(
                        label: enrollment.approvalLabel,
                        color: CoachTokens.warning,
                      ),
                    if (enrollment.expiring)
                      const CoachStatusChip(
                        label: 'Expiring',
                        color: CoachTokens.warning,
                        icon: Icons.hourglass_bottom_rounded,
                      ),
                  ],
                ),
                const SizedBox(height: CoachTokens.space2),
                Text(
                  _validityLabel(enrollment),
                  style: const TextStyle(
                    fontSize: 11,
                    color: CoachTokens.textMuted,
                  ),
                ),
                if (!isLast) ...[
                  const SizedBox(height: CoachTokens.space2),
                  const Divider(height: 1, color: CoachTokens.border),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Names where the validity date came from — one inherited from the batch is
  /// not a per-student commitment, and a coach chasing a renewal needs to know
  /// which it is.
  String _validityLabel(CoachEnrollment enrollment) {
    final joined = (enrollment.enrollmentDate ?? '').trim();
    final until = (enrollment.validTill ?? '').trim();

    final parts = <String>[
      if (joined.isNotEmpty) 'Joined $joined',
      if (until.isEmpty)
        'No end date'
      else
        'Valid till $until${enrollment.validityFromBatch ? ' (batch)' : ''}',
    ];

    return parts.join('  ·  ');
  }
}
