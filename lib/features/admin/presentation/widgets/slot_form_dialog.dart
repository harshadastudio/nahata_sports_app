import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/coach.dart';
import '../../domain/entities/court_slot.dart';
import '../theme/admin_theme.dart';
import '../utils/server_field_errors.dart';
import 'admin_form_fields.dart';

/// Add / Edit slot.
///
/// [slot] null means create (`POST /courts/{id}/slots`), otherwise edit
/// (`PUT /courts/{id}/slots/{slotId}`). The update route documents the times,
/// the price override and the status, so on an edit the days and the slot type
/// render read-only.
///
/// Two rules the spec is explicit about are enforced before anything is sent:
/// a slot is exactly one hour, and it may not overlap another slot on a day
/// they share.
class SlotFormDialog extends StatefulWidget {
  const SlotFormDialog({
    super.key,
    required this.onSubmit,
    required this.findClashes,
    this.slot,
  });

  final CourtSlot? slot;

  /// Throws on failure so this dialog can stay open and explain itself.
  final Future<void> Function(CourtSlotDraft draft) onSubmit;

  /// Existing slots the draft would collide with. Returned rather than thrown
  /// so this dialog can name the offender instead of saying "clash".
  final List<CourtSlot> Function(CourtSlotDraft draft) findClashes;

  bool get isEdit => slot != null;

  /// Resolves to true when a save succeeded.
  static Future<bool> show(
    BuildContext context, {
    CourtSlot? slot,
    required Future<void> Function(CourtSlotDraft draft) onSubmit,
    required List<CourtSlot> Function(CourtSlotDraft draft) findClashes,
  }) async {
    AdminLog.ui('${slot == null ? 'Add' : 'Edit'} slot dialog opened');

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => SlotFormDialog(
        slot: slot,
        onSubmit: onSubmit,
        findClashes: findClashes,
      ),
    );

    AdminLog.ui('Slot dialog closed (saved: ${saved ?? false})');
    return saved ?? false;
  }

  @override
  State<SlotFormDialog> createState() => _SlotFormDialogState();
}

