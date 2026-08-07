import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../admin/core/admin_log.dart';
import '../../../admin/domain/entities/court.dart';
import '../../../admin/domain/repositories/court_repository.dart';
import '../../../admin/presentation/state/view_state.dart';
import '../../../admin/presentation/theme/admin_theme.dart';
import '../../../admin/presentation/widgets/admin_dialogs.dart';
import '../../../admin/presentation/widgets/admin_states.dart';
import '../../../admin/presentation/widgets/glass_card.dart';
import '../../domain/entities/gate_scan.dart';
import '../state/security_guard_controller.dart';
import '../widgets/gate_page_header.dart';
import '../widgets/scan_stats_row.dart';
import 'gate_scanner_page.dart';

/// The court gate: choose a court and a date, watch that slot's figures, scan
/// its bookings, and email a member their pass.
///
/// `/courts/bookings/scan-stats` takes `courtId` and `date`, so both pickers
/// drive the figures — with no court chosen the endpoint is asked for the whole
/// day across every court, which is what a single-gate venue wants.
class CourtGatePage extends StatefulWidget {
  const CourtGatePage({super.key});

  @override
  State<CourtGatePage> createState() => _CourtGatePageState();
}

class _CourtGatePageState extends State<CourtGatePage> {
  List<Court> _courts = const [];
  ViewState _courtsState = ViewState.idle;
  String? _courtsError;

  Court? _court;
  DateTime _date = DateTime.now();

  ScanStats _stats = ScanStats.empty;
  ViewState _statsState = ViewState.idle;
  String? _statsError;

