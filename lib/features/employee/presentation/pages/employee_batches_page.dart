import 'package:flutter/material.dart';

import '../../data/repositories/employee_dashboard_repository_impl.dart';
import '../../domain/entities/employee_master.dart';
import '../state/employee_masters_controller.dart';
import '../theme/employee_theme.dart';
import '../widgets/employee_collection_scaffold.dart';
import '../widgets/employee_forms.dart';

/// Employee → Batch. Coaching batches, schedules and fees.
class EmployeeBatchesPage extends StatefulWidget {
  const EmployeeBatchesPage({super.key});

  @override
  State<EmployeeBatchesPage> createState() => _EmployeeBatchesPageState();
}

class _EmployeeBatchesPageState extends State<EmployeeBatchesPage> {
  late final EmployeeBatchesController _controller =
      EmployeeBatchesController(EmployeeDashboardRepositoryImpl());

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
      builder: (context, _) => EmployeeCollectionScaffold<EmployeeBatch>(
        title: 'Batches',
        controller: _controller,
        subtitle: () => '${_controller.items.length} batch'
            '${_controller.items.length == 1 ? '' : 'es'}',
        scopeNotice: 'Coaching batches at your own complex.',
        onAdd: _controller.canCreate ? () => _openForm(null) : null,
        addLabel: 'Add batch',
        emptyIcon: Icons.groups_outlined,
        emptyTitle:
            _controller.canCreate ? 'No batches yet' : 'Add a sport first',
        emptyMessage: _controller.canCreate
            ? 'Add a batch so students have something to enrol in.'
            : 'A batch belongs to a sport, and your complex has none yet. Add '
                'a sport on the Sports screen, then come back.',
        emptyActionLabel: 'Add a batch',
        itemBuilder: (context, batch) => _batchCard(batch),
      ),
    );
  }

  Widget _batchCard(EmployeeBatch batch) {
    return EmployeeCard(
      margin: const EdgeInsets.only(bottom: EmployeeTokens.space3),
      accentColor: EmployeeTokens.statusColor(batch.status),
      onTap: () => _openForm(batch),
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
                      batch.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: EmployeeTokens.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (batch.sportName.isNotEmpty) batch.sportName,
                        batch.coachName.isEmpty
                            ? 'Unassigned'
                            : batch.coachName,
                      ].join(' · '),
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
              Text(
                batch.feesLabel,
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
                Icons.schedule_rounded,
                size: 13,
                color: EmployeeTokens.textMuted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  batch.scheduleLabel,
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
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                size: 13,
                color: EmployeeTokens.textMuted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  batch.endDate == null
                      ? 'From ${batch.startLabel}'
                      : '${batch.startLabel} – ${batch.endLabel}',
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
          Row(
            children: [
              // The chips reflow inside the Expanded rather than pushing the
              // delete button off the card.
              Expanded(
                child: Wrap(
                  spacing: EmployeeTokens.space2,
                  runSpacing: EmployeeTokens.space2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    EmployeeChip(label: batch.status, dense: true),
                    EmployeeChip(
                      label: '${batch.occupancyLabel} students',
                      color: batch.isFull
                          ? EmployeeTokens.danger
                          : EmployeeTokens.info,
                      icon: Icons.groups_outlined,
                      dense: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: EmployeeTokens.space2),
              IconButton(
                onPressed: () => _delete(batch),
                icon: const Icon(Icons.delete_outline_rounded, size: 19),
                color: EmployeeTokens.danger,
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _delete(EmployeeBatch batch) async {
    final ok = await confirmEmployeeAction(
      context,
      title: 'Delete "${batch.displayName}"?',
      message: batch.isFull || (batch.currentStudents ?? 0) > 0
          ? '${batch.currentStudents} student(s) are enrolled. Deleting the '
              'batch may break their enrollment and fee records.'
          : 'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;

    final error = await _controller.delete(batch);
    if (!mounted) return;

    showEmployeeToast(
      context,
      error ?? 'Batch deleted',
      isError: error != null,
    );
  }

  Future<void> _openForm(EmployeeBatch? batch) {
    return showEmployeeSheet<void>(
      context: context,
      title: batch == null ? 'Add batch' : 'Edit batch',
      subtitle: batch?.displayName,
      builder: (context) => _BatchForm(batch: batch, controller: _controller),
    );
  }
}

class _BatchForm extends StatefulWidget {
  const _BatchForm({required this.batch, required this.controller});

  final EmployeeBatch? batch;
  final EmployeeBatchesController controller;

  @override
  State<_BatchForm> createState() => _BatchFormState();
}

class _BatchFormState extends State<_BatchForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.batch?.name ?? '');
  late final TextEditingController _schedule =
      TextEditingController(text: widget.batch?.schedule ?? '');
  late final TextEditingController _days =
      TextEditingController(text: widget.batch?.days ?? '');
  late final TextEditingController _maxStudents = TextEditingController(
    text: (widget.batch?.maxStudents ?? 20).toString(),
  );
  late final TextEditingController _fees = TextEditingController(
    text: widget.batch == null || widget.batch!.fees == 0
        ? ''
        : widget.batch!.fees.toString(),
  );

  late int? _sportId = widget.batch?.sportId;
  late int? _coachId = widget.batch?.coachId;
  late DateTime? _startDate = widget.batch?.startDate ?? DateTime.now();
  late DateTime? _endDate = widget.batch?.endDate;
  late String _status = employeeBatchStatuses.contains(widget.batch?.status)
      ? widget.batch!.status
      : employeeBatchStatuses.first;

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _schedule.dispose();
    _days.dispose();
    _maxStudents.dispose();
    _fees.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'A batch name is required.');
      return;
    }
    if (_sportId == null) {
      setState(() => _error = 'Pick the sport this batch teaches.');
      return;
    }
    if (_startDate == null) {
      setState(() => _error = 'A start date is required.');
      return;
    }
    if (_endDate != null && _endDate!.isBefore(_startDate!)) {
      setState(() => _error = 'The end date cannot be before the start date.');
      return;
    }

    final fees = num.tryParse(_fees.text.trim());
    if (fees == null || fees < 0) {
      setState(() => _error = 'Enter a valid fee amount.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await widget.controller.save(
      id: widget.batch?.id,
      name: _name.text,
      sportId: _sportId!,
      coachId: _coachId,
      schedule: _schedule.text,
      days: _days.text,
      startDate: _startDate!,
      endDate: _endDate,
      maxStudents: int.tryParse(_maxStudents.text.trim()),
      fees: fees,
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
      widget.batch == null ? 'Batch created' : 'Batch updated',
    );
  }

  @override
  Widget build(BuildContext context) {
    final sports = widget.controller.sports;
    final coaches = widget.controller.coaches;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmployeeFormError(message: _error),

        EmployeeField(
          label: 'Batch name',
          required: true,
          child: EmployeeTextField(
            controller: _name,
            hintText: 'e.g. Morning Batch',
          ),
        ),

        EmployeeField(
          label: 'Sport',
          required: true,
          child: EmployeeDropdown<int>(
            value: _sportId,
            items: sports.map((s) => s.id).toList(),
            labelOf: (id) => sports.firstWhere((s) => s.id == id).displayName,
            placeholder: 'Select a sport',
            onChanged: (value) => setState(() => _sportId = value),
          ),
        ),

        EmployeeField(
          label: 'Coach',
          hint: 'An unassigned batch is fine — assign one later.',
          child: EmployeeDropdown<int>(
            value: _coachId,
            items: coaches.map((c) => c.id).toList(),
            labelOf: (id) => coaches.firstWhere((c) => c.id == id).displayName,
            placeholder: coaches.isEmpty ? 'No coaches yet' : 'Unassigned',
            onChanged: (value) => setState(() => _coachId = value),
          ),
        ),

        Row(
          children: [
            Expanded(
              child: EmployeeField(
                label: 'Starts',
                required: true,
                child: EmployeeDateField(
                  value: _startDate,
                  clearable: false,
                  onChanged: (value) => setState(() => _startDate = value),
                ),
              ),
            ),
            const SizedBox(width: EmployeeTokens.space3),
            Expanded(
              child: EmployeeField(
                label: 'Ends',
                child: EmployeeDateField(
                  value: _endDate,
                  placeholder: 'Open-ended',
                  onChanged: (value) => setState(() => _endDate = value),
                ),
              ),
            ),
          ],
        ),

        EmployeeField(
          label: 'Schedule',
          child: EmployeeTextField(
            controller: _schedule,
            hintText: 'e.g. 6:00 AM - 7:30 AM',
          ),
        ),

        EmployeeField(
          label: 'Days',
          child: EmployeeTextField(
            controller: _days,
            textCapitalization: TextCapitalization.words,
            hintText: 'e.g. Mon,Wed,Fri',
          ),
        ),

        Row(
          children: [
            Expanded(
              child: EmployeeField(
                label: 'Max students',
                child: EmployeeNumberField(
                  controller: _maxStudents,
                  allowDecimal: false,
                  hintText: '20',
                ),
              ),
            ),
            const SizedBox(width: EmployeeTokens.space3),
            Expanded(
              child: EmployeeField(
                label: 'Fees',
                required: true,
                child: EmployeeNumberField(
                  controller: _fees,
                  isCurrency: true,
                  hintText: '0',
                ),
              ),
            ),
          ],
        ),

        EmployeeField(
          label: 'Status',
          child: EmployeeDropdown<String>(
            value: _status,
            items: employeeBatchStatuses,
            labelOf: (s) => s,
            onChanged: (value) => setState(() => _status = value ?? _status),
          ),
        ),

        EmployeeSheetActions(
          saving: _saving,
          saveLabel: widget.batch == null ? 'Create batch' : 'Update batch',
          onSave: _save,
        ),
      ],
    );
  }
}
