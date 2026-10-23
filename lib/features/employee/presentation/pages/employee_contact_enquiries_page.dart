import 'package:flutter/material.dart';

import '../../data/repositories/employee_dashboard_repository_impl.dart';
import '../../domain/entities/employee_contact_enquiry.dart';
import '../state/employee_contact_enquiries_controller.dart';
import '../theme/employee_theme.dart';
import '../widgets/employee_forms.dart';
import '../widgets/employee_list_scaffold.dart';

/// Employee → Contact Enquiries. The "Contact Us" queue from the public site.
class EmployeeContactEnquiriesPage extends StatefulWidget {
  const EmployeeContactEnquiriesPage({super.key});

  @override
  State<EmployeeContactEnquiriesPage> createState() =>
      _EmployeeContactEnquiriesPageState();
}

class _EmployeeContactEnquiriesPageState
    extends State<EmployeeContactEnquiriesPage> {
  late final EmployeeContactEnquiriesController _controller =
      EmployeeContactEnquiriesController(EmployeeDashboardRepositoryImpl());

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
      builder: (context, _) => EmployeeListScaffold<EmployeeContactEnquiry>(
        title: 'Contact enquiries',
        controller: _controller,
        subtitle: () => '${_controller.total} enquir'
            '${_controller.total == 1 ? 'y' : 'ies'}',
        header: _countsStrip(),
        filters: EmployeeFilterChips<String>(
          values: EmployeeContactEnquiriesController.statuses,
          selected: _controller.status,
          labelOf: EmployeeContactEnquiry.labelFor,
          onChanged: _controller.setStatus,
        ),
        itemBuilder: (context, enquiry) => _enquiryCard(enquiry),
        emptyIcon: Icons.mark_email_unread_outlined,
        emptyTitle: 'No enquiries found',
        emptyMessage: _controller.isFiltered
            ? 'Nothing matches this filter.'
            : 'Messages sent through the website will arrive here.',
      ),
    );
  }

  /// The `statusCounts` block this route sends alongside its rows.
  ///
  /// Returns null rather than an empty strip when the backend sent no counts —
  /// a row of zeroes would read as "nothing has ever come in", which is a
  /// different claim from "the server did not say".
  Widget? _countsStrip() {
    final counts = _controller.counts;
    if (counts.isEmpty) return null;

    final entries = EmployeeContactEnquiry.statuses
        .map((status) => MapEntry(status, counts.countOf(status)))
        .where((entry) => entry.value > 0)
        .toList(growable: false);

    if (entries.isEmpty) return null;

    return Wrap(
      spacing: EmployeeTokens.space2,
      runSpacing: EmployeeTokens.space2,
      children: [
        for (final entry in entries)
          EmployeeChip(
            label: '${EmployeeContactEnquiry.labelFor(entry.key)} · '
                '${entry.value}',
            color: EmployeeTokens.statusColor(entry.key),
          ),
      ],
    );
  }

  Widget _enquiryCard(EmployeeContactEnquiry enquiry) {
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
                      style: TextStyle(
                        fontSize: 14.5,
                        // An unread message is worth pulling the eye to; a
                        // handled one is not.
                        fontWeight: enquiry.isNew
                            ? FontWeight.w800
                            : FontWeight.w700,
                        color: EmployeeTokens.textDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      enquiry.displaySubject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: EmployeeTokens.textBody,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: EmployeeTokens.space2),
              EmployeeChip(label: enquiry.displayStatus, dense: true),
            ],
          ),
          if (enquiry.preview.isNotEmpty) ...[
            const SizedBox(height: EmployeeTokens.space3),
            Text(
              enquiry.preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                height: 1.4,
                color: EmployeeTokens.textMuted,
              ),
            ),
          ],
          const SizedBox(height: EmployeeTokens.space2),
          Text(
            enquiry.receivedLabel,
            style: const TextStyle(
              fontSize: 11,
              color: EmployeeTokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openDetail(EmployeeContactEnquiry enquiry) {
    return showEmployeeSheet<void>(
      context: context,
      title: 'Enquiry ${enquiry.shortId}',
      subtitle: enquiry.displayName,
      builder: (context) => _ContactEnquiryDetail(
        enquiry: enquiry,
        controller: _controller,
      ),
    );
  }
}

class _ContactEnquiryDetail extends StatefulWidget {
  const _ContactEnquiryDetail({
    required this.enquiry,
    required this.controller,
  });

  final EmployeeContactEnquiry enquiry;
  final EmployeeContactEnquiriesController controller;

  @override
  State<_ContactEnquiryDetail> createState() => _ContactEnquiryDetailState();
}

class _ContactEnquiryDetailState extends State<_ContactEnquiryDetail> {
  late EmployeeContactEnquiry _enquiry = widget.enquiry;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Opened over the list row, then upgraded to the full record. The row is
    // enough to render the sheet, so there is no spinner here — the message
    // simply fills in if the read brought back more of it.
    _refresh();
  }

  Future<void> _refresh() async {
    final fresh = await widget.controller.loadEnquiry(_enquiry.id);
    if (fresh == null || !mounted) return;
    setState(() => _enquiry = fresh);
  }

  @override
  Widget build(BuildContext context) {
    final enquiry = _enquiry;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmployeeChip(label: enquiry.displayStatus),
        const SizedBox(height: EmployeeTokens.space5),

        _section('From'),
        EmployeeDetailRow(label: 'Name', value: enquiry.displayName),
        EmployeeDetailRow(label: 'Email', value: enquiry.email),
        EmployeeDetailRow(label: 'Phone', value: enquiry.phone),
        EmployeeDetailRow(label: 'Received', value: enquiry.receivedExactLabel),

        if (enquiry.subject.trim().isNotEmpty) ...[
          const SizedBox(height: EmployeeTokens.space4),
          _section('Subject'),
          Text(
            enquiry.displaySubject,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: EmployeeTokens.textDark,
            ),
          ),
        ],

        if (enquiry.message.trim().isNotEmpty) ...[
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
              enquiry.message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: EmployeeTokens.textBody,
              ),
            ),
          ),
        ],

        const SizedBox(height: EmployeeTokens.space5),
        _section('Mark as'),
        Wrap(
          spacing: EmployeeTokens.space2,
          runSpacing: EmployeeTokens.space2,
          children: [
            for (final status in EmployeeContactEnquiry.statuses)
              _statusButton(status),
          ],
        ),

        const SizedBox(height: EmployeeTokens.space3),
        const Text(
          'There is no reply box here — replies go out by email or phone. '
          'This only records where the desk has got to.',
          style: TextStyle(
            fontSize: 11.5,
            height: 1.45,
            color: EmployeeTokens.textMuted,
          ),
        ),

        const SizedBox(height: EmployeeTokens.space3),
        TextButton.icon(
          onPressed: _busy ? null : _delete,
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          label: const Text('Delete enquiry'),
          style: TextButton.styleFrom(
            foregroundColor: EmployeeTokens.danger,
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
      ],
    );
  }

  Widget _statusButton(String status) {
    final selected = _enquiry.status.toLowerCase() == status.toLowerCase();
    final tone = EmployeeTokens.statusColor(status);

    return ChoiceChip(
      label: Text(EmployeeContactEnquiry.labelFor(status)),
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

  Future<void> _delete() async {
    final ok = await confirmEmployeeAction(
      context,
      title: 'Delete this enquiry?',
      message: 'It is removed from the queue. The sender is not notified.',
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
