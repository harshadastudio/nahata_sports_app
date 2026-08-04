import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/event_pass.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import '../utils/server_field_errors.dart';
import 'admin_form_fields.dart';

/// Books passes on a customer's behalf — `POST /event-passes/bookings/create`.
///
/// The route takes a plain name, email and phone rather than a user id, so this
/// is genuinely usable from the desk for a walk-in: nothing has to exist in the
/// Users module first.
class EventBookingDialog extends StatefulWidget {
  const EventBookingDialog({
    super.key,
    required this.event,
    required this.onSubmit,
  });

  final AdminEventPass event;

  /// Throws on failure so this dialog can stay open and explain itself.
  final Future<void> Function(EventBookingDraft draft) onSubmit;

  /// Resolves to true when the booking succeeded.
  static Future<bool> show(
    BuildContext context, {
    required AdminEventPass event,
    required Future<void> Function(EventBookingDraft draft) onSubmit,
  }) async {
    AdminLog.ui('Event booking dialog opened for ${event.id}');

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => EventBookingDialog(event: event, onSubmit: onSubmit),
    );

    AdminLog.ui('Event booking dialog closed (saved: ${saved ?? false})');
    return saved ?? false;
  }

  @override
  State<EventBookingDialog> createState() => _EventBookingDialogState();
}

