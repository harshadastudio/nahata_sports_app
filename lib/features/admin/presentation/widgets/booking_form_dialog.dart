import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/booking.dart';
import '../../domain/entities/court.dart';
import '../../domain/entities/court_slot.dart';
import '../../domain/entities/sport.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import '../utils/server_field_errors.dart';
import 'admin_form_fields.dart';

/// Add / Edit booking.
///
/// [booking] null means create (`POST /bookings`), otherwise edit
/// (`PUT /bookings/{id}`). The update route documents the date, the times, the
/// two statuses and the notes, so on an edit the customer, sport and court
/// render read-only — the same treatment every update-restricted form in this
/// console gives its fixed fields.
///
/// The clash check runs before anything is sent: a court cannot hold two
/// bookings at the same time, and finding that out from a 500 is worse than
/// finding it out from the form.
class BookingFormDialog extends StatefulWidget {
  const BookingFormDialog({
    super.key,
    required this.onSubmit,
    required this.findClashes,
    required this.courts,
    required this.courtsState,
    required this.onReloadCourts,
    required this.sports,
    required this.sportsState,
    required this.onReloadSports,
    this.booking,
    this.customerHint,
    this.clashScopeNote,
  });

  final Booking? booking;

  /// Throws on failure so this dialog can stay open and explain itself.
  final Future<void> Function(BookingDraft draft) onSubmit;

  /// Bookings the draft would collide with. Returned rather than thrown so this
  /// dialog can name the offender.
  final List<Booking> Function(BookingDraft draft) findClashes;

  final List<Court> courts;
  final ViewState courtsState;
  final VoidCallback onReloadCourts;

  final List<Sport> sports;
  final ViewState sportsState;
  final VoidCallback onReloadSports;

  /// Shown under the customer field. There is no `/users` catalogue in this
  /// console, so a create takes the numeric user id.
  final String? customerHint;

  /// Explains how much of the calendar the clash check can actually see.
  final String? clashScopeNote;

  bool get isEdit => booking != null;

  /// Resolves to true when a save succeeded.
  static Future<bool> show(
    BuildContext context, {
    Booking? booking,
    required Future<void> Function(BookingDraft draft) onSubmit,
    required List<Booking> Function(BookingDraft draft) findClashes,
    required List<Court> courts,
    required ViewState courtsState,
    required VoidCallback onReloadCourts,
    required List<Sport> sports,
    required ViewState sportsState,
    required VoidCallback onReloadSports,
    String? customerHint,
    String? clashScopeNote,
  }) async {
    AdminLog.ui('${booking == null ? 'Add' : 'Edit'} booking dialog opened');

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => BookingFormDialog(
        booking: booking,
        onSubmit: onSubmit,
        findClashes: findClashes,
        courts: courts,
        courtsState: courtsState,
        onReloadCourts: onReloadCourts,
        sports: sports,
        sportsState: sportsState,
        onReloadSports: onReloadSports,
        customerHint: customerHint,
        clashScopeNote: clashScopeNote,
      ),
    );

    AdminLog.ui('Booking dialog closed (saved: ${saved ?? false})');
    return saved ?? false;
  }

  @override
  State<BookingFormDialog> createState() => _BookingFormDialogState();
}

