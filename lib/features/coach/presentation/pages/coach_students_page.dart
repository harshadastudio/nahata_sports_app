import 'package:flutter/material.dart';

import '../../data/repositories/coach_dashboard_repository_impl.dart';
import '../../domain/entities/coach_student.dart';
import '../../domain/repositories/coach_dashboard_repository.dart';
import '../state/coach_students_controller.dart';
import '../state/coach_view_state.dart';
import '../theme/coach_theme.dart';
import '../widgets/coach_states.dart';

/// My Students — the coach's roster.
///
/// Rows are **enrollments**, so a student in two of this coach's batches
/// appears once per batch. That is what the backend counts, and the header
/// says so rather than quietly de-duplicating and disagreeing with the
/// dashboard's student tile.
class CoachStudentsPage extends StatefulWidget {
  const CoachStudentsPage({super.key, this.repository});

  final CoachDashboardRepository? repository;

  @override
  State<CoachStudentsPage> createState() => _CoachStudentsPageState();
}

class _CoachStudentsPageState extends State<CoachStudentsPage> {
  late final CoachStudentsController _controller = CoachStudentsController(
    widget.repository ?? CoachDashboardRepositoryImpl(),
  );

  final _scroll = ScrollController();
  final _search = TextEditingController();

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

  /// Fetches the next page a screen-and-a-bit before the end, so the list does
  /// not visibly stall at the bottom.
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CoachTokens.canvas,
      appBar: AppBar(
        backgroundColor: CoachTokens.brand,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'My Students',
          style: TextStyle(fontWeight: FontWeight.w600),
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
              hintText: 'Search by name',
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
                for (final status in CoachStudentsController.statusFilters)
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

  // ---------------------------------------------------------------------------
  // List
  // ---------------------------------------------------------------------------

  Widget _list() {
    if (_controller.state.isLoading && _controller.students.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(CoachTokens.space4),
        children: const [CoachListShimmer()],
      );
    }

    if (_controller.state.isFailed && _controller.students.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: CoachTokens.space8),
          CoachErrorView(
            message: _controller.error ?? 'Could not load your students.',
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
                  title: 'No matching students',
                  message: 'Nothing on your roster matches those filters.',
                  actionLabel: 'Clear filters',
                  onAction: () {
                    _search.clear();
                    _controller.clearFilters();
                  },
                )
              : const CoachEmptyView(
                  icon: Icons.people_outline_rounded,
                  title: 'No students yet',
                  message:
                      'Students enrolled in your batches will appear here. Ask '
                      'an admin to assign you a batch if this looks wrong.',
                ),
        ],
      );
    }

    // +2: the count header, and the trailing loader / end-of-list marker.
    return ListView.builder(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        CoachTokens.space4,
        CoachTokens.space3,
        CoachTokens.space4,
        CoachTokens.space8,
      ),
      itemCount: _controller.students.length + 2,
      itemBuilder: (context, index) {
        if (index == 0) return _countHeader();

        if (index == _controller.students.length + 1) return _footer();

        return _studentCard(_controller.students[index - 1]);
      },
    );
  }

  Widget _countHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: CoachTokens.space3),
      child: Text(
        'Showing ${_controller.students.length} of ${_controller.total} '
        'enrolment${_controller.total == 1 ? '' : 's'}',
        style: const TextStyle(
          fontSize: 12,
          color: CoachTokens.textMuted,
        ),
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

    // A failed *append* keeps the rows already loaded and offers a retry, so a
    // dropped page never costs the coach the list they were reading.
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

  Widget _studentCard(CoachStudent student) {
    final attendanceTone =
        CoachTokens.attendanceColor(student.attendancePercent);

    return CoachCard(
      margin: const EdgeInsets.only(bottom: CoachTokens.space3),
      onTap: () => _showDetail(student),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CoachAvatar(initial: student.initial),
          const SizedBox(width: CoachTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        student.displayName,
                        style: const TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: CoachTokens.textDark,
                        ),
                      ),
                    ),
                    const SizedBox(width: CoachTokens.space2),
                    CoachStatusChip(label: student.statusLabel),
                  ],
                ),
                if (student.batchName.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    student.batchName,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: CoachTokens.textBody,
                    ),
                  ),
                ],
                const SizedBox(height: CoachTokens.space3),
                Row(
                  children: [
                    _metric(
                      Icons.how_to_reg_outlined,
                      student.attendanceLabel,
                      attendanceTone,
                    ),
                    const SizedBox(width: CoachTokens.space4),
                    _metric(
                      Icons.trending_up_rounded,
                      student.performanceLabel,
                      student.hasPerformance
                          ? CoachTokens.purple
                          : CoachTokens.textMuted,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(IconData icon, String value, Color tone) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.5, color: tone),
          const SizedBox(width: 5),
          Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: tone,
            ),
          ),
        ],
      );

  // ---------------------------------------------------------------------------
  // Detail
  // ---------------------------------------------------------------------------

  void _showDetail(CoachStudent student) {
    showModalBottomSheet<void>(
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
          CoachTokens.space5,
          CoachTokens.space3,
          CoachTokens.space5,
          CoachTokens.space6,
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
                  margin: const EdgeInsets.only(bottom: CoachTokens.space5),
                  decoration: BoxDecoration(
                    color: CoachTokens.border,
                    borderRadius:
                        BorderRadius.circular(CoachTokens.radiusPill),
                  ),
                ),
              ),
              Row(
                children: [
                  CoachAvatar(initial: student.initial, radius: 26),
                  const SizedBox(width: CoachTokens.space3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.displayName,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: CoachTokens.textDark,
                          ),
                        ),
                        const SizedBox(height: 3),
                        CoachStatusChip(label: student.statusLabel),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: CoachTokens.space5),
              _detailRow(Icons.groups_2_outlined, 'Batch', student.batchName),
              _detailRow(Icons.phone_outlined, 'Phone', student.phone),
              _detailRow(Icons.mail_outline_rounded, 'Email', student.email),
              _detailRow(
                Icons.how_to_reg_outlined,
                'Attendance',
                student.attendanceLabel,
              ),
              _detailRow(
                Icons.trending_up_rounded,
                'Performance',
                student.performanceLabel,
              ),
              _detailRow(
                Icons.event_outlined,
                'Enrolled',
                student.enrollmentDate == null
                    ? ''
                    : _formatDate(student.enrollmentDate!),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    if (value.trim().isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: CoachTokens.space4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: CoachTokens.textMuted),
          const SizedBox(width: CoachTokens.space3),
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                color: CoachTokens.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: CoachTokens.textDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// `06 Aug 2026`. Formatted by hand rather than through `intl` so the coach
  /// screens do not depend on a locale being initialised.
  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')} '
      '${_months[date.month - 1]} ${date.year}';
}
