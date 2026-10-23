import 'package:flutter/material.dart';

import '../../data/repositories/employee_dashboard_repository_impl.dart';
import '../../domain/entities/employee_event_booking.dart';
import '../state/employee_event_bookings_controller.dart';
import '../theme/employee_theme.dart';
import '../widgets/employee_forms.dart';
import '../widgets/employee_list_scaffold.dart';

/// Employee → Issue Event Pass. The bookings made against this complex's
/// events, and the passes issued on each.
class EmployeeEventBookingsPage extends StatefulWidget {
  const EmployeeEventBookingsPage({super.key});

  @override
  State<EmployeeEventBookingsPage> createState() =>
      _EmployeeEventBookingsPageState();
}

class _EmployeeEventBookingsPageState extends State<EmployeeEventBookingsPage> {
  late final EmployeeEventBookingsController _controller =
      EmployeeEventBookingsController(EmployeeDashboardRepositoryImpl());

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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final selecting = _controller.isSelecting;

        return EmployeeListScaffold<EmployeeEventBooking>(
          title: 'Issue event pass',
          controller: _controller,
          subtitle: () => selecting
              ? '${_controller.selectedCount} selected'
              : '${_controller.total} booking'
                  '${_controller.total == 1 ? '' : 's'}',
          scopeNotice: 'Bookings for your own complex\'s events — the rows '
              'carry guest names and emails.',
          actions: [
            if (selecting) ...[
              IconButton(
                onPressed: _deleteSelected,
                icon: const Icon(Icons.delete_outline_rounded),
                tooltip: 'Delete selected',
              ),
              IconButton(
                onPressed: _controller.clearSelection,
                icon: const Icon(Icons.close_rounded),
                tooltip: 'Clear selection',
              ),
            ],
          ],
          itemBuilder: (context, booking) => _bookingCard(booking, selecting),
          emptyIcon: Icons.confirmation_number_outlined,
          emptyTitle: 'No event bookings yet',
          emptyMessage: 'Bookings made against your events will show up here.',
        );
      },
    );
  }

  Widget _bookingCard(EmployeeEventBooking booking, bool selecting) {
    final selected = _controller.isSelected(booking.id);

    return EmployeeCard(
      margin: const EdgeInsets.only(bottom: EmployeeTokens.space3),
      accentColor: booking.isCancelled
          ? EmployeeTokens.textMuted
          : EmployeeTokens.statusColor(booking.paymentStatus),
      // Once anything is selected, a tap toggles rather than opens — otherwise
      // building a selection means long-pressing every row after the first.
      onTap: () => selecting
          ? _controller.toggleSelected(booking.id)
          : _openDetail(booking),
      onLongPress: () => _controller.toggleSelected(booking.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selecting)
                Padding(
                  padding: const EdgeInsets.only(right: EmployeeTokens.space2),
                  child: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 22,
                    color: selected
                        ? EmployeeTokens.brand
                        : EmployeeTokens.textMuted,
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(right: EmployeeTokens.space3),
                  child: EmployeeAvatar(initial: booking.initial, radius: 19),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      booking.displayName,
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
                      booking.displayEventTitle,
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
              EmployeeChip(label: booking.paymentStatus, dense: true),
            ],
          ),
          const SizedBox(height: EmployeeTokens.space3),
          Wrap(
            spacing: EmployeeTokens.space2,
            runSpacing: EmployeeTokens.space2,
            children: [
              if (booking.slotLabel.isNotEmpty)
                EmployeeChip(
                  label: booking.slotLabel,
                  color: EmployeeTokens.info,
                  icon: Icons.event_outlined,
                  dense: true,
                ),
              EmployeeChip(
                label: '${booking.passCount} pass'
                    '${booking.passCount == 1 ? '' : 'es'}',
                color: EmployeeTokens.purple,
                icon: Icons.confirmation_number_outlined,
                dense: true,
              ),
              EmployeeChip(
                label: booking.amountLabel,
                color: EmployeeTokens.accent,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: EmployeeTokens.space2),
          Text(
            '${booking.displayReference} · ${booking.bookedAtLabel}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: EmployeeTokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final count = _controller.selectedCount;
    if (count == 0) return;

    final ok = await confirmEmployeeAction(
      context,
      title: 'Delete $count booking${count == 1 ? '' : 's'}?',
      message: 'The bookings and every pass issued against them are removed. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;

    final error = await _controller.deleteSelected();
    if (!mounted) return;

    showEmployeeToast(
      context,
      error ?? '$count booking${count == 1 ? '' : 's'} deleted',
      isError: error != null,
    );
  }

  Future<void> _openDetail(EmployeeEventBooking booking) {
    return showEmployeeSheet<void>(
      context: context,
      title: booking.displayReference,
      subtitle: booking.displayName,
      builder: (context) => _BookingDetail(
        booking: booking,
        controller: _controller,
      ),
    );
  }
}

class _BookingDetail extends StatefulWidget {
  const _BookingDetail({required this.booking, required this.controller});

  final EmployeeEventBooking booking;
  final EmployeeEventBookingsController controller;

  @override
  State<_BookingDetail> createState() => _BookingDetailState();
}

class _BookingDetailState extends State<_BookingDetail> {
  /// The list route carries `individualPasses[]` on every booking, so the
  /// sheet already has them — there is no per-booking passes route to call.
  List<EmployeeIndividualPass> get _passes => widget.booking.passes;

  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: EmployeeTokens.space2,
          runSpacing: EmployeeTokens.space2,
          children: [
            EmployeeChip(label: booking.paymentStatus),
            EmployeeChip(label: booking.bookingStatus),
          ],
        ),
        const SizedBox(height: EmployeeTokens.space5),

        _section('Guest'),
        EmployeeDetailRow(label: 'Name', value: booking.displayName),
        EmployeeDetailRow(label: 'Email', value: booking.email),
        EmployeeDetailRow(label: 'Phone', value: booking.phone),

        const SizedBox(height: EmployeeTokens.space4),
        _section('Booking'),
        EmployeeDetailRow(
          label: 'Reference',
          value: booking.displayReference,
          monospace: true,
        ),
        EmployeeDetailRow(label: 'Event', value: booking.displayEventTitle),
        EmployeeDetailRow(label: 'Slot', value: booking.slotLabel),
        EmployeeDetailRow(label: 'Amount', value: booking.amountLabel),
        EmployeeDetailRow(label: 'Booked', value: booking.bookedAtLabel),

        const SizedBox(height: EmployeeTokens.space4),
        _section('Passes'),
        if (_passes.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(EmployeeTokens.space3),
            decoration: BoxDecoration(
              color: EmployeeTokens.canvas,
              borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
            ),
            child: const Text(
              'No individual passes were issued against this booking.',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: EmployeeTokens.textMuted,
              ),
            ),
          )
        else
          ..._passes.map(_passRow),

        const SizedBox(height: EmployeeTokens.space5),

        if (_passes.isNotEmpty) ...[
          FilledButton.icon(
            onPressed: _busy ? null : _emailAll,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.mail_outline_rounded, size: 18),
            label: Text(
              'Email all ${_passes.length} pass'
              '${_passes.length == 1 ? '' : 'es'}',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: EmployeeTokens.brand,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
              ),
            ),
          ),
          const SizedBox(height: EmployeeTokens.space2),
          const Text(
            'Each pass is sent as its own email with its own QR code, so a '
            'group booking arrives as one mail per person.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: EmployeeTokens.textMuted,
            ),
          ),
        ],

        const SizedBox(height: EmployeeTokens.space3),
        TextButton.icon(
          onPressed: _busy ? null : _delete,
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          label: const Text('Delete booking'),
          style: TextButton.styleFrom(
            foregroundColor: EmployeeTokens.danger,
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
      ],
    );
  }

  Widget _passRow(EmployeeIndividualPass pass) {
    return Container(
      margin: const EdgeInsets.only(bottom: EmployeeTokens.space2),
      padding: const EdgeInsets.fromLTRB(
        EmployeeTokens.space3,
        EmployeeTokens.space2,
        EmployeeTokens.space2,
        EmployeeTokens.space2,
      ),
      decoration: BoxDecoration(
        color: EmployeeTokens.canvas,
        borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pass.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: EmployeeTokens.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${pass.displayCode} · ${pass.scannedLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    color: pass.isUsed
                        ? EmployeeTokens.success
                        : EmployeeTokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _busy ? null : () => _emailOne(pass),
            icon: const Icon(Icons.mail_outline_rounded, size: 18),
            color: EmployeeTokens.brand,
            tooltip: 'Email this pass',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Future<void> _emailOne(EmployeeIndividualPass pass) async {
    final address = await _askForAddress(
      title: 'Email pass',
      subtitle: pass.displayName,
      initial: pass.email ?? widget.booking.email,
    );
    if (address == null || !mounted) return;

    setState(() => _busy = true);
    final error = await widget.controller.emailPass(
      pass,
      address,
      recipientName:
          pass.holderName.trim().isEmpty ? null : pass.holderName.trim(),
    );
    if (!mounted) return;

    setState(() => _busy = false);
    showEmployeeToast(
      context,
      error ?? 'Pass sent to ${address.trim()}',
      isError: error != null,
    );
  }

  Future<void> _emailAll() async {
    final address = await _askForAddress(
      title: 'Email all passes',
      subtitle: widget.booking.displayReference,
      initial: widget.booking.email,
    );
    if (address == null || !mounted) return;

    setState(() => _busy = true);
    final error = await widget.controller.emailAllPasses(
      widget.booking,
      address,
    );
    if (!mounted) return;

    setState(() => _busy = false);
    showEmployeeToast(
      context,
      error ??
          '${_passes.length} pass${_passes.length == 1 ? '' : 'es'} sent to '
              '${address.trim()}',
      isError: error != null,
    );
  }

  Future<String?> _askForAddress({
    required String title,
    required String subtitle,
    String? initial,
  }) {
    return showEmployeeSheet<String>(
      context: context,
      title: title,
      subtitle: subtitle,
      builder: (context) => _EmailForm(initial: initial),
    );
  }

  Future<void> _delete() async {
    final ok = await confirmEmployeeAction(
      context,
      title: 'Delete ${widget.booking.displayReference}?',
      message: 'The booking and every pass issued against it are removed. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    final error = await widget.controller.delete(widget.booking);
    if (!mounted) return;

    setState(() => _busy = false);

    if (error == null) Navigator.of(context).pop();
    showEmployeeToast(
      context,
      error ?? 'Booking deleted',
      isError: error != null,
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
}

class _EmailForm extends StatefulWidget {
  const _EmailForm({this.initial});

  final String? initial;

  @override
  State<_EmailForm> createState() => _EmailFormState();
}

class _EmailFormState extends State<_EmailForm> {
  late final TextEditingController _email =
      TextEditingController(text: widget.initial ?? '');

  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _send() {
    final draft = EmployeeEventPassEmailDraft(email: _email.text);
    if (!draft.isValid) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }

    Navigator.of(context).pop(_email.text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmployeeFormError(message: _error),

        EmployeeField(
          label: 'Email address',
          required: true,
          hint: 'Defaults to the address on the booking.',
          child: EmployeeTextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
            hintText: 'name@example.com',
            onSubmitted: (_) => _send(),
          ),
        ),

        EmployeeSheetActions(saveLabel: 'Send', onSave: _send),
      ],
    );
  }
}
