import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../admin/core/admin_log.dart';
import '../../../admin/domain/entities/paged.dart';
import '../../../admin/presentation/state/view_state.dart';
import '../../../admin/presentation/theme/admin_theme.dart';
import '../../../admin/presentation/utils/admin_format.dart';
import '../../../admin/presentation/widgets/admin_states.dart';
import '../../../admin/presentation/widgets/glass_card.dart';
import '../../../admin/presentation/widgets/pagination_bar.dart';
import '../../domain/entities/gate_scan.dart';
import '../state/security_guard_controller.dart';
import '../widgets/gate_page_header.dart';
import 'gate_scanner_page.dart';

/// The coaching gate: scan a student's pass, then the day's log of who came in.
///
/// A coaching scan has no direction — `/fees/scan-pass` marks attendance, and
/// there is no "out" leg — so the scanner runs without the IN/OUT toggle.
class CoachingGatePage extends StatefulWidget {
  const CoachingGatePage({super.key});

  @override
  State<CoachingGatePage> createState() => _CoachingGatePageState();
}

class _CoachingGatePageState extends State<CoachingGatePage> {
  static const int _pageSize = 50;

  final TextEditingController _search = TextEditingController();

  Paged<ScanLogEntry> _logs = const Paged<ScanLogEntry>();
  ViewState _state = ViewState.idle;
  String? _error;

  DateTime _date = DateTime.now();
  int _page = 1;

