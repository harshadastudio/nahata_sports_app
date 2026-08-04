import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/court_slot.dart';
import '../../domain/entities/event_pass.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import '../utils/server_field_errors.dart';
import 'admin_form_fields.dart';
import 'complex_image_field.dart';
import 'complex_picker_field.dart';

/// Add / Edit event pass.
///
/// [event] null means create (`POST /event-passes`), which sends the slots and
/// FAQs nested in the same body. On an edit those arrays are **read-only**: the
/// collection only exemplifies `title` and `status` on `PUT`, and replacing the
/// slot array on an event that already has bookings against it is not something
/// an unspecified route should be trusted with.
class EventPassFormDialog extends StatefulWidget {
  const EventPassFormDialog({
    super.key,
    required this.onSubmit,
    required this.onUploadImage,
    required this.complexes,
    required this.complexesState,
    required this.onReloadComplexes,
    this.event,
  });

  final AdminEventPass? event;

  /// Throws on failure so this dialog can stay open and explain itself.
  final Future<void> Function(EventPassDraft draft) onSubmit;

  final Future<String> Function(String path, {String? filename}) onUploadImage;

  final List<SportsComplex> complexes;
  final ViewState complexesState;
  final VoidCallback onReloadComplexes;

  bool get isEdit => event != null;

  /// Resolves to true when a save succeeded.
  static Future<bool> show(
    BuildContext context, {
    AdminEventPass? event,
    required Future<void> Function(EventPassDraft draft) onSubmit,
    required Future<String> Function(String path, {String? filename})
    onUploadImage,
    required List<SportsComplex> complexes,
    required ViewState complexesState,
    required VoidCallback onReloadComplexes,
  }) async {
    AdminLog.ui('${event == null ? 'Add' : 'Edit'} event dialog opened');

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => EventPassFormDialog(
        event: event,
        onSubmit: onSubmit,
        onUploadImage: onUploadImage,
        complexes: complexes,
        complexesState: complexesState,
        onReloadComplexes: onReloadComplexes,
      ),
    );

    AdminLog.ui('Event dialog closed (saved: ${saved ?? false})');
    return saved ?? false;
  }

  @override
  State<EventPassFormDialog> createState() => _EventPassFormDialogState();
}

/// One row of the slot editor. Mutable because the editor edits it in place.
class _SlotRow {
  // Every field starts empty and is filled by the editor; the constructor
  // takes no seed values because a create always begins from a blank slot.
  _SlotRow()
    : price = TextEditingController(),
      capacity = TextEditingController();

  DateTime? date;
  SlotTime? start;
  SlotTime? end;
  final TextEditingController price;
  final TextEditingController capacity;

  void dispose() {
    price.dispose();
    capacity.dispose();
  }

  bool get isComplete =>
      date != null &&
      start != null &&
      end != null &&
      num.tryParse(price.text.trim()) != null &&
      int.tryParse(capacity.text.trim()) != null;

  EventPassSlot toSlot() => EventPassSlot(
    date: date,
    startTimeRaw: start?.wire,
    endTimeRaw: end?.wire,
    price: num.tryParse(price.text.trim()),
    capacity: int.tryParse(capacity.text.trim()),
  );
}

class _FaqRow {
  _FaqRow()
    : question = TextEditingController(),
      answer = TextEditingController();

  final TextEditingController question;
  final TextEditingController answer;

  void dispose() {
    question.dispose();
    answer.dispose();
  }

  EventFaq toFaq() =>
      EventFaq(question: question.text, answer: answer.text);
}

