import 'package:flutter/material.dart';

import '../../data/repositories/employee_dashboard_repository_impl.dart';
import '../../domain/entities/employee_event.dart';
import '../state/employee_events_controller.dart';
import '../theme/employee_theme.dart';
import '../widgets/employee_forms.dart';
import '../widgets/employee_list_scaffold.dart';

/// Employee → Events. The complex's event passes, their slots, the extra
/// questions on the booking form and the FAQs shown beside it.
class EmployeeEventsPage extends StatefulWidget {
  const EmployeeEventsPage({super.key});

  @override
  State<EmployeeEventsPage> createState() => _EmployeeEventsPageState();
}

class _EmployeeEventsPageState extends State<EmployeeEventsPage> {
  late final EmployeeEventsController _controller =
      EmployeeEventsController(EmployeeDashboardRepositoryImpl());

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
      builder: (context, _) => EmployeeListScaffold<EmployeeEvent>(
        title: 'Events',
        controller: _controller,
        subtitle: () => '${_controller.total} event'
            '${_controller.total == 1 ? '' : 's'}',
        scopeNotice: 'Events running at your own complex.',
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(null),
          backgroundColor: EmployeeTokens.brand,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('New event'),
        ),
        filters: EmployeeFilterChips<EmployeeEventTimeframe>(
          values: EmployeeEventTimeframe.values,
          selected: _controller.timeframe,
          labelOf: (t) => t.label,
          // The chip row hands back null when the selected chip is tapped
          // again. That reads as "no filter", which for this list means every
          // event — the `all` timeframe, not a cleared one.
          onChanged: (value) =>
              _controller.setTimeframe(value ?? EmployeeEventTimeframe.all),
        ),
        itemBuilder: (context, event) => _eventCard(event),
        emptyIcon: Icons.celebration_outlined,
        emptyTitle: _controller.timeframe == EmployeeEventTimeframe.past
            ? 'No past events'
            : 'No events yet',
        emptyMessage: _controller.timeframe == EmployeeEventTimeframe.past
            ? 'Events that have finished will be listed here.'
            : 'Create an event and add the slots people can book.',
      ),
    );
  }

  Widget _eventCard(EmployeeEvent event) {
    return EmployeeCard(
      margin: const EdgeInsets.only(bottom: EmployeeTokens.space3),
      accentColor:
          event.isPast ? EmployeeTokens.textMuted : EmployeeTokens.success,
      onTap: () => _openForm(event),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  event.displayTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: EmployeeTokens.textDark,
                  ),
                ),
              ),
              const SizedBox(width: EmployeeTokens.space2),
              IconButton(
                onPressed: () => _delete(event),
                icon: const Icon(Icons.delete_outline_rounded, size: 19),
                color: EmployeeTokens.danger,
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          if ((event.description ?? '').isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              event.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: EmployeeTokens.textMuted,
              ),
            ),
          ],
          const SizedBox(height: EmployeeTokens.space3),
          Wrap(
            spacing: EmployeeTokens.space2,
            runSpacing: EmployeeTokens.space2,
            children: [
              EmployeeChip(
                label: event.dateLabel,
                color: EmployeeTokens.info,
                icon: Icons.event_outlined,
                dense: true,
              ),
              EmployeeChip(
                label: event.slotsLabel,
                color: EmployeeTokens.purple,
                icon: Icons.schedule_outlined,
                dense: true,
              ),
              EmployeeChip(
                label: event.priceLabel,
                color: EmployeeTokens.accent,
                dense: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _delete(EmployeeEvent event) async {
    final ok = await confirmEmployeeAction(
      context,
      title: 'Delete "${event.displayTitle}"?',
      message: 'The event, its slots and the passes issued against it are all '
          'removed. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;

    final error = await _controller.delete(event);
    if (!mounted) return;

    showEmployeeToast(context, error ?? 'Event deleted', isError: error != null);
  }

  /// Opens the form.
  ///
  /// An existing event is **re-read in full first**: the list route does not
  /// reliably carry the custom fields and FAQs, and saving a form seeded from a
  /// partial row would send back empty arrays and delete them.
  Future<void> _openForm(EmployeeEvent? event) async {
    var seed = event;

    if (event != null) {
      final detail = await _controller.loadDetail(event.id);
      if (!mounted) return;
      if (detail == null) {
        showEmployeeToast(
          context,
          'That event could not be opened. Pull to refresh and try again.',
          isError: true,
        );
        return;
      }
      seed = detail;
    }

    if (!mounted) return;

    await showEmployeeSheet<void>(
      context: context,
      title: seed == null ? 'New event' : 'Edit event',
      subtitle: seed?.displayTitle,
      builder: (context) => _EventForm(event: seed, controller: _controller),
    );
  }
}

class _EventForm extends StatefulWidget {
  const _EventForm({required this.event, required this.controller});

  final EmployeeEvent? event;
  final EmployeeEventsController controller;

  @override
  State<_EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<_EventForm> {
  late final TextEditingController _title =
      TextEditingController(text: widget.event?.title ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.event?.description ?? '');
  late final TextEditingController _image =
      TextEditingController(text: widget.event?.image ?? '');

  late List<EmployeeEventSlot> _slots =
      List<EmployeeEventSlot>.from(widget.event?.slots ?? const []);
  late List<EmployeeEventCustomField> _fields =
      List<EmployeeEventCustomField>.from(
    widget.event?.customFields ?? const [],
  );
  late List<EmployeeEventFaq> _faqs =
      List<EmployeeEventFaq>.from(widget.event?.faqs ?? const []);

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.event != null;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _image.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final draft = EmployeeEventDraft(
      title: _title.text,
      description: _description.text,
      image: _image.text,
      slots: _slots,
      customFields: _fields,
      faqs: _faqs,
    );

    final invalid = draft.validationError;
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = _isEdit
        ? await widget.controller.update(widget.event!.id, draft)
        : await widget.controller.create(draft);

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }

    Navigator.of(context).pop();
    showEmployeeToast(context, _isEdit ? 'Event updated' : 'Event created');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmployeeFormError(message: _error),

        EmployeeField(
          label: 'Title',
          required: true,
          child: EmployeeTextField(
            controller: _title,
            hintText: 'e.g. Summer Basketball Camp',
          ),
        ),

        EmployeeField(
          label: 'Description',
          child: EmployeeTextField(
            controller: _description,
            maxLines: 3,
            hintText: 'What the event is',
          ),
        ),

        EmployeeField(
          label: 'Banner image URL',
          hint: 'Leave blank for no banner.',
          child: EmployeeTextField(
            controller: _image,
            keyboardType: TextInputType.url,
            textCapitalization: TextCapitalization.none,
            hintText: 'https://…',
          ),
        ),

        _EventSection(
          title: 'Slots',
          subtitle: 'What people actually book.',
          addLabel: 'Add slot',
          onAdd: _addSlot,
          children: [
            for (var i = 0; i < _slots.length; i++)
              _slotTile(_slots[i], i),
          ],
        ),

        _EventSection(
          title: 'Custom fields',
          subtitle: 'Extra questions on the booking form.',
          addLabel: 'Add field',
          onAdd: _addField,
          children: [
            for (var i = 0; i < _fields.length; i++)
              _fieldTile(_fields[i], i),
          ],
        ),

        _EventSection(
          title: 'FAQs',
          subtitle: 'Shown beside the event.',
          addLabel: 'Add FAQ',
          onAdd: _addFaq,
          children: [
            for (var i = 0; i < _faqs.length; i++) _faqTile(_faqs[i], i),
          ],
        ),

        const SizedBox(height: EmployeeTokens.space2),
        EmployeeSheetActions(
          saving: _saving,
          saveLabel: _isEdit ? 'Update event' : 'Create event',
          onSave: _save,
        ),
      ],
    );
  }

  // ── Slots ─────────────────────────────────────────────────────────────────

  Widget _slotTile(EmployeeEventSlot slot, int index) {
    return _EventRow(
      title: slot.displayName,
      subtitle: [
        slot.dateLabel,
        if (slot.timeLabel != null) slot.timeLabel!,
        slot.priceLabel,
        slot.passType,
      ].join(' · '),
      onEdit: () => _editSlot(index),
      onDelete: () => setState(() => _slots.removeAt(index)),
    );
  }

  Future<void> _addSlot() async {
    final slot = await showEmployeeSheet<EmployeeEventSlot>(
      context: context,
      title: 'Add slot',
      builder: (context) => const _SlotForm(slot: null),
    );
    if (slot != null && mounted) setState(() => _slots = [..._slots, slot]);
  }

  Future<void> _editSlot(int index) async {
    final slot = await showEmployeeSheet<EmployeeEventSlot>(
      context: context,
      title: 'Edit slot',
      subtitle: _slots[index].displayName,
      builder: (context) => _SlotForm(slot: _slots[index]),
    );
    if (slot == null || !mounted) return;

    setState(() {
      final next = [..._slots];
      next[index] = slot;
      _slots = next;
    });
  }

  // ── Custom fields ─────────────────────────────────────────────────────────

  Widget _fieldTile(EmployeeEventCustomField field, int index) {
    return _EventRow(
      title: field.label,
      subtitle: field.summary,
      onEdit: () => _editField(index),
      onDelete: () => setState(() => _fields.removeAt(index)),
    );
  }

  Future<void> _addField() async {
    final field = await showEmployeeSheet<EmployeeEventCustomField>(
      context: context,
      title: 'Add custom field',
      builder: (context) => const _CustomFieldForm(field: null),
    );
    if (field != null && mounted) setState(() => _fields = [..._fields, field]);
  }

  Future<void> _editField(int index) async {
    final field = await showEmployeeSheet<EmployeeEventCustomField>(
      context: context,
      title: 'Edit custom field',
      subtitle: _fields[index].label,
      builder: (context) => _CustomFieldForm(field: _fields[index]),
    );
    if (field == null || !mounted) return;

    setState(() {
      final next = [..._fields];
      next[index] = field;
      _fields = next;
    });
  }

  // ── FAQs ──────────────────────────────────────────────────────────────────

  Widget _faqTile(EmployeeEventFaq faq, int index) {
    return _EventRow(
      title: faq.question,
      subtitle: faq.answer,
      onEdit: () => _editFaq(index),
      onDelete: () => setState(() => _faqs.removeAt(index)),
    );
  }

  Future<void> _addFaq() async {
    final faq = await showEmployeeSheet<EmployeeEventFaq>(
      context: context,
      title: 'Add FAQ',
      builder: (context) => const _FaqForm(faq: null),
    );
    if (faq != null && mounted) setState(() => _faqs = [..._faqs, faq]);
  }

  Future<void> _editFaq(int index) async {
    final faq = await showEmployeeSheet<EmployeeEventFaq>(
      context: context,
      title: 'Edit FAQ',
      builder: (context) => _FaqForm(faq: _faqs[index]),
    );
    if (faq == null || !mounted) return;

    setState(() {
      final next = [..._faqs];
      next[index] = faq;
      _faqs = next;
    });
  }
}

