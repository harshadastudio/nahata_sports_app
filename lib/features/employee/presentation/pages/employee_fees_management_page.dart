import 'package:flutter/material.dart';

import '../../data/repositories/employee_dashboard_repository_impl.dart';
import '../../domain/entities/employee_fee.dart';
import '../../domain/entities/employee_master.dart';
import '../state/employee_fees_controller.dart';
import '../theme/employee_theme.dart';
import '../widgets/employee_forms.dart';
import '../widgets/employee_list_scaffold.dart';

/// Fees Management — creating and correcting the records themselves.
///
/// Approving a payment lives on the separate Fees Approval screen, gated on its
/// own permission, so an admin can grant one without the other.
class EmployeeFeesManagementPage extends StatefulWidget {
  const EmployeeFeesManagementPage({super.key});

  @override
  State<EmployeeFeesManagementPage> createState() =>
      _EmployeeFeesManagementPageState();
}

class _EmployeeFeesManagementPageState
    extends State<EmployeeFeesManagementPage> {
  late final EmployeeFeesManagementController _controller =
      EmployeeFeesManagementController(EmployeeDashboardRepositoryImpl());
  final TextEditingController _search = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.load();
  }

  @override
  void dispose() {
    _search.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Wrapped so both the empty-state copy and the add button's enabled state
    // track the controller.
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => EmployeeListScaffold<EmployeeFee>(
        title: 'Fees management',
        controller: _controller,
        subtitle: () => '${_controller.total} record'
            '${_controller.total == 1 ? '' : 's'}',
        scopeNotice: 'Fee records for batches at your own complex.',
        floatingActionButton: FloatingActionButton.extended(
          // The create form needs both pickers; without them it would offer
          // empty dropdowns and refuse to save.
          onPressed: _controller.canCreate ? () => _openForm(null) : null,
          backgroundColor: _controller.canCreate
              ? EmployeeTokens.brand
              : EmployeeTokens.textMuted,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add record'),
        ),
        filters: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EmployeeSearchBar(
              controller: _search,
              hintText: 'Search by student name',
              onChanged: _controller.onSearchChanged,
              onClear: () => _controller.onSearchChanged(''),
            ),
            const SizedBox(height: EmployeeTokens.space3),
            EmployeeFilterChips<String>(
              values: EmployeeFeesManagementController.paymentStatuses,
              selected: _controller.paymentStatus,
              labelOf: (s) => s,
              allLabel: 'All payments',
              onChanged: _controller.setPaymentStatus,
            ),
          ],
        ),
        itemBuilder: (context, fee) => _feeCard(fee),
        emptyIcon: Icons.account_balance_wallet_outlined,
        emptyTitle: 'No fee records',
        emptyMessage: _controller.isFiltered
            ? 'Nothing matches these filters.'
            : 'Add a record when a student enrolls and pays.',
      ),
    );
  }

  Widget _feeCard(EmployeeFee fee) {
    return EmployeeCard(
      margin: const EdgeInsets.only(bottom: EmployeeTokens.space3),
      accentColor: EmployeeTokens.statusColor(fee.paymentStatus),
      onTap: () => _openForm(fee),
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
                      fee.displayName,
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
                      [
                        fee.displayBatch,
                        if (fee.sportName.isNotEmpty) fee.sportName,
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
                fee.amountLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: EmployeeTokens.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: EmployeeTokens.space3),
          Row(
            children: [
              // Reflows inside the Expanded rather than pushing the delete
              // button off the card.
              Expanded(
                child: Wrap(
                  spacing: EmployeeTokens.space2,
                  runSpacing: EmployeeTokens.space2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    EmployeeChip(label: fee.paymentStatus, dense: true),
                    EmployeeChip(
                      label: 'Approval: ${fee.approvalStatus}',
                      color: EmployeeTokens.statusColor(fee.approvalStatus),
                      dense: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: EmployeeTokens.space2),
              IconButton(
                onPressed: () => _delete(fee),
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

  Future<void> _delete(EmployeeFee fee) async {
    final ok = await confirmEmployeeAction(
      context,
      title: 'Delete this fee record?',
      message: 'The record for ${fee.displayName} in ${fee.displayBatch} will '
          'be removed. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;

    final error = await _controller.delete(fee);
    if (!mounted) return;

    showEmployeeToast(
      context,
      error ?? 'Fee record deleted',
      isError: error != null,
    );
  }

  Future<void> _openForm(EmployeeFee? fee) {
    return showEmployeeSheet<void>(
      context: context,
      title: fee == null ? 'Add fee record' : 'Update fee payment',
      subtitle: fee == null ? null : fee.displayName,
      builder: (context) => _FeeForm(fee: fee, controller: _controller),
    );
  }
}

class _FeeForm extends StatefulWidget {
  const _FeeForm({required this.fee, required this.controller});

  /// Null for a create.
  final EmployeeFee? fee;

  final EmployeeFeesManagementController controller;

  @override
  State<_FeeForm> createState() => _FeeFormState();
}

class _FeeFormState extends State<_FeeForm> {
  late final TextEditingController _amount = TextEditingController(
    text: widget.fee == null || widget.fee!.amountPaid == 0
        ? ''
        : widget.fee!.amountPaid.toString(),
  );
  late final TextEditingController _notes =
      TextEditingController(text: widget.fee?.notes ?? '');

  late int? _studentId = widget.fee?.studentId;
  late int? _batchId = widget.fee?.batchId;
  late DateTime? _enrolledOn = widget.fee?.enrollmentDate ?? DateTime.now();
  late String _paymentStatus = _valueIn(
    widget.fee?.paymentStatus ?? 'Pending',
    EmployeeFeesManagementController.paymentStatuses,
  );

  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.fee != null;

  static String _valueIn(String value, List<String> options) =>
      options.contains(value) ? value : options.first;

  @override
  void dispose() {
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_isEdit && (_studentId == null || _batchId == null)) {
      setState(() => _error = 'Select both a student and a batch.');
      return;
    }

    final amount = num.tryParse(_amount.text.trim());
    if (amount == null || amount < 0) {
      setState(() => _error = 'Enter a valid amount.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final draft = EmployeeFeeDraft(
      studentId: _studentId,
      batchId: _batchId,
      amountPaid: amount,
      paymentStatus: _paymentStatus,
      enrollmentDate: _enrolledOn,
      notes: _notes.text,
    );

    final error = _isEdit
        ? await widget.controller.update(widget.fee!.id, draft)
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
    showEmployeeToast(
      context,
      _isEdit ? 'Fee record updated' : 'Fee record created',
    );
  }

  @override
  Widget build(BuildContext context) {
    final students = widget.controller.students;
    final batches = widget.controller.batches;

    EmployeeBatch? selectedBatch;
    for (final batch in batches) {
      if (batch.id != _batchId) continue;
      selectedBatch = batch;
      break;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmployeeFormError(message: _error),

        if (_isEdit)
          // Student and batch are what make the record; `PUT /fees/{id}` does
          // not accept them, so they are shown rather than offered.
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: EmployeeTokens.space4),
            padding: const EdgeInsets.all(EmployeeTokens.space3),
            decoration: BoxDecoration(
              color: EmployeeTokens.canvas,
              borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.fee!.displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: EmployeeTokens.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.fee!.displayBatch}'
                  '${widget.fee!.batchFeesLabel == null ? '' : ' · Batch fee ${widget.fee!.batchFeesLabel}'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: EmployeeTokens.textMuted,
                  ),
                ),
              ],
            ),
          )
        else ...[
          EmployeeField(
            label: 'Student',
            required: true,
            child: EmployeeDropdown<int>(
              value: _studentId,
              items: students.map((s) => s.id).toList(),
              labelOf: (id) =>
                  students.firstWhere((s) => s.id == id).displayName,
              subtitleOf: (id) =>
                  students.firstWhere((s) => s.id == id).detail,
              placeholder: 'Select a student',
              onChanged: (value) => setState(() => _studentId = value),
            ),
          ),
          EmployeeField(
            label: 'Batch',
            required: true,
            hint: selectedBatch == null
                ? null
                : 'Batch fee: ${selectedBatch.feesLabel}',
            child: EmployeeDropdown<int>(
              value: _batchId,
              items: batches.map((b) => b.id).toList(),
              labelOf: (id) => batches.firstWhere((b) => b.id == id).displayName,
              subtitleOf: (id) => batches.firstWhere((b) => b.id == id).feesLabel,
              placeholder: 'Select a batch',
              onChanged: (value) => setState(() => _batchId = value),
            ),
          ),
          EmployeeField(
            label: 'Enrollment date',
            child: EmployeeDateField(
              value: _enrolledOn,
              clearable: false,
              onChanged: (value) => setState(() => _enrolledOn = value),
            ),
          ),
        ],

        EmployeeField(
          label: 'Amount paid',
          required: true,
          child: EmployeeNumberField(
            controller: _amount,
            isCurrency: true,
            hintText: '0',
          ),
        ),

        EmployeeField(
          label: 'Payment status',
          child: EmployeeDropdown<String>(
            value: _paymentStatus,
            items: EmployeeFeesManagementController.paymentStatuses,
            labelOf: (s) => s,
            onChanged: (value) =>
                setState(() => _paymentStatus = value ?? _paymentStatus),
          ),
        ),

        EmployeeField(
          label: 'Notes',
          child: EmployeeTextField(
            controller: _notes,
            maxLines: 3,
            hintText: 'How it was collected, anything unusual',
          ),
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
                  'Recording a payment here does not issue the gate pass — '
                  'that happens when it is approved on the Fees Approval '
                  'screen.',
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

        EmployeeSheetActions(
          saving: _saving,
          saveLabel: _isEdit ? 'Update record' : 'Create record',
          onSave: _save,
        ),
      ],
    );
  }
}
