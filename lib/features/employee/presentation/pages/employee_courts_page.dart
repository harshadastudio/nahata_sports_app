import 'package:flutter/material.dart';

import '../../data/repositories/employee_dashboard_repository_impl.dart';
import '../../domain/entities/employee_master.dart';
import '../state/employee_masters_controller.dart';
import '../theme/employee_theme.dart';
import '../widgets/employee_collection_scaffold.dart';
import '../widgets/employee_forms.dart';

/// Employee → Court. Courts and grounds, and what they cost.
class EmployeeCourtsPage extends StatefulWidget {
  const EmployeeCourtsPage({super.key});

  @override
  State<EmployeeCourtsPage> createState() => _EmployeeCourtsPageState();
}

class _EmployeeCourtsPageState extends State<EmployeeCourtsPage> {
  late final EmployeeCourtsController _controller =
      EmployeeCourtsController(EmployeeDashboardRepositoryImpl());

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
      builder: (context, _) => EmployeeCollectionScaffold<EmployeeCourt>(
        title: 'Courts',
        controller: _controller,
        subtitle: () => '${_controller.items.length} court'
            '${_controller.items.length == 1 ? '' : 's'}',
        scopeNotice: 'The courts and grounds at your own complex.',
        // A court belongs to a sport, so there is nothing to add until one
        // exists. Hiding the button beats a form that cannot be filled in.
        onAdd: _controller.canCreate ? () => _openForm(null) : null,
        addLabel: 'Add court',
        emptyIcon: Icons.place_outlined,
        emptyTitle: _controller.canCreate ? 'No courts yet' : 'Add a sport first',
        emptyMessage: _controller.canCreate
            ? 'Add your first court — slots and bookings both hang off one.'
            : 'A court belongs to a sport, and your complex has none yet. Add '
                'a sport on the Sports screen, then come back.',
        emptyActionLabel: 'Add a court',
        itemBuilder: (context, court) => _courtCard(court),
      ),
    );
  }

  Widget _courtCard(EmployeeCourt court) {
    return EmployeeCard(
      margin: const EdgeInsets.only(bottom: EmployeeTokens.space3),
      accentColor:
          court.isActive ? EmployeeTokens.success : EmployeeTokens.textMuted,
      onTap: () => _openForm(court),
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
                        court.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: EmployeeTokens.textDark,
                        ),
                      ),
                    ),
                    Text(
                      '${court.rateLabel}/hr',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: EmployeeTokens.textDark,
                      ),
                    ),
                  ],
                ),
                if (court.sportName.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    court.sportName,
                    style: const TextStyle(
                      fontSize: 12,
                      color: EmployeeTokens.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: EmployeeTokens.space3),
                Wrap(
                  spacing: EmployeeTokens.space2,
                  runSpacing: EmployeeTokens.space2,
                  children: [
                    EmployeeChip(label: court.status, dense: true),
                    if ((court.surfaceType ?? '').isNotEmpty)
                      EmployeeChip(
                        label: court.surfaceType!,
                        color: EmployeeTokens.info,
                        dense: true,
                      ),
                    if (court.capacity != null)
                      EmployeeChip(
                        label: 'Holds ${court.capacity}',
                        color: EmployeeTokens.purple,
                        icon: Icons.groups_outlined,
                        dense: true,
                      ),
                    if (court.lightingAvailable)
                      const EmployeeChip(
                        label: 'Floodlights',
                        color: EmployeeTokens.warning,
                        icon: Icons.lightbulb_outline_rounded,
                        dense: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _delete(court),
            icon: const Icon(Icons.delete_outline_rounded, size: 19),
            color: EmployeeTokens.danger,
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Future<void> _delete(EmployeeCourt court) async {
    final ok = await confirmEmployeeAction(
      context,
      title: 'Delete "${court.displayName}"?',
      message: 'Its slots go with it, and existing bookings may be affected. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;

    final error = await _controller.delete(court);
    if (!mounted) return;

    showEmployeeToast(
      context,
      error ?? 'Court deleted',
      isError: error != null,
    );
  }

  Future<void> _openForm(EmployeeCourt? court) {
    return showEmployeeSheet<void>(
      context: context,
      title: court == null ? 'Add court' : 'Edit court',
      subtitle: court?.displayName,
      builder: (context) => _CourtForm(court: court, controller: _controller),
    );
  }
}

class _CourtForm extends StatefulWidget {
  const _CourtForm({required this.court, required this.controller});

  final EmployeeCourt? court;
  final EmployeeCourtsController controller;

  @override
  State<_CourtForm> createState() => _CourtFormState();
}

class _CourtFormState extends State<_CourtForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.court?.name ?? '');
  late final TextEditingController _rate = TextEditingController(
    text: widget.court == null || widget.court!.hourlyRate == 0
        ? ''
        : widget.court!.hourlyRate.toString(),
  );
  late final TextEditingController _capacity = TextEditingController(
    text: widget.court?.capacity?.toString() ?? '',
  );
  late final TextEditingController _surface =
      TextEditingController(text: widget.court?.surfaceType ?? '');

  late int? _sportId = widget.court?.sportId;
  late bool _lighting = widget.court?.lightingAvailable ?? false;
  late String _status = employeeActiveStatuses.contains(widget.court?.status)
      ? widget.court!.status
      : employeeActiveStatuses.first;

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _rate.dispose();
    _capacity.dispose();
    _surface.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'A court name is required.');
      return;
    }
    if (_sportId == null) {
      setState(() => _error = 'Pick the sport this court is for.');
      return;
    }

    final rate = num.tryParse(_rate.text.trim());
    if (rate == null || rate < 0) {
      setState(() => _error = 'Enter a valid hourly rate.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await widget.controller.save(
      id: widget.court?.id,
      name: _name.text,
      sportId: _sportId!,
      capacity: int.tryParse(_capacity.text.trim()),
      surfaceType: _surface.text,
      lightingAvailable: _lighting,
      hourlyRate: rate,
      status: _status,
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
      widget.court == null ? 'Court created' : 'Court updated',
    );
  }

  @override
  Widget build(BuildContext context) {
    final sports = widget.controller.sports;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmployeeFormError(message: _error),

        EmployeeField(
          label: 'Court name',
          required: true,
          child: EmployeeTextField(
            controller: _name,
            hintText: 'e.g. Badminton Court 1',
          ),
        ),

        EmployeeField(
          label: 'Sport',
          required: true,
          child: EmployeeDropdown<int>(
            value: _sportId,
            items: sports.map((s) => s.id).toList(),
            labelOf: (id) => sports.firstWhere((s) => s.id == id).displayName,
            subtitleOf: (id) => sports.firstWhere((s) => s.id == id).category,
            placeholder: 'Select a sport',
            onChanged: (value) => setState(() => _sportId = value),
          ),
        ),

        Row(
          children: [
            Expanded(
              child: EmployeeField(
                label: 'Hourly rate',
                required: true,
                child: EmployeeNumberField(
                  controller: _rate,
                  isCurrency: true,
                  hintText: '0',
                ),
              ),
            ),
            const SizedBox(width: EmployeeTokens.space3),
            Expanded(
              child: EmployeeField(
                label: 'Capacity',
                child: EmployeeNumberField(
                  controller: _capacity,
                  allowDecimal: false,
                  hintText: 'Any',
                ),
              ),
            ),
          ],
        ),

        EmployeeField(
          label: 'Surface type',
          child: EmployeeTextField(
            controller: _surface,
            hintText: 'e.g. Synthetic, Wooden, Turf',
          ),
        ),

        EmployeeSwitchField(
          label: 'Floodlights available',
          subtitle: 'Whether the court can be played on after dark',
          value: _lighting,
          onChanged: (value) => setState(() => _lighting = value),
        ),

        EmployeeField(
          label: 'Status',
          hint: 'An inactive court stops taking new bookings.',
          child: EmployeeDropdown<String>(
            value: _status,
            items: employeeActiveStatuses,
            labelOf: (s) => s,
            onChanged: (value) => setState(() => _status = value ?? _status),
          ),
        ),

        EmployeeSheetActions(
          saving: _saving,
          saveLabel: widget.court == null ? 'Create court' : 'Update court',
          onSave: _save,
        ),
      ],
    );
  }
}