  @override
  void initState() {
    super.initState();
    AdminLog.life('CourtGatePage mounted');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadCourts();
      _loadStats();
    });
  }

  @override
  void dispose() {
    AdminLog.life('CourtGatePage disposed');
    super.dispose();
  }

  /// `GET /courts?status=Active&limit=100`
  Future<void> _loadCourts() async {
    setState(() {
      _courtsState = ViewState.loading;
      _courtsError = null;
    });

    try {
      final courts = await context.read<CourtRepository>().fetchCourts();
      if (!mounted) return;

      // Only the courts a gate can actually admit anyone to.
      final active = courts
          .where(
            (court) =>
                (court.statusRaw ?? 'Active').toLowerCase().trim() != 'inactive',
          )
          .toList(growable: false);

      setState(() {
        _courts = active;
        _courtsState = ViewState.ready;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _courtsState = ViewState.failed;
        _courtsError = _messageOf(error);
      });
    }
  }

  /// `GET /courts/bookings/scan-stats?courtId=&date=`
  Future<void> _loadStats() async {
    setState(() {
      _statsState = ViewState.loading;
      _statsError = null;
    });

    try {
      final stats =
          await context.read<SecurityGuardController>().gates.courtScanStats(
                courtId: _court?.id,
                date: _isoDate(_date),
              );
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _statsState = ViewState.ready;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statsState = ViewState.failed;
        _statsError = _messageOf(error);
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 1),
    );
    if (picked == null || !mounted) return;

    setState(() => _date = picked);
    await _loadStats();
  }

  Future<void> _openScanner() async {
    final guard = context.read<SecurityGuardController>();

    await GateScannerPage.push(
      context,
      kind: GateScanKind.courtBooking,
      title: _court == null
          ? 'Court Booking Scanner'
          : 'Scan · ${_court!.name ?? 'Court'}',
      onRecorded: guard.recordScan,
      onScan: (code, direction) => guard.gates.scanCourtBooking(
        passCode: code,
        direction: direction,
      ),
    );

    if (!mounted) return;
    await _loadStats();
  }

  /// `POST /courts/bookings/{bookingId}/members/{memberId}/send-email`
  ///
  /// Both ids are typed in: a guard emailing a pass has them from the booking
  /// in front of them, and there is no endpoint that lists a court's members
  /// for a date to pick from.
  Future<void> _sendMemberEmail() async {
    final result = await showDialog<_EmailRequest>(
      context: context,
      builder: (_) => const _SendEmailDialog(),
    );
    if (result == null || !mounted) return;

    try {
      final message =
          await context.read<SecurityGuardController>().gates.sendBookingEmail(
                bookingId: result.bookingId,
                memberId: result.memberId,
                recipientEmail: result.email,
              );
      if (!mounted) return;
      AdminFeedback.success(context, message);
    } catch (error) {
      if (!mounted) return;
      AdminFeedback.error(context, _messageOf(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final isMobile = MediaQuery.sizeOf(context).width < AdminTokens.mobileMax;

    return ColoredBox(
      color: tokens.canvas,
      child: RefreshIndicator(
        onRefresh: () async {
          await _loadCourts();
          await _loadStats();
        },
        child: ListView(
          padding: EdgeInsets.all(
            isMobile ? AdminTokens.space4 : AdminTokens.space6,
          ),
          children: [
            GatePageHeader(
              title: 'Court Booking Scanner',
              subtitle: _court == null
                  ? 'All courts · ${_readableDate(_date)}'
                  : '${_court!.name ?? 'Court'} · ${_readableDate(_date)}',
              onScan: _openScanner,
            ),
            const SizedBox(height: AdminTokens.space5),

            SolidCard(
              child: _Pickers(
                courts: _courts,
                courtsState: _courtsState,
                courtsError: _courtsError,
                selected: _court,
                date: _date,
                onRetryCourts: _loadCourts,
                onCourt: (court) async {
                  setState(() => _court = court);
                  await _loadStats();
                },
                onPickDate: _pickDate,
                onEmail: _sendMemberEmail,
              ),
            ),
            const SizedBox(height: AdminTokens.space5),

            SolidCard(
              child: ScanStatsRow(
                stats: _stats,
                loading: _statsState.isLoading,
                error: _statsError,
                onRetry: _loadStats,
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

  static String _readableDate(DateTime value) =>
      '${value.day.toString().padLeft(2, '0')}/'
      '${value.month.toString().padLeft(2, '0')}/${value.year}';

  static String _messageOf(Object error) {
    final text = error.toString().replaceFirst('Exception: ', '');
    return text.isEmpty ? 'Something went wrong. Please try again.' : text;
  }
}

class _Pickers extends StatelessWidget {
  const _Pickers({
    required this.courts,
    required this.courtsState,
    required this.courtsError,
    required this.selected,
    required this.date,
    required this.onRetryCourts,
    required this.onCourt,
    required this.onPickDate,
    required this.onEmail,
  });

  final List<Court> courts;
  final ViewState courtsState;
  final String? courtsError;
  final Court? selected;
  final DateTime date;
  final VoidCallback onRetryCourts;
  final ValueChanged<Court?> onCourt;
  final VoidCallback onPickDate;
  final VoidCallback onEmail;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    if (courtsState.isFailed) {
      return ErrorStateView(
        compact: true,
        title: 'Courts unavailable',
        message: courtsError ?? 'The court list could not be loaded.',
        onRetry: onRetryCourts,
      );
    }

    return Wrap(
      spacing: AdminTokens.space3,
      runSpacing: AdminTokens.space3,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 240,
          child: DropdownButtonFormField<int?>(
            initialValue: selected?.id,
            isExpanded: true,
            isDense: true,
            decoration: const InputDecoration(
              labelText: 'Court',
              isDense: true,
            ),
            items: [
              const DropdownMenuItem<int?>(child: Text('All courts')),
              for (final court in courts)
                DropdownMenuItem<int?>(
                  value: court.id,
                  child: Text(
                    [
                      court.name ?? 'Court ${court.id}',
                      if ((court.sportName ?? '').trim().isNotEmpty)
                        court.sportName!.trim(),
                    ].join(' · '),
                  ),
                ),
            ],
            onChanged: courtsState.isLoading
                ? null
                : (id) => onCourt(
                      id == null
                          ? null
                          : courts.firstWhere((court) => court.id == id),
                    ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: onPickDate,
          icon: const Icon(Icons.calendar_today_rounded, size: 16),
          label: Text(
            '${date.day.toString().padLeft(2, '0')}/'
            '${date.month.toString().padLeft(2, '0')}/${date.year}',
          ),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
        ),
        if (courtsState.isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: tokens.accent,
            ),
          ),
        const Spacer(),
        OutlinedButton.icon(
          onPressed: onEmail,
          icon: const Icon(Icons.alternate_email_rounded, size: 16),
          label: const Text('Email a pass'),
          style: OutlinedButton.styleFrom(minimumSize: const Size(0, 46)),
        ),
      ],
    );
  }
}

/// What the email dialog collects.
class _EmailRequest {
  const _EmailRequest({
    required this.bookingId,
    required this.memberId,
    required this.email,
  });

  final String bookingId;
  final String memberId;
  final String email;
}

class _SendEmailDialog extends StatefulWidget {
  const _SendEmailDialog();

  @override
  State<_SendEmailDialog> createState() => _SendEmailDialogState();
}

class _SendEmailDialogState extends State<_SendEmailDialog> {
  final _formKey = GlobalKey<FormState>();
  final _booking = TextEditingController();
  final _member = TextEditingController();
  final _email = TextEditingController();

  @override
  void dispose() {
    _booking.dispose();
    _member.dispose();
    _email.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    Navigator.of(context).pop(
      _EmailRequest(
        bookingId: _booking.text.trim(),
        memberId: _member.text.trim(),
        email: _email.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return AlertDialog(
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
      ),
      title: Row(
        children: [
          Icon(Icons.alternate_email_rounded, size: 20, color: tokens.accent),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              'Email a booking pass',
              style: TextStyle(
                color: tokens.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sends the pass to one member of a booking. Both ids are on the '
              'booking record.',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AdminTokens.space4),
            TextFormField(
              controller: _booking,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Booking id'),
              validator: (value) => (value ?? '').trim().isEmpty
                  ? 'Enter the booking id'
                  : null,
            ),
            const SizedBox(height: AdminTokens.space3),
            TextFormField(
              controller: _member,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Member id'),
              validator: (value) =>
                  (value ?? '').trim().isEmpty ? 'Enter the member id' : null,
            ),
            const SizedBox(height: AdminTokens.space3),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Recipient email',
                hintText: 'amit@example.com',
              ),
              validator: (value) {
                final text = (value ?? '').trim();
                if (text.isEmpty) return 'Enter an email address';
                if (!RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$').hasMatch(text)) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Send email')),
      ],
    );
  }
}