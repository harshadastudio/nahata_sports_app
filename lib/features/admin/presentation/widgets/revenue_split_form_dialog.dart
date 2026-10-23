import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/revenue_split.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/server_field_errors.dart';
import 'admin_form_fields.dart';

/// Create / edit a Revenue Split rule.
///
/// [rule] null means create (`POST /revenue-splits`), otherwise edit
/// (`PUT /revenue-splits/{id}`). The scope switch is the important part —
/// `batch` beats `sport_coach`, which beats `sport` — so choosing one clears
/// the fields the other scopes do not use.
class RevenueSplitFormDialog extends StatefulWidget {
  const RevenueSplitFormDialog({
    super.key,
    required this.onSubmit,
    required this.options,
    required this.optionsState,
    required this.onReloadOptions,
    this.rule,
  });

  final RevenueSplitRule? rule;

  /// Throws on failure so this dialog can stay open and explain itself.
  final Future<void> Function(RevenueSplitDraft draft) onSubmit;

  final RevenueSplitOptions options;
  final ViewState optionsState;
  final VoidCallback onReloadOptions;

  bool get isEdit => rule != null;

  /// Resolves to true when a save succeeded.
  static Future<bool> show(
    BuildContext context, {
    RevenueSplitRule? rule,
    required Future<void> Function(RevenueSplitDraft draft) onSubmit,
    required RevenueSplitOptions options,
    required ViewState optionsState,
    required VoidCallback onReloadOptions,
  }) async {
    AdminLog.ui(
      '${rule == null ? 'Add' : 'Edit'} revenue split rule dialog opened'
      '${rule == null ? '' : ' for ${rule.id}'}',
    );

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => RevenueSplitFormDialog(
        rule: rule,
        onSubmit: onSubmit,
        options: options,
        optionsState: optionsState,
        onReloadOptions: onReloadOptions,
      ),
    );

    AdminLog.ui('Revenue split dialog closed (saved: ${saved ?? false})');
    return saved ?? false;
  }

  @override
  State<RevenueSplitFormDialog> createState() =>
      _RevenueSplitFormDialogState();
}

