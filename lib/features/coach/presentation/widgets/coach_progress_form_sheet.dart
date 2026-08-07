import 'package:flutter/material.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/coach_log.dart';
import '../../domain/entities/coach_option.dart';
import '../../domain/entities/coach_progress.dart';
import '../theme/coach_theme.dart';

/// Record or edit a student assessment.
///
/// Two modes, because the backend treats them differently: creating adds a
/// **new dated record** (which is what the improvement figure is computed
/// from), while editing rewrites an existing one. On edit the student cannot
/// be changed — moving an assessment to a different student would rewrite two
/// students' histories at once, and the route does not support it anyway.
///
/// Returns `true` once something is saved.
Future<bool> showCoachProgressFormSheet({
  required BuildContext context,
  required List<CoachOption> students,
  required List<CoachOption> sports,
  required Future<void> Function(CoachProgressDraft draft) onSubmit,
  CoachProgress? existing,
}) async {
  final result = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CoachProgressFormSheet(
      students: students,
      sports: sports,
      onSubmit: onSubmit,
      existing: existing,
    ),
  );
  return result ?? false;
}

class _CoachProgressFormSheet extends StatefulWidget {
  const _CoachProgressFormSheet({
    required this.students,
    required this.sports,
    required this.onSubmit,
    this.existing,
  });

  final List<CoachOption> students;
  final List<CoachOption> sports;
  final Future<void> Function(CoachProgressDraft draft) onSubmit;
  final CoachProgress? existing;

  @override
  State<_CoachProgressFormSheet> createState() =>
      _CoachProgressFormSheetState();
}

