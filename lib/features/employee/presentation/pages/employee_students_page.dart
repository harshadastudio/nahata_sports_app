import 'package:flutter/material.dart';

import '../../data/repositories/employee_dashboard_repository_impl.dart';
import '../../domain/entities/employee_student.dart';
import '../state/employee_students_controller.dart';
import '../theme/employee_theme.dart';
import '../widgets/employee_forms.dart';
import '../widgets/employee_list_scaffold.dart';

/// Employee → Student List. The roster of students enrolled at this complex.
class EmployeeStudentsPage extends StatefulWidget {
  const EmployeeStudentsPage({super.key});

  @override
  State<EmployeeStudentsPage> createState() => _EmployeeStudentsPageState();
}

class _EmployeeStudentsPageState extends State<EmployeeStudentsPage> {
  late final EmployeeStudentsController _controller =
      EmployeeStudentsController(EmployeeDashboardRepositoryImpl());
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => EmployeeListScaffold<EmployeeStudent>(
        title: 'Student list',
        controller: _controller,
        subtitle: () => '${_controller.total} student'
            '${_controller.total == 1 ? '' : 's'}',
        scopeNotice: 'The students enrolled at your own complex.',
        filters: EmployeeSearchBar(
          controller: _search,
          hintText: 'Search by name, email or phone',
          onChanged: _controller.onSearchChanged,
          onClear: () => _controller.onSearchChanged(''),
        ),
        itemBuilder: (context, student) => _studentCard(student),
        emptyIcon: Icons.school_outlined,
        emptyTitle: 'No students found',
        emptyMessage: _controller.isFiltered
            ? 'Nothing matches that search.'
            : 'Students enrolled at your complex will show up here.',
      ),
    );
  }

  Widget _studentCard(EmployeeStudent student) {
    return EmployeeCard(
      margin: const EdgeInsets.only(bottom: EmployeeTokens.space3),
      accentColor:
          student.isActive ? EmployeeTokens.success : EmployeeTokens.textMuted,
      onTap: () => _openDetail(student),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EmployeeAvatar(initial: student.initial, radius: 19),
              const SizedBox(width: EmployeeTokens.space3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: EmployeeTokens.textDark,
                      ),
                    ),
                    if (student.phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        student.phone,
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
              EmployeeChip(label: student.status, dense: true),
            ],
          ),
          if (student.batchLabel.isNotEmpty) ...[
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
                    student.batchLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: EmployeeTokens.textBody,
                    ),
                  ),
                ),
                if (student.ageLabel != null)
                  Text(
                    student.ageLabel!,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: EmployeeTokens.textMuted,
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openDetail(EmployeeStudent student) {
    return showEmployeeSheet<void>(
      context: context,
      title: 'Student #${student.id}',
      subtitle: student.displayName,
      builder: (context) => _StudentDetail(
        student: student,
        controller: _controller,
      ),
    );
  }
}

class _StudentDetail extends StatefulWidget {
  const _StudentDetail({required this.student, required this.controller});

  final EmployeeStudent student;
  final EmployeeStudentsController controller;

  @override
  State<_StudentDetail> createState() => _StudentDetailState();
}

class _StudentDetailState extends State<_StudentDetail> {
  late EmployeeStudent _student = widget.student;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final student = _student;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EmployeeChip(label: student.status),
        const SizedBox(height: EmployeeTokens.space5),

        _section('Student'),
        EmployeeDetailRow(label: 'Name', value: student.displayName),
        EmployeeDetailRow(label: 'Email', value: student.email),
        EmployeeDetailRow(label: 'Phone', value: student.phone),
        EmployeeDetailRow(label: 'Date of birth', value: student.dobLabel),
        if (student.ageLabel != null)
          EmployeeDetailRow(label: 'Age', value: student.ageLabel!),
        EmployeeDetailRow(label: 'Gender', value: student.gender ?? ''),
        EmployeeDetailRow(
          label: 'Blood group',
          value: student.bloodGroup ?? '',
        ),

        const SizedBox(height: EmployeeTokens.space4),
        _section('Enrolment'),
        EmployeeDetailRow(label: 'Batch', value: student.batchName),
        EmployeeDetailRow(label: 'Sport', value: student.sportName),
        EmployeeDetailRow(label: 'Coach', value: student.coachName),

