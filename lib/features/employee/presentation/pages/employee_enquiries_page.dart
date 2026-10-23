import 'package:flutter/material.dart';

import '../../data/repositories/employee_dashboard_repository_impl.dart';
import '../../domain/entities/employee_coach.dart';
import '../../domain/entities/employee_enquiry.dart';
import '../../domain/entities/employee_formats.dart';
import '../../domain/entities/employee_master.dart';
import '../state/employee_enquiries_controller.dart';
import '../theme/employee_theme.dart';
import '../widgets/employee_forms.dart';
import '../widgets/employee_list_scaffold.dart';

/// Coaching Enquiries — review, then approve and enroll.
class EmployeeEnquiriesPage extends StatefulWidget {
  const EmployeeEnquiriesPage({super.key});

  @override
  State<EmployeeEnquiriesPage> createState() => _EmployeeEnquiriesPageState();
}

class _EmployeeEnquiriesPageState extends State<EmployeeEnquiriesPage> {
  late final EmployeeEnquiriesController _controller =
      EmployeeEnquiriesController(EmployeeDashboardRepositoryImpl());
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
    // Wrapped so the empty-state copy tracks the filters.
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => EmployeeListScaffold<EmployeeEnquiry>(
        title: 'Coaching enquiries',
        controller: _controller,
        subtitle: () => '${_controller.total} enquir'
            '${_controller.total == 1 ? 'y' : 'ies'}',
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _controller.canCreate ? _openCreate : null,
          backgroundColor: _controller.canCreate
              ? EmployeeTokens.brand
              : EmployeeTokens.textMuted,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add enquiry'),
        ),
        filters: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EmployeeSearchBar(
              controller: _search,
              hintText: 'Search by name, email or phone',
              onChanged: _controller.onSearchChanged,
              onClear: () => _controller.onSearchChanged(''),
            ),
            const SizedBox(height: EmployeeTokens.space3),
            _dateFilter(),
            const SizedBox(height: EmployeeTokens.space3),
            EmployeeFilterChips<String>(
              values: EmployeeEnquiriesController.statuses,
              selected: _controller.status,
              labelOf: (s) => s,
              onChanged: _controller.setStatus,
            ),
          ],
        ),
        itemBuilder: (context, enquiry) => _enquiryCard(enquiry),
        emptyIcon: Icons.forum_outlined,
        emptyTitle: 'No enquiries found',
        emptyMessage: _controller.isFiltered
            ? 'Nothing matches these filters.'
            : 'Enquiries submitted for your complex will show up here.',
      ),
    );
  }

  Widget _enquiryCard(EmployeeEnquiry enquiry) {
    return EmployeeCard(
      margin: const EdgeInsets.only(bottom: EmployeeTokens.space3),
      accentColor: EmployeeTokens.statusColor(enquiry.status),
      onTap: () => _openDetail(enquiry),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EmployeeAvatar(initial: enquiry.initial, radius: 19),
              const SizedBox(width: EmployeeTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      enquiry.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: EmployeeTokens.textDark,
                      ),
                    ),
                    if (enquiry.phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        enquiry.phone,
                        style: const TextStyle(
                          fontSize: 12,
                          color: EmployeeTokens.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: EmployeeTokens.space2),
              EmployeeChip(label: enquiry.status, dense: true),
            ],
          ),
          const SizedBox(height: EmployeeTokens.space3),
          Row(
            children: [
              const Icon(
                Icons.groups_outlined,
                size: 13,
                color: EmployeeTokens.textMuted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  [
                    if (enquiry.batchName.isNotEmpty) enquiry.batchName,
                    if (enquiry.sportLabel.isNotEmpty) enquiry.sportLabel,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: EmployeeTokens.textBody,
                  ),
                ),
              ),
              if (enquiry.capacityLabel != null)
                Text(
                  enquiry.capacityLabel!,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: enquiry.isBatchFull
                        ? EmployeeTokens.danger
                        : EmployeeTokens.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: EmployeeTokens.space2),
          Text(
            enquiry.submittedLabel,
            style: const TextStyle(
              fontSize: 11,
              color: EmployeeTokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  /// The received-between window.
  ///
  /// Rendered as one tappable row rather than two date fields: the filter bar
  /// is already three rows deep, and a range is read as a single fact.
  Widget _dateFilter() {
    final from = _controller.from;
    final to = _controller.to;
    final active = from != null || to != null;

    return InkWell(
      onTap: _pickDateRange,
      borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          horizontal: EmployeeTokens.space3,
          vertical: EmployeeTokens.space3,
        ),
        decoration: BoxDecoration(
          color: EmployeeTokens.surface,
          borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
          border: Border.all(
            color: active ? EmployeeTokens.brand : EmployeeTokens.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.date_range_rounded,
              size: 17,
              color: active ? EmployeeTokens.brand : EmployeeTokens.textMuted,
            ),
            const SizedBox(width: EmployeeTokens.space2),
            Expanded(
              child: Text(
                active
                    ? '${from == null ? 'Any' : formatDay(from)} → '
                        '${to == null ? 'Any' : formatDay(to)}'
                    : 'Received between…',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  color: active
                      ? EmployeeTokens.textDark
                      : EmployeeTokens.textMuted,
                ),
              ),
            ),
            if (active)
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 17),
                color: EmployeeTokens.textMuted,
                onPressed: () => _controller.setDateRange(null, null),
                tooltip: 'Clear dates',
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final from = _controller.from;
    final to = _controller.to;

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: from != null && to != null
          ? DateTimeRange(start: from, end: to)
          : null,
    );
    if (picked == null || !mounted) return;

    _controller.setDateRange(picked.start, picked.end);
  }

  Future<void> _openCreate() async {
    final draft = await showEmployeeSheet<EmployeeEnquiryDraft>(
      context: context,
      title: 'Add enquiry',
      builder: (context) => _EnquiryForm(
        controller: _controller,
        enquiry: null,
      ),
    );
    if (draft == null || !mounted) return;

    final outcome = await _controller.create(draft);
    if (!mounted) return;

    showEmployeeToast(
      context,
      outcome.error ?? outcome.result?.message ?? 'Enquiry added',
      isError: outcome.error != null,
    );
  }

  Future<void> _openDetail(EmployeeEnquiry enquiry) {
    return showEmployeeSheet<void>(
      context: context,
      title: 'Enquiry #${enquiry.id}',
      subtitle: enquiry.displayName,
      builder: (context) => _EnquiryDetail(
        enquiry: enquiry,
        controller: _controller,
      ),
    );
  }
}