class _CoachProgressFormSheetState extends State<_CoachProgressFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _notes;
  late final TextEditingController _areas;

  CoachOption? _student;
  CoachOption? _sport;
  late double _score;
  CoachSkillLevel _level = CoachSkillLevel.beginner;
  late DateTime _date;

  bool _submitting = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();

    final existing = widget.existing;

    _notes = TextEditingController(text: existing?.notes ?? '');
    _areas = TextEditingController();
    _score = (existing?.currentScore ?? 70).toDouble().clamp(0, 100);
    _level = existing?.skillLevel ?? CoachSkillLevel.beginner;
    _date = existing?.lastUpdated ?? DateTime.now();

    if (existing != null) {
      // The student is fixed on an edit, but is still resolved so the sheet
      // can show who the assessment belongs to.
      _student = _findOption(widget.students, existing.studentId) ??
          CoachOption(id: existing.studentId, name: existing.displayName);
      _sport = _findOption(widget.sports, existing.sportId);
    } else if (widget.students.length == 1) {
      _student = widget.students.first;
    }

    if (_sport == null && widget.sports.length == 1) {
      _sport = widget.sports.first;
    }
  }

  static CoachOption? _findOption(List<CoachOption> options, int id) {
    for (final option in options) {
      if (option.id == id) return option;
    }
    return null;
  }

  @override
  void dispose() {
    _notes.dispose();
    _areas.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_student == null) {
      setState(() => _error = 'Pick a student.');
      return;
    }
    if (_sport == null) {
      setState(() => _error = 'Pick a sport.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      await widget.onSubmit(
        CoachProgressDraft(
          // Sent on create only — the edit route ignores studentId, and
          // including it would suggest it can be moved.
          studentId: _isEdit ? null : _student!.id,
          sportId: _sport!.id,
          fitnessScore: _score.round(),
          skillLevel: _level,
          notes: _notes.text,
          improvementAreas: _areas.text,
          assessmentDate: _date,
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      CoachLog.failure('Progress submit failed', error: e);
      setState(() {
        _error = e is ApiException
            ? e.message
            : 'Could not save this assessment. Please try again.';
        _submitting = false;
      });
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(now) ? now : _date,
      firstDate: DateTime(now.year - 2),
      // An assessment cannot be dated in the future.
      lastDate: now,
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: CoachTokens.surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(CoachTokens.radiusLg + 4),
            ),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 4,
                margin:
                    const EdgeInsets.symmetric(vertical: CoachTokens.space3),
                decoration: BoxDecoration(
                  color: CoachTokens.border,
                  borderRadius: BorderRadius.circular(CoachTokens.radiusPill),
                ),
              ),
              _header(),
              const Divider(height: 1, color: CoachTokens.border),
              Expanded(child: _body(scrollController)),
              _footer(insets),
            ],
          ),
        );
      },
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        CoachTokens.space5,
        0,
        CoachTokens.space3,
        CoachTokens.space4,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'Edit assessment' : 'Record assessment',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: CoachTokens.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isEdit
                      ? _student?.displayName ?? ''
                      : 'Adds a new dated record',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: CoachTokens.textMuted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed:
                _submitting ? null : () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded),
            color: CoachTokens.textMuted,
          ),
        ],
      ),
    );
  }

  Widget _body(ScrollController scrollController) {
    return Form(
      key: _formKey,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.all(CoachTokens.space5),
        children: [
          if (!_isEdit) ...[
            _label('Student *'),
            const SizedBox(height: CoachTokens.space2),
            DropdownButtonFormField<CoachOption>(
              initialValue: _student,
              isExpanded: true,
              style: const TextStyle(
                fontSize: 14.5,
                color: CoachTokens.textDark,
              ),
              decoration: _decoration(
                'Select student',
                Icons.person_outline_rounded,
              ),
              items: widget.students
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text(
                        s.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged:
                  _submitting ? null : (v) => setState(() => _student = v),
            ),
            const SizedBox(height: CoachTokens.space4),
          ],
          _label('Sport *'),
          const SizedBox(height: CoachTokens.space2),
          DropdownButtonFormField<CoachOption>(
            initialValue: _sport,
            isExpanded: true,
            style: const TextStyle(fontSize: 14.5, color: CoachTokens.textDark),
            decoration: _decoration(
              'Select sport',
              Icons.sports_tennis_outlined,
            ),
            items: widget.sports
                .map(
                  (s) => DropdownMenuItem(
                    value: s,
                    child: Text(
                      s.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
                .toList(),
            onChanged: _submitting ? null : (v) => setState(() => _sport = v),
          ),
          const SizedBox(height: CoachTokens.space5),
          _scoreSlider(),
          const SizedBox(height: CoachTokens.space5),
          _label('Skill level'),
          const SizedBox(height: CoachTokens.space2),
          _levelChips(),
          const SizedBox(height: CoachTokens.space5),
          _label('Assessment date'),
          const SizedBox(height: CoachTokens.space2),
          InkWell(
            onTap: _submitting ? null : _pickDate,
            borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
            child: InputDecorator(
              decoration: _decoration('', Icons.calendar_today_outlined),
              child: Text(
                _formatDate(_date),
                style: const TextStyle(
                  fontSize: 14,
                  color: CoachTokens.textDark,
                ),
              ),
            ),
          ),
          const SizedBox(height: CoachTokens.space4),
          _label('Coach notes'),
          const SizedBox(height: CoachTokens.space2),
          TextFormField(
            controller: _notes,
            maxLines: 3,
            enabled: !_submitting,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 14.5),
            decoration: _decoration(
              'What went well, what to work on',
              Icons.notes_rounded,
            ),
          ),
          const SizedBox(height: CoachTokens.space4),
          _label('Improvement areas'),
          const SizedBox(height: CoachTokens.space2),
          TextFormField(
            controller: _areas,
            maxLines: 2,
            enabled: !_submitting,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 14.5),
            decoration: _decoration(
              'e.g. footwork, stamina',
              Icons.flag_outlined,
            ),
          ),
        ],
      ),
    );
  }

  Widget _scoreSlider() {
    final score = _score.round();
    final tone = score >= 80
        ? CoachTokens.success
        : score >= 60
            ? CoachTokens.info
            : score >= 40
                ? CoachTokens.warning
                : CoachTokens.danger;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _label('Fitness score *')),
            Text(
              '$score',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: tone,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: tone,
            thumbColor: tone,
            inactiveTrackColor: CoachTokens.canvas,
            overlayColor: tone.withValues(alpha: 0.14),
            trackHeight: 5,
          ),
          child: Slider(
            value: _score,
            min: 0,
            max: 100,
            divisions: 100,
            label: '$score',
            onChanged: _submitting
                ? null
                : (value) => setState(() => _score = value),
          ),
        ),
      ],
    );
  }

  Widget _levelChips() {
    return Wrap(
      spacing: CoachTokens.space2,
      runSpacing: CoachTokens.space2,
      children: CoachSkillLevel.values.map((level) {
        final selected = _level == level;
        return ChoiceChip(
          label: Text(level.label),
          selected: selected,
          showCheckmark: false,
          onSelected: _submitting
              ? null
              : (_) => setState(() => _level = level),
          labelStyle: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: selected ? CoachTokens.brand : CoachTokens.textBody,
          ),
          backgroundColor: CoachTokens.canvas,
          selectedColor: CoachTokens.brandSoft,
          side: BorderSide(
            color: selected ? CoachTokens.brand : CoachTokens.border,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(CoachTokens.radiusPill),
          ),
        );
      }).toList(),
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
          color: CoachTokens.textMuted,
        ),
      );

  InputDecoration _decoration(String hint, IconData icon) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
          borderSide: BorderSide(color: color, width: width),
        );

    return InputDecoration(
      hintText: hint.isEmpty ? null : hint,
      hintStyle: const TextStyle(fontSize: 14, color: CoachTokens.textMuted),
      prefixIcon: Icon(icon, size: 19, color: CoachTokens.textMuted),
      filled: true,
      fillColor: CoachTokens.canvas,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: CoachTokens.space3,
        vertical: CoachTokens.space3 + 2,
      ),
      border: border(CoachTokens.border),
      enabledBorder: border(CoachTokens.border),
      focusedBorder: border(CoachTokens.brand, 1.4),
      errorBorder: border(CoachTokens.danger),
      focusedErrorBorder: border(CoachTokens.danger, 1.4),
    );
  }

  Widget _footer(double insets) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        CoachTokens.space5,
        CoachTokens.space4,
        CoachTokens.space5,
        CoachTokens.space4 + insets,
      ),
      decoration: const BoxDecoration(
        color: CoachTokens.canvas,
        border: Border(top: BorderSide(color: CoachTokens.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_error != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 17,
                  color: CoachTokens.danger,
                ),
                const SizedBox(width: CoachTokens.space2),
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: CoachTokens.danger,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: CoachTokens.space3),
          ],
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check_rounded, size: 19),
              label: Text(
                _submitting
                    ? 'Saving…'
                    : _isEdit
                        ? 'Save changes'
                        : 'Record assessment',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: CoachTokens.brand,
                padding:
                    const EdgeInsets.symmetric(vertical: CoachTokens.space4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(CoachTokens.radiusSm),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')} '
      '${_months[date.month - 1]} ${date.year}';
}