/// A titled group inside the event form, with its own "add" button.
class _EventSection extends StatelessWidget {
  const _EventSection({
    required this.title,
    required this.subtitle,
    required this.addLabel,
    required this.onAdd,
    required this.children,
  });

  final String title;
  final String subtitle;
  final String addLabel;
  final VoidCallback onAdd;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: EmployeeTokens.space5),
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
                      title.toUpperCase(),
                      style: const TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 0.9,
                        fontWeight: FontWeight.w700,
                        color: EmployeeTokens.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: EmployeeTokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add_rounded, size: 17),
                label: Text(addLabel),
                style: TextButton.styleFrom(
                  foregroundColor: EmployeeTokens.brand,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: EmployeeTokens.space2),
          if (children.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(EmployeeTokens.space3),
              decoration: BoxDecoration(
                color: EmployeeTokens.canvas,
                borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
              ),
              child: Text(
                'None added.',
                style: const TextStyle(
                  fontSize: 12,
                  color: EmployeeTokens.textMuted,
                ),
              ),
            )
          else
            ...children,
        ],
      ),
    );
  }
}

/// One editable child row inside the event form.
class _EventRow extends StatelessWidget {
  const _EventRow({
    required this.title,
    required this.subtitle,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final String subtitle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
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
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: EmployeeTokens.textDark,
                  ),
                ),
                if (subtitle.trim().isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.35,
                      color: EmployeeTokens.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 17),
            color: EmployeeTokens.brand,
            tooltip: 'Edit',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.close_rounded, size: 18),
            color: EmployeeTokens.danger,
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}