class _RevenueSplitFormDialogState extends State<RevenueSplitFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _coachPercent;
  late final TextEditingController _notes;

  RevenueSplitScope _scope = RevenueSplitScope.batch;
  RevenueSplitBatchOption? _batch;
  RevenueSplitSportOption? _sport;
  RevenueSplitCoachOption? _coach;
  DateTime? _effectiveFrom;

  bool _saving = false;
  String? _error;
  ServerFieldErrors _fieldErrors = ServerFieldErrors.none;

  @override
  void initState() {
    super.initState();
    final rule = widget.rule;

    _coachPercent = TextEditingController(
      text: rule == null ? '' : _numberText(rule.coachPercent),
    );
    _notes = TextEditingController(text: rule?.notes ?? '');

    _scope = rule?.scope ?? RevenueSplitScope.batch;
    _effectiveFrom = rule?.effectiveFrom ?? DateTime.now();

    _batch = _matchBatch(rule?.batchId);
    _sport = _matchSport(rule?.sportId);
    _coach = _matchCoach(rule?.coachId);

    AdminLog.life(
      'RevenueSplitFormDialog mounted (${widget.isEdit ? 'edit' : 'create'})',
    );
  }

  @override
  void didUpdateWidget(covariant RevenueSplitFormDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The option lists may land after the dialog opened; preselect once they
    // do, same as CouponFormDialog.
    if (_batch == null && widget.rule?.batchId != null) {
      final matched = _matchBatch(widget.rule!.batchId);
      if (matched != null) setState(() => _batch = matched);
    }
    if (_sport == null && widget.rule?.sportId != null) {
      final matched = _matchSport(widget.rule!.sportId);
      if (matched != null) setState(() => _sport = matched);
    }
    if (_coach == null && widget.rule?.coachId != null) {
      final matched = _matchCoach(widget.rule!.coachId);
      if (matched != null) setState(() => _coach = matched);
    }
  }

  @override
  void dispose() {
    _coachPercent.dispose();
    _notes.dispose();
    AdminLog.life('RevenueSplitFormDialog disposed');
    super.dispose();
  }

  static String _numberText(num value) =>
      value == value.roundToDouble()
          ? value.toStringAsFixed(0)
          : value.toString();

  RevenueSplitBatchOption? _matchBatch(int? id) {
    if (id == null) return null;
    for (final batch in widget.options.batches) {
      if (batch.id == id) return batch;
    }
    return null;
  }

  RevenueSplitSportOption? _matchSport(int? id) {
    if (id == null) return null;
    for (final sport in widget.options.sports) {
      if (sport.id == id) return sport;
    }
    return null;
  }

  RevenueSplitCoachOption? _matchCoach(int? id) {
    if (id == null) return null;
    for (final coach in widget.options.coaches) {
      if (coach.id == id) return coach;
    }
    return null;
  }

  Future<void> _pickEffectiveFrom() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _effectiveFrom ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 3),
      helpText: 'Effective from',
    );
    if (picked == null || !mounted) return;
    setState(
      () => _effectiveFrom = DateTime(picked.year, picked.month, picked.day),
    );
  }

  Future<void> _submit() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) {
      AdminLog.ui('Revenue split form failed local validation');
      return;
    }
    if (_effectiveFrom == null) {
      setState(() => _error = 'Pick the date this rule takes effect from.');
      return;
    }

    final draft = RevenueSplitDraft(
      scope: _scope,
      batchId: _scope == RevenueSplitScope.batch ? _batch?.id : null,
      sportId: _scope == RevenueSplitScope.batch ? null : _sport?.id,
      coachId: _scope == RevenueSplitScope.sportCoach ? _coach?.id : null,
      coachPercent: num.tryParse(_coachPercent.text.trim()) ?? 0,
      effectiveFrom: _effectiveFrom!,
      notes: _notes.text,
    );

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = ServerFieldErrors.none;
    });

    try {
      await widget.onSubmit(draft);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      final parsed = ServerFieldErrors.from(error);
      setState(() {
        _saving = false;
        _error = parsed.summary ?? error.message;
        _fieldErrors = parsed;
      });
      _formKey.currentState?.validate();
      AdminLog.failure('Revenue split save rejected: ${error.message}');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this rule. Please try again.';
      });
      AdminLog.failure(
        'Revenue split save crashed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < AdminTokens.mobileMax;
    final isEdit = widget.isEdit;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? AdminTokens.space4 : AdminTokens.space8,
        vertical: AdminTokens.space6,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 560, maxHeight: size.height * 0.9),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminFormHeader(
              title: isEdit ? 'Edit revenue split rule' : 'New revenue split rule',
              subtitle: isEdit
                  ? widget.rule!.targetLabel
                  : 'Which share of a payment goes to the coach',
              icon: isEdit ? Icons.edit_outlined : Icons.percent_rounded,
              onClose: _saving ? null : () => Navigator.of(context).pop(false),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AdminTokens.space5),
                child: Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        AdminFormErrorBanner(message: _error!),
                        const SizedBox(height: AdminTokens.space4),
                      ],
                      const AdminFormSection(
                        icon: Icons.tune_rounded,
                        label: 'Scope',
                        color: Color(0xFF3949AB),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminVocabularyDropdown<RevenueSplitScope>(
                        label: 'Applies to',
                        icon: Icons.category_outlined,
                        value: _scope,
                        required: true,
                        enabled: !_saving,
                        items: RevenueSplitScope.values,
                        labelOf: (scope) => scope.label,
                        onChanged: (scope) => setState(() {
                          _scope = scope ?? RevenueSplitScope.batch;
                          if (_scope == RevenueSplitScope.batch) {
                            _sport = null;
                            _coach = null;
                          } else if (_scope == RevenueSplitScope.sport) {
                            _batch = null;
                            _coach = null;
                          } else {
                            _batch = null;
                          }
                        }),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      if (_scope == RevenueSplitScope.batch)
                        AdminCatalogueDropdown<RevenueSplitBatchOption>(
                          label: 'Batch',
                          icon: Icons.groups_2_outlined,
                          options: widget.options.batches,
                          value: _batch,
                          labelOf: (batch) => batch.displayName,
                          idOf: (batch) => batch.id,
                          state: widget.optionsState,
                          onReload: widget.onReloadOptions,
                          enabled: !_saving,
                          required: true,
                          error: _fieldErrors.forKeys(const ['batchId', 'batch_id']),
                          note: 'The most specific rule — beats every other scope.',
                          onChanged: (batch) => setState(() => _batch = batch),
                        )
                      else ...[
                        AdminCatalogueDropdown<RevenueSplitSportOption>(
                          label: 'Sport',
                          icon: Icons.sports_tennis_outlined,
                          options: widget.options.sports,
                          value: _sport,
                          labelOf: (sport) => sport.displayName,
                          idOf: (sport) => sport.id,
                          state: widget.optionsState,
                          onReload: widget.onReloadOptions,
                          enabled: !_saving,
                          required: true,
                          error: _fieldErrors.forKeys(const ['sportId', 'sport_id']),
                          onChanged: (sport) => setState(() => _sport = sport),
                        ),
                        if (_scope == RevenueSplitScope.sportCoach) ...[
                          const SizedBox(height: AdminTokens.space4),
                          AdminCatalogueDropdown<RevenueSplitCoachOption>(
                            label: 'Coach',
                            icon: Icons.person_outline_rounded,
                            options: widget.options.coaches,
                            value: _coach,
                            labelOf: (coach) => coach.displayName,
                            idOf: (coach) => coach.id,
                            state: widget.optionsState,
                            onReload: widget.onReloadOptions,
                            enabled: !_saving,
                            required: true,
                            error: _fieldErrors.forKeys(const [
                              'coachId',
                              'coach_id',
                            ]),
                            note: 'Beaten only by a batch rule.',
                            onChanged: (coach) => setState(() => _coach = coach),
                          ),
                        ] else
                          const Padding(
                            padding: EdgeInsets.only(top: AdminTokens.space2),
                            child: Text(
                              'The fallback tier — everyone coaching this sport, '
                              'unless a more specific rule exists.',
                              style: TextStyle(fontSize: 11.5),
                            ),
                          ),
                      ],
                      const SizedBox(height: AdminTokens.space5),
                      const AdminFormSection(
                        icon: Icons.percent_rounded,
                        label: 'The split',
                        color: Color(0xFF10B981),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminFieldPair(
                        narrow: narrow,
                        first: AdminTextField(
                          controller: _coachPercent,
                          label: "Coach's share (%)",
                          icon: Icons.percent_rounded,
                          hint: 'e.g. 40',
                          required: true,
                          enabled: !_saving,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                          ],
                          onChanged: (_) => setState(() {}),
                          validator: (value) {
                            final server = _fieldErrors.forKeys(const [
                              'coachPercent',
                              'coach_percent',
                            ]);
                            if (server != null) return server;
                            final text = (value ?? '').trim();
                            if (text.isEmpty) return 'Enter the coach share';
                            final parsed = num.tryParse(text);
                            if (parsed == null) return 'Enter a number';
                            if (parsed < 0 || parsed > 100) {
                              return 'Must be between 0 and 100';
                            }
                            return null;
                          },
                        ),
                        second: AdminReadOnlyField(
                          label: "Nahata's share (%)",
                          icon: Icons.percent_rounded,
                          value: () {
                            final coach = num.tryParse(_coachPercent.text.trim());
                            if (coach == null) return null;
                            return (100 - coach).toString();
                          }(),
                          note: 'Always 100 minus the coach share.',
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _DateField(
                        label: 'Effective from',
                        value: _effectiveFrom,
                        enabled: !_saving,
                        onTap: _pickEffectiveFrom,
                        error: _effectiveFrom == null
                            ? null
                            : _fieldErrors.forKeys(const [
                                'effectiveFrom',
                                'effective_from',
                              ]),
                        note: 'Applies only to money received on or after this date. '
                            'Payments already collected keep their old split.',
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminTextField(
                        controller: _notes,
                        label: 'Notes',
                        icon: Icons.notes_rounded,
                        hint: 'Optional — why this rate was agreed',
                        enabled: !_saving,
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (_) => _fieldErrors.forKeys(const ['notes']),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AdminFormFooter(
              saving: _saving,
              submitLabel: isEdit ? 'Save changes' : 'Create rule',
              onCancel: _saving ? null : () => Navigator.of(context).pop(false),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// A tap-to-pick date, styled like [CouponFormDialog]'s.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onTap,
    this.note,
    this.error,
  });

  final String label;
  final DateTime? value;
  final bool enabled;
  final VoidCallback onTap;
  final String? note;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        AdminFieldLabel(label, required: true),
        const SizedBox(height: AdminTokens.space2),
        InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AdminTokens.space4,
              vertical: AdminTokens.space3 + 2,
            ),
            decoration: BoxDecoration(
              color: tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
              border: Border.all(
                color: error != null ? tokens.danger : tokens.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 17,
                  color: tokens.textMuted,
                ),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Text(
                    value == null
                        ? 'Select a date'
                        : '${value!.year}-${value!.month.toString().padLeft(2, '0')}'
                              '-${value!.day.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      color: value == null
                          ? tokens.textMuted
                          : tokens.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.expand_more_rounded,
                  size: 18,
                  color: tokens.textMuted,
                ),
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 5),
          Text(error!, style: TextStyle(color: tokens.danger, fontSize: 11.5)),
        ] else if (note != null) ...[
          const SizedBox(height: 5),
          Text(note!, style: TextStyle(color: tokens.textMuted, fontSize: 11.5)),
        ],
      ],
    );
  }
}