class _EnquiryDetail extends StatefulWidget {
  const _EnquiryDetail({required this.enquiry, required this.controller});

  final EmployeeEnquiry enquiry;
  final EmployeeEnquiriesController controller;

  @override
  State<_EnquiryDetail> createState() => _EnquiryDetailState();
}

class _EnquiryDetailState extends State<_EnquiryDetail> {
  late EmployeeEnquiry _enquiry = widget.enquiry;
  bool _busy = false;

  Future<void> _approve() async {
    final ok = await confirmEmployeeAction(
      context,
      title: 'Approve and enroll?',
      message: 'This enrolls ${_enquiry.displayName} in '
          '"${_enquiry.batchName}" and opens their fee record as Pending. '
          'That fee still needs approving before their gate pass unlocks.',
      confirmLabel: 'Approve & enroll',
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    final error = await widget.controller.approve(_enquiry);
    if (!mounted) return;

    setState(() {
      _busy = false;
      if (error == null) _enquiry = _enquiry.copyWith(status: 'Approved');
    });

    showEmployeeToast(
      context,
      error ?? 'Approved — ${_enquiry.displayName} is enrolled',
      isError: error != null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final enquiry = _enquiry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmployeeChip(label: enquiry.status),
        const SizedBox(height: EmployeeTokens.space5),

        _section('Student'),
        EmployeeDetailRow(label: 'Name', value: enquiry.displayName),
        EmployeeDetailRow(label: 'Email', value: enquiry.email),
        EmployeeDetailRow(label: 'Phone', value: enquiry.phone),

        const SizedBox(height: EmployeeTokens.space4),
        _section('Enquiry'),
        EmployeeDetailRow(label: 'Batch', value: enquiry.batchName),
        EmployeeDetailRow(label: 'Sport', value: enquiry.sportLabel),
        EmployeeDetailRow(label: 'Coach', value: enquiry.coachName),
        if (enquiry.feesLabel != null)
          EmployeeDetailRow(label: 'Batch fee', value: enquiry.feesLabel!),
        if (enquiry.capacityLabel != null)
          EmployeeDetailRow(
            label: 'Capacity',
            value: enquiry.capacityLabel!,
            valueColor:
                enquiry.isBatchFull ? EmployeeTokens.danger : null,
          ),
        if ((enquiry.referenceNumber ?? '').isNotEmpty)
          EmployeeDetailRow(
            label: 'Reference',
            value: enquiry.referenceNumber!,
            monospace: true,
          ),
        EmployeeDetailRow(label: 'Submitted', value: enquiry.submittedLabel),

        // What the student is *actually* enrolled in, which is not the same as
        // what the enquiry asked for: an All Sports enquiry can be approved by
        // several coaches, each into their own batch.
        if (enquiry.enrolments.isNotEmpty) ...[
          const SizedBox(height: EmployeeTokens.space4),
          _section('Enrolled in'),
          ...enquiry.enrolments.map(_enrolmentRow),
        ],

        if ((enquiry.message ?? '').isNotEmpty) ...[
          const SizedBox(height: EmployeeTokens.space4),
          _section('Message'),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(EmployeeTokens.space3),
            decoration: BoxDecoration(
              color: EmployeeTokens.canvas,
              borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
            ),
            child: Text(
              enquiry.message!,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: EmployeeTokens.textBody,
              ),
            ),
          ),
        ],

        const SizedBox(height: EmployeeTokens.space5),

        if (!enquiry.isActionable)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(EmployeeTokens.space3),
            decoration: BoxDecoration(
              color: EmployeeTokens.canvas,
              borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  enquiry.isApproved
                      ? Icons.check_circle_outline_rounded
                      : Icons.block_rounded,
                  size: 16,
                  color: EmployeeTokens.statusColor(enquiry.status),
                ),
                const SizedBox(width: EmployeeTokens.space2),
                Expanded(
                  child: Text(
                    enquiry.isApproved
                        ? 'Already approved — the student is enrolled. Their '
                            'fee is on the Fees Approval screen.'
                        : 'This enquiry was rejected and cannot be approved.',
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: EmployeeTokens.textBody,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          FilledButton.icon(
            // A full batch is refused by the API with a 400, so the button is
            // disabled rather than left to fail.
            onPressed: _busy || enquiry.isBatchFull ? null : _approve,
            icon: _busy
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.how_to_reg_rounded, size: 18),
            label: Text(
              enquiry.isBatchFull ? 'Batch is full' : 'Approve & enroll',
            ),
            style: FilledButton.styleFrom(
              backgroundColor: EmployeeTokens.success,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
              ),
            ),
          ),
          const SizedBox(height: EmployeeTokens.space3),
          const Text(
            'Enrolling starts the student\'s fee record as Pending. It needs '
            'approving on the Fees Approval screen before their gate pass QR '
            'unlocks.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: EmployeeTokens.textMuted,
            ),
          ),
        ],

        const SizedBox(height: EmployeeTokens.space5),
        _section('Move along the queue'),
        Wrap(
          spacing: EmployeeTokens.space2,
          runSpacing: EmployeeTokens.space2,
          children: [
            for (final status in EmployeeEnquiry.settableStatuses)
              _statusButton(status),
          ],
        ),
        const SizedBox(height: EmployeeTokens.space2),
        const Text(
          'Approved is not on this list — it is set by Approve & enroll, '
          'which also creates the student and their fee record.',
          style: TextStyle(
            fontSize: 11.5,
            height: 1.45,
            color: EmployeeTokens.textMuted,
          ),
        ),

        const SizedBox(height: EmployeeTokens.space4),
        Row(
          children: [
            // The API refuses an edit once the enquiry is Approved, so the
            // button is hidden rather than left to fail with a 400.
            if (enquiry.isEditable)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _edit,
                  icon: const Icon(Icons.edit_outlined, size: 17),
                  label: const Text('Edit'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: EmployeeTokens.brand,
                    minimumSize: const Size(0, 46),
                    side: const BorderSide(color: EmployeeTokens.border),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(EmployeeTokens.radiusSm),
                    ),
                  ),
                ),
              ),
            if (enquiry.isEditable)
              const SizedBox(width: EmployeeTokens.space3),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _delete,
                icon: const Icon(Icons.delete_outline_rounded, size: 17),
                label: const Text('Delete'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: EmployeeTokens.danger,
                  minimumSize: const Size(0, 46),
                  side: const BorderSide(color: EmployeeTokens.border),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(EmployeeTokens.radiusSm),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _statusButton(String status) {
    final selected = _enquiry.status.toLowerCase() == status.toLowerCase();
    final tone = EmployeeTokens.statusColor(status);

    return ChoiceChip(
      label: Text(status),
      selected: selected,
      onSelected: _busy || selected ? null : (_) => _setStatus(status),
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : tone,
      ),
      selectedColor: tone,
      backgroundColor: EmployeeTokens.surface,
      side: BorderSide(color: selected ? tone : EmployeeTokens.border),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(EmployeeTokens.radiusPill),
      ),
    );
  }

  Future<void> _setStatus(String status) async {
    setState(() => _busy = true);
    final error = await widget.controller.setEnquiryStatus(_enquiry, status);
    if (!mounted) return;

    setState(() {
      _busy = false;
      if (error == null) _enquiry = _enquiry.copyWith(status: status);
    });

    showEmployeeToast(
      context,
      error ?? 'Marked $status',
      isError: error != null,
    );
  }

  Future<void> _edit() async {
    final draft = await showEmployeeSheet<EmployeeEnquiryDraft>(
      context: context,
      title: 'Edit enquiry',
      subtitle: _enquiry.displayName,
      builder: (context) => _EnquiryForm(
        controller: widget.controller,
        enquiry: _enquiry,
      ),
    );
    if (draft == null || !mounted) return;

    setState(() => _busy = true);
    final error = await widget.controller.update(_enquiry, draft);
    if (!mounted) return;

    setState(() => _busy = false);

    // The list has re-read, so the row behind this sheet is now the fresh one.
    // The sheet is closed rather than patched: the server re-derives the sport
    // and coach from the batch, and this side cannot recompute those names.
    if (error == null) Navigator.of(context).pop();
    showEmployeeToast(
      context,
      error ?? 'Enquiry updated',
      isError: error != null,
    );
  }

  Future<void> _delete() async {
    final ok = await confirmEmployeeAction(
      context,
      title: 'Delete this enquiry?',
      message: 'It is removed from the queue. Any student already enrolled '
          'from it stays enrolled.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    final error = await widget.controller.delete(_enquiry);
    if (!mounted) return;

    setState(() => _busy = false);

    if (error == null) Navigator.of(context).pop();
    showEmployeeToast(
      context,
      error ?? 'Enquiry deleted',
      isError: error != null,
    );
  }

  Widget _enrolmentRow(EmployeeEnquiryEnrolment enrolment) {
    final detail = enrolment.detailLabel;

    return Container(
      margin: const EdgeInsets.only(bottom: EmployeeTokens.space2),
      padding: const EdgeInsets.all(EmployeeTokens.space3),
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
                  enrolment.displayBatch,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: EmployeeTokens.textDark,
                  ),
                ),
                if (detail.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: EmployeeTokens.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (enrolment.status.trim().isNotEmpty) ...[
            const SizedBox(width: EmployeeTokens.space2),
            EmployeeChip(label: enrolment.status),
          ],
        ],
      ),
    );
  }

  Widget _section(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: EmployeeTokens.space2),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          letterSpacing: 0.9,
          fontWeight: FontWeight.w700,
          color: EmployeeTokens.textMuted,
        ),
      ),
    );
  }
}

