import 'package:flutter/material.dart';

import '../../data/repositories/employee_dashboard_repository_impl.dart';
import '../../domain/entities/employee_master.dart';
import '../state/employee_masters_controller.dart';
import '../theme/employee_theme.dart';
import '../widgets/employee_collection_scaffold.dart';
import '../widgets/employee_forms.dart';

/// Employee → Slot. The bookable times on a court.
///
/// These are **templates**: a slot here repeats on the days it lists, on every
/// date. Closing a court for one day belongs on the Blocked Slots screen.
class EmployeeSlotsPage extends StatefulWidget {
  const EmployeeSlotsPage({super.key});

  @override
  State<EmployeeSlotsPage> createState() => _EmployeeSlotsPageState();
}

class _EmployeeSlotsPageState extends State<EmployeeSlotsPage> {
  late final EmployeeSlotsController _controller =
      EmployeeSlotsController(EmployeeDashboardRepositoryImpl());

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
      builder: (context, _) => EmployeeCollectionScaffold<EmployeeSlot>(
        title: 'Slots',
        controller: _controller,
        subtitle: () {
          final court = _controller.court;
          if (court == null) return 'No courts yet';
          return '${court.displayName} · ${_controller.items.length} slot'
              '${_controller.items.length == 1 ? '' : 's'}';
        },
        scopeNotice: 'Slots repeat on every date. To close a court for one '
            'day, use Blocked Slots.',
        toolbar: _courtPicker(),
        onAdd: _controller.hasCourt ? () => _openForm(null) : null,
        addLabel: 'Add slot',
        emptyIcon: Icons.schedule_outlined,
        emptyTitle:
            _controller.hasCourt ? 'No slots on this court' : 'Add a court first',
        emptyMessage: _controller.hasCourt
            ? 'Add the times this court can be booked for.'
            : 'Slots belong to a court, and your complex has none yet. Add one '
                'on the Courts screen, then come back.',
        emptyActionLabel: 'Add a slot',
        itemBuilder: (context, slot) => _slotCard(slot),
      ),
    );
  }

  Widget _courtPicker() {
    final courts = _controller.courts;
    final court = _controller.court;

    if (courts.isEmpty) {
      return const Text(
        'No courts to pick from yet.',
        style: TextStyle(fontSize: 12.5, color: EmployeeTokens.textMuted),
      );
    }

    return Row(
      children: [
        const Icon(
          Icons.place_outlined,
          size: 17,
          color: EmployeeTokens.textMuted,
        ),
        const SizedBox(width: EmployeeTokens.space2),
        Expanded(
          child: EmployeeDropdown<int>(
            value: court?.id,
            items: courts.map((c) => c.id).toList(),
            labelOf: (id) => courts.firstWhere((c) => c.id == id).displayName,
            subtitleOf: (id) {
              final match = courts.firstWhere((c) => c.id == id);
              return match.sportName.isEmpty ? null : match.sportName;
            },
            placeholder: 'Select a court',
            onChanged: (value) {
              if (value == null) return;
              _controller.selectCourt(
                courts.firstWhere((c) => c.id == value),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _slotCard(EmployeeSlot slot) {
    return EmployeeCard(
      margin: const EdgeInsets.only(bottom: EmployeeTokens.space3),
      accentColor:
          slot.isActive ? EmployeeTokens.success : EmployeeTokens.textMuted,
      onTap: () => _openForm(slot),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        slot.timeLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: EmployeeTokens.textDark,
                        ),
                      ),
                    ),
                    if (slot.priceOverride != null)
                      Text(
                        slot.priceLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: EmployeeTokens.accent,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  slot.daysLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: EmployeeTokens.textMuted,
                  ),
                ),
                const SizedBox(height: EmployeeTokens.space3),
                // Wrap, not Row: three chips plus a label do not fit one line
                // on a narrow phone once the system font is scaled up.
                Wrap(
                  spacing: EmployeeTokens.space2,
                  runSpacing: EmployeeTokens.space2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    EmployeeChip(label: slot.status, dense: true),
                    EmployeeChip(
                      label: slot.slotType,
                      color: slot.slotType.toLowerCase() == 'peak'
                          ? EmployeeTokens.accent
                          : EmployeeTokens.info,
                      dense: true,
                    ),
                    if (slot.priceOverride == null)
                      const Text(
                        "Court's rate",
                        style: TextStyle(
                          fontSize: 11,
                          color: EmployeeTokens.textMuted,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                onPressed: () => _toggle(slot),
                icon: Icon(
                  slot.isActive
                      ? Icons.toggle_on_rounded
                      : Icons.toggle_off_rounded,
                  size: 26,
                ),
                color: slot.isActive
                    ? EmployeeTokens.success
                    : EmployeeTokens.textMuted,
                tooltip: slot.isActive ? 'Deactivate' : 'Activate',
                visualDensity: VisualDensity.compact,
              ),
              IconButton(
                onPressed: () => _delete(slot),
                icon: const Icon(Icons.delete_outline_rounded, size: 19),
                color: EmployeeTokens.danger,
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(EmployeeSlot slot) async {
    // Deactivating a template closes this time on every date, which is a much
    // bigger action than it looks — so it is confirmed and the one-day
    // alternative is named.
    if (slot.isActive) {
      final ok = await confirmEmployeeAction(
        context,
        title: 'Deactivate this slot?',
        message: '${slot.timeLabel} stops being bookable on **every** date, '
            'not just today. To close it for one day, use Blocked Slots '
            'instead.',
        confirmLabel: 'Deactivate',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }

    final error = await _controller.toggleStatus(slot);
    if (!mounted) return;

    showEmployeeToast(
      context,
      error ?? (slot.isActive ? 'Slot deactivated' : 'Slot activated'),
      isError: error != null,
    );
  }

  Future<void> _delete(EmployeeSlot slot) async {
    final ok = await confirmEmployeeAction(
      context,
      title: 'Delete the ${slot.timeLabel} slot?',
      message: 'This removes the time from the court for good.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;

    final error = await _controller.delete(slot);
    if (!mounted) return;

    showEmployeeToast(
      context,
      error ?? 'Slot deleted',
      isError: error != null,
    );
  }

  Future<void> _openForm(EmployeeSlot? slot) {
    return showEmployeeSheet<void>(
      context: context,
      title: slot == null ? 'Add slot' : 'Edit slot',
      subtitle: _controller.court?.displayName,
      builder: (context) => _SlotForm(slot: slot, controller: _controller),
    );
  }
}

class _SlotForm extends StatefulWidget {
  const _SlotForm({required this.slot, required this.controller});

  final EmployeeSlot? slot;
  final EmployeeSlotsController controller;

  @override
  State<_SlotForm> createState() => _SlotFormState();
}

class _SlotFormState extends State<_SlotForm> {
  late final TextEditingController _price = TextEditingController(
    text: widget.slot?.priceOverride?.toString() ?? '',
  );

  late String? _start = _trimSeconds(widget.slot?.startTime);
  late String? _end = _trimSeconds(widget.slot?.endTime);
  late String _type = widget.slot?.slotType ?? 'Regular';
  late String _status = employeeActiveStatuses.contains(widget.slot?.status)
      ? widget.slot!.status
      : employeeActiveStatuses.first;

  late final Set<String> _days = widget.slot == null
      ? Set.of(employeeWeekDays)
      : Set.of(widget.slot!.days);

  bool _saving = false;
  String? _error;

  static const List<String> _types = ['Regular', 'Peak'];

  /// The API stores `HH:mm:ss`; the picker works in `HH:mm`.
  static String? _trimSeconds(String? raw) {
    final text = raw?.trim();
    if (text == null || text.isEmpty) return null;
    final parts = text.split(':');
    if (parts.length < 2) return text;
    return '${parts[0]}:${parts[1]}';
  }

  @override
  void dispose() {
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if ((_start ?? '').isEmpty || (_end ?? '').isEmpty) {
      setState(() => _error = 'A start time and an end time are both required.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await widget.controller.save(
      id: widget.slot?.id,
      draft: EmployeeSlotDraft(
        startTime: _start!,
        endTime: _end!,
        slotType: _type,
        priceOverride: num.tryParse(_price.text.trim()),
        days: _days.toList(),
        status: _status,
      ),
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
    showEmployeeToast(
      context,
      widget.slot == null ? 'Slot created' : 'Slot updated',
    );
  }

  @override
  Widget build(BuildContext context) {
    final allDays = _days.length == employeeWeekDays.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmployeeFormError(message: _error),

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

        Container(
          padding: const EdgeInsets.all(EmployeeTokens.space3),
          margin: const EdgeInsets.only(bottom: EmployeeTokens.space4),
          decoration: BoxDecoration(
            color: EmployeeTokens.brandSoft,
            borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline_rounded,
                size: 15,
                color: EmployeeTokens.brand,
              ),
              SizedBox(width: EmployeeTokens.space2),
              Expanded(
                child: Text(
                  'Keep slots to one hour. Partner booking feeds read these '
                  'rows literally, so a three-hour row is published as one '
                  'unbookable block.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: EmployeeTokens.textBody,
                  ),
                ),
              ),
            ],
          ),
        ),

        EmployeeField(
          label: 'Slot type',
          child: EmployeeDropdown<String>(
            value: _type,
            items: _types,
            labelOf: (t) => t,
            onChanged: (value) => setState(() => _type = value ?? _type),
          ),
        ),

        EmployeeField(
          label: 'Price override',
          hint: "Leave blank to charge the court's own hourly rate.",
          child: EmployeeNumberField(
            controller: _price,
            isCurrency: true,
            hintText: "Court's rate",
          ),
        ),

        EmployeeField(
          label: 'Available days',
          hint: allDays
              ? 'Available every day.'
              : _days.isEmpty
                  ? 'No day picked — the slot will be available every day.'
                  : 'Available on ${employeeWeekDays.where(_days.contains).join(', ')}.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => setState(() {
                  if (allDays) {
                    _days.clear();
                  } else {
                    _days
                      ..clear()
                      ..addAll(employeeWeekDays);
                  }
                }),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: EmployeeTokens.space2,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        allDays
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 20,
                        color: allDays
                            ? EmployeeTokens.brand
                            : EmployeeTokens.textMuted,
                      ),
                      const SizedBox(width: EmployeeTokens.space2),
                      const Text(
                        'All days',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: EmployeeTokens.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: EmployeeTokens.space2),
              Wrap(
                spacing: EmployeeTokens.space2,
                runSpacing: EmployeeTokens.space2,
                children: [
                  for (final day in employeeWeekDays)
                    _dayChip(day, _days.contains(day)),
                ],
              ),
            ],
          ),
        ),

        EmployeeField(
          label: 'Status',
          child: EmployeeDropdown<String>(
            value: _status,
            items: employeeActiveStatuses,
            labelOf: (s) => s,
            onChanged: (value) => setState(() => _status = value ?? _status),
          ),
        ),

        EmployeeSheetActions(
          saving: _saving,
          saveLabel: widget.slot == null ? 'Create slot' : 'Update slot',
          onSave: _save,
        ),
      ],
    );
  }

  Widget _dayChip(String day, bool active) {
    return Material(
      color: active ? EmployeeTokens.brand : EmployeeTokens.surface,
      borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
      child: InkWell(
        onTap: () => setState(() {
          if (active) {
            _days.remove(day);
          } else {
            _days.add(day);
          }
        }),
        borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: EmployeeTokens.space3 + 2,
            vertical: EmployeeTokens.space2 + 2,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
            border: Border.all(
              color: active ? EmployeeTokens.brand : EmployeeTokens.border,
            ),
          ),
          child: Text(
            day,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : EmployeeTokens.textBody,
            ),
          ),
        ),
      ),
    );
  }
}
