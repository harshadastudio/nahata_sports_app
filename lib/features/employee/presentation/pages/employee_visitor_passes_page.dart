import 'package:flutter/material.dart';

import '../../data/repositories/employee_dashboard_repository_impl.dart';
import '../../domain/entities/employee_visitor_pass.dart';
import '../state/employee_visitor_passes_controller.dart';
import '../theme/employee_theme.dart';
import '../widgets/employee_forms.dart';
import '../widgets/employee_list_scaffold.dart';

/// Employee → Visitor List. Generate a gate pass, email it, revoke it.
class EmployeeVisitorPassesPage extends StatefulWidget {
  const EmployeeVisitorPassesPage({super.key});

  @override
  State<EmployeeVisitorPassesPage> createState() =>
      _EmployeeVisitorPassesPageState();
}

class _EmployeeVisitorPassesPageState extends State<EmployeeVisitorPassesPage> {
  late final EmployeeVisitorPassesController _controller =
      EmployeeVisitorPassesController(EmployeeDashboardRepositoryImpl());

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
      builder: (context, _) => EmployeeListScaffold<EmployeeVisitorPass>(
        title: 'Visitor passes',
        controller: _controller,
        subtitle: () => '${_controller.total} pass'
            '${_controller.total == 1 ? '' : 'es'}',
        scopeNotice: 'Passes issued at your own complex. The gate scans them; '
            'this screen issues them.',
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _openGenerate,
          backgroundColor: EmployeeTokens.brand,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.badge_outlined),
          label: const Text('New pass'),
        ),
        itemBuilder: (context, pass) => _passCard(pass),
        emptyIcon: Icons.badge_outlined,
        emptyTitle: 'No visitor passes yet',
        emptyMessage: 'Generate a pass and the visitor can be scanned in at '
            'the gate.',
      ),
    );
  }

  Widget _passCard(EmployeeVisitorPass pass) {
    return EmployeeCard(
      margin: const EdgeInsets.only(bottom: EmployeeTokens.space3),
      accentColor: EmployeeTokens.statusColor(pass.status),
      onTap: () => _openDetail(pass),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EmployeeAvatar(initial: pass.initial, radius: 19),
              const SizedBox(width: EmployeeTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pass.displayName,
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
                      pass.displayCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontFamily: 'monospace',
                        color: EmployeeTokens.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: EmployeeTokens.space2),
              EmployeeChip(label: pass.displayStatus, dense: true),
            ],
          ),
          const SizedBox(height: EmployeeTokens.space3),
          Row(
            children: [
              const Icon(
                Icons.interests_outlined,
                size: 13,
                color: EmployeeTokens.textMuted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  [
                    pass.visitPurpose,
                    if (pass.phoneNumber.isNotEmpty) pass.phoneNumber,
                  ].join(' · '),
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
          const SizedBox(height: EmployeeTokens.space2),
          Text(
            pass.movementLabel ?? pass.issuedLabel,
            style: const TextStyle(
              fontSize: 11,
              color: EmployeeTokens.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openGenerate() async {
    final draft = await showEmployeeSheet<EmployeeVisitorPassDraft>(
      context: context,
      title: 'New visitor pass',
      builder: (context) => const _VisitorPassForm(),
    );
    if (draft == null || !mounted) return;

    final error = await _controller.generate(draft);
    if (!mounted) return;

    if (error != null) {
      showEmployeeToast(context, error, isError: true);
      return;
    }

    final pass = _controller.lastGenerated;
    showEmployeeToast(
      context,
      pass == null
          ? 'Visitor pass generated'
          : 'Pass ${pass.displayCode} generated',
    );

    // The pass number and QR code only ever arrive in the create answer, so the
    // detail sheet is opened straight away rather than making the user find the
    // new row to see them.
    if (pass != null) await _openDetail(pass);
  }

  Future<void> _openDetail(EmployeeVisitorPass pass) {
    return showEmployeeSheet<void>(
      context: context,
      title: pass.displayCode,
      subtitle: pass.displayName,
      builder: (context) => _VisitorPassDetail(
        pass: pass,
        controller: _controller,
      ),
    );
  }
}

class _VisitorPassDetail extends StatefulWidget {
  const _VisitorPassDetail({required this.pass, required this.controller});

  final EmployeeVisitorPass pass;
  final EmployeeVisitorPassesController controller;

  @override
  State<_VisitorPassDetail> createState() => _VisitorPassDetailState();
}

class _VisitorPassDetailState extends State<_VisitorPassDetail> {
  late EmployeeVisitorPass _pass = widget.pass;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Opened over the list row, then re-read: the desk never moves a pass along
    // its lifecycle, so the gate may have checked this visitor in since the
    // list loaded. No spinner — the row already renders the whole sheet.
    _refresh();
  }

  Future<void> _refresh() async {
    final fresh = await widget.controller.loadPass(_pass);
    if (fresh == null || !mounted) return;
    setState(() => _pass = fresh);
  }

  @override
  Widget build(BuildContext context) {
    final pass = _pass;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmployeeChip(label: pass.displayStatus),
        const SizedBox(height: EmployeeTokens.space5),

        _section('Visitor'),
        EmployeeDetailRow(label: 'Name', value: pass.displayName),
        EmployeeDetailRow(label: 'Phone', value: pass.phoneNumber),
        EmployeeDetailRow(label: 'Purpose', value: pass.visitPurpose),
        if ((pass.email ?? '').isNotEmpty)
          EmployeeDetailRow(label: 'Emailed to', value: pass.email!),

        const SizedBox(height: EmployeeTokens.space4),
        _section('Pass'),
        EmployeeDetailRow(
          label: 'Pass number',
          value: pass.displayCode,
          monospace: true,
        ),
        EmployeeDetailRow(label: 'Issued', value: pass.issuedLabel),
        if (pass.movementLabel != null)
          EmployeeDetailRow(label: 'Gate', value: pass.movementLabel!),

        const SizedBox(height: EmployeeTokens.space5),

        FilledButton.icon(
          onPressed: _busy ? null : _email,
          icon: const Icon(Icons.mail_outline_rounded, size: 18),
          label: const Text('Email this pass'),
          style: FilledButton.styleFrom(
            backgroundColor: EmployeeTokens.brand,
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(EmployeeTokens.radiusSm),
            ),
          ),
        ),
        const SizedBox(height: EmployeeTokens.space2),
        const Text(
          'The pass and its QR code are emailed to whichever address you '
          'enter — it does not have to be the visitor\'s.',
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
          label: const Text('Delete pass'),
          style: TextButton.styleFrom(
            foregroundColor: EmployeeTokens.danger,
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
      ],
    );
  }

  Future<void> _email() async {
    final address = await showEmployeeSheet<String>(
      context: context,
      title: 'Email pass',
      subtitle: _pass.displayCode,
      builder: (context) => _EmailPassForm(initial: _pass.email),
    );
    if (address == null || !mounted) return;

    setState(() => _busy = true);
    final error = await widget.controller.email(_pass, address);
    if (!mounted) return;

    setState(() => _busy = false);
    showEmployeeToast(
      context,
      error ?? 'Pass emailed to ${address.trim()}',
      isError: error != null,
    );
  }

  Future<void> _delete() async {
    final ok = await confirmEmployeeAction(
      context,
      title: 'Delete ${_pass.displayCode}?',
      message: 'The visitor will no longer be able to be scanned in with it. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    final error = await widget.controller.delete(_pass);
    if (!mounted) return;

    setState(() => _busy = false);

    if (error == null) Navigator.of(context).pop();
    showEmployeeToast(
      context,
      error ?? 'Visitor pass deleted',
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

class _VisitorPassForm extends StatefulWidget {
  const _VisitorPassForm();

  @override
  State<_VisitorPassForm> createState() => _VisitorPassFormState();
}

class _VisitorPassFormState extends State<_VisitorPassForm> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();

  String _purpose = EmployeeVisitorPassDraft.purposes.first;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _generate() {
    final draft = EmployeeVisitorPassDraft(
      visitorName: _name.text,
      phoneNumber: _phone.text,
      visitPurpose: _purpose,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmployeeFormError(message: _error),

        EmployeeField(
          label: 'Visitor name',
          required: true,
          child: EmployeeTextField(
            controller: _name,
            hintText: 'Who is visiting',
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

        EmployeeField(
          label: 'Purpose',
          child: EmployeeDropdown<String>(
            value: _purpose,
            items: EmployeeVisitorPassDraft.purposes,
            labelOf: (p) => p,
            onChanged: (value) => setState(() => _purpose = value ?? _purpose),
          ),
        ),

        EmployeeSheetActions(saveLabel: 'Generate pass', onSave: _generate),
      ],
    );
  }
}

/// Collects the address for a send-email call. Shared shape with the event
/// pass screen, but kept local: the two sheets say different things about who
/// the mail is for.
class _EmailPassForm extends StatefulWidget {
  const _EmailPassForm({this.initial});

  final String? initial;

  @override
  State<_EmailPassForm> createState() => _EmailPassFormState();
}

class _EmailPassFormState extends State<_EmailPassForm> {
  late final TextEditingController _email =
      TextEditingController(text: widget.initial ?? '');

  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  void _send() {
    final draft = EmployeeVisitorPassEmailDraft(email: _email.text);
    if (!draft.isValid) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }

    Navigator.of(context).pop(_email.text);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmployeeFormError(message: _error),

        EmployeeField(
          label: 'Email address',
          required: true,
          child: EmployeeTextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            textCapitalization: TextCapitalization.none,
            hintText: 'name@example.com',
            onSubmitted: (_) => _send(),
          ),
        ),

        EmployeeSheetActions(saveLabel: 'Send pass', onSave: _send),
      ],
    );
  }
}
