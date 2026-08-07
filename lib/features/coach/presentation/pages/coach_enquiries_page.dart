import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/coach_log.dart';
import '../../data/repositories/coach_dashboard_repository_impl.dart';
import '../../domain/entities/coach_enquiry.dart';
import '../../domain/repositories/coach_dashboard_repository.dart';
import '../state/coach_enquiries_controller.dart';
import '../state/coach_view_state.dart';
import '../theme/coach_theme.dart';
import '../widgets/coach_enquiry_form_sheet.dart';
import '../widgets/coach_states.dart';

/// Coaching Enquiries — the coach's own queue.
///
/// A coach may move an enquiry to Pending, Reviewed, Contacted or Rejected.
/// `Approved` is admin-only (the backend 400s on it), so it is never offered
/// here — approving is what enrolls the student, and that is not a coach's
/// call.
class CoachEnquiriesPage extends StatefulWidget {
  const CoachEnquiriesPage({super.key, this.repository});

  final CoachDashboardRepository? repository;

  @override
  State<CoachEnquiriesPage> createState() => _CoachEnquiriesPageState();
}

class _CoachEnquiriesPageState extends State<CoachEnquiriesPage> {
  late final CoachDashboardRepository _repository =
      widget.repository ?? CoachDashboardRepositoryImpl();
  late final CoachEnquiriesController _controller =
      CoachEnquiriesController(_repository);