class _SlotForm extends StatefulWidget {
  const _SlotForm({required this.slot});

  final EmployeeEventSlot? slot;

  @override
  State<_SlotForm> createState() => _SlotFormState();
}

class _SlotFormState extends State<_SlotForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.slot?.name ?? '');
  late final TextEditingController _price = TextEditingController(
    text: widget.slot == null ? '' : widget.slot!.price.toString(),
  );

  late DateTime? _date = widget.slot?.date;
  late String? _startTime = widget.slot?.startTime;
  late String? _endTime = widget.slot?.endTime;
  late String _passType =
      EmployeeEventSlot.passTypes.contains(widget.slot?.passType)
          ? widget.slot!.passType
          : EmployeeEventSlot.passTypes.first;

  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give the slot a name.');
      return;
    }
    if (_date == null) {
      setState(() => _error = 'Choose the date this slot runs on.');
      return;
    }

    Navigator.of(context).pop(
      EmployeeEventSlot(
        // Carried through so the API updates this slot rather than replacing
        // it — and with it, the bookings already made against it.
        id: widget.slot?.id,
        name: _name.text.trim(),
        date: _date,
        price: num.tryParse(_price.text.trim()) ?? 0,
        passType: _passType,
        startTime: _startTime,
        endTime: _endTime,
        capacity: widget.slot?.capacity,
        booked: widget.slot?.booked,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmployeeFormError(message: _error),

        EmployeeField(
          label: 'Slot name',
          required: true,
          child: EmployeeTextField(
            controller: _name,
            hintText: 'e.g. Morning Batch',
          ),
        ),

        EmployeeField(
          label: 'Date',
          required: true,
          child: EmployeeDateField(
            value: _date,
            firstDate: DateTime(now.year - 1),
            lastDate: DateTime(now.year + 3),
            onChanged: (value) => setState(() => _date = value),
          ),
        ),

        Row(
          children: [
            Expanded(
              child: EmployeeField(
                label: 'Starts',
                child: EmployeeTimeField(
                  value: _startTime,
                  onChanged: (value) => setState(() => _startTime = value),
                ),
              ),
            ),
            const SizedBox(width: EmployeeTokens.space3),
            Expanded(
              child: EmployeeField(
                label: 'Ends',
                child: EmployeeTimeField(
                  value: _endTime,
                  onChanged: (value) => setState(() => _endTime = value),
                ),
              ),
            ),
          ],
        ),

        EmployeeField(
          label: 'Price',
          child: EmployeeNumberField(
            controller: _price,
            isCurrency: true,
            hintText: '0',
          ),
        ),

        EmployeeField(
          label: 'Pass type',
          hint: 'How many people one pass admits.',
          child: EmployeeDropdown<String>(
            value: _passType,
            items: EmployeeEventSlot.passTypes,
            labelOf: (t) => t,
            onChanged: (value) =>
                setState(() => _passType = value ?? _passType),
          ),
        ),

        EmployeeSheetActions(
          saveLabel: widget.slot == null ? 'Add slot' : 'Save slot',
          onSave: _save,
        ),
      ],
    );
  }
}