/// The walk-in enquiry form, behind `POST /coaching-enquiries/admin/create`
/// and `PUT /coaching-enquiries/admin/{id}`.
///
/// The batch is the field that matters: the server derives the sport, the coach
/// and the complex from it, so the two dropdowns above it are conveniences that
/// keep the stored row and the form in step. Marking the enquiry **All sports**
/// removes all three — the prospect has not chosen yet, and the enquiry then
/// reaches every sports coach in the complex.
class _EnquiryForm extends StatefulWidget {
  const _EnquiryForm({required this.controller, required this.enquiry});

  final EmployeeEnquiriesController controller;

  /// Null when adding.
  final EmployeeEnquiry? enquiry;

  @override
  State<_EnquiryForm> createState() => _EnquiryFormState();
}

class _EnquiryFormState extends State<_EnquiryForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.enquiry?.name ?? '');
  late final TextEditingController _email =
      TextEditingController(text: widget.enquiry?.email ?? '');
  late final TextEditingController _phone =
      TextEditingController(text: widget.enquiry?.phone ?? '');
  late final TextEditingController _message =
      TextEditingController(text: widget.enquiry?.message ?? '');

  late int? _sportId = widget.enquiry?.sportId;
  late int? _batchId = widget.enquiry?.batchId;
  late int? _coachId = widget.enquiry?.coachId;
  late bool _isAllSports = widget.enquiry?.isAllSports ?? false;

  String? _error;

  bool get _isEdit => widget.enquiry != null;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _message.dispose();
    super.dispose();
  }

  /// The batches for the chosen sport, or all of them when no sport is picked.
  ///
  /// Filtered here rather than re-queried: `GET /batches?limit=200` already
  /// returns the whole complex, so narrowing is a local operation.
  List<EmployeeBatch> get _visibleBatches {
    final all = widget.controller.batches;
    final sportId = _sportId;
    if (sportId == null) return all;
    return all
        .where((batch) => batch.sportId == null || batch.sportId == sportId)
        .toList(growable: false);
  }

  void _save() {
    final draft = EmployeeEnquiryDraft(
      name: _name.text,
      email: _email.text,
      phone: _phone.text,
      sportId: _sportId,
      batchId: _batchId,
      coachId: _coachId,
      message: _message.text,
      isAllSports: _isAllSports,
    );

    final invalid = draft.validationError;
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }

    Navigator.of(context).pop(draft);
  }

  @override
  Widget build(BuildContext context) {
    final sports = widget.controller.sports;
    final coaches = widget.controller.coaches;
    final batches = _visibleBatches;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmployeeFormError(message: _error),

        EmployeeField(
          label: 'Name',
          required: true,
          child: EmployeeTextField(
            controller: _name,
            hintText: "The prospect's name",
          ),
        ),

        EmployeeField(
          label: 'Email',
          required: true,
          child: EmployeeTextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
            hintText: 'name@example.com',
          ),
        ),

        EmployeeField(
          label: 'Phone',
          required: true,
          child: EmployeeTextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            hintText: '10-digit mobile number',
          ),
        ),

        EmployeeSwitchField(
          label: 'All sports',
          subtitle: 'They have not chosen a sport yet — this reaches every '
              'sports coach at the complex.',
          value: _isAllSports,
          onChanged: (value) => setState(() {
            _isAllSports = value;
            // An All Sports enquiry must carry no sport, batch or coach; the
            // API contradicts itself otherwise.
            if (value) {
              _sportId = null;
              _batchId = null;
              _coachId = null;
            }
          }),
        ),

        if (!_isAllSports) ...[
          EmployeeField(
            label: 'Sport',
            hint: 'Optional — it is derived from the batch when left blank.',
            child: EmployeeDropdown<int>(
              value: _sportId,
              items: sports.map((sport) => sport.id).toList(growable: false),
              labelOf: (id) => sports
                  .firstWhere(
                    (sport) => sport.id == id,
                    orElse: () => const EmployeeSport(id: 0),
                  )
                  .displayName,
              onChanged: (value) => setState(() {
                _sportId = value;
                // The batch that was chosen may belong to another sport now.
                if (_batchId != null &&
                    !_visibleBatches.any((b) => b.id == _batchId)) {
                  _batchId = null;
                }
              }),
            ),
          ),

          EmployeeField(
            label: 'Batch',
            required: true,
            child: EmployeeDropdown<int>(
              value: _batchId,
              items: batches.map((batch) => batch.id).toList(growable: false),
              labelOf: (id) => batches
                  .firstWhere(
                    (batch) => batch.id == id,
                    orElse: () => const EmployeeBatch(id: 0),
                  )
                  .displayName,
              subtitleOf: (id) => batches
                  .firstWhere(
                    (batch) => batch.id == id,
                    orElse: () => const EmployeeBatch(id: 0),
                  )
                  .feesLabel,
              onChanged: (value) => setState(() => _batchId = value),
            ),
          ),

          EmployeeField(
            label: 'Coach',
            hint: 'Optional — also derived from the batch.',
            child: EmployeeDropdown<int>(
              value: _coachId,
              items: coaches.map((coach) => coach.id).toList(growable: false),
              labelOf: (id) => coaches
                  .firstWhere(
                    (coach) => coach.id == id,
                    orElse: () => const EmployeeCoach(id: 0),
                  )
                  .displayName,
              onChanged: (value) => setState(() => _coachId = value),
            ),
          ),
        ],

        EmployeeField(
          label: 'Message',
          child: EmployeeTextField(
            controller: _message,
            maxLines: 3,
            hintText: 'e.g. Walk-in enquiry',
          ),
        ),

        EmployeeSheetActions(
          saveLabel: _isEdit ? 'Save enquiry' : 'Add enquiry',
          onSave: _save,
        ),
      ],
    );
  }
}