        const SizedBox(height: EmployeeTokens.space5),

        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _openFeedback,
                icon: const Icon(Icons.rate_review_outlined, size: 17),
                label: const Text('Feedback'),
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
            const SizedBox(width: EmployeeTokens.space3),
            Expanded(
              child: FilledButton.icon(
                onPressed: _busy ? null : _openEdit,
                icon: const Icon(Icons.edit_outlined, size: 17),
                label: const Text('Edit'),
                style: FilledButton.styleFrom(
                  backgroundColor: EmployeeTokens.brand,
                  minimumSize: const Size(0, 46),
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(EmployeeTokens.radiusSm),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: EmployeeTokens.space3),
        TextButton.icon(
          onPressed: _busy ? null : _delete,
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
          label: const Text('Delete student'),
          style: TextButton.styleFrom(
            foregroundColor: EmployeeTokens.danger,
            minimumSize: const Size(double.infinity, 44),
          ),
        ),
      ],
    );
  }

  Future<void> _openEdit() async {
    final saved = await showEmployeeSheet<EmployeeStudentDraft>(
      context: context,
      title: 'Edit student',
      subtitle: _student.displayName,
      builder: (context) => _StudentForm(student: _student),
    );
    if (saved == null || !mounted) return;

    setState(() => _busy = true);
    final error = await widget.controller.save(_student, saved);
    if (!mounted) return;

    setState(() {
      _busy = false;
      if (error == null) {
        _student = _student.copyWith(
          name: saved.name,
          phone: saved.phone,
          gender: saved.gender,
          bloodGroup: saved.bloodGroup,
          dob: saved.dob,
        );
      }
    });

    showEmployeeToast(
      context,
      error ?? 'Student updated',
      isError: error != null,
    );
  }

  Future<void> _openFeedback() async {
    final draft = await showEmployeeSheet<EmployeeStudentFeedbackDraft>(
      context: context,
      title: 'Send feedback',
      subtitle: _student.displayName,
      builder: (context) => const _StudentFeedbackForm(),
    );
    if (draft == null || !mounted) return;

    setState(() => _busy = true);
    final error = await widget.controller.sendFeedback(_student, draft);
    if (!mounted) return;

    setState(() => _busy = false);
    showEmployeeToast(
      context,
      error ?? 'Feedback sent to ${_student.displayName}',
      isError: error != null,
    );
  }

  Future<void> _delete() async {
    final ok = await confirmEmployeeAction(
      context,
      title: 'Delete ${_student.displayName}?',
      message: 'Their enrolment and fee history stay on the account, but the '
          'student record is removed from your complex. This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;

    setState(() => _busy = true);
    final error = await widget.controller.delete(_student);
    if (!mounted) return;

    setState(() => _busy = false);

    if (error == null) Navigator.of(context).pop();
    showEmployeeToast(
      context,
      error ?? 'Student deleted',
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

/// The five fields `PUT /students/{id}` accepts. Email, batch and status are
/// shown on the detail sheet but are not editable here — the route ignores
/// them, and offering a box that silently does nothing is worse than omitting
/// it.
class _StudentForm extends StatefulWidget {
  const _StudentForm({required this.student});

  final EmployeeStudent student;

  @override
  State<_StudentForm> createState() => _StudentFormState();
}

class _StudentFormState extends State<_StudentForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.student.name);
  late final TextEditingController _phone =
      TextEditingController(text: widget.student.phone);

  late String? _gender = _genders.contains(widget.student.gender)
      ? widget.student.gender
      : null;
  late String? _bloodGroup = _bloodGroups.contains(widget.student.bloodGroup)
      ? widget.student.bloodGroup
      : null;
  late DateTime? _dob = widget.student.dob;

  String? _error;

  static const List<String> _genders = ['Male', 'Female', 'Other'];
  static const List<String> _bloodGroups = [
    'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-', //
  ];

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = "A student's name is required.");
      return;
    }

    final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
    if (digits.isNotEmpty && digits.length < 10) {
      setState(() => _error = 'Enter a 10-digit phone number, or leave it '
          'blank.');
      return;
    }

    Navigator.of(context).pop(
      EmployeeStudentDraft(
        name: _name.text,
        phone: _phone.text,
        gender: _gender,
        bloodGroup: _bloodGroup,
        dob: _dob,
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
          label: 'Name',
          required: true,
          child: EmployeeTextField(
            controller: _name,
            hintText: "The student's full name",
          ),
        ),

        EmployeeField(
          label: 'Phone',
          child: EmployeeTextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            hintText: '10-digit mobile number',
          ),
        ),

        EmployeeField(
          label: 'Date of birth',
          child: EmployeeDateField(
            value: _dob,
            // A student cannot be born in the future, and 100 years back is
            // further than the picker will ever reasonably need.
            firstDate: DateTime(now.year - 100),
            lastDate: now,
            onChanged: (value) => setState(() => _dob = value),
          ),
        ),

        EmployeeField(
          label: 'Gender',
          child: EmployeeDropdown<String>(
            value: _gender,
            items: _genders,
            labelOf: (g) => g,
            onChanged: (value) => setState(() => _gender = value),
          ),
        ),

        EmployeeField(
          label: 'Blood group',
          child: EmployeeDropdown<String>(
            value: _bloodGroup,
            items: _bloodGroups,
            labelOf: (b) => b,
            onChanged: (value) => setState(() => _bloodGroup = value),
          ),
        ),

        EmployeeSheetActions(saveLabel: 'Save changes', onSave: _save),
      ],
    );
  }
}

/// `POST /students/{id}/feedback` — a note the student sees on their own
/// dashboard.
class _StudentFeedbackForm extends StatefulWidget {
  const _StudentFeedbackForm();

  @override
  State<_StudentFeedbackForm> createState() => _StudentFeedbackFormState();
}

class _StudentFeedbackFormState extends State<_StudentFeedbackForm> {
  final TextEditingController _title = TextEditingController();
  final TextEditingController _message = TextEditingController();

  String? _error;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  void _send() {
    final draft = EmployeeStudentFeedbackDraft(
      title: _title.text,
      message: _message.text,
    );

    if (!draft.isValid) {
      setState(() => _error = 'Write the message you want them to read.');
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
          label: 'Title',
          hint: 'Optional — the heading they see first.',
          child: EmployeeTextField(
            controller: _title,
            hintText: 'e.g. Great progress',
          ),
        ),

        EmployeeField(
          label: 'Message',
          required: true,
          child: EmployeeTextField(
            controller: _message,
            maxLines: 5,
            hintText: 'What you want the student to know',
          ),
        ),

        EmployeeSheetActions(saveLabel: 'Send feedback', onSave: _send),
      ],
    );
  }
}
