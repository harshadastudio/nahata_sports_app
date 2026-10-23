import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/event_pass_model.dart';

/// The organiser's extra questions, asked before an event booking is created.
///
/// An event pass can carry a `customFields` list — "Child Name", "Date of
/// Birth", "10th Grade" — and `POST /event-passes/bookings/create` expects the
/// answers back as `customFieldValues: [{key, value}]`. This collects them.
///
/// The field set is entirely API-driven: nothing here knows what any
/// particular event asks. An unrecognised `type` falls back to a plain text
/// field so a new question type still reaches the user rather than being
/// silently dropped.
class EventCustomFieldsForm extends StatefulWidget {
  const EventCustomFieldsForm({
    super.key,
    required this.fields,
    required this.eventTitle,
  });

  final List<EventCustomField> fields;
  final String eventTitle;

  /// Opens the form and resolves to `{key: value}` for the booking payload, or
  /// null if the user backed out — which the caller must treat as "do not
  /// book", not as "no answers".
  static Future<Map<String, String>?> show(
    BuildContext context, {
    required List<EventCustomField> fields,
    required String eventTitle,
  }) {
    return showDialog<Map<String, String>>(
      context: context,
      // The answers are required to book; dismissing by tapping outside would
      // read as an accidental cancel of a payment the user meant to make.
      barrierDismissible: false,
      builder: (_) =>
          EventCustomFieldsForm(fields: fields, eventTitle: eventTitle),
    );
  }

  @override
  State<EventCustomFieldsForm> createState() => _EventCustomFieldsFormState();
}

class _EventCustomFieldsFormState extends State<EventCustomFieldsForm> {
  static const Color _navy = Color(0xFF1A237E);

  final _formKey = GlobalKey<FormState>();

  /// Live text per field key. Select and date fields write here too, so
  /// submission reads one map regardless of how the value was entered.
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    for (final field in widget.fields) {
      final key = field.key;
      if (key != null) _controllers[key] = TextEditingController();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validate(EventCustomField field, String? value) {
    final text = (value ?? '').trim();

    if (field.required && text.isEmpty) {
      return '${field.displayLabel} is required';
    }
    // An optional field left blank is fine; only a filled one is checked.
    if (text.isEmpty) return null;

    if (field.isNumber && num.tryParse(text) == null) {
      return 'Enter a number';
    }
    return null;
  }

  Future<void> _pickDate(EventCustomField field) async {
    final controller = _controllers[field.key];
    if (controller == null) return;

    final now = DateTime.now();
    final existing = DateTime.tryParse(controller.text);

    final picked = await showDatePicker(
      context: context,
      initialDate: existing ?? now,
      // Wide enough for a date of birth at one end and a future date at the
      // other — the field is generic, so the range cannot be assumed.
      firstDate: DateTime(now.year - 100),
      lastDate: DateTime(now.year + 10),
    );

    if (picked == null) return;
    final month = picked.month.toString().padLeft(2, '0');
    final day = picked.day.toString().padLeft(2, '0');
    // ISO, which is what the rest of the booking payload uses.
    setState(() => controller.text = '${picked.year}-$month-$day');
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final answers = <String, String>{};
    for (final field in widget.fields) {
      final key = field.key;
      if (key == null) continue;
      final value = _controllers[key]?.text.trim() ?? '';
      // Blank optional answers are left out rather than sent as empty strings.
      if (value.isNotEmpty) answers[key] = value;
    }

    Navigator.pop(context, answers);
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context).size;

    return Dialog(
      key: const Key('event_custom_fields_form'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: media.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              color: _navy,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'A few details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.eventTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final field in widget.fields) ...[
                        _buildField(field),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      key: const Key('event_custom_fields_continue'),
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Continue',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(EventCustomField field) {
    final controller = _controllers[field.key];
    if (controller == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                field.displayLabel,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            if (field.required)
              const Text(
                ' *',
                style: TextStyle(color: Colors.red, fontSize: 13),
              ),
          ],
        ),
        const SizedBox(height: 6),
        if (field.isSelect)
          _buildSelect(field, controller)
        else
          _buildTextField(field, controller),
      ],
    );
  }

  Widget _buildSelect(
    EventCustomField field,
    TextEditingController controller,
  ) {
    return DropdownButtonFormField<String>(
      key: ValueKey('event_field_${field.key}'),
      initialValue: controller.text.isEmpty ? null : controller.text,
      // Long option labels wrap instead of overflowing the dropdown.
      isExpanded: true,
      decoration: _decoration(field),
      validator: (value) => _validate(field, value),
      items: [
        for (final option in field.options)
          DropdownMenuItem(value: option, child: Text(option)),
      ],
      // Mirrored into the controller so _submit reads every answer from one
      // place, whatever widget captured it.
      onChanged: (value) => controller.text = value ?? '',
    );
  }

  Widget _buildTextField(
    EventCustomField field,
    TextEditingController controller,
  ) {
    return TextFormField(
      key: ValueKey('event_field_${field.key}'),
      controller: controller,
      // A date is chosen from the picker, never typed.
      readOnly: field.isDate,
      onTap: field.isDate ? () => _pickDate(field) : null,
      keyboardType: field.isNumber
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      inputFormatters: field.isNumber
          ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]
          : null,
      validator: (value) => _validate(field, value),
      decoration: _decoration(field),
    );
  }

  InputDecoration _decoration(EventCustomField field) {
    return InputDecoration(
      hintText: (field.placeholder ?? '').trim().isNotEmpty
          ? field.placeholder
          : field.displayLabel,
      hintStyle: const TextStyle(fontSize: 13.5, color: Colors.black38),
      isDense: true,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      suffixIcon: field.isDate
          ? const Icon(Icons.calendar_today_outlined, size: 18)
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: _navy),
      ),
    );
  }
}
