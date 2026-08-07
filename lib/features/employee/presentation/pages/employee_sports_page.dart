import 'package:flutter/material.dart';

import '../../data/repositories/employee_dashboard_repository_impl.dart';
import '../../domain/entities/employee_master.dart';
import '../state/employee_masters_controller.dart';
import '../theme/employee_theme.dart';
import '../widgets/employee_collection_scaffold.dart';
import '../widgets/employee_forms.dart';

/// Employee → Sports. What the complex offers.
class EmployeeSportsPage extends StatefulWidget {
  const EmployeeSportsPage({super.key});

  @override
  State<EmployeeSportsPage> createState() => _EmployeeSportsPageState();
}

class _EmployeeSportsPageState extends State<EmployeeSportsPage> {
  late final EmployeeSportsController _controller =
      EmployeeSportsController(EmployeeDashboardRepositoryImpl());

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
    return EmployeeCollectionScaffold<EmployeeSport>(
      title: 'Sports',
      controller: _controller,
      subtitle: () => '${_controller.items.length} sport'
          '${_controller.items.length == 1 ? '' : 's'}',
      scopeNotice: 'The sports offered at your own complex.',
      onAdd: () => _openForm(null),
      addLabel: 'Add sport',
      emptyIcon: Icons.emoji_events_outlined,
      emptyTitle: 'No sports yet',
      emptyMessage: 'Add your first sport — courts and batches both hang off '
          'one.',
      emptyActionLabel: 'Add a sport',
      itemBuilder: (context, sport) => _sportCard(sport),
    );
  }

  Widget _sportCard(EmployeeSport sport) {
    return EmployeeCard(
      margin: const EdgeInsets.only(bottom: EmployeeTokens.space3),
      accentColor:
          sport.isActive ? EmployeeTokens.success : EmployeeTokens.textMuted,
      onTap: () => _openForm(sport),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sport.displayName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: EmployeeTokens.textDark,
                  ),
                ),
                if ((sport.description ?? '').isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    sport.description!,
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
                    EmployeeChip(label: sport.status, dense: true),
                    if ((sport.category ?? '').isNotEmpty)
                      EmployeeChip(
                        label: sport.category!,
                        color: EmployeeTokens.info,
                        dense: true,
                      ),
                    if (sport.ageLabel != null)
                      EmployeeChip(
                        label: sport.ageLabel!,
                        color: EmployeeTokens.purple,
                        icon: Icons.cake_outlined,
                        dense: true,
                      ),
                    if (sport.allowedMembers != null)
                      EmployeeChip(
                        label: 'Max ${sport.allowedMembers}',
                        color: EmployeeTokens.textMuted,
                        icon: Icons.groups_outlined,
                        dense: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _delete(sport),
            icon: const Icon(Icons.delete_outline_rounded, size: 19),
            color: EmployeeTokens.danger,
            tooltip: 'Delete',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Future<void> _delete(EmployeeSport sport) async {
    final ok = await confirmEmployeeAction(
      context,
      title: 'Delete "${sport.displayName}"?',
      message: 'Courts and batches attached to this sport may stop working. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;

    final error = await _controller.delete(sport);
    if (!mounted) return;

    showEmployeeToast(
      context,
      error ?? 'Sport deleted',
      isError: error != null,
    );
  }

  Future<void> _openForm(EmployeeSport? sport) {
    return showEmployeeSheet<void>(
      context: context,
      title: sport == null ? 'Add sport' : 'Edit sport',
      subtitle: sport?.displayName,
      builder: (context) => _SportForm(sport: sport, controller: _controller),
    );
  }
}

class _SportForm extends StatefulWidget {
  const _SportForm({required this.sport, required this.controller});

  final EmployeeSport? sport;
  final EmployeeSportsController controller;

  @override
  State<_SportForm> createState() => _SportFormState();
}

class _SportFormState extends State<_SportForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.sport?.name ?? '');
  late final TextEditingController _description =
      TextEditingController(text: widget.sport?.description ?? '');
  late final TextEditingController _minAge = TextEditingController(
    text: widget.sport?.minAge?.toString() ?? '',
  );
  late final TextEditingController _maxAge = TextEditingController(
    text: widget.sport?.maxAge?.toString() ?? '',
  );
  late final TextEditingController _members = TextEditingController(
    text: widget.sport?.allowedMembers?.toString() ?? '',
  );

  late String _category = employeeSportCategories.contains(
    widget.sport?.category,
  )
      ? widget.sport!.category!
      : employeeSportCategories.first;

  late String _status = employeeActiveStatuses.contains(widget.sport?.status)
      ? widget.sport!.status
      : employeeActiveStatuses.first;

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    _minAge.dispose();
    _maxAge.dispose();
    _members.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'A sport name is required.');
      return;
    }

    final minAge = int.tryParse(_minAge.text.trim());
    final maxAge = int.tryParse(_maxAge.text.trim());
    if (minAge != null && maxAge != null && minAge > maxAge) {
      setState(() => _error = 'The minimum age cannot be above the maximum.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await widget.controller.save(
      id: widget.sport?.id,
      name: _name.text,
      description: _description.text,
      category: _category,
      minAge: minAge,
      maxAge: maxAge,
      allowedMembers: int.tryParse(_members.text.trim()),
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
      widget.sport == null ? 'Sport created' : 'Sport updated',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmployeeFormError(message: _error),

        EmployeeField(
          label: 'Sport name',
          required: true,
          child: EmployeeTextField(
            controller: _name,
            hintText: 'e.g. Badminton',
          ),
        ),

        EmployeeField(
          label: 'Description',
          child: EmployeeTextField(
            controller: _description,
            maxLines: 3,
            hintText: 'What players should know about it',
          ),
        ),

        EmployeeField(
          label: 'Category',
          child: EmployeeDropdown<String>(
            value: _category,
            items: employeeSportCategories,
            labelOf: (c) => c,
            onChanged: (value) =>
                setState(() => _category = value ?? _category),
          ),
        ),

        Row(
          children: [
            Expanded(
              child: EmployeeField(
                label: 'Min age',
                child: EmployeeNumberField(
                  controller: _minAge,
                  allowDecimal: false,
                  hintText: 'Any',
                ),
              ),
            ),
            const SizedBox(width: EmployeeTokens.space3),
            Expanded(
              child: EmployeeField(
                label: 'Max age',
                child: EmployeeNumberField(
                  controller: _maxAge,
                  allowDecimal: false,
                  hintText: 'Any',
                ),
              ),
            ),
          ],
        ),

        EmployeeField(
          label: 'Max members per booking',
          hint: 'How many people one booking may bring in.',
          child: EmployeeNumberField(
            controller: _members,
            allowDecimal: false,
            hintText: 'No limit',
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
          saveLabel: widget.sport == null ? 'Create sport' : 'Update sport',
          onSave: _save,
        ),
      ],
    );
  }
}
