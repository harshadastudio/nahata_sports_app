import 'package:flutter/material.dart';

import '../../data/repositories/employee_dashboard_repository_impl.dart';
import '../../domain/entities/employee_attendance.dart';
import '../../domain/entities/employee_formats.dart';
import '../state/employee_attendance_controller.dart';
import '../theme/employee_theme.dart';
import '../widgets/employee_forms.dart';
import '../widgets/employee_list_scaffold.dart';

/// Attendance Management — what coaches and the gate have marked.
///
/// Read-only. See [EmployeeAttendanceController] for why the app does not offer
/// a Mark button here even though the API would accept one.
class EmployeeAttendancePage extends StatefulWidget {
  const EmployeeAttendancePage({super.key});

  @override
  State<EmployeeAttendancePage> createState() => _EmployeeAttendancePageState();
}

class _EmployeeAttendancePageState extends State<EmployeeAttendancePage> {
  late final EmployeeAttendanceController _controller =
      EmployeeAttendanceController(EmployeeDashboardRepositoryImpl());

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
      builder: (context, _) => EmployeeListScaffold<EmployeeAttendanceRecord>(
        title: 'Attendance',
        controller: _controller,
        subtitle: () => '${_controller.total} record'
            '${_controller.total == 1 ? '' : 's'}',
        scopeNotice:
            'Marked by coaches and at the gate — this view is read-only.',
        filters: _filters(),
        itemBuilder: (context, record) => _recordCard(record),
        emptyIcon: Icons.fact_check_outlined,
        emptyTitle: 'No attendance records',
        emptyMessage: _controller.isFiltered
            ? 'Nothing matches these filters. Try another date.'
            : 'Records appear here once a coach marks a session or a student '
                'scans in at the gate.',
      ),
    );
  }

  Widget _filters() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final date = _controller.date;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: date ?? now,
                        firstDate: DateTime(now.year - 2),
                        lastDate: now,
                      );
                      if (picked != null) _controller.setDate(picked);
                    },
                    icon: const Icon(Icons.calendar_today_rounded, size: 15),
                    label: Text(
                      date == null ? 'Any date' : formatDay(date),
                      style: const TextStyle(fontSize: 12.5),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: date == null
                          ? EmployeeTokens.textBody
                          : EmployeeTokens.brand,
                      side: BorderSide(
                        color: date == null
                            ? EmployeeTokens.border
                            : EmployeeTokens.brand,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: EmployeeTokens.space3,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(EmployeeTokens.radiusSm),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: EmployeeTokens.space2),
                OutlinedButton(
                  onPressed: () => _controller.setDate(DateTime.now()),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EmployeeTokens.brand,
                    side: const BorderSide(color: EmployeeTokens.border),
                    padding: const EdgeInsets.symmetric(
                      horizontal: EmployeeTokens.space4,
                      vertical: EmployeeTokens.space3,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(EmployeeTokens.radiusSm),
                    ),
                  ),
                  child: const Text('Today', style: TextStyle(fontSize: 12.5)),
                ),
                if (_controller.isFiltered) ...[
                  const SizedBox(width: EmployeeTokens.space2),
                  IconButton(
                    onPressed: _controller.clearFilters,
                    icon: const Icon(Icons.filter_alt_off_rounded, size: 20),
                    color: EmployeeTokens.danger,
                    tooltip: 'Clear filters',
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ],
            ),
            const SizedBox(height: EmployeeTokens.space3),
            EmployeeFilterChips<String>(
              values: EmployeeAttendanceController.statuses,
              selected: _controller.status,
              labelOf: (s) => s,
              onChanged: _controller.setStatus,
            ),
          ],
        );
      },
    );
  }

  Widget _recordCard(EmployeeAttendanceRecord record) {
    final tone = EmployeeTokens.statusColor(record.status);

    return EmployeeCard(
      margin: const EdgeInsets.only(bottom: EmployeeTokens.space3),
      accentColor: tone,
      onTap: () => _openDetail(record),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EmployeeAvatar(initial: record.initial, radius: 19, color: tone),
          const SizedBox(width: EmployeeTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.displayName,
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
                  record.sportBatchLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: EmployeeTokens.textMuted,
                  ),
                ),
                const SizedBox(height: EmployeeTokens.space2),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 12,
                      color: EmployeeTokens.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      record.dateLabel,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: EmployeeTokens.textBody,
                      ),
                    ),
                    if (record.markedByLabel != '—') ...[
                      const SizedBox(width: EmployeeTokens.space3),
                      const Icon(
                        Icons.how_to_reg_rounded,
                        size: 12,
                        color: EmployeeTokens.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: Text(
                          record.markedByLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: EmployeeTokens.textBody,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: EmployeeTokens.space2),
          EmployeeChip(label: record.status, dense: true),
        ],
      ),
    );
  }

  Future<void> _openDetail(EmployeeAttendanceRecord record) {
    return showEmployeeSheet<void>(
      context: context,
      title: record.displayName,
      subtitle: record.sportBatchLabel,
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EmployeeChip(label: record.status),
          const SizedBox(height: EmployeeTokens.space5),
          EmployeeDetailRow(label: 'Student', value: record.displayName),
          EmployeeDetailRow(label: 'Email', value: record.studentEmail),
          EmployeeDetailRow(label: 'Sport', value: record.sportName),
          EmployeeDetailRow(label: 'Batch', value: record.batchName),
          EmployeeDetailRow(label: 'Date', value: record.dateLabel),
          EmployeeDetailRow(label: 'Marked by', value: record.markedByLabel),
          EmployeeDetailRow(label: 'Their role', value: record.markedByRole),
          if ((record.notes ?? '').isNotEmpty)
            EmployeeDetailRow(label: 'Notes', value: record.notes!),
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
                    'Attendance is marked by the batch coach and at the gate. '
                    'Ask the coach to correct a record rather than re-marking '
                    'it here — a second mark would overwrite theirs.',
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