class _EventBookingDialogState extends State<EventBookingDialog> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _passes = TextEditingController(text: '1');
  final _coupon = TextEditingController();

  EventPassSlot? _slot;

  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    // Preselect the first slot still to run, which is what a walk-in almost
    // always wants.
    final now = DateTime.now();
    for (final slot in widget.event.slots) {
      if (slot.id != null && slot.isUpcomingOn(now)) {
        _slot = slot;
        break;
      }
    }
    _slot ??= widget.event.slots.where((slot) => slot.id != null).firstOrNull;
  }

  @override
  void dispose() {
    for (final controller in [_name, _email, _phone, _passes, _coupon]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Only slots the API can be asked about — one without an id is unbookable.
  List<EventPassSlot> get _options =>
      widget.event.slots.where((slot) => slot.id != null).toList();

  num? get _total {
    final slot = _slot;
    final count = int.tryParse(_passes.text.trim());
    if (slot?.price == null || count == null) return null;
    return slot!.price! * count;
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final slot = _slot;
    if (slot?.id == null) {
      setState(() => _error = 'Pick a slot to book onto.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = const {};
    });

    try {
      await widget.onSubmit(
        EventBookingDraft(
          eventPassId: widget.event.id,
          slotId: slot!.id,
          name: _name.text,
          email: _email.text,
          phone: _phone.text,
          numberOfPasses: int.tryParse(_passes.text.trim()) ?? 1,
          couponCode: _coupon.text,
        ),
      );
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
      AdminLog.failure('Event booking rejected: ${error.message}');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not book these passes. Please try again.';
      });
      AdminLog.failure(
        'Event booking crashed',
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
    final options = _options;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? AdminTokens.space4 : AdminTokens.space8,
        vertical: AdminTokens.space6,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminFormHeader(
              title: 'Book passes',
              subtitle: widget.event.displayTitle,
              icon: Icons.confirmation_number_rounded,
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
                      if (options.isEmpty) ...[
                        const AdminFormNote(
                          icon: Icons.info_outline_rounded,
                          text:
                              'This event has no bookable slot — the list did '
                              'not return one with an id. Open the event to '
                              'load its full detail, then try again.',
                        ),
                        const SizedBox(height: AdminTokens.space4),
                      ],

                      AdminFormSection(
                        icon: Icons.event_note_rounded,
                        label: 'Slot',
                        color: tokens.accent,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminVocabularyDropdown<EventPassSlot>(
                        label: 'Slot',
                        icon: Icons.event_note_rounded,
                        value: _slot,
                        enabled: !_saving && options.isNotEmpty,
                        required: true,
                        error: _serverError(const ['slotId', 'slot_id']),
                        items: options,
                        labelOf: (slot) =>
                            '${AdminFormat.date(slot.date)} · '
                            '${slot.windowLabel} · '
                            '${AdminFormat.currency(slot.price)}',
                        onChanged: (slot) => setState(() => _slot = slot),
                      ),

                      const SizedBox(height: AdminTokens.space6),
                      AdminFormSection(
                        icon: Icons.person_outline_rounded,
                        label: 'Customer',
                        color: tokens.info,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminTextField(
                        controller: _name,
                        label: 'Name',
                        hint: 'e.g. Rahul Sharma',
                        icon: Icons.person_outline_rounded,
                        required: true,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          final server = _serverError(['name']);
                          if (server != null) return server;
                          if ((value ?? '').trim().isEmpty) {
                            return 'A name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminFieldPair(
                        narrow: narrow,
                        first: AdminTextField(
                          controller: _phone,
                          label: 'Phone',
                          hint: '10-digit mobile number',
                          icon: Icons.phone_outlined,
                          required: true,
                          enabled: !_saving,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(15),
                          ],
                          validator: (value) {
                            final server = _serverError(['phone']);
                            if (server != null) return server;
                            final text = (value ?? '').trim();
                            if (text.isEmpty) return 'A phone number is needed';
                            final digits = text.replaceAll(
                              RegExp(r'[^0-9]'),
                              '',
                            );
                            if (digits.length < 10) {
                              return 'Enter at least 10 digits';
                            }
                            return null;
                          },
                        ),
                        second: AdminTextField(
                          controller: _email,
                          label: 'Email',
                          hint: 'Where the passes are sent',
                          icon: Icons.mail_outline_rounded,
                          enabled: !_saving,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final server = _serverError(['email']);
                            if (server != null) return server;
                            final text = (value ?? '').trim();
                            // Optional, but a typo is worth catching: the
                            // passes are emailed to it.
                            if (text.isEmpty) return null;
                            if (!RegExp(
                              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                            ).hasMatch(text)) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                        ),
                      ),

                      const SizedBox(height: AdminTokens.space6),
                      AdminFormSection(
                        icon: Icons.payments_outlined,
                        label: 'Passes',
                        color: tokens.success,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminFieldPair(
                        narrow: narrow,
                        first: AdminTextField(
                          controller: _passes,
                          label: 'Number of passes',
                          hint: 'e.g. 2',
                          icon: Icons.confirmation_number_outlined,
                          required: true,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            final server = _serverError([
                              'numberOfPasses',
                              'number_of_passes',
                            ]);
                            if (server != null) return server;
                            final parsed = int.tryParse(
                              (value ?? '').trim(),
                            );
                            if (parsed == null) return 'Numbers only';
                            if (parsed < 1) return 'At least one pass';

                            // The seat count is the slot's whole capacity, not
                            // what is left — the route does not report sales —
                            // so this only catches the obviously impossible.
                            final capacity = _slot?.capacity;
                            if (capacity != null && parsed > capacity) {
                              return 'The slot seats $capacity';
                            }
                            return null;
                          },
                        ),
                        second: AdminTextField(
                          controller: _coupon,
                          label: 'Coupon code',
                          hint: 'Optional',
                          icon: Icons.local_offer_outlined,
                          enabled: !_saving,
                          textCapitalization: TextCapitalization.characters,
                          validator: (_) => _serverError([
                            'couponCode',
                            'coupon_code',
                          ]),
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space3),
                      _TotalNote(total: _total),
                    ],
                  ),
                ),
              ),
            ),
            AdminFormFooter(
              saving: _saving,
              submitLabel: 'Book passes',
              onCancel: _saving ? null : () => Navigator.of(context).pop(false),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalNote extends StatelessWidget {
  const _TotalNote({required this.total});

  final num? total;

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
      child: Row(
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 16,
            color: tokens.textMuted,
          ),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              // Before any coupon: this app does not know the discount rules,
              // and the server prices the booking.
              total == null
                  ? 'Pick a slot and a pass count to see the total.'
                  : 'Before any coupon, this comes to '
                        '${AdminFormat.currency(total)}. The server prices the '
                        'booking.',
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
