import 'package:flutter/material.dart';

import '../../core/coach_log.dart';
import '../../data/repositories/coach_dashboard_repository_impl.dart';
import '../../domain/entities/coach_attendance.dart';
import '../../domain/entities/coach_option.dart';
import '../../domain/entities/coach_student.dart';
import '../../domain/repositories/coach_dashboard_repository.dart';
import '../state/coach_attendance_controller.dart';
import '../state/coach_view_state.dart';
import '../theme/coach_theme.dart';
import '../widgets/coach_states.dart';

/// The Attendance Sheet.
///
/// Two tabs, matching the website's page: **Mark** (pick a batch and a date,
/// set each student, save) and **Records** (the log of what has been marked).
///
/// Saving upserts on `(studentId, batchId, date)`, so re-saving a sheet
/// corrects it rather than duplicating — which is what makes the partial-save
/// retry below safe.
class CoachAttendancePage extends StatefulWidget {
  const CoachAttendancePage({super.key, this.repository});

  final CoachDashboardRepository? repository;

  @override
  State<CoachAttendancePage> createState() => _CoachAttendancePageState();
}

class _CoachAttendancePageState extends State<CoachAttendancePage>
    with SingleTickerProviderStateMixin {
  late final CoachDashboardRepository _repository =
      widget.repository ?? CoachDashboardRepositoryImpl();

  late final CoachAttendanceSheetController _sheet =
      CoachAttendanceSheetController(_repository);
  late final CoachAttendanceRecordsController _records =
      CoachAttendanceRecordsController(_repository);

  late final TabController _tabs = TabController(length: 2, vsync: this);

  @override
  void initState() {
    super.initState();
    _sheet.addListener(_onChanged);
    _records.addListener(_onChanged);
    // The save bar only belongs to the Mark tab, and switching tabs does not
    // rebuild on its own — so the swipe has to be listened for.
    _tabs.addListener(_onChanged);
    _sheet.loadBatches();
    _records.load();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _sheet.removeListener(_onChanged);
    _records.removeListener(_onChanged);
    _tabs.removeListener(_onChanged);
    _sheet.dispose();
    _records.dispose();
    _tabs.dispose();
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
          'Attendance',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          indicatorWeight: 2.5,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
          tabs: const [
            Tab(text: 'MARK'),
            Tab(text: 'RECORDS'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [_markTab(), _recordsTab()],
      ),
      bottomNavigationBar: _saveBar(),
    );
  }

  // ===========================================================================
  // Mark tab
  // ===========================================================================

  Widget _markTab() {
    if (_sheet.batchesState.isLoading && _sheet.batches.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(CoachTokens.space4),
        children: const [CoachListShimmer(rows: 4)],
      );
    }

    if (_sheet.batchesState.isFailed) {
      return CoachErrorView(
        message: _sheet.batchesError ?? 'Could not load your batches.',
        onRetry: _sheet.loadBatches,
      );
    }

    if (_sheet.batches.isEmpty) {
      return const CoachEmptyView(
        icon: Icons.groups_2_outlined,
        title: 'No active batches',
        message:
            'Attendance is marked against a batch, and you have none active. '
            'Ask an admin to assign you one.',
      );
    }

    return Column(
      children: [
        _sheetHeader(),
        Expanded(child: _roster()),
      ],
    );
  }

  Widget _sheetHeader() {
    return Container(
      color: CoachTokens.surface,
      padding: const EdgeInsets.fromLTRB(
        CoachTokens.space4,
        CoachTokens.space4,
        CoachTokens.space4,
        CoachTokens.space3,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<CoachOption>(
                  initialValue: _sheet.batch,
                  isExpanded: true,
                  style: const TextStyle(
                    fontSize: 14,
                    color: CoachTokens.textDark,
                  ),
                  decoration: _fieldDecoration(
                    'Batch',
                    Icons.groups_2_outlined,
                  ),
                  items: _sheet.batches
                      .map(
                        (b) => DropdownMenuItem(
                          value: b,
                          child: Text(
                            b.displayName,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: _sheet.saving ? null : _sheet.selectBatch,
                ),
              ),
              const SizedBox(width: CoachTokens.space3),
              Expanded(
                flex: 2,
                child: InkWell(
                  onTap: _sheet.saving ? null : _pickDate,
                  borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
                  child: InputDecorator(
                    decoration: _fieldDecoration(
                      'Date',
                      Icons.calendar_today_outlined,
                    ),
                    child: Text(
                      _sheet.dateKey,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: CoachTokens.textDark,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_sheet.roster.isNotEmpty) ...[
            const SizedBox(height: CoachTokens.space3),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${_sheet.markedCount}/${_sheet.roster.length} marked'
                    '${_sheet.markedCount == 0 ? '' : '  ·  ${_sheet.presentCount} present, ${_sheet.absentCount} absent'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: CoachTokens.textMuted,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: _sheet.saving
                      ? null
                      : () => _sheet.markAll(CoachAttendanceStatus.present),
                  style: TextButton.styleFrom(
                    foregroundColor: CoachTokens.success,
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('All present'),
                ),
                if (_sheet.markedCount > 0)
                  TextButton(
                    onPressed: _sheet.saving ? null : _sheet.clearMarks,
                    style: TextButton.styleFrom(
                      foregroundColor: CoachTokens.textMuted,
                      visualDensity: VisualDensity.compact,
                      textStyle: const TextStyle(fontSize: 12.5),
                    ),
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _roster() {
    if (_sheet.batch == null) {
      return const CoachEmptyView(
        icon: Icons.touch_app_outlined,
        title: 'Pick a batch',
        message: 'Choose one of your batches to load its students.',
      );
    }

    if (_sheet.rosterState.isLoading) {
      return ListView(
        padding: const EdgeInsets.all(CoachTokens.space4),
        children: const [CoachListShimmer()],
      );
    }

    if (_sheet.rosterState.isFailed) {
      return CoachErrorView(
        message: _sheet.rosterError ?? 'Could not load the roster.',
        onRetry: _sheet.loadRoster,
      );
    }

    if (_sheet.roster.isEmpty) {
      return CoachEmptyView(
        icon: Icons.person_off_outlined,
        title: 'No students in this batch',
        message:
            'No active enrolments were found for ${_sheet.batch!.displayName}.',
        actionLabel: 'Reload',
        onAction: _sheet.loadRoster,
      );
    }

    return RefreshIndicator(
      color: CoachTokens.brand,
      onRefresh: _sheet.loadRoster,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          CoachTokens.space4,
          CoachTokens.space3,
          CoachTokens.space4,
          CoachTokens.space8,
        ),
        itemCount: _sheet.roster.length,
        itemBuilder: (context, index) => _rosterCard(_sheet.roster[index]),
      ),
    );
  }

  Widget _rosterCard(CoachStudent student) {
    final marked = _sheet.statusFor(student.id);

    return CoachCard(
      margin: const EdgeInsets.only(bottom: CoachTokens.space3),
      accentColor: marked == null
          ? null
          : CoachTokens.statusColor(marked.slug),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CoachAvatar(initial: student.initial, radius: 18),
              const SizedBox(width: CoachTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.displayName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: CoachTokens.textDark,
                      ),
                    ),
                    if (student.attendanceLabel != '—') ...[
                      const SizedBox(height: 2),
                      Text(
                        '${student.attendanceLabel} overall',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: CoachTokens.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CoachTokens.space3),
          Row(
            children: [
              for (final status in CoachAttendanceStatus.values)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(
                      right: status == CoachAttendanceStatus.values.last
                          ? 0
                          : CoachTokens.space2,
                    ),
                    child: _statusButton(student.id, status, marked == status),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusButton(
    int studentId,
    CoachAttendanceStatus status,
    bool selected,
  ) {
    final tone = CoachTokens.statusColor(status.slug);

    return Material(
      color: selected ? tone : CoachTokens.canvas,
      borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
      child: InkWell(
        onTap: _sheet.saving ? null : () => _sheet.mark(studentId, status),
        borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
        child: Container(
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
            border: Border.all(
              color: selected ? tone : CoachTokens.border,
            ),
          ),
          child: Text(
            status.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : CoachTokens.textBody,
            ),
          ),
        ),
      ),
    );
  }

  /// Only the save bar for the Mark tab — hidden on Records and when there is
  /// nothing pending, so it never covers the list for no reason.
  Widget? _saveBar() {
    if (_tabs.index != 0 || _sheet.markedCount == 0) return null;

    return Container(
      padding: const EdgeInsets.all(CoachTokens.space4),
      decoration: const BoxDecoration(
        color: CoachTokens.surface,
        border: Border(top: BorderSide(color: CoachTokens.border)),
      ),
      child: SafeArea(
        top: false,
        child: FilledButton.icon(
          onPressed: _sheet.canSave ? _save : null,
          icon: _sheet.saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_rounded, size: 19),
          label: Text(
            _sheet.saving
                ? 'Saving…'
                : 'Save ${_sheet.markedCount} student'
                    '${_sheet.markedCount == 1 ? '' : 's'}',
          ),
          style: FilledButton.styleFrom(
            backgroundColor: CoachTokens.brand,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _sheet.date,
      // A month back covers late entry; the future is not markable.
      firstDate: DateTime(now.year, now.month - 1, now.day),
      lastDate: now,
    );

    if (picked == null) return;
    await _sheet.setDate(picked);
  }

  Future<void> _save() async {
    CoachLog.ui('Saving attendance sheet');
    final failures = await _sheet.save();
    if (!mounted) return;

    final messenger = ScaffoldMessenger.of(context);

    if (failures.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Attendance saved'),
          backgroundColor: CoachTokens.success,
        ),
      );
      // The log is now stale — refresh it so the Records tab agrees.
      await _records.refresh();
      return;
    }

    // Says exactly who is still unmarked. Their marks are kept, so tapping
    // Save again re-sends only them.
    final names = failures
        .map((f) => f.student.displayName)
        .take(3)
        .join(', ');
    final extra = failures.length > 3 ? ' and ${failures.length - 3} more' : '';

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          '${failures.length} could not be saved: $names$extra. '
          'Tap Save to retry.',
        ),
        backgroundColor: CoachTokens.danger,
        duration: const Duration(seconds: 6),
      ),
    );
    await _records.refresh();
  }

  // ===========================================================================
  // Records tab
  // ===========================================================================

  Widget _recordsTab() {
    return Column(
      children: [
        _recordFilters(),
        Expanded(
          child: RefreshIndicator(
            color: CoachTokens.brand,
            onRefresh: _records.refresh,
            child: _recordList(),
          ),
        ),
      ],
    );
  }

  Widget _recordFilters() {
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
            ActionChip(
              avatar: const Icon(
                Icons.calendar_today_outlined,
                size: 15,
                color: CoachTokens.brand,
              ),
              label: Text(
                _records.date == null
                    ? 'Any date'
                    : coachDateKey(_records.date!),
              ),
              onPressed: _pickRecordDate,
              backgroundColor: _records.date == null
                  ? CoachTokens.canvas
                  : CoachTokens.brandSoft,
              labelStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: CoachTokens.textBody,
              ),
              side: BorderSide(
                color: _records.date == null
                    ? CoachTokens.border
                    : CoachTokens.brand,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(CoachTokens.radiusPill),
              ),
            ),
            const SizedBox(width: CoachTokens.space2),
            for (final status in CoachAttendanceStatus.values)
              Padding(
                padding: const EdgeInsets.only(right: CoachTokens.space2),
                child: FilterChip(
                  label: Text(status.label),
                  selected: _records.status == status,
                  onSelected: (_) => _records.setStatus(status),
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _records.status == status
                        ? CoachTokens.statusColor(status.slug)
                        : CoachTokens.textBody,
                  ),
                  backgroundColor: CoachTokens.canvas,
                  selectedColor:
                      CoachTokens.statusColor(status.slug).withValues(alpha: 0.14),
                  side: BorderSide(
                    color: _records.status == status
                        ? CoachTokens.statusColor(status.slug)
                        : CoachTokens.border,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(CoachTokens.radiusPill),
                  ),
                ),
              ),
            if (_records.isFiltered)
              TextButton.icon(
                onPressed: _records.clearFilters,
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

  Future<void> _pickRecordDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _records.date ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked != null) _records.setDate(picked);
  }

  Widget _recordList() {
    if (_records.state.isLoading && _records.records.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(CoachTokens.space4),
        children: const [CoachListShimmer()],
      );
    }

    if (_records.state.isFailed && _records.records.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: CoachTokens.space8),
          CoachErrorView(
            message: _records.error ?? 'Could not load attendance records.',
            onRetry: _records.load,
          ),
        ],
      );
    }

    if (_records.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          const SizedBox(height: CoachTokens.space8),
          _records.isFiltered
              ? CoachEmptyView(
                  icon: Icons.search_off_rounded,
                  title: 'Nothing matches',
                  message: 'No attendance records match those filters.',
                  actionLabel: 'Clear filters',
                  onAction: _records.clearFilters,
                )
              : const CoachEmptyView(
                  icon: Icons.fact_check_outlined,
                  title: 'Nothing marked yet',
                  message:
                      'Attendance you mark — here or by scanning a gate pass — '
                      'shows up in this log.',
                ),
        ],
      );
    }

    final grouped = _records.byDate;
    final days = grouped.keys.toList();

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        CoachTokens.space4,
        CoachTokens.space3,
        CoachTokens.space4,
        CoachTokens.space8,
      ),
      // +1 for the trailing loader / "load more" row.
      itemCount: days.length + 1,
      itemBuilder: (context, index) {
        if (index == days.length) {
          if (_records.loadingMore) {
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
          if (_records.hasMore) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: CoachTokens.space4),
              child: Center(
                child: TextButton.icon(
                  onPressed: _records.loadMore,
                  icon: const Icon(Icons.expand_more_rounded, size: 18),
                  label: const Text('Load more'),
                  style: TextButton.styleFrom(
                    foregroundColor: CoachTokens.brand,
                  ),
                ),
              ),
            );
          }
          return const SizedBox(height: CoachTokens.space4);
        }

        final day = days[index];
        final rows = grouped[day]!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoachSectionHeader(
              title: day,
              padding: EdgeInsets.only(
                top: index == 0 ? 0 : CoachTokens.space4,
                bottom: CoachTokens.space2,
              ),
              trailing: Text(
                '${rows.length}',
                style: const TextStyle(
                  fontSize: 12.5,
                  color: CoachTokens.textMuted,
                ),
              ),
            ),
            ...rows.map(_recordCard),
          ],
        );
      },
    );
  }

  Widget _recordCard(CoachAttendanceRecord record) {
    final tone = CoachTokens.statusColor(record.statusLabel);

    return CoachCard(
      margin: const EdgeInsets.only(bottom: CoachTokens.space2 + 2),
      padding: const EdgeInsets.symmetric(
        horizontal: CoachTokens.space3 + 2,
        vertical: CoachTokens.space3,
      ),
      child: Row(
        children: [
          CoachAvatar(initial: record.initial, radius: 17, color: tone),
          const SizedBox(width: CoachTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.displayName,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: CoachTokens.textDark,
                  ),
                ),
                if (record.batchName.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    record.batchName,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: CoachTokens.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          CoachStatusChip(label: record.statusLabel, color: tone),
        ],
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
}