  final _scroll = ScrollController();

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
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _create() async {
    CoachLog.ui('New enquiry tapped');

    final sent = await showCoachEnquiryFormSheet(
      context: context,
      repository: _repository,
      onSubmit: _controller.create,
    );

    if (!mounted || !sent) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enquiry sent to admin'),
        backgroundColor: CoachTokens.success,
      ),
    );
  }

  Future<void> _changeStatus(CoachEnquiry enquiry) async {
    final picked = await showModalBottomSheet<CoachEnquiryStatus>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: CoachTokens.surface,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(CoachTokens.radiusLg + 4),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          CoachTokens.space4,
          CoachTokens.space3,
          CoachTokens.space4,
          CoachTokens.space5,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: CoachTokens.space4),
                  decoration: BoxDecoration(
                    color: CoachTokens.border,
                    borderRadius:
                        BorderRadius.circular(CoachTokens.radiusPill),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CoachTokens.space2,
                ),
                child: Text(
                  'Move ${enquiry.displayName} to',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: CoachTokens.textDark,
                  ),
                ),
              ),
              const SizedBox(height: CoachTokens.space3),
              // Only the four a coach is allowed to set — `Approved` would be
              // refused with a 400.
              ...CoachEnquiryStatus.coachSettable.map(
                (status) => ListTile(
                  dense: true,
                  leading: Icon(
                    enquiry.status == status
                        ? Icons.radio_button_checked_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 20,
                    color: CoachTokens.statusColor(status.slug),
                  ),
                  title: Text(
                    status.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: CoachTokens.textDark,
                    ),
                  ),
                  onTap: () => Navigator.of(context).pop(status),
                ),
              ),
              const SizedBox(height: CoachTokens.space2),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: CoachTokens.space3,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 15,
                      color: CoachTokens.textMuted,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'To approve and enrol the student, use Approve & '
                        'enrol from the menu — approving does more than change '
                        'this status.',
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.4,
                          color: CoachTokens.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (picked == null || picked == enquiry.status || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _controller.updateStatus(enquiry.id, picked);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Could not update that enquiry.',
          ),
          backgroundColor: CoachTokens.danger,
        ),
      );
    }
  }

  /// Approving is the one enquiry action that creates records rather than
  /// moving a status, so it is confirmed and it says what will happen.
  Future<void> _approveAndEnroll(CoachEnquiry enquiry) async {
    CoachLog.ui('Approve & enrol ${enquiry.id}');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CoachTokens.radiusMd),
        ),
        icon: const Icon(
          Icons.how_to_reg_rounded,
          size: 30,
          color: CoachTokens.success,
        ),
        title: const Text(
          'Approve and enrol?',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          '${enquiry.displayName} will be created as a student and enrolled '
          'in ${enquiry.batchName ?? 'the batch'}. Their fee record starts '
          'as Pending, so you can collect it from Fees Management afterwards.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: CoachTokens.textMuted),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: CoachTokens.success),
            child: const Text('Approve & enrol'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _controller.approveAndEnroll(id: enquiry.id);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${enquiry.displayName} enrolled'),
          backgroundColor: CoachTokens.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            // The backend's own wording is the useful part here — "Batch is
            // full" and "already approved" both arrive as a 400.
            e is ApiException ? e.message : 'Could not approve that enquiry.',
          ),
          backgroundColor: CoachTokens.danger,
        ),
      );
    }
  }

  Future<void> _delete(CoachEnquiry enquiry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(CoachTokens.radiusMd),
        ),
        title: const Text(
          'Delete enquiry?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
        content: Text(
          "${enquiry.displayName}'s enquiry will be removed for the admin "
          'team too.',
          style: const TextStyle(fontSize: 13.5, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(foregroundColor: CoachTokens.textMuted),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: CoachTokens.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await _controller.delete(enquiry.id);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Enquiry deleted'),
          backgroundColor: CoachTokens.success,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is ApiException ? e.message : 'Could not delete that enquiry.',
          ),
          backgroundColor: CoachTokens.danger,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoachTokens.canvas,
      appBar: AppBar(
        backgroundColor: CoachTokens.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Coaching Enquiries',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: CoachRefreshLine(visible: _controller.refreshing),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: CoachTokens.brand,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New'),
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

  Widget _filters() {
    return Container(
      color: CoachTokens.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: CoachTokens.space4,
        vertical: CoachTokens.space2,
      ),
      child: SizedBox(
        height: 40,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            // Every status is filterable, including the admin-only `Approved` —
            // a coach cannot set it but does need to see what got approved.
            for (final status in CoachEnquiryStatus.values)
              Padding(
                padding: const EdgeInsets.only(right: CoachTokens.space2),
                child: FilterChip(
                  label: Text(status.label),
                  selected: _controller.status == status,
                  onSelected: (_) => _controller.setStatus(status),
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _controller.status == status
                        ? CoachTokens.statusColor(status.slug)
                        : CoachTokens.textBody,
                  ),
                  backgroundColor: CoachTokens.canvas,
                  selectedColor: CoachTokens.statusColor(status.slug)
                      .withValues(alpha: 0.14),
                  side: BorderSide(
                    color: _controller.status == status
                        ? CoachTokens.statusColor(status.slug)
                        : CoachTokens.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CoachTokens.radiusPill),
                  ),
                ),
              ),
            if (_controller.isFiltered)
              TextButton.icon(
                onPressed: _controller.clearFilters,
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
    );
  }

  Widget _list() {
    if (_controller.state.isLoading && _controller.enquiries.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(CoachTokens.space4),
        children: const [CoachListShimmer()],
      );
    }

    if (_controller.state.isFailed && _controller.enquiries.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: CoachTokens.space8),
          CoachErrorView(
            message: _controller.error ?? 'Could not load your enquiries.',
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
          _controller.isFiltered
              ? CoachEmptyView(
                  icon: Icons.search_off_rounded,
                  title: 'Nothing matches',
                  message: 'No enquiry of yours has that status.',
                  actionLabel: 'Clear filters',
                  onAction: _controller.clearFilters,
                )
              : CoachEmptyView(
                  icon: Icons.forum_outlined,
                  title: 'No enquiries yet',
                  message:
                      'Enquiries assigned to you appear here. You can also '
                      'file one for a prospective student.',
                  actionLabel: 'New enquiry',
                  onAction: _create,
                ),
        ],
      );
    }

    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        CoachTokens.space4,
        CoachTokens.space3,
        CoachTokens.space4,
        // Room for the FAB.
        CoachTokens.space8 + 56,
      ),
      itemCount: _controller.enquiries.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) return _summary();
        if (index == _controller.enquiries.length + 1) return _footer();
        return _enquiryCard(_controller.enquiries[index - 1]);
      },
    );
  }

  Widget _summary() {
    return Padding(
      padding: const EdgeInsets.only(bottom: CoachTokens.space3),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${_controller.enquiries.length} of ${_controller.total} '
              'enquir${_controller.total == 1 ? 'y' : 'ies'}',
              style: const TextStyle(
                fontSize: 12,
                color: CoachTokens.textMuted,
              ),
            ),
          ),
          if (_controller.openCount > 0)
            CoachStatusChip(
              label: '${_controller.openCount} open',
              color: CoachTokens.warning,
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

  Widget _enquiryCard(CoachEnquiry enquiry) {
    final tone = CoachTokens.statusColor(enquiry.statusLabel);

    return CoachCard(
      margin: const EdgeInsets.only(bottom: CoachTokens.space3),
      accentColor: tone,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CoachAvatar(initial: enquiry.initial, radius: 19, color: tone),
              const SizedBox(width: CoachTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      enquiry.displayName,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: CoachTokens.textDark,
                      ),
                    ),
                    if (enquiry.contactLabel.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        enquiry.contactLabel,
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
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert_rounded,
                  size: 19,
                  color: CoachTokens.textMuted,
                ),
                padding: EdgeInsets.zero,
                onSelected: (value) {
                  if (value == 'approve') _approveAndEnroll(enquiry);
                  if (value == 'status') _changeStatus(enquiry);
                  if (value == 'delete') _delete(enquiry);
                },
                itemBuilder: (context) => [
                  // Hidden once approved — the backend refuses a second
                  // approval with a 400, so offering it would only fail.
                  if (enquiry.status != CoachEnquiryStatus.approved)
                    const PopupMenuItem(
                      value: 'approve',
                      child: Text('Approve & enrol'),
                    ),
                  const PopupMenuItem(
                    value: 'status',
                    child: Text('Change status'),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ],
          ),
          if (enquiry.contextLabel.isNotEmpty) ...[
            const SizedBox(height: CoachTokens.space2 + 2),
            Text(
              enquiry.contextLabel,
              style: const TextStyle(
                fontSize: 12.5,
                color: CoachTokens.textBody,
              ),
            ),
          ],
          if ((enquiry.message ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: CoachTokens.space2 + 2),
            Text(
              enquiry.message!.trim(),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: CoachTokens.textBody,
              ),
            ),
          ],
          const SizedBox(height: CoachTokens.space3),
          Row(
            children: [
              InkWell(
                onTap: () => _changeStatus(enquiry),
                borderRadius: BorderRadius.circular(CoachTokens.radiusPill),
                child: CoachStatusChip(
                  label: enquiry.statusLabel,
                  color: tone,
                  icon: Icons.expand_more_rounded,
                ),
              ),
              const Spacer(),
              if (enquiry.createdAt != null)
                Text(
                  _formatDate(enquiry.createdAt!),
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: CoachTokens.textMuted,
                  ),
                ),
            ],
          ),
          if (enquiry.referenceNumber != null) ...[
            const SizedBox(height: CoachTokens.space2),
            Text(
              enquiry.referenceNumber!,
              style: const TextStyle(
                fontSize: 10.5,
                letterSpacing: 0.4,
                color: CoachTokens.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')} '
      '${_months[date.month - 1]} ${date.year}';
}