class _EventPassFormDialogState extends State<EventPassFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _title;
  late final TextEditingController _description;

  SportsComplex? _complex;
  AdminUserStatus? _status;
  String? _image;

  final List<_SlotRow> _slots = <_SlotRow>[];
  final List<_FaqRow> _faqs = <_FaqRow>[];

  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    final event = widget.event;

    _title = TextEditingController(text: event?.title ?? '');
    _description = TextEditingController(text: event?.description ?? '');
    _status = event?.status ?? AdminUserStatus.active;
    _image = event?.image;
    _complex = _matchComplex(event);

    if (!widget.isEdit) {
      // A create starts with one empty slot: an event with none has nothing to
      // sell, and the repository refuses to send it.
      _slots.add(_SlotRow());
    }

    AdminLog.life(
      'EventPassFormDialog mounted (${widget.isEdit ? 'edit' : 'create'})',
    );
  }

  SportsComplex? _matchComplex(AdminEventPass? event) {
    if (event == null) return null;
    final id = event.sportComplexId;
    if (id != null) {
      for (final complex in widget.complexes) {
        if (complex.id == id) return complex;
      }
    }
    final name = (event.sportComplexName ?? '').trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final complex in widget.complexes) {
      if (complex.name.trim().toLowerCase() == name) return complex;
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant EventPassFormDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The venue list may land after the dialog opened; preselect once it does.
    if (_complex == null && widget.complexes.isNotEmpty) {
      final matched = _matchComplex(widget.event);
      if (matched != null) setState(() => _complex = matched);
    }
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    for (final slot in _slots) {
      slot.dispose();
    }
    for (final faq in _faqs) {
      faq.dispose();
    }
    AdminLog.life('EventPassFormDialog disposed');
    super.dispose();
  }

  Future<void> _pickSlotDate(_SlotRow slot) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: slot.date ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
      helpText: 'Select the slot date',
    );
    if (picked == null || !mounted) return;
    setState(
      () => slot.date = DateTime(picked.year, picked.month, picked.day),
    );
  }

  Future<void> _pickSlotTime(_SlotRow slot, {required bool start}) async {
    final current = start ? slot.start : slot.end;

    final picked = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 9, minute: 0)
          : TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: start ? 'Select the start time' : 'Select the end time',
    );
    if (picked == null || !mounted) return;

    setState(() {
      final value = SlotTime(picked.hour * 60 + picked.minute);
      if (start) {
        slot.start = value;
        // Events run for hours rather than a fixed slot length, so the end is
        // only proposed when it is still empty.
        slot.end ??= value.plusMinutes(60);
      } else {
        slot.end = value;
      }
    });
  }

  /// The first thing wrong with the slot list, or null when it is sound.
  String? get _slotProblem {
    if (widget.isEdit) return null;
    if (_slots.isEmpty) return 'Add at least one slot.';

    for (var index = 0; index < _slots.length; index++) {
      final slot = _slots[index];
      final number = index + 1;

      if (slot.date == null) return 'Slot $number needs a date.';
      if (slot.start == null || slot.end == null) {
        return 'Slot $number needs a start and an end time.';
      }
      if (slot.start!.minutesUntil(slot.end!) == 0) {
        return 'Slot $number cannot start and end at the same time.';
      }
      if (num.tryParse(slot.price.text.trim()) == null) {
        return 'Slot $number needs a price.';
      }
      if (int.tryParse(slot.capacity.text.trim()) == null) {
        return 'Slot $number needs a capacity.';
      }
      if ((int.tryParse(slot.capacity.text.trim()) ?? 0) < 1) {
        return 'Slot $number needs a capacity of at least 1.';
      }
    }
    return null;
  }

  EventPassDraft _draft() {
    return widget.isEdit
        // Only what the PUT example implies. The slot and FAQ arrays are not
        // sent: see the class doc.
        ? EventPassDraft(
            title: _title.text,
            description: _description.text,
            image: _image ?? '',
            status: _status,
          )
        : EventPassDraft(
            sportComplexId: _complex?.id,
            title: _title.text,
            description: _description.text,
            image: _image ?? '',
            status: _status,
            slots: _slots.map((slot) => slot.toSlot()).toList(),
            faqs: _faqs.map((faq) => faq.toFaq()).toList(),
          );
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final problem = _slotProblem;
    if (problem != null) {
      setState(() => _error = problem);
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
      AdminLog.failure('Event save rejected: ${error.message}');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this event. Please try again.';
      });
      AdminLog.failure(
        'Event save crashed',
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

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? AdminTokens.space4 : AdminTokens.space8,
        vertical: AdminTokens.space6,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 860,
          maxHeight: size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminFormHeader(
              title: isEdit ? 'Edit event' : 'Add event',
              subtitle: isEdit
                  ? widget.event!.displayTitle
                  : 'Create an event and open its passes for sale',
              icon: isEdit
                  ? Icons.edit_outlined
                  : Icons.confirmation_number_rounded,
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
                              'The update route is documented only by example '
                              '(title and status). The venue, slots and FAQs '
                              'are shown read-only — replacing the slot array '
                              'on an event that already has bookings is not '
                              'something an unspecified route should be '
                              'trusted with.',
                        ),
                        const SizedBox(height: AdminTokens.space4),
                      ],

                      // --- 1. Basics ----------------------------------------
                      AdminFormSection(
                        icon: Icons.info_outline_rounded,
                        label: 'Event Details',
                        color: tokens.accent,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminTextField(
                        controller: _title,
                        label: 'Title',
                        hint: 'e.g. Independence Day Cricket Cup',
                        icon: Icons.title_rounded,
                        required: true,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          final server = _serverError(['title', 'name']);
                          if (server != null) return server;
                          if ((value ?? '').trim().isEmpty) {
                            return 'A title is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      if (isEdit)
                        AdminReadOnlyField(
                          label: 'Sports complex',
                          value: widget.event!.sportComplexName,
                          icon: Icons.stadium_outlined,
                        )
                      else
                        ComplexPickerField(
                          complexes: widget.complexes,
                          state: widget.complexesState,
                          onReload: widget.onReloadComplexes,
                          initialComplex: _complex,
                          enabled: !_saving,
                          serverError: _serverError(const [
                            'sportComplexId',
                            'sport_complex_id',
                          ]),
                          onChanged: (complex) =>
                              setState(() => _complex = complex),
                          validator: (complex) =>
                              complex == null ? 'Pick a sports complex' : null,
                        ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminTextField(
                        controller: _description,
                        label: 'Description',
                        hint: 'What the event is and who it is for',
                        icon: Icons.notes_rounded,
                        enabled: !_saving,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (_) => _serverError(['description']),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminStatusDropdown(
                        value: _status,
                        enabled: !_saving,
                        error: _serverError(const ['status']),
                        onChanged: (status) =>
                            setState(() => _status = status),
                      ),

                      // --- 2. Slots -----------------------------------------
                      const SizedBox(height: AdminTokens.space6),
                      AdminFormSection(
                        icon: Icons.event_note_rounded,
                        label: 'Slots',
                        color: tokens.info,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      if (isEdit)
                        _ReadOnlySlots(event: widget.event!)
                      else ...[
                        for (var index = 0; index < _slots.length; index++)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AdminTokens.space3,
                            ),
                            child: _SlotEditor(
                              index: index,
                              slot: _slots[index],
                              enabled: !_saving,
                              // The last slot cannot be removed: the create
                              // route needs at least one.
                              onRemove: _slots.length == 1
                                  ? null
                                  : () => setState(() {
                                      _slots.removeAt(index).dispose();
                                    }),
                              onPickDate: () => _pickSlotDate(_slots[index]),
                              onPickStart: () =>
                                  _pickSlotTime(_slots[index], start: true),
                              onPickEnd: () =>
                                  _pickSlotTime(_slots[index], start: false),
                              onChanged: () => setState(() {}),
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () => setState(() => _slots.add(_SlotRow())),
                            icon: const Icon(Icons.add_rounded, size: 17),
                            label: const Text('Add slot'),
                          ),
                        ),
                      ],

                      // --- 3. FAQs ------------------------------------------
                      const SizedBox(height: AdminTokens.space6),
                      AdminFormSection(
                        icon: Icons.help_outline_rounded,
                        label: 'FAQs',
                        color: tokens.success,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      if (isEdit)
                        _ReadOnlyFaqs(event: widget.event!)
                      else ...[
                        for (var index = 0; index < _faqs.length; index++)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: AdminTokens.space3,
                            ),
                            child: _FaqEditor(
                              index: index,
                              faq: _faqs[index],
                              enabled: !_saving,
                              onRemove: () => setState(() {
                                _faqs.removeAt(index).dispose();
                              }),
                            ),
                          ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () => setState(() => _faqs.add(_FaqRow())),
                            icon: const Icon(Icons.add_rounded, size: 17),
                            label: const Text('Add FAQ'),
                          ),
                        ),
                      ],

                      // --- 4. Image -----------------------------------------
                      const SizedBox(height: AdminTokens.space6),
                      AdminFormSection(
                        icon: Icons.image_outlined,
                        label: 'Event Image',
                        color: const Color(0xFF3949AB),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      // The sports-complex module's field, reused as-is. The
                      // event API documents no delete-image route, so no
                      // onServerDelete is passed.
                      ComplexImageField(
                        imageUrl: _image,
                        enabled: !_saving,
                        onUpload: widget.onUploadImage,
                        onChanged: (url) => setState(() => _image = url),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AdminFormFooter(
              saving: _saving,
              submitLabel: isEdit ? 'Save Changes' : 'Save Event',
              onCancel: _saving ? null : () => Navigator.of(context).pop(false),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotEditor extends StatelessWidget {
  const _SlotEditor({
    required this.index,
    required this.slot,
    required this.enabled,
    required this.onRemove,
    required this.onPickDate,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onChanged,
  });

  final int index;
  final _SlotRow slot;
  final bool enabled;
  final VoidCallback? onRemove;
  final VoidCallback onPickDate;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space3),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(
          color: slot.isComplete
              ? tokens.success.withValues(alpha: 0.35)
              : tokens.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Slot ${index + 1}',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (onRemove != null)
                IconButton(
                  onPressed: enabled ? onRemove : null,
                  icon: const Icon(Icons.close_rounded, size: 17),
                  tooltip: 'Remove slot',
                  color: tokens.textMuted,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: AdminTokens.space2),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: _MiniPicker(
                  icon: Icons.calendar_today_rounded,
                  label: slot.date == null
                      ? 'Date'
                      : AdminFormat.date(slot.date),
                  set: slot.date != null,
                  enabled: enabled,
                  onTap: onPickDate,
                ),
              ),
              const SizedBox(width: AdminTokens.space2),
              Expanded(
                flex: 2,
                child: _MiniPicker(
                  icon: Icons.access_time_rounded,
                  label: slot.start?.label ?? 'Start',
                  set: slot.start != null,
                  enabled: enabled,
                  onTap: onPickStart,
                ),
              ),
              const SizedBox(width: AdminTokens.space2),
              Expanded(
                flex: 2,
                child: _MiniPicker(
                  icon: Icons.access_time_rounded,
                  label: slot.end?.label ?? 'End',
                  set: slot.end != null,
                  enabled: enabled,
                  onTap: onPickEnd,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space2),
          Row(
            children: [
              Expanded(
                child: _MiniField(
                  controller: slot.price,
                  hint: 'Price',
                  icon: Icons.currency_rupee_rounded,
                  enabled: enabled,
                  decimal: true,
                  onChanged: onChanged,
                ),
              ),
              const SizedBox(width: AdminTokens.space2),
              Expanded(
                child: _MiniField(
                  controller: slot.capacity,
                  hint: 'Capacity',
                  icon: Icons.groups_outlined,
                  enabled: enabled,
                  onChanged: onChanged,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniPicker extends StatelessWidget {
  const _MiniPicker({
    required this.icon,
    required this.label,
    required this.set,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool set;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AdminTokens.space3,
          vertical: AdminTokens.space3,
        ),
        decoration: BoxDecoration(
          color: tokens.surface,
          borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
          border: Border.all(color: tokens.border),
        ),
        child: Row(
          children: [
            Icon(icon, size: 15, color: tokens.textMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: set ? tokens.textPrimary : tokens.textMuted,
                  fontSize: 12.5,
                  fontWeight: set ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniField extends StatelessWidget {
  const _MiniField({
    required this.controller,
    required this.hint,
    required this.icon,
    required this.enabled,
    required this.onChanged,
    this.decimal = false,
  });

  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool enabled;
  final VoidCallback onChanged;
  final bool decimal;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return TextField(
      controller: controller,
      enabled: enabled,
      onChanged: (_) => onChanged(),
      keyboardType: TextInputType.numberWithOptions(decimal: decimal),
      inputFormatters: [
        if (decimal)
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
        else
          FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(9),
      ],
      style: TextStyle(fontSize: 12.5, color: tokens.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: tokens.surface,
        prefixIcon: Icon(icon, size: 15, color: tokens.textMuted),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 34,
          minHeight: 34,
        ),
      ),
    );
  }
}

class _FaqEditor extends StatelessWidget {
  const _FaqEditor({
    required this.index,
    required this.faq,
    required this.enabled,
    required this.onRemove,
  });

  final int index;
  final _FaqRow faq;
  final bool enabled;
  final VoidCallback onRemove;

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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'FAQ ${index + 1}',
                style: TextStyle(
                  color: tokens.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: enabled ? onRemove : null,
                icon: const Icon(Icons.close_rounded, size: 17),
                tooltip: 'Remove FAQ',
                color: tokens.textMuted,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space2),
          TextField(
            controller: faq.question,
            enabled: enabled,
            style: TextStyle(fontSize: 13, color: tokens.textPrimary),
            decoration: InputDecoration(
              hintText: 'Question',
              isDense: true,
              filled: true,
              fillColor: tokens.surface,
            ),
          ),
          const SizedBox(height: AdminTokens.space2),
          TextField(
            controller: faq.answer,
            enabled: enabled,
            maxLines: 2,
            style: TextStyle(fontSize: 13, color: tokens.textPrimary),
            decoration: InputDecoration(
              hintText: 'Answer',
              isDense: true,
              filled: true,
              fillColor: tokens.surface,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlySlots extends StatelessWidget {
  const _ReadOnlySlots({required this.event});

  final AdminEventPass event;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    if (event.slots.isEmpty) {
      return Text(
        'This event has no slots.',
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final slot in event.slots)
          Padding(
            padding: const EdgeInsets.only(bottom: AdminTokens.space2),
            child: Container(
              padding: const EdgeInsets.all(AdminTokens.space3),
              decoration: BoxDecoration(
                color: tokens.surfaceAlt,
                borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
                border: Border.all(color: tokens.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${AdminFormat.date(slot.date)} · ${slot.windowLabel}',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: tokens.textPrimary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${AdminFormat.currency(slot.price)} · '
                    '${AdminFormat.number(slot.capacity)} seats',
                    style: TextStyle(color: tokens.textMuted, fontSize: 12),
                  ),
                  const SizedBox(width: AdminTokens.space2),
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 14,
                    color: tokens.textMuted,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _ReadOnlyFaqs extends StatelessWidget {
  const _ReadOnlyFaqs({required this.event});

  final AdminEventPass event;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    if (event.faqs.isEmpty) {
      return Text(
        'This event has no FAQs.',
        style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final faq in event.faqs)
          Padding(
            padding: const EdgeInsets.only(bottom: AdminTokens.space2),
            child: Container(
              padding: const EdgeInsets.all(AdminTokens.space3),
              decoration: BoxDecoration(
                color: tokens.surfaceAlt,
                borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
                border: Border.all(color: tokens.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    AdminFormat.text(faq.question),
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    AdminFormat.text(faq.answer),
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 12,
                      height: 1.45,
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