class _CustomFieldForm extends StatefulWidget {
  const _CustomFieldForm({required this.field});

  final EmployeeEventCustomField? field;

  @override
  State<_CustomFieldForm> createState() => _CustomFieldFormState();
}

class _CustomFieldFormState extends State<_CustomFieldForm> {
  late final TextEditingController _label =
      TextEditingController(text: widget.field?.label ?? '');
  late final TextEditingController _placeholder =
      TextEditingController(text: widget.field?.placeholder ?? '');
  late final TextEditingController _options = TextEditingController(
    text: (widget.field?.options ?? const <String>[]).join(', '),
  );

  late String _type =
      EmployeeEventCustomField.types.contains(widget.field?.type)
          ? widget.field!.type
          : EmployeeEventCustomField.types.first;
  late bool _required = widget.field?.required ?? false;

  String? _error;

  bool get _isSelect => _type.toLowerCase() == 'select';

  @override
  void dispose() {
    _label.dispose();
    _placeholder.dispose();
    _options.dispose();
    super.dispose();
  }

  List<String> _parsedOptions() => _options.text
      .split(',')
      .map((option) => option.trim())
      .where((option) => option.isNotEmpty)
      .toList(growable: false);

  void _save() {
    if (_label.text.trim().isEmpty) {
      setState(() => _error = 'Give the field a label.');
      return;
    }

    final options = _isSelect ? _parsedOptions() : const <String>[];
    if (_isSelect && options.isEmpty) {
      setState(() => _error = 'A dropdown needs at least one option.');
      return;
    }

    Navigator.of(context).pop(
      EmployeeEventCustomField(
        id: widget.field?.id,
        label: _label.text.trim(),
        type: _type,
        required: _required,
        placeholder: _placeholder.text,
        options: options,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmployeeFormError(message: _error),

        EmployeeField(
          label: 'Label',
          required: true,
          child: EmployeeTextField(
            controller: _label,
            hintText: 'e.g. T-shirt size',
          ),
        ),

        EmployeeField(
          label: 'Type',
          child: EmployeeDropdown<String>(
            value: _type,
            items: EmployeeEventCustomField.types,
            labelOf: (t) => t,
            onChanged: (value) => setState(() => _type = value ?? _type),
          ),
        ),

        if (_isSelect)
          EmployeeField(
            label: 'Options',
            required: true,
            hint: 'Separate each choice with a comma.',
            child: EmployeeTextField(
              controller: _options,
              hintText: 'S, M, L',
            ),
          )
        else
          EmployeeField(
            label: 'Placeholder',
            child: EmployeeTextField(
              controller: _placeholder,
              hintText: 'Hint shown inside the box',
            ),
          ),

        EmployeeSwitchField(
          label: 'Required',
          subtitle: 'The booking cannot be completed without it.',
          value: _required,
          onChanged: (value) => setState(() => _required = value),
        ),

        EmployeeSheetActions(
          saveLabel: widget.field == null ? 'Add field' : 'Save field',
          onSave: _save,
        ),
      ],
    );
  }
}