  @override
  void initState() {
    super.initState();
    AdminLog.life('CoachingGatePage mounted');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadLogs();
    });
  }

  @override
  void dispose() {
    _search.dispose();
    AdminLog.life('CoachingGatePage disposed');
    super.dispose();
  }

  /// `GET /fees/scan-logs?page=&limit=&date=&scannerRole=SECURITY`
  ///
  /// Scoped to this role on purpose: a guard's log is what happened at the
  /// gate, not what a coach marked in a session hall.
  Future<void> _loadLogs() async {
    setState(() {
      _state = ViewState.loading;
      _error = null;
    });

    try {
      final logs =
          await context.read<SecurityGuardController>().gates.scanLogs(
                page: _page,
                limit: _pageSize,
                date: _isoDate(_date),
                scannerRole: 'SECURITY',
                search: _search.text.trim().isEmpty ? null : _search.text.trim(),
              );

      if (!mounted) return;
      setState(() {
        _logs = logs;
        _state = ViewState.ready;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _state = ViewState.failed;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (picked == null || !mounted) return;

    setState(() {
      _date = picked;
      _page = 1;
    });
    await _loadLogs();
  }

  Future<void> _openScanner() async {
    final guard = context.read<SecurityGuardController>();

    await GateScannerPage.push(
      context,
      kind: GateScanKind.coaching,
      title: 'Coaching Attendance',
      // Attendance is one-way: a student is marked present, there is no exit.
      supportsDirection: false,
      onRecorded: guard.recordScan,
      onScan: (code, _) => guard.gates.scanCoachingPass(code),
    );

    if (!mounted) return;
    setState(() => _page = 1);
    await _loadLogs();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < AdminTokens.mobileMax;

    return ColoredBox(
      color: tokens.canvas,
      child: RefreshIndicator(
        onRefresh: _loadLogs,
        child: ListView(
          padding: EdgeInsets.all(
            isMobile ? AdminTokens.space4 : AdminTokens.space6,
          ),
          children: [
            GatePageHeader(
              title: 'Coaching Attendance',
              subtitle: 'Scan a student gate pass to mark them present',
              onScan: _openScanner,
              scanLabel: 'Scan pass',
            ),
            const SizedBox(height: AdminTokens.space5),

            SolidCard(
              padding: EdgeInsets.zero,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(AdminTokens.space4),
                    child: Wrap(
                      spacing: AdminTokens.space3,
                      runSpacing: AdminTokens.space3,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        SizedBox(
                          width: isMobile ? double.infinity : 300,
                          child: TextField(
                            controller: _search,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) {
                              setState(() => _page = 1);
                              _loadLogs();
                            },
                            style: TextStyle(
                              fontSize: 13.5,
                              color: tokens.textPrimary,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search student, phone or pass code',
                              isDense: true,
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                size: 18,
                                color: tokens.textMuted,
                              ),
                              suffixIcon: _search.text.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: () {
                                        _search.clear();
                                        setState(() => _page = 1);
                                        _loadLogs();
                                      },
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                      ),
                                      color: tokens.textMuted,
                                    ),
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(
                            Icons.calendar_today_rounded,
                            size: 16,
                          ),
                          label: Text(
                            '${_date.day.toString().padLeft(2, '0')}/'
                            '${_date.month.toString().padLeft(2, '0')}/'
                            '${_date.year}',
                          ),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: _state.isLoading ? null : _loadLogs,
                          icon: const Icon(Icons.refresh_rounded, size: 16),
                          label: const Text('Refresh'),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 44),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: tokens.border),
                  _LogTable(
                    state: _state,
                    error: _error,
                    logs: _logs.items,
                    compact: isMobile,
                    onRetry: _loadLogs,
                  ),
                  if (_logs.items.isNotEmpty || _page > 1)
                    PaginationBar(
                      page: _logs,
                      limit: _pageSize,
                      busy: _state.isLoading,
                      onPage: (next) {
                        setState(() => _page = next);
                        _loadLogs();
                      },
                      // The log is read at one page size; changing it would
                      // only re-fetch the same rows differently sliced.
                      onLimit: (_) {},
                    ),
                ],
              ),
            ),
            const SizedBox(height: AdminTokens.space6),
          ],
        ),
      ),
    );
  }

  static String _isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class _LogTable extends StatelessWidget {
  const _LogTable({
    required this.state,
    required this.error,
    required this.logs,
    required this.compact,
    required this.onRetry,
  });

  final ViewState state;
  final String? error;
  final List<ScanLogEntry> logs;
  final bool compact;
  final VoidCallback onRetry;

  static const List<int> _flex = [22, 14, 18, 20, 16, 10];
  static const List<String> _labels = [
    'Student',
    'Phone',
    'Batch',
    'Pass Code',
    'Scanner',
    'Time',
  ];

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    if (state.isLoading || state.isIdle) {
      return const Padding(
        padding: EdgeInsets.all(AdminTokens.space4),
        child: TableShimmer(rows: 6),
      );
    }

    if (state.isFailed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AdminTokens.space6),
        child: ErrorStateView(
          compact: true,
          title: 'Scan logs unavailable',
          message: error ?? 'The log could not be loaded.',
          onRetry: onRetry,
        ),
      );
    }

    if (logs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AdminTokens.space6),
        child: EmptyStateView(
          icon: Icons.fact_check_outlined,
          title: 'No scans on this date',
          message:
              'Student passes scanned at the gate on the selected date appear '
              'here.',
        ),
      );
    }

    if (compact) {
      return ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AdminTokens.space3),
        itemCount: logs.length,
        separatorBuilder: (_, __) => const SizedBox(height: AdminTokens.space2),
        itemBuilder: (context, index) => _LogCard(entry: logs[index]),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        const minWidth = 900.0;
        final width =
            constraints.maxWidth < minWidth ? minWidth : constraints.maxWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: width,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AdminTokens.space4,
                    vertical: AdminTokens.space3,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.surfaceAlt,
                    border: Border(bottom: BorderSide(color: tokens.border)),
                  ),
                  child: Row(
                    children: [
                      for (var i = 0; i < _labels.length; i++)
                        Expanded(
                          flex: _flex[i],
                          child: Text(
                            _labels[i],
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: tokens.textMuted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                for (final entry in logs) _LogRow(entry: entry),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.entry});

  final ScanLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    Widget cell(String value, int flex) => Expanded(
          flex: flex,
          child: Text(
            value.trim().isEmpty ? AdminFormat.dash : value,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.textSecondary, fontSize: 12.5),
          ),
        );

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.space4,
        vertical: AdminTokens.space3,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: _LogTable._flex[0],
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    entry.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (entry.attendance.trim().isNotEmpty)
                  _AttendanceChip(value: entry.attendance),
              ],
            ),
          ),
          cell(entry.phone, _LogTable._flex[1]),
          cell(entry.batchName, _LogTable._flex[2]),
          cell(entry.passCode, _LogTable._flex[3]),
          cell(
            [entry.scannerName, entry.scannerRole]
                .where((part) => part.trim().isNotEmpty)
                .join(' · '),
            _LogTable._flex[4],
          ),
          Expanded(
            flex: _LogTable._flex[5],
            child: Text(
              entry.timeLabel,
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.entry});

  final ScanLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space3),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: tokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.displayName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (entry.attendance.trim().isNotEmpty)
                _AttendanceChip(value: entry.attendance),
              const SizedBox(width: AdminTokens.space2),
              Text(
                entry.timeLabel,
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            [
              entry.batchName,
              entry.phone,
              entry.passCode,
            ].where((part) => part.trim().isNotEmpty).join(' · '),
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class _AttendanceChip extends StatelessWidget {
  const _AttendanceChip({required this.value});

  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final present = value.toLowerCase().contains('present');
    final colour = present ? tokens.success : tokens.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: colour.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: colour,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}