class _BookingFormDialogState extends State<BookingFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _userId;
  late final TextEditingController _amount;
  late final TextEditingController _transactionId;
  late final TextEditingController _notes;

  Sport? _sport;
  Court? _court;
  DateTime? _date;
  SlotTime? _start;
  SlotTime? _end;
  BookingSource? _source;
  BookingStatus? _status;
  PaymentStatus? _payment;

  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    final booking = widget.booking;

    _userId = TextEditingController(text: booking?.userId?.toString() ?? '');
    _amount = TextEditingController(text: _numberText(booking?.amount));
    _transactionId = TextEditingController(text: booking?.transactionId ?? '');
    _notes = TextEditingController(text: booking?.notes ?? '');

    _date = booking?.date;
    _start = booking?.startTime;
    _end = booking?.endTime;
    _source = booking?.source ?? BookingSource.admin;
    _status = booking?.status ?? BookingStatus.confirmed;
    _payment = booking?.payment ?? PaymentStatus.pending;

    _sport = _matchSport(booking);
    _court = _matchCourt(booking);

    AdminLog.life(
      'BookingFormDialog mounted (${widget.isEdit ? 'edit' : 'create'})',
    );
  }

  static String _numberText(num? value) {
    if (value == null) return '';
    if (value is int) return value.toString();
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  Sport? _matchSport(Booking? booking) {
    final id = booking?.sportId;
    if (id == null) return null;
    for (final sport in widget.sports) {
      if (sport.id == id) return sport;
    }
    return null;
  }

  Court? _matchCourt(Booking? booking) {
    final id = booking?.courtId;
    if (id == null) return null;
    for (final court in widget.courts) {
      if (court.id == id) return court;
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant BookingFormDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Either catalogue may land after the dialog opened; preselect once it has.
    if (_sport == null && widget.sports.isNotEmpty) {
      final matched = _matchSport(widget.booking);
      if (matched != null) setState(() => _sport = matched);
    }
    if (_court == null && widget.courts.isNotEmpty) {
      final matched = _matchCourt(widget.booking);
      if (matched != null) setState(() => _court = matched);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _userId,
      _amount,
      _transactionId,
      _notes,
    ]) {
      controller.dispose();
    }
    AdminLog.life('BookingFormDialog disposed');
    super.dispose();
  }

  /// The courts that play the chosen sport. A filter that would empty the list
  /// falls back to the full one — a stale `/courts` read must never make a
  /// booking impossible.
  List<Court> get _courtOptions {
    final sportId = _sport?.id;
    if (sportId == null) return widget.courts;

    final scoped = widget.courts
        .where((court) => court.sportId == sportId)
        .toList(growable: false);
    return scoped.isEmpty ? widget.courts : scoped;
  }

  BookingDraft _draft() {
    return widget.isEdit
        // Only the documented editable fields.
        ? BookingDraft(
            date: _date,
            startTime: _start,
            endTime: _end,
            status: _status,
            payment: _payment,
            notes: _notes.text,
          )
        : BookingDraft(
            userId: int.tryParse(_userId.text.trim()),
            sportId: _sport?.id,
            courtId: _court?.id,
            sportComplexId: _court?.sportComplexId,
            date: _date,
            startTime: _start,
            endTime: _end,
            amount: num.tryParse(_amount.text.trim()),
            source: _source,
            status: _status,
            payment: _payment,
            transactionId: _transactionId.text,
            notes: _notes.text,
          );
  }

  /// The clash check needs the court, which an edit does not send — so it is
  /// run against the booking's own court.
  List<Booking> get _clashes {
    if (_date == null || _start == null || _end == null) return const [];

    final draft = widget.isEdit
        ? BookingDraft(
            courtId: widget.booking!.courtId,
            date: _date,
            startTime: _start,
            endTime: _end,
            status: _status,
          )
        : _draft();

    if (draft.courtId == null) return const [];
    return widget.findClashes(draft);
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      helpText: 'Select the booking date',
    );

    if (picked == null || !mounted) return;
    setState(() => _date = DateTime(picked.year, picked.month, picked.day));
    _formKey.currentState?.validate();
  }

  Future<void> _pickTime({required bool start}) async {
    final current = start ? _start : _end;

    final picked = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 7, minute: 0)
          : TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: start ? 'Select the start time' : 'Select the end time',
    );

    if (picked == null || !mounted) return;

    setState(() {
      final value = SlotTime(picked.hour * 60 + picked.minute);
      if (start) {
        _start = value;
        // Courts are booked by the hour here, so choosing a start proposes the
        // end rather than making the admin compute it. It stays editable.
        _end ??= value.plusMinutes(60);
      } else {
        _end = value;
      }
    });
    _formKey.currentState?.validate();
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_date == null) {
      setState(() => _error = 'Pick a booking date.');
      return;
    }
    if (_start == null || _end == null) {
      setState(() => _error = 'Set both the start and the end time.');
      return;
    }
    if (_start!.minutesUntil(_end!) == 0) {
      setState(() => _error = 'The end time cannot equal the start time.');
      return;
    }

    final clashes = _clashes;
    if (clashes.isNotEmpty) {
      setState(() {
        _error =
            'That court is already booked in this window: '
            '${clashes.map((booking) => '${booking.displayReference} '
                '(${booking.windowLabel})').join(', ')}.';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = const {};
    });

    try {
      await widget.onSubmit(_draft());
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      final parsed = ServerFieldErrors.from(error);
      setState(() {
        _saving = false;
        _error = parsed.summary ?? error.message;
        _fieldErrors = parsed.fields;
      });
      _formKey.currentState?.validate();
      AdminLog.failure('Booking save rejected: ${error.message}');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this booking. Please try again.';
      });
      AdminLog.failure(
        'Booking save crashed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  String? _serverError(List<String> keys) {
    for (final key in keys) {
      final message = _fieldErrors[key];
      if (message != null) return message;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < AdminTokens.mobileMax;
    final isEdit = widget.isEdit;
    final clashes = _clashes;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? AdminTokens.space4 : AdminTokens.space8,
        vertical: AdminTokens.space6,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 780,
          maxHeight: size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminFormHeader(
              title: isEdit ? 'Edit booking' : 'Add booking',
              subtitle: isEdit
                  ? widget.booking!.displayReference
                  : 'Reserve a court for a customer',
              icon: isEdit
                  ? Icons.edit_outlined
                  : Icons.event_available_rounded,
              onClose: _saving ? null : () => Navigator.of(context).pop(false),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AdminTokens.space5),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        AdminFormErrorBanner(message: _error!),
                        const SizedBox(height: AdminTokens.space4),
                      ],
                      if (isEdit) ...[
                        const AdminFormNote(
                          icon: Icons.lock_outline_rounded,
                          text:
                              'The update route accepts the date, the times, '
                              'the two statuses and the notes. The customer, '
                              'sport and court are shown read-only.',
                        ),
                        const SizedBox(height: AdminTokens.space4),
                      ],

                      // --- 1. Who and what ----------------------------------
                      AdminFormSection(
                        icon: Icons.person_outline_rounded,
                        label: 'Customer & Court',
                        color: tokens.accent,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      if (isEdit) ...[
                        AdminFieldPair(
                          narrow: narrow,
                          first: AdminReadOnlyField(
                            label: 'Customer',
                            value: widget.booking!.customerName,
                            icon: Icons.person_outline_rounded,
                          ),
                          second: AdminReadOnlyField(
                            label: 'Phone',
                            value: widget.booking!.customerPhone,
                            icon: Icons.phone_outlined,
                          ),
                        ),
                        const SizedBox(height: AdminTokens.space4),
                        AdminFieldPair(
                          narrow: narrow,
                          first: AdminReadOnlyField(
                            label: 'Sport',
                            value: widget.booking!.sportName,
                            icon: Icons.sports_tennis_outlined,
                          ),
                          second: AdminReadOnlyField(
                            label: 'Court',
                            value: widget.booking!.courtName,
                            icon: Icons.grid_view_outlined,
                          ),
                        ),
                      ] else ...[
                        AdminTextField(
                          controller: _userId,
                          label: 'Customer (user ID)',
                          hint: 'e.g. 585',
                          icon: Icons.person_outline_rounded,
                          required: true,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(9),
                          ],
                          validator: (value) {
                            final server = _serverError(['userId', 'user_id']);
                            if (server != null) return server;
                            final text = (value ?? '').trim();
                            if (text.isEmpty) return 'A customer is required';
                            if (int.tryParse(text) == null) {
                              return 'Numbers only';
                            }
                            return null;
                          },
                        ),
                        if (widget.customerHint != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            widget.customerHint!,
                            style: TextStyle(
                              color: tokens.textMuted,
                              fontSize: 11,
                              height: 1.4,
                            ),
                          ),
                        ],
                        const SizedBox(height: AdminTokens.space4),
                        AdminFieldPair(
                          narrow: narrow,
                          first: AdminCatalogueDropdown<Sport>(
                            label: 'Sport',
                            icon: Icons.sports_tennis_outlined,
                            options: widget.sports,
                            value: _sport,
                            labelOf: (sport) => sport.displayName,
                            idOf: (sport) => sport.id,
                            state: widget.sportsState,
                            onReload: widget.onReloadSports,
                            enabled: !_saving,
                            required: true,
                            error: _serverError(const ['sportId', 'sport_id']),
                            onChanged: (sport) {
                              setState(() {
                                _sport = sport;
                                // A court that does not play the new sport
                                // would be a booking the backend has to
                                // reject, so it is dropped here instead.
                                final court = _court;
                                if (court != null &&
                                    sport != null &&
                                    court.sportId != null &&
                                    court.sportId != sport.id) {
                                  _court = null;
                                }
                              });
                            },
                          ),
                          second: AdminCatalogueDropdown<Court>(
                            label: 'Court',
                            icon: Icons.grid_view_outlined,
                            options: _courtOptions,
                            value: _court,
                            labelOf: (court) => court.displayName,
                            idOf: (court) => court.id,
                            state: widget.courtsState,
                            onReload: widget.onReloadCourts,
                            enabled: !_saving,
                            required: true,
                            error: _serverError(const ['courtId', 'court_id']),
                            onChanged: (court) =>
                                setState(() => _court = court),
                          ),
                        ),
                      ],

                      // --- 2. Schedule --------------------------------------
                      const SizedBox(height: AdminTokens.space6),
                      AdminFormSection(
                        icon: Icons.schedule_rounded,
                        label: 'Schedule',
                        color: tokens.info,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _DateField(
                        label: 'Booking Date',
                        value: _date,
                        required: true,
                        enabled: !_saving,
                        onTap: _pickDate,
                        error:
                            _serverError(const ['date', 'bookingDate']) ??
                            (_date == null ? 'A date is required' : null),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminFieldPair(
                        narrow: narrow,
                        first: _TimeField(
                          label: 'Start Time',
                          value: _start,
                          required: true,
                          enabled: !_saving,
                          onTap: () => _pickTime(start: true),
                        ),
                        second: _TimeField(
                          label: 'End Time',
                          value: _end,
                          required: true,
                          enabled: !_saving,
                          onTap: () => _pickTime(start: false),
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space3),
                      _ClashNotice(
                        clashes: clashes,
                        ready: _date != null && _start != null && _end != null,
                        scopeNote: widget.clashScopeNote,
                      ),

                      // --- 3. Payment ---------------------------------------
                      const SizedBox(height: AdminTokens.space6),
                      AdminFormSection(
                        icon: Icons.payments_outlined,
                        label: 'Payment',
                        color: tokens.success,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      if (isEdit)
                        AdminReadOnlyField(
                          label: 'Amount',
                          value: AdminFormat.currency(widget.booking!.amount),
                          icon: Icons.currency_rupee_rounded,
                        )
                      else
                        AdminFieldPair(
                          narrow: narrow,
                          first: AdminTextField(
                            controller: _amount,
                            label: 'Amount',
                            hint: 'e.g. 800',
                            icon: Icons.currency_rupee_rounded,
                            enabled: !_saving,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                              LengthLimitingTextInputFormatter(9),
                            ],
                            validator: (value) {
                              final server = _serverError([
                                'totalAmount',
                                'amount',
                              ]);
                              if (server != null) return server;
                              final text = (value ?? '').trim();
                              if (text.isEmpty) return null;
                              final parsed = num.tryParse(text);
                              if (parsed == null) return 'Numbers only';
                              if (parsed < 0) return 'Cannot be negative';
                              return null;
                            },
                          ),
                          second: AdminTextField(
                            controller: _transactionId,
                            label: 'Transaction ID',
                            hint: 'Optional',
                            icon: Icons.receipt_long_outlined,
                            enabled: !_saving,
                            validator: (_) => _serverError([
                              'transactionId',
                              'transaction_id',
                            ]),
                          ),
                        ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminFieldPair(
                        narrow: narrow,
                        first: AdminVocabularyDropdown<PaymentStatus>(
                          label: 'Payment Status',
                          icon: Icons.payments_outlined,
                          value: _payment,
                          enabled: !_saving,
                          required: true,
                          error: _serverError(const [
                            'paymentStatus',
                            'payment_status',
                          ]),
                          items: PaymentStatus.values,
                          labelOf: (payment) => payment.label,
                          onChanged: (payment) =>
                              setState(() => _payment = payment),
                        ),
                        second: AdminVocabularyDropdown<BookingStatus>(
                          label: 'Booking Status',
                          icon: Icons.event_available_outlined,
                          value: _status,
                          enabled: !_saving,
                          required: true,
                          error: _serverError(const [
                            'bookingStatus',
                            'booking_status',
                            'status',
                          ]),
                          items: BookingStatus.values,
                          labelOf: (status) => status.label,
                          onChanged: (status) =>
                              setState(() => _status = status),
                        ),
                      ),

                      // --- 4. Source and notes ------------------------------
                      const SizedBox(height: AdminTokens.space6),
                      AdminFormSection(
                        icon: Icons.notes_rounded,
                        label: 'Source & Notes',
                        color: tokens.warning,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      if (isEdit)
                        AdminReadOnlyField(
                          label: 'Booking source',
                          value: widget.booking!.bookingSourceRaw,
                          icon: Icons.input_rounded,
                        )
                      else
                        AdminVocabularyDropdown<BookingSource>(
                          label: 'Booking Source',
                          icon: Icons.input_rounded,
                          value: _source,
                          enabled: !_saving,
                          required: true,
                          error: _serverError(const [
                            'bookingSource',
                            'booking_source',
                          ]),
                          items: BookingSource.values,
                          labelOf: (source) => source.label,
                          onChanged: (source) =>
                              setState(() => _source = source),
                        ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminTextField(
                        controller: _notes,
                        label: 'Notes',
                        hint: 'Anything the desk should know',
                        icon: Icons.sticky_note_2_outlined,
                        enabled: !_saving,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (_) => _serverError(['notes']),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AdminFormFooter(
              saving: _saving,
              submitLabel: isEdit ? 'Save Changes' : 'Save Booking',
              onCancel: _saving ? null : () => Navigator.of(context).pop(false),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Live feedback on whether the court is free.
class _ClashNotice extends StatelessWidget {
  const _ClashNotice({
    required this.clashes,
    required this.ready,
    this.scopeNote,
  });

  final List<Booking> clashes;
  final bool ready;
  final String? scopeNote;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    if (!ready) {
      return Text(
        'Pick a date and both times to check the court is free.',
        style: TextStyle(color: tokens.textMuted, fontSize: 11.5, height: 1.4),
      );
    }

    final clashing = clashes.isNotEmpty;
    final color = clashing ? tokens.danger : tokens.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(AdminTokens.space3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                clashing
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline,
                size: 17,
                color: color,
              ),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                child: Text(
                  clashing
                      ? 'Already booked: '
                            '${clashes.map((booking) => booking.displayReference).join(', ')}.'
                      : 'No clash among the bookings loaded.',
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Said plainly: this check only sees what is in memory, and the backend
        // remains the authority.
        if (scopeNote != null) ...[
          const SizedBox(height: 6),
          Text(
            scopeNote!,
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
    this.required = false,
    this.enabled = true,
    this.error,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;
  final bool required;
  final bool enabled;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminFieldLabel(label, required: required),
        const SizedBox(height: AdminTokens.space2),
        InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AdminTokens.space4,
              vertical: AdminTokens.space3 + 3,
            ),
            decoration: BoxDecoration(
              color: tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
              border: Border.all(
                color: error != null ? tokens.danger : tokens.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 17,
                  color: tokens.textMuted,
                ),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Text(
                    value == null
                        ? 'Select a date'
                        : AdminFormat.date(value),
                    style: TextStyle(
                      color: value == null
                          ? tokens.textMuted
                          : tokens.textPrimary,
                      fontSize: 13.5,
                      fontWeight: value == null
                          ? FontWeight.w400
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 6),
          Text(
            error!,
            style: TextStyle(color: tokens.danger, fontSize: 11.5),
          ),
        ],
      ],
    );
  }
}

class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
    this.required = false,
    this.enabled = true,
  });

  final String label;
  final SlotTime? value;
  final VoidCallback onTap;
  final bool required;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminFieldLabel(label, required: required),
        const SizedBox(height: AdminTokens.space2),
        InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AdminTokens.space4,
              vertical: AdminTokens.space3 + 3,
            ),
            decoration: BoxDecoration(
              color: tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
              border: Border.all(
                color: value == null ? tokens.border : tokens.borderStrong,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 18,
                  color: tokens.textMuted,
                ),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Text(
                    value?.label ?? 'Select a time',
                    style: TextStyle(
                      color: value == null
                          ? tokens.textMuted
                          : tokens.textPrimary,
                      fontSize: 13.5,
                      fontWeight: value == null
                          ? FontWeight.w400
                          : FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