class _FaqForm extends StatefulWidget {
  const _FaqForm({required this.faq});

  final EmployeeEventFaq? faq;

  @override
  State<_FaqForm> createState() => _FaqFormState();
}

class _FaqFormState extends State<_FaqForm> {
  late final TextEditingController _question =
      TextEditingController(text: widget.faq?.question ?? '');
  late final TextEditingController _answer =
      TextEditingController(text: widget.faq?.answer ?? '');

  String? _error;

  @override
  void dispose() {
    _question.dispose();
    _answer.dispose();
    super.dispose();
  }

  void _save() {
    final faq = EmployeeEventFaq(
      id: widget.faq?.id,
      question: _question.text,
      answer: _answer.text,
    );

    if (!faq.isValid) {
      setState(() => _error = 'Both a question and an answer are needed.');
      return;
    }

    Navigator.of(context).pop(faq);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmployeeFormError(message: _error),

        EmployeeField(
          label: 'Question',
          required: true,
          child: EmployeeTextField(
            controller: _question,
            maxLines: 2,
            hintText: 'e.g. What should I bring?',
          ),
        ),

        EmployeeField(
          label: 'Answer',
          required: true,
          child: EmployeeTextField(
            controller: _answer,
            maxLines: 4,
            hintText: 'Sports shoes and a water bottle.',
          ),
        ),

        EmployeeSheetActions(
          saveLabel: widget.faq == null ? 'Add FAQ' : 'Save FAQ',
          onSave: _save,
        ),
      ],
    );
  }
}
