import 'package:flutter/material.dart';

import '../../data/repositories/employee_dashboard_repository_impl.dart';
import '../../domain/entities/employee_enquiry.dart';
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
                    if (enquiry.sportName.isNotEmpty) enquiry.sportName,
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
        EmployeeDetailRow(label: 'Sport', value: enquiry.sportName),
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
      ],
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