class _SlotFormDialogState extends State<SlotFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _price;

  SlotTime? _start;
  SlotTime? _end;
  Set<Weekday> _days = <Weekday>{};
  String? _customDays;
  SlotType? _type;
  AdminUserStatus? _status;

  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    final slot = widget.slot;

    _price = TextEditingController(text: _numberText(slot?.priceOverride));
    _start = slot?.startTime;
    _end = slot?.endTime;
    _type = slot?.slotType ?? SlotType.regular;
    _status = slot?.status ?? AdminUserStatus.active;

    final days = slot?.days ?? CoachAvailability.none;
    if (days.isCustom) {
      _customDays = days.raw;
    } else {
      _days = days.days.toSet();
    }

    AdminLog.life(
      'SlotFormDialog mounted (${widget.isEdit ? 'edit' : 'create'})',
    );
  }

  static String _numberText(num? value) {
    if (value == null) return '';
    if (value is int) return value.toString();
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  @override
  void dispose() {
    _price.dispose();
    AdminLog.life('SlotFormDialog disposed');
    super.dispose();
  }

  String _daysValue() => _customDays ?? CoachAvailability.compose(_days);

  /// Only what this dialog is allowed to change, so an edit never sends the
  /// days or the type the route does not document as editable.
  CourtSlotDraft _draft() {
    final price = _price.text.trim();

    return widget.isEdit
        ? CourtSlotDraft(
            startTime: _start,
            endTime: _end,
            priceOverride: price.isEmpty ? null : num.tryParse(price),
            // An override that was there and has been emptied has to be sent as
            // an explicit null, or it could never be removed.
            clearPriceOverride:
                price.isEmpty && widget.slot?.hasPriceOverride == true,
            status: _status,
          )
        : CourtSlotDraft(
            startTime: _start,
            endTime: _end,
            availableDays: _daysValue(),
            slotType: _type,
            priceOverride: price.isEmpty ? null : num.tryParse(price),
            status: _status,
          );
  }

  /// Everything the API would reject, checked before spending a round trip.
  String? get _windowProblem =>
      CourtSlotDraft.validateWindow(_start, _end);

  List<CourtSlot> get _clashes {
    if (_start == null || _end == null) return const [];
    return widget.findClashes(_draft());
  }

  Future<void> _pickTime({required bool start}) async {
    final current = start ? _start : _end;

    final picked = await showTimePicker(
      context: context,
      initialTime: current == null
          ? const TimeOfDay(hour: 7, minute: 0)
          : TimeOfDay(hour: current.hour, minute: current.minute),
      helpText: start ? 'Select start time' : 'Select end time',
    );

    if (picked == null || !mounted) return;

    setState(() {
      final value = SlotTime(picked.hour * 60 + picked.minute);
      if (start) {
        _start = value;
        // The rule is a one-hour slot, so choosing a start proposes the end
        // rather than making the admin compute it. It stays editable.
        _end = value.plusMinutes(CourtSlotDraft.requiredMinutes);
      } else {
        _end = value;
      }
    });
    _formKey.currentState?.validate();
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final problem = _windowProblem;
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }

    final clashes = _clashes;
    if (clashes.isNotEmpty) {
      setState(() {
        _error =
            'This window overlaps ${clashes.length == 1 ? 'an existing slot' : '${clashes.length} existing slots'}: '
            '${clashes.map((slot) => slot.windowLabel).join(', ')}.';
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
      final parsed = ServerFieldErrors.from(error, fieldLabel: 'Slot type');
      setState(() {
        _saving = false;
        _error = parsed.summary ?? error.message;
        _fieldErrors = parsed.fields;
      });
      _formKey.currentState?.validate();
      AdminLog.failure('Slot save rejected: ${error.message}');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this slot. Please try again.';
      });
      AdminLog.failure(
        'Slot save crashed',
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

    final windowProblem = _windowProblem;
    final clashes = _clashes;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? AdminTokens.space4 : AdminTokens.space8,
        vertical: AdminTokens.space6,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminFormHeader(
              title: isEdit ? 'Edit slot' : 'Add slot',
              subtitle: isEdit
                  ? widget.slot!.windowLabel
                  : 'One bookable hour on this court',
              icon: isEdit ? Icons.edit_outlined : Icons.more_time_rounded,
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
                              'The update route accepts the times, the price '
                              'override and the status. The days and the slot '
                              'type are shown read-only.',
                        ),
                        const SizedBox(height: AdminTokens.space4),
                      ],

                      AdminFormSection(
                        icon: Icons.schedule_rounded,
                        label: 'Time',
                        color: tokens.accent,
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
                      _WindowNotice(
                        problem: windowProblem,
                        clashes: clashes,
                        start: _start,
                        end: _end,
                      ),

                      const SizedBox(height: AdminTokens.space6),
                      AdminFormSection(
                        icon: Icons.event_repeat_rounded,
                        label: 'Availability',
                        color: tokens.info,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      if (isEdit)
                        AdminFieldPair(
                          narrow: narrow,
                          first: AdminReadOnlyField(
                            label: 'Available days',
                            value: widget.slot!.days.isEmpty
                                ? null
                                : widget.slot!.days.raw,
                            icon: Icons.event_repeat_rounded,
                          ),
                          second: AdminReadOnlyField(
                            label: 'Slot type',
                            value: widget.slot!.slotTypeRaw,
                            icon: Icons.category_outlined,
                          ),
                        )
                      else ...[
                        _DaysField(
                          days: _days,
                          customValue: _customDays,
                          enabled: !_saving,
                          onChanged: (days) => setState(() => _days = days),
                          onClearCustom: () =>
                              setState(() => _customDays = null),
                        ),
                        const SizedBox(height: AdminTokens.space4),
                        AdminVocabularyDropdown<SlotType>(
                          label: 'Slot Type',
                          icon: Icons.category_outlined,
                          value: _type,
                          enabled: !_saving,
                          required: true,
                          error: _serverError(const ['slotType', 'slot_type']),
                          items: SlotType.values,
                          labelOf: (type) => type.label,
                          onChanged: (type) => setState(() => _type = type),
                        ),
                      ],

                      const SizedBox(height: AdminTokens.space6),
                      AdminFormSection(
                        icon: Icons.currency_rupee_rounded,
                        label: 'Price & Status',
                        color: tokens.success,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminFieldPair(
                        narrow: narrow,
                        first: AdminTextField(
                          controller: _price,
                          label: 'Price Override',
                          hint: 'Leave blank to charge the court rate',
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
                              'priceOverride',
                              'price_override',
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
                        second: AdminStatusDropdown(
                          value: _status,
                          enabled: !_saving,
                          error: _serverError(const ['status']),
                          onChanged: (status) =>
                              setState(() => _status = status),
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space2),
                      Text(
                        'Active means bookable; Inactive blocks the slot.',
                        style: TextStyle(
                          color: tokens.textMuted,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AdminFormFooter(
              saving: _saving,
              submitLabel: isEdit ? 'Save Changes' : 'Save Slot',
              onCancel: _saving ? null : () => Navigator.of(context).pop(false),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Live feedback on the window: the one-hour rule, and any clash.
class _WindowNotice extends StatelessWidget {
  const _WindowNotice({
    required this.problem,
    required this.clashes,
    required this.start,
    required this.end,
  });

  final String? problem;
  final List<CourtSlot> clashes;
  final SlotTime? start;
  final SlotTime? end;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    if (start == null && end == null) {
      return Text(
        'A slot must be exactly one hour long.',
        style: TextStyle(color: tokens.textMuted, fontSize: 11.5, height: 1.4),
      );
    }

    final bad = problem != null || clashes.isNotEmpty;
    final message = problem ??
        (clashes.isEmpty
            ? 'One hour — this window is valid.'
            : 'Overlaps ${clashes.map((slot) => slot.windowLabel).join(', ')}.');

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space3),
      decoration: BoxDecoration(
        color: (bad ? tokens.warning : tokens.success).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(
          color: (bad ? tokens.warning : tokens.success).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            bad ? Icons.error_outline_rounded : Icons.check_circle_outline,
            size: 17,
            color: bad ? tokens.warning : tokens.success,
          ),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              message,
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

/// Day chips over the comma-separated string the column actually stores.
class _DaysField extends StatelessWidget {
  const _DaysField({
    required this.days,
    required this.customValue,
    required this.enabled,
    required this.onChanged,
    required this.onClearCustom,
  });

  final Set<Weekday> days;
  final String? customValue;
  final bool enabled;
  final ValueChanged<Set<Weekday>> onChanged;
  final VoidCallback onClearCustom;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final custom = customValue != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Expanded(child: AdminFieldLabel('Available Days')),
            if (!custom)
              TextButton(
                onPressed: enabled
                    ? () => onChanged(Weekday.values.toSet())
                    : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AdminTokens.space2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('All days', style: TextStyle(fontSize: 11.5)),
              ),
          ],
        ),
        const SizedBox(height: AdminTokens.space2),
        if (custom) ...[
          Container(
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
                    customValue!,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: enabled ? onClearCustom : null,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Pick days instead',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
        ] else
          Wrap(
            spacing: AdminTokens.space2,
            runSpacing: AdminTokens.space2,
            children: Weekday.values.map((day) {
              final selected = days.contains(day);
              return GestureDetector(
                onTap: enabled
                    ? () {
                        final next = days.toSet();
                        if (!next.remove(day)) next.add(day);
                        onChanged(next);
                      }
                    : null,
                child: AnimatedContainer(
                  duration: AdminTokens.fast,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AdminTokens.space3 + 2,
                    vertical: AdminTokens.space2 + 2,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? tokens.accentSoft : tokens.surfaceAlt,
                    borderRadius: BorderRadius.circular(
                      AdminTokens.radiusPill,
                    ),
                    border: Border.all(
                      color: selected ? tokens.accent : tokens.border,
                    ),
                  ),
                  child: Text(
                    day.shortLabel,
                    style: TextStyle(
                      color: selected ? tokens.accent : tokens.textSecondary,
                      fontSize: 12.5,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
