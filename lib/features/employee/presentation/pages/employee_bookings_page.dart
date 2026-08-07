import 'package:flutter/material.dart';

import '../../data/repositories/employee_dashboard_repository_impl.dart';
import '../../domain/entities/employee_booking.dart';
import '../../domain/entities/employee_formats.dart';
import '../../domain/entities/employee_master.dart';
import '../../domain/entities/employee_paged.dart';
import '../state/employee_bookings_controller.dart';
import '../theme/employee_theme.dart';
import '../widgets/employee_forms.dart';
import '../widgets/employee_list_scaffold.dart';

/// Bookings Management — the complex's court bookings.
///
/// Three levels, matching the website: the list, a detail sheet with the quick
/// status actions and the QR pass, and a full edit form.
class EmployeeBookingsPage extends StatefulWidget {
  const EmployeeBookingsPage({super.key});

  @override
  State<EmployeeBookingsPage> createState() => _EmployeeBookingsPageState();
}

class _EmployeeBookingsPageState extends State<EmployeeBookingsPage> {
  late final EmployeeBookingsController _controller =
      EmployeeBookingsController(EmployeeDashboardRepositoryImpl());

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
    // Wrapped so the empty-state copy tracks the filters: clearing them and
    // still seeing "nothing matches these filters" reads as a bug.
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => EmployeeListScaffold<EmployeeBooking>(
        title: 'Bookings',
        controller: _controller,
        subtitle: () => '${_controller.total} booking'
            '${_controller.total == 1 ? '' : 's'}',
        filters: _filters(),
        itemBuilder: (context, booking) => _bookingCard(booking),
        emptyIcon: Icons.event_busy_rounded,
        emptyTitle: 'No bookings found',
        emptyMessage: _controller.isFiltered
            ? 'Nothing matches these filters. Try clearing one.'
            : 'Bookings taken at your complex will show up here.',
        exhaustedLabel: 'End of the list',
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Filters
  // ───────────────────────────────────────────────────────────────────────────

  Widget _filters() {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _dateChip()),
                const SizedBox(width: EmployeeTokens.space2),
                Expanded(child: _sportChip()),
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
              values: EmployeeBookingsController.bookingStatuses,
              selected: _controller.bookingStatus,
              labelOf: (s) => s,
              allLabel: 'All statuses',
              onChanged: _controller.setBookingStatus,
            ),
            const SizedBox(height: EmployeeTokens.space2),
            EmployeeFilterChips<String>(
              values: EmployeeBookingsController.paymentStatuses,
              selected: _controller.paymentStatus,
              labelOf: (s) => s,
              allLabel: 'All payments',
              onChanged: _controller.setPaymentStatus,
            ),
          ],
        );
      },
    );
  }

  Widget _dateChip() {
    final date = _controller.date;
    return _filterButton(
      icon: Icons.calendar_today_rounded,
      label: date == null ? 'Any date' : formatDay(date),
      active: date != null,
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? now,
          firstDate: DateTime(now.year - 2),
          lastDate: DateTime(now.year + 2),
        );
        if (picked != null) _controller.setDate(picked);
      },
      onClear: date == null ? null : () => _controller.setDate(null),
    );
  }

  Widget _sportChip() {
    final sport = _controller.sport;
    final sports = _controller.sports;

    return _filterButton(
      icon: Icons.emoji_events_outlined,
      label: sport?.name ?? 'All sports',
      active: sport != null,
      // Disabled while the sport list is still coming in — an empty picker
      // would look like the complex has no sports.
      onTap: sports.isEmpty
          ? null
          : () async {
              final picked = await _pickSport(sports);
              if (picked != null) _controller.setSport(picked.id == -1 ? null : picked);
            },
      onClear: sport == null ? null : () => _controller.setSport(null),
    );
  }

  Future<EmployeeOption?> _pickSport(List<EmployeeSport> sports) {
    return showEmployeeSheet<EmployeeOption>(
      context: context,
      title: 'Filter by sport',
      builder: (context) => Column(
        children: [
          ListTile(
            leading: const Icon(Icons.clear_all_rounded,
                color: EmployeeTokens.textMuted),
            title: const Text('All sports'),
            onTap: () => Navigator.of(context)
                .pop(const EmployeeOption(id: -1, name: 'All sports')),
          ),
          const Divider(height: 1, color: EmployeeTokens.border),
          for (final sport in sports)
            ListTile(
              leading: const Icon(Icons.emoji_events_outlined,
                  color: EmployeeTokens.brand),
              title: Text(sport.displayName),
              subtitle: sport.category == null ? null : Text(sport.category!),
              onTap: () => Navigator.of(context).pop(
                EmployeeOption(id: sport.id, name: sport.displayName),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterButton({
    required IconData icon,
    required String label,
    required bool active,
    VoidCallback? onTap,
    VoidCallback? onClear,
  }) {
    return Material(
      color: active ? EmployeeTokens.brandSoft : EmployeeTokens.canvas,
      borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: EmployeeTokens.space3,
            vertical: EmployeeTokens.space3,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
            border: Border.all(
              color: active ? EmployeeTokens.brand : EmployeeTokens.border,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 15,
                color: active
                    ? EmployeeTokens.brand
                    : EmployeeTokens.textMuted,
              ),
              const SizedBox(width: EmployeeTokens.space2),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: active
                        ? EmployeeTokens.brand
                        : EmployeeTokens.textBody,
                  ),
                ),
              ),
              if (onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(
                    Icons.close_rounded,
                    size: 15,
                    color: EmployeeTokens.brand,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Row
  // ───────────────────────────────────────────────────────────────────────────

  Widget _bookingCard(EmployeeBooking booking) {
    return EmployeeCard(
      margin: const EdgeInsets.only(bottom: EmployeeTokens.space3),
      accentColor: EmployeeTokens.statusColor(booking.bookingStatus),
      onTap: () => _openDetail(booking),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: EmployeeTokens.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      [
                        if (booking.sportName.isNotEmpty) booking.sportName,
                        if (booking.courtName.isNotEmpty) booking.courtName,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: EmployeeTokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: EmployeeTokens.space2),
              Text(
                booking.amountLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: EmployeeTokens.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: EmployeeTokens.space3),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 13,
                color: EmployeeTokens.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                booking.dateLabel,
                style: const TextStyle(
                  fontSize: 12,
                  color: EmployeeTokens.textBody,
                ),
              ),
              const SizedBox(width: EmployeeTokens.space3),
              const Icon(
                Icons.schedule_rounded,
                size: 13,
                color: EmployeeTokens.textMuted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  booking.timeLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: EmployeeTokens.textBody,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: EmployeeTokens.space3),
          Wrap(
            spacing: EmployeeTokens.space2,
            runSpacing: EmployeeTokens.space2,
            children: [
              EmployeeChip(label: booking.bookingStatus, dense: true),
              EmployeeChip(label: booking.paymentStatus, dense: true),
              if (booking.source.isNotEmpty)
                EmployeeChip(
                  label: booking.source,
                  color: EmployeeTokens.textMuted,
                  icon: Icons.public_rounded,
                  dense: true,
                ),
              if (booking.wasReassigned)
                const EmployeeChip(
                  label: 'Reassigned',
                  color: EmployeeTokens.info,
                  icon: Icons.swap_horiz_rounded,
                  dense: true,
                ),
              if (booking.hasPass)
                const EmployeeChip(
                  label: 'QR pass',
                  color: EmployeeTokens.brand,
                  icon: Icons.qr_code_rounded,
                  dense: true,
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Detail sheet
  // ───────────────────────────────────────────────────────────────────────────

  Future<void> _openDetail(EmployeeBooking booking) async {
    await showEmployeeSheet<void>(
      context: context,
      title: 'Booking details',
      subtitle: booking.reference,
      builder: (sheetContext) => _BookingDetail(
        booking: booking,
        controller: _controller,
        onEdit: () {
          Navigator.of(sheetContext).pop();
          _openEdit(booking);
        },
      ),
    );
  }

  Future<void> _openEdit(EmployeeBooking booking) async {
    await showEmployeeSheet<void>(
      context: context,
      title: 'Edit booking',
      subtitle: booking.reference,
      builder: (sheetContext) => _BookingForm(
        booking: booking,
        controller: _controller,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail sheet body
// ─────────────────────────────────────────────────────────────────────────────

class _BookingDetail extends StatefulWidget {
  const _BookingDetail({
    required this.booking,
    required this.controller,
    required this.onEdit,
  });

  final EmployeeBooking booking;
  final EmployeeBookingsController controller;
  final VoidCallback onEdit;

  @override
  State<_BookingDetail> createState() => _BookingDetailState();
}

class _BookingDetailState extends State<_BookingDetail> {
  late EmployeeBooking _booking = widget.booking;
  bool _busy = false;

  Future<void> _run(Future<String?> Function() action, String success) async {
    setState(() => _busy = true);
    final error = await action();
    if (!mounted) return;
    setState(() => _busy = false);

    showEmployeeToast(context, error ?? success, isError: error != null);
    if (error != null) return;

    // The controller already patched its own copy; mirror it here so the sheet
    // does not keep showing the status the user just changed away from.
    for (final row in widget.controller.items) {
      if (row.id != _booking.id) continue;
      setState(() => _booking = row);
      break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = _booking;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: EmployeeTokens.space2,
          runSpacing: EmployeeTokens.space2,
          children: [
            EmployeeChip(label: 'Booking: ${booking.bookingStatus}'),
            EmployeeChip(label: 'Payment: ${booking.paymentStatus}'),
          ],
        ),
        const SizedBox(height: EmployeeTokens.space5),

        _section('Customer'),
        EmployeeDetailRow(label: 'Name', value: booking.displayName),
        EmployeeDetailRow(label: 'Email', value: booking.userEmail),
        EmployeeDetailRow(label: 'Phone', value: booking.userPhone),
        if ((booking.customerName ?? '').isNotEmpty &&
            booking.userName.isNotEmpty &&
            booking.customerName!.trim() != booking.userName.trim())
          // Worth spelling out: partner bookings share one account, so the
          // account name is rarely the person who turns up.
          EmployeeDetailRow(label: 'Account', value: booking.userName),

        const SizedBox(height: EmployeeTokens.space4),
        _section('Booking'),
        EmployeeDetailRow(label: 'Sport', value: booking.sportName),
        EmployeeDetailRow(label: 'Court', value: booking.courtName),
        EmployeeDetailRow(label: 'Venue', value: booking.venueName),
        EmployeeDetailRow(label: 'Source', value: booking.source),
        EmployeeDetailRow(label: 'Date', value: booking.dateLabel),
        EmployeeDetailRow(label: 'Time', value: booking.timeLabel),
        EmployeeDetailRow(
          label: 'Amount',
          value: booking.amountLabel,
          valueColor: EmployeeTokens.success,
        ),
        if ((booking.transactionId ?? '').isNotEmpty)
          EmployeeDetailRow(
            label: 'Transaction',
            value: booking.transactionId!,
            monospace: true,
          ),
        if (booking.wasReassigned)
          EmployeeDetailRow(
            label: 'Reassigned',
            value: 'from court #${booking.movedFromCourtId}'
                '${(booking.moveReason ?? '').isEmpty ? '' : ' — ${booking.moveReason}'}',
          ),
        if ((booking.notes ?? '').isNotEmpty)
          EmployeeDetailRow(label: 'Notes', value: booking.notes!),

        if (booking.hasPass) ...[
          const SizedBox(height: EmployeeTokens.space4),
          _section('Gate pass'),
          _passCard(booking),
        ],

        const SizedBox(height: EmployeeTokens.space5),
        _section('Update payment'),
        Row(
          children: [
            Expanded(
              child: _action(
                label: 'Mark paid',
                icon: Icons.check_circle_outline_rounded,
                color: EmployeeTokens.success,
                enabled: !_busy && !booking.isPaid,
                onTap: () => _run(
                  () => widget.controller
                      .setBookingPaymentStatus(booking, 'Paid'),
                  'Marked as paid',
                ),
              ),
            ),
            const SizedBox(width: EmployeeTokens.space3),
            Expanded(
              child: _action(
                label: 'Refund',
                icon: Icons.undo_rounded,
                color: EmployeeTokens.purple,
                enabled: !_busy && booking.paymentStatus != 'Refunded',
                onTap: () => _run(
                  () => widget.controller
                      .setBookingPaymentStatus(booking, 'Refunded'),
                  'Marked as refunded',
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: EmployeeTokens.space4),
        _section('Update booking'),
        Row(
          children: [
            Expanded(
              child: _action(
                label: 'Complete',
                icon: Icons.task_alt_rounded,
                color: EmployeeTokens.info,
                enabled: !_busy && booking.bookingStatus != 'Completed',
                onTap: () => _run(
                  () => widget.controller
                      .setBookingStatusFor(booking, 'Completed'),
                  'Booking completed',
                ),
              ),
            ),
            const SizedBox(width: EmployeeTokens.space3),
            Expanded(
              child: _action(
                label: 'Cancel',
                icon: Icons.cancel_outlined,
                color: EmployeeTokens.danger,
                enabled: !_busy && !booking.isCancelled,
                onTap: () async {
                  final ok = await confirmEmployeeAction(
                    context,
                    title: 'Cancel this booking?',
                    message:
                        'The slot goes back on sale. Any refund has to be '
                        'recorded separately.',
                    confirmLabel: 'Cancel booking',
                    destructive: true,
                  );
                  if (!ok) return;
                  await _run(
                    () => widget.controller
                        .setBookingStatusFor(booking, 'Cancelled'),
                    'Booking cancelled',
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: EmployeeTokens.space5),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : widget.onEdit,
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit booking'),
                style: FilledButton.styleFrom(
                  backgroundColor: EmployeeTokens.brand,
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
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final ok = await confirmEmployeeAction(
                        context,
                        title: 'Delete booking ${booking.reference}?',
                        message: 'This removes it from the list for good.',
                        confirmLabel: 'Delete',
                        destructive: true,
                      );
                      if (!ok || !context.mounted) return;

                      final error =
                          await widget.controller.deleteBooking(booking);
                      if (!context.mounted) return;

                      showEmployeeToast(
                        context,
                        error ?? 'Booking deleted',
                        isError: error != null,
                      );
                      if (error == null) Navigator.of(context).pop();
                    },
              style: OutlinedButton.styleFrom(
                foregroundColor: EmployeeTokens.danger,
                side: const BorderSide(color: EmployeeTokens.border),
                padding: const EdgeInsets.symmetric(
                  horizontal: EmployeeTokens.space4,
                  vertical: EmployeeTokens.space4,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
                ),
              ),
              child: const Icon(Icons.delete_outline_rounded, size: 20),
            ),
          ],
        ),
      ],
    );
  }

  Widget _passCard(EmployeeBooking booking) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(EmployeeTokens.space4),
      decoration: BoxDecoration(
        color: EmployeeTokens.canvas,
        borderRadius: BorderRadius.circular(EmployeeTokens.radiusMd),
      ),
      child: Column(
        children: [
          if ((booking.qrCode ?? '').isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
              child: Image.network(
                booking.qrCode!,
                width: 150,
                height: 150,
                fit: BoxFit.contain,
                // The QR is served as a data URI on some rows and a URL on
                // others; a broken image must not take the sheet down.
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.qr_code_2_rounded,
                  size: 90,
                  color: EmployeeTokens.textMuted,
                ),
              ),
            ),
          if ((booking.passCode ?? '').isNotEmpty) ...[
            const SizedBox(height: EmployeeTokens.space3),
            SelectableText(
              booking.passCode!,
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: EmployeeTokens.textDark,
              ),
            ),
          ],
          if (booking.maxPersons != null) ...[
            const SizedBox(height: EmployeeTokens.space2),
            EmployeeChip(
              label: 'Valid for ${booking.maxPersons} '
                  'person${booking.maxPersons == 1 ? '' : 's'}',
              color: EmployeeTokens.info,
              icon: Icons.groups_outlined,
            ),
          ],
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: EmployeeTokens.space2),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          letterSpacing: 0.9,
          fontWeight: FontWeight.w700,
          color: EmployeeTokens.textMuted,
        ),
      ),
    );
  }

  Widget _action({
    required String label,
    required IconData icon,
    required Color color,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 17),
      label: Text(
        label,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: 0.4)),
        padding: const EdgeInsets.symmetric(vertical: EmployeeTokens.space3),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Edit form
// ─────────────────────────────────────────────────────────────────────────────

class _BookingForm extends StatefulWidget {
  const _BookingForm({required this.booking, required this.controller});

  final EmployeeBooking booking;
  final EmployeeBookingsController controller;

  @override
  State<_BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends State<_BookingForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.booking.displayName);
  late final TextEditingController _amount = TextEditingController(
    text: widget.booking.totalAmount == 0
        ? ''
        : widget.booking.totalAmount.toString(),
  );
  late final TextEditingController _notes =
      TextEditingController(text: widget.booking.notes ?? '');

  late DateTime? _date = widget.booking.date;
  late String? _start = widget.booking.startTime;
  late String? _end = widget.booking.endTime;
  late String _bookingStatus =
      _valueIn(widget.booking.bookingStatus, EmployeeBookingsController.bookingStatuses);
  late String _paymentStatus =
      _valueIn(widget.booking.paymentStatus, EmployeeBookingsController.paymentStatuses);
  late int? _sportId = widget.booking.sportId;
  late int? _courtId = widget.booking.courtId;

  bool _saving = false;
  String? _error;

  /// The API can hold a status the dropdown does not list (a legacy value, or a
  /// new one added server-side). Falling back to the first entry keeps the form
  /// usable instead of asserting.
  static String _valueIn(String value, List<String> options) =>
      options.contains(value) ? value : options.first;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'A name is required.');
      return;
    }
    if (_date == null || (_start ?? '').isEmpty || (_end ?? '').isEmpty) {
      setState(() => _error = 'Date, start time and end time are all required.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await widget.controller.saveBooking(
      widget.booking.id,
      customerName: _name.text,
      date: _date!,
      startTime: _start!,
      endTime: _end!,
      totalAmount: num.tryParse(_amount.text.trim()),
      notes: _notes.text,
      bookingStatus: _bookingStatus,
      paymentStatus: _paymentStatus,
      sportId: _sportId,
      courtId: _courtId,
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }

    Navigator.of(context).pop();
    showEmployeeToast(context, 'Booking updated');
  }

  @override
  Widget build(BuildContext context) {
    final sports = widget.controller.sports;
    final courts = widget.controller.courtsForSport(_sportId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmployeeFormError(message: _error),

        EmployeeField(
          label: 'Customer name',
          required: true,
          hint: 'Stored on this booking, not on the account — partner bookings '
              'all share one login.',
          child: EmployeeTextField(
            controller: _name,
            hintText: 'Who the slot is for',
            prefixIcon: Icons.person_outline_rounded,
          ),
        ),

        EmployeeField(
          label: 'Sport',
          child: EmployeeDropdown<int>(
            value: _sportId,
            items: sports.map((s) => s.id).toList(),
            labelOf: (id) =>
                sports.firstWhere((s) => s.id == id).displayName,
            placeholder: 'Select a sport',
            // Changing the sport clears the court: the old one belongs to a
            // sport that is no longer selected.
            onChanged: (value) => setState(() {
              _sportId = value;
              _courtId = null;
            }),
          ),
        ),

        EmployeeField(
          label: 'Court',
          child: EmployeeDropdown<int>(
            value: _courtId,
            items: courts.map((c) => c.id).toList(),
            labelOf: (id) => courts.firstWhere((c) => c.id == id).displayName,
            subtitleOf: (id) => courts.firstWhere((c) => c.id == id).rateLabel,
            placeholder: sports.isEmpty ? 'Loading…' : 'Select a court',
            onChanged: (value) => setState(() => _courtId = value),
          ),
        ),

        EmployeeField(
          label: 'Date',
          required: true,
          child: EmployeeDateField(
            value: _date,
            clearable: false,
            onChanged: (value) => setState(() => _date = value),
          ),
        ),

        Row(
          children: [
            Expanded(
              child: EmployeeField(
                label: 'Start time',
                required: true,
                child: EmployeeTimeField(
                  value: _start,
                  onChanged: (value) => setState(() => _start = value),
                ),
              ),
            ),
            const SizedBox(width: EmployeeTokens.space3),
            Expanded(
              child: EmployeeField(
                label: 'End time',
                required: true,
                child: EmployeeTimeField(
                  value: _end,
                  onChanged: (value) => setState(() => _end = value),
                ),
              ),
            ),
          ],
        ),

        EmployeeField(
          label: 'Total amount',
          child: EmployeeNumberField(
            controller: _amount,
            isCurrency: true,
            hintText: '0',
          ),
        ),

        Row(
          children: [
            Expanded(
              child: EmployeeField(
                label: 'Booking status',
                child: EmployeeDropdown<String>(
                  value: _bookingStatus,
                  items: EmployeeBookingsController.bookingStatuses,
                  labelOf: (s) => s,
                  onChanged: (value) =>
                      setState(() => _bookingStatus = value ?? _bookingStatus),
                ),
              ),
            ),
            const SizedBox(width: EmployeeTokens.space3),
            Expanded(
              child: EmployeeField(
                label: 'Payment status',
                child: EmployeeDropdown<String>(
                  value: _paymentStatus,
                  items: EmployeeBookingsController.paymentStatuses,
                  labelOf: (s) => s,
                  onChanged: (value) =>
                      setState(() => _paymentStatus = value ?? _paymentStatus),
                ),
              ),
            ),
          ],
        ),

        EmployeeField(
          label: 'Notes',
          child: EmployeeTextField(
            controller: _notes,
            maxLines: 3,
            hintText: 'Anything the next person on the desk should know',
          ),
        ),

        const SizedBox(height: EmployeeTokens.space2),
        EmployeeSheetActions(
          saving: _saving,
          saveLabel: 'Update booking',
          onSave: _save,
        ),
      ],
    );
  }
}
