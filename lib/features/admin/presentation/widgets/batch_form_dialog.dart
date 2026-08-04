import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/batch.dart';
import '../../domain/entities/coach.dart';
import '../../domain/entities/sport.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import 'admin_dialogs.dart';
import 'complex_image_field.dart';
import 'complex_picker_field.dart';

/// Add / Edit batch.
///
/// The layout follows the sections the spec lays out — Basic Information,
/// Schedule, Capacity & Fees, Description, Image, Status — and reuses the
/// console's existing venue picker and image field rather than growing new
/// ones.
///
/// [batch] null means create (`POST /batches`), otherwise edit
/// (`PUT /batches/{id}`). The update route documents exactly six editable
/// fields — name, fees, max students, description, duration and status — so on
/// an edit everything else renders read-only with a notice explaining why, the
/// same treatment the Security Guard and Coach forms give their fixed fields.
///
/// Closing with unsaved work asks before discarding it: this is the longest
/// form in the console and losing it to a stray tap would be expensive.
class BatchFormDialog extends StatefulWidget {
  const BatchFormDialog({
    super.key,
    required this.onSubmit,
    required this.onUploadImage,
    required this.sports,
    required this.sportsState,
    required this.onReloadSports,
    required this.coaches,
    required this.coachesState,
    required this.onReloadCoaches,
    required this.complexes,
    required this.complexesState,
    required this.onReloadComplexes,
    this.batch,
    this.knownAgeGroups = const [],
  });

  final AdminBatch? batch;

  /// Throws on failure so this dialog can stay open and explain itself.
  final Future<void> Function(BatchDraft draft) onSubmit;

  final Future<String> Function(String path, {String? filename}) onUploadImage;

  final List<Sport> sports;
  final ViewState sportsState;
  final VoidCallback onReloadSports;

  final List<Coach> coaches;
  final ViewState coachesState;
  final VoidCallback onReloadCoaches;

  final List<SportsComplex> complexes;
  final ViewState complexesState;
  final VoidCallback onReloadComplexes;

  /// Age groups seen on the rows so far — there is no `/age-groups` route, so
  /// the suggestions are learned rather than hardcoded.
  final List<String> knownAgeGroups;

  bool get isEdit => batch != null;

  /// Resolves to true when a save succeeded.
  static Future<bool> show(
    BuildContext context, {
    AdminBatch? batch,
    required Future<void> Function(BatchDraft draft) onSubmit,
    required Future<String> Function(String path, {String? filename})
    onUploadImage,
    required List<Sport> sports,
    required ViewState sportsState,
    required VoidCallback onReloadSports,
    required List<Coach> coaches,
    required ViewState coachesState,
    required VoidCallback onReloadCoaches,
    required List<SportsComplex> complexes,
    required ViewState complexesState,
    required VoidCallback onReloadComplexes,
    List<String> knownAgeGroups = const [],
  }) async {
    AdminLog.ui(
      '${batch == null ? 'Add' : 'Edit'} batch dialog opened'
      '${batch == null ? '' : ' for ${batch.id}'}',
    );

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => BatchFormDialog(
        batch: batch,
        onSubmit: onSubmit,
        onUploadImage: onUploadImage,
        sports: sports,
        sportsState: sportsState,
        onReloadSports: onReloadSports,
        coaches: coaches,
        coachesState: coachesState,
        onReloadCoaches: onReloadCoaches,
        complexes: complexes,
        complexesState: complexesState,
        onReloadComplexes: onReloadComplexes,
        knownAgeGroups: knownAgeGroups,
      ),
    );

    AdminLog.ui('Batch dialog closed (saved: ${saved ?? false})');
    return saved ?? false;
  }

  @override
  State<BatchFormDialog> createState() => _BatchFormDialogState();
}

class _BatchFormDialogState extends State<BatchFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _schedule;
  late final TextEditingController _maxStudents;
  late final TextEditingController _fees;
  late final TextEditingController _ageGroup;
  late final TextEditingController _duration;
  late final TextEditingController _description;
  late final TextEditingController _feature;

  Sport? _sport;
  Coach? _coach;
  SportsComplex? _complex;

  DateTime? _startDate;
  DateTime? _endDate;
  String? _startTime;
  String? _endTime;

  Set<Weekday> _days = <Weekday>{};

  /// Kept verbatim when the stored schedule is not a day list, so a save never
  /// rewrites what the admin actually wrote.
  String? _customDays;

  List<String> _features = const [];
  String? _image;
  AdminUserStatus? _status;

  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  /// A snapshot of every value as the dialog opened, so "discard changes?" is
  /// only asked when there is something to discard.
  late final Map<String, String> _initial;

  @override
  void initState() {
    super.initState();
    final batch = widget.batch;

    _name = TextEditingController(text: batch?.name?.trim() ?? '');
    _schedule = TextEditingController(text: batch?.schedule ?? '');
    _maxStudents = TextEditingController(
      text: batch?.maxStudents?.toString() ?? '',
    );
    _fees = TextEditingController(text: _numberText(batch?.fees));
    _ageGroup = TextEditingController(text: batch?.ageGroup ?? '');
    _duration = TextEditingController(text: batch?.duration ?? '');
    _description = TextEditingController(text: batch?.description ?? '');
    _feature = TextEditingController();

    final availability = batch?.days ?? CoachAvailability.none;
    if (availability.isCustom) {
      _customDays = availability.raw;
    } else {
      _days = availability.days.toSet();
    }

    _startDate = batch?.startDate;
    _endDate = batch?.endDate;
    _startTime = batch?.startTime;
    _endTime = batch?.endTime;
    _features = List<String>.from(batch?.features ?? const <String>[]);
    _image = batch?.image;
    _status = batch?.status ?? AdminUserStatus.active;

    _sport = _matchSport(batch);
    _coach = _matchCoach(batch);
    _complex = _matchComplex(batch);

    _initial = _snapshot();

    AdminLog.life(
      'BatchFormDialog mounted (${widget.isEdit ? 'edit' : 'create'})',
    );
  }

  /// `2500.0` reads as `2500` in the box; a fee with paise keeps them.
  static String _numberText(num? value) {
    if (value == null) return '';
    if (value is int) return value.toString();
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  Map<String, String> _snapshot() => <String, String>{
    'name': _name.text,
    'schedule': _schedule.text,
    'maxStudents': _maxStudents.text,
    'fees': _fees.text,
    'ageGroup': _ageGroup.text,
    'duration': _duration.text,
    'description': _description.text,
    'sport': '${_sport?.id}',
    'coach': '${_coach?.id}',
    'complex': '${_complex?.id}',
    'startDate': '${_startDate?.toIso8601String()}',
    'endDate': '${_endDate?.toIso8601String()}',
    'startTime': '$_startTime',
    'endTime': '$_endTime',
    'days': _daysValue(),
    'features': _features.join('|'),
    'image': '$_image',
    'status': '${_status?.slug}',
  };

  bool get _isDirty {
    final now = _snapshot();
    for (final entry in _initial.entries) {
      if (now[entry.key] != entry.value) return true;
    }
    return false;
  }

  /// What goes on the wire: the composed day list, or the untouched free text.
  String _daysValue() =>
      _customDays ?? CoachAvailability.compose(_days);

  Sport? _matchSport(AdminBatch? batch) {
    if (batch == null) return null;
    final id = batch.sportId;
    if (id != null) {
      for (final sport in widget.sports) {
        if (sport.id == id) return sport;
      }
    }
    final name = (batch.sportName ?? '').trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final sport in widget.sports) {
      if (sport.displayName.trim().toLowerCase() == name) return sport;
    }
    return null;
  }

  Coach? _matchCoach(AdminBatch? batch) {
    if (batch == null) return null;
    final id = batch.coachId;
    if (id != null) {
      for (final coach in widget.coaches) {
        if (coach.id == id) return coach;
      }
    }
    final name = (batch.coachName ?? '').trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final coach in widget.coaches) {
      if (coach.displayName.trim().toLowerCase() == name) return coach;
    }
    return null;
  }

  SportsComplex? _matchComplex(AdminBatch? batch) {
    if (batch == null) return null;
    final id = batch.sportComplexId;
    if (id != null) {
      for (final complex in widget.complexes) {
        if (complex.id == id) return complex;
      }
    }
    final name = (batch.sportComplexName ?? '').trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final complex in widget.complexes) {
      if (complex.name.trim().toLowerCase() == name) return complex;
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant BatchFormDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Any catalogue may land after the dialog opened; preselect once it has.
    if (_sport == null && widget.sports.isNotEmpty) {
      final matched = _matchSport(widget.batch);
      if (matched != null) setState(() => _sport = matched);
    }
    if (_coach == null && widget.coaches.isNotEmpty) {
      final matched = _matchCoach(widget.batch);
      if (matched != null) setState(() => _coach = matched);
    }
    if (_complex == null && widget.complexes.isNotEmpty) {
      final matched = _matchComplex(widget.batch);
      if (matched != null) setState(() => _complex = matched);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _schedule,
      _maxStudents,
      _fees,
      _ageGroup,
      _duration,
      _description,
      _feature,
    ]) {
      controller.dispose();
    }
    AdminLog.life('BatchFormDialog disposed');
    super.dispose();
  }

  /// The coaches on offer at the chosen complex, then the chosen sport.
  ///
  /// A filter that would empty the list falls back to the full one rather than
  /// leaving an empty dropdown — a stale `/coaches` read must never make the
  /// batch unassignable.
  List<Coach> get _coachOptions {
    var options = widget.coaches;

    final complexId = _complex?.id;
    if (complexId != null) {
      final scoped = options
          .where((coach) => coach.sportComplexId == complexId)
          .toList(growable: false);
      if (scoped.isNotEmpty) options = scoped;
    }

    final sportId = _sport?.id;
    if (sportId != null) {
      final scoped = options
          .where((coach) => coach.sportId == sportId)
          .toList(growable: false);
      if (scoped.isNotEmpty) options = scoped;
    }

    return options;
  }

  List<Sport> get _sportOptions {
    final complexId = _complex?.id;
    if (complexId == null) return widget.sports;

    final scoped = widget.sports
        .where((sport) => sport.sportComplexId == complexId)
        .toList(growable: false);
    return scoped.isEmpty ? widget.sports : scoped;
  }

  Future<void> _close([bool saved = false]) async {
    if (saved) {
      Navigator.of(context).pop(true);
      return;
    }

    if (_saving) return;

    if (_isDirty) {
      final discard = await ConfirmDialog.show(
        context,
        title: 'Discard changes?',
        message:
            'This batch has unsaved changes. Closing now will lose them.',
        confirmLabel: 'Discard',
        cancelLabel: 'Keep editing',
        destructive: true,
        icon: Icons.warning_amber_rounded,
      );
      if (!discard || !mounted) return;
    }

    if (mounted) Navigator.of(context).pop(false);
  }

  Future<void> _submit() async {
    if (_saving) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      AdminLog.ui('Batch form failed local validation');
      return;
    }

    final draft = widget.isEdit
        // Only the six documented fields; toUpdateJson drops the rest anyway,
        // but sending them from here would misrepresent the intent.
        ? BatchDraft(
            name: _name.text,
            fees: _numOrNull(_fees.text),
            maxStudents: _intOrNull(_maxStudents.text),
            description: _description.text,
            duration: _duration.text,
            status: _status,
          )
        : BatchDraft(
            name: _name.text,
            sportId: _sport?.id,
            coachId: _coach?.id,
            sportComplexId: _complex?.id,
            schedule: _schedule.text,
            days: _daysValue(),
            startDate: _startDate,
            endDate: _endDate,
            startTime: _startTime,
            endTime: _endTime,
            maxStudents: _intOrNull(_maxStudents.text),
            fees: _numOrNull(_fees.text),
            ageGroup: _ageGroup.text,
            duration: _duration.text,
            description: _description.text,
            features: _features,
            // Empty rather than null so an image the admin removed is actually
            // cleared on the server record instead of silently kept.
            image: _image ?? '',
            status: _status,
          );

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = const {};
    });

    try {
      await widget.onSubmit(draft);
      if (!mounted) return;
      await _close(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
        _fieldErrors = _readFieldErrors(error.errors);
      });
      _formKey.currentState?.validate();
      AdminLog.failure('Batch save rejected: ${error.message}');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this batch. Please try again.';
      });
      AdminLog.failure(
        'Batch save crashed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  static int? _intOrNull(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
  }

  static num? _numOrNull(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return num.tryParse(text);
  }

  static Map<String, String> _readFieldErrors(Map<String, dynamic>? errors) {
    if (errors == null) return const {};
    final result = <String, String>{};
    errors.forEach((key, value) {
      if (value is List && value.isNotEmpty) {
        result[key] = value.first.toString();
      } else if (value != null) {
        result[key] = value.toString();
      }
    });
    return result;
  }

  String? _serverError(List<String> keys) {
    for (final key in keys) {
      final message = _fieldErrors[key];
      if (message != null) return message;
    }
    return null;
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final initial = (start ? _startDate : _endDate) ?? _startDate ?? now;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      // Wide enough for a batch that started last season and one planned two
      // years out; nothing here is a booking window.
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      helpText: start ? 'Select start date' : 'Select end date',
    );

    if (picked == null || !mounted) return;

    setState(() {
      if (start) {
        _startDate = picked;
        // An end date now before the start is worse than none at all.
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = null;
      } else {
        _endDate = picked;
      }
    });
    _formKey.currentState?.validate();
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      helpText: start ? 'Select start time' : 'Select end time',
    );

    if (picked == null || !mounted) return;

    // Formatted through MaterialLocalizations so it matches the "7:00 PM" the
    // API already stores rather than a 24-hour string it has never seen.
    final label = MaterialLocalizations.of(
      context,
    ).formatTimeOfDay(picked, alwaysUse24HourFormat: false);

    setState(() {
      if (start) {
        _startTime = label;
      } else {
        _endTime = label;
      }
    });
  }

  void _addFeature() {
    final text = _feature.text.trim();
    if (text.isEmpty) return;
    if (_features.any((f) => f.toLowerCase() == text.toLowerCase())) {
      _feature.clear();
      return;
    }
    setState(() {
      _features = [..._features, text];
      _feature.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < AdminTokens.mobileMax;
    final isEdit = widget.isEdit;

    return PopScope(
      // The discard prompt owns the close path, so a back gesture has to route
      // through it too rather than dropping the form on the floor.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Dialog(
        insetPadding: EdgeInsets.symmetric(
          horizontal: narrow ? AdminTokens.space4 : AdminTokens.space8,
          vertical: AdminTokens.space6,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 860,
            maxHeight: size.height * 0.92,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Header(
                title: isEdit ? 'Edit batch' : 'Add batch',
                subtitle: isEdit
                    ? widget.batch!.displayName
                    : 'Create a batch and open it for enrolment',
                icon: isEdit ? Icons.edit_outlined : Icons.groups_2_rounded,
                onClose: _saving ? null : _close,
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
                          _ErrorBanner(message: _error!),
                          const SizedBox(height: AdminTokens.space4),
                        ],
                        if (isEdit) ...[
                          _Note(
                            icon: Icons.lock_outline_rounded,
                            text:
                                'The update route accepts six fields — name, '
                                'fees, maximum students, description, duration '
                                'and status. Everything else is shown here '
                                'read-only.',
                          ),
                          const SizedBox(height: AdminTokens.space4),
                        ],

                        // --- 1. Basic information ----------------------------
                        _Section(
                          icon: Icons.groups_2_outlined,
                          label: 'Basic Information',
                          color: tokens.accent,
                        ),
                        const SizedBox(height: AdminTokens.space4),
                        _Field(
                          controller: _name,
                          label: 'Batch Name',
                          hint: 'e.g. Morning Batch (Beginners)',
                          icon: Icons.badge_outlined,
                          required: true,
                          enabled: !_saving,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            final server = _serverError(['name', 'batchName']);
                            if (server != null) return server;
                            if ((value ?? '').trim().isEmpty) {
                              return 'Batch name is required';
                            }
                            if ((value ?? '').trim().length < 2) {
                              return 'Enter the full name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: AdminTokens.space4),
                        if (isEdit) ...[
                          _Pair(
                            narrow: narrow,
                            first: _ReadOnlyField(
                              label: 'Sports complex',
                              value: widget.batch!.sportComplexName,
                              icon: Icons.stadium_outlined,
                            ),
                            second: _ReadOnlyField(
                              label: 'Sport',
                              value: widget.batch!.sportName,
                              icon: Icons.sports_tennis_outlined,
                            ),
                          ),
                          const SizedBox(height: AdminTokens.space4),
                          _ReadOnlyField(
                            label: 'Coach',
                            value: widget.batch!.coachName,
                            icon: Icons.sports_outlined,
                          ),
                        ] else ...[
                          _Pair(
                            narrow: narrow,
                            first: ComplexPickerField(
                              complexes: widget.complexes,
                              state: widget.complexesState,
                              onReload: widget.onReloadComplexes,
                              initialComplex: _complex,
                              enabled: !_saving,
                              serverError: _serverError(const [
                                'sportComplexId',
                                'sport_complex_id',
                              ]),
                              onChanged: (complex) {
                                setState(() {
                                  _complex = complex;
                                  // A sport or coach not offered at the new
                                  // venue would be an assignment the backend
                                  // has to reject, so both are dropped here.
                                  final sport = _sport;
                                  if (sport != null &&
                                      complex != null &&
                                      sport.sportComplexId != null &&
                                      sport.sportComplexId != complex.id) {
                                    _sport = null;
                                  }
                                  final coach = _coach;
                                  if (coach != null &&
                                      complex != null &&
                                      coach.sportComplexId != null &&
                                      coach.sportComplexId != complex.id) {
                                    _coach = null;
                                  }
                                });
                              },
                              validator: (complex) => complex == null
                                  ? 'Sport complex is required'
                                  : null,
                            ),
                            second: _PickerDropdown<Sport>(
                              label: 'Sport',
                              icon: Icons.sports_tennis_outlined,
                              options: _sportOptions,
                              value: _sport,
                              labelOf: (sport) => sport.displayName,
                              idOf: (sport) => sport.id,
                              state: widget.sportsState,
                              onReload: widget.onReloadSports,
                              enabled: !_saving,
                              required: true,
                              error: _serverError(const ['sportId', 'sport_id']),
                              onChanged: (sport) {
                                setState(() {
                                  _sport = sport;
                                  final coach = _coach;
                                  if (coach != null &&
                                      sport != null &&
                                      coach.sportId != null &&
                                      coach.sportId != sport.id) {
                                    _coach = null;
                                  }
                                });
                              },
                            ),
                          ),
                          const SizedBox(height: AdminTokens.space4),
                          _PickerDropdown<Coach>(
                            label: 'Coach',
                            icon: Icons.sports_outlined,
                            options: _coachOptions,
                            value: _coach,
                            labelOf: (coach) => coach.displayName,
                            idOf: (coach) => coach.id,
                            state: widget.coachesState,
                            onReload: widget.onReloadCoaches,
                            enabled: !_saving,
                            required: true,
                            error: _serverError(const ['coachId', 'coach_id']),
                            note: _coachScopeNote,
                            onChanged: (coach) =>
                                setState(() => _coach = coach),
                          ),
                        ],

                        // --- 2. Schedule -------------------------------------
                        const SizedBox(height: AdminTokens.space6),
                        _Section(
                          icon: Icons.calendar_month_outlined,
                          label: 'Schedule',
                          color: tokens.info,
                        ),
                        const SizedBox(height: AdminTokens.space4),
                        if (isEdit) ...[
                          _Pair(
                            narrow: narrow,
                            first: _ReadOnlyField(
                              label: 'Schedule',
                              value: widget.batch!.scheduleLabel,
                              icon: Icons.schedule_rounded,
                            ),
                            second: _ReadOnlyField(
                              label: 'Days',
                              value: widget.batch!.daysLabel,
                              icon: Icons.event_repeat_rounded,
                            ),
                          ),
                          const SizedBox(height: AdminTokens.space4),
                          _Pair(
                            narrow: narrow,
                            first: _ReadOnlyField(
                              label: 'Start date',
                              value: _dateLabel(widget.batch!.startDate),
                              icon: Icons.event_available_outlined,
                            ),
                            second: _ReadOnlyField(
                              label: 'End date',
                              value: _dateLabel(widget.batch!.endDate),
                              icon: Icons.event_busy_outlined,
                            ),
                          ),
                        ] else ...[
                          _Field(
                            controller: _schedule,
                            label: 'Schedule',
                            hint: 'e.g. 7:00 PM to 8:00 PM',
                            icon: Icons.schedule_rounded,
                            enabled: !_saving,
                            validator: (_) => _serverError(['schedule']),
                          ),
                          const SizedBox(height: AdminTokens.space4),
                          _DaysField(
                            days: _days,
                            customValue: _customDays,
                            enabled: !_saving,
                            onChanged: (days) => setState(() => _days = days),
                            onClearCustom: () =>
                                setState(() => _customDays = null),
                          ),
                          const SizedBox(height: AdminTokens.space4),
                          _Pair(
                            narrow: narrow,
                            first: _DateField(
                              label: 'Start Date',
                              value: _startDate,
                              icon: Icons.event_available_outlined,
                              required: true,
                              enabled: !_saving,
                              onTap: () => _pickDate(start: true),
                              error:
                                  _serverError(const [
                                    'startDate',
                                    'start_date',
                                  ]) ??
                                  (_startDate == null
                                      ? 'Start date is required'
                                      : null),
                            ),
                            second: _DateField(
                              label: 'End Date',
                              value: _endDate,
                              icon: Icons.event_busy_outlined,
                              required: true,
                              enabled: !_saving,
                              onTap: () => _pickDate(start: false),
                              error:
                                  _serverError(const ['endDate', 'end_date']) ??
                                  (_endDate == null
                                      ? 'End date is required'
                                      : (_startDate != null &&
                                                _endDate!.isBefore(_startDate!)
                                            ? 'Must be on or after the start'
                                            : null)),
                            ),
                          ),
                          const SizedBox(height: AdminTokens.space4),
                          _Pair(
                            narrow: narrow,
                            first: _TimeField(
                              label: 'Start Time',
                              value: _startTime,
                              enabled: !_saving,
                              onTap: () => _pickTime(start: true),
                              onClear: () => setState(() => _startTime = null),
                            ),
                            second: _TimeField(
                              label: 'End Time',
                              value: _endTime,
                              enabled: !_saving,
                              onTap: () => _pickTime(start: false),
                              onClear: () => setState(() => _endTime = null),
                            ),
                          ),
                        ],

                        // --- 3. Capacity and fees ----------------------------
                        const SizedBox(height: AdminTokens.space6),
                        _Section(
                          icon: Icons.event_seat_outlined,
                          label: 'Capacity & Fees',
                          color: tokens.success,
                        ),
                        const SizedBox(height: AdminTokens.space4),
                        _Pair(
                          narrow: narrow,
                          first: _Field(
                            controller: _maxStudents,
                            label: 'Maximum Students',
                            hint: 'e.g. 20',
                            icon: Icons.groups_outlined,
                            required: true,
                            enabled: !_saving,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(4),
                            ],
                            validator: (value) {
                              final server = _serverError([
                                'maxStudents',
                                'max_students',
                              ]);
                              if (server != null) return server;
                              final text = (value ?? '').trim();
                              if (text.isEmpty) {
                                return 'Maximum students is required';
                              }
                              final parsed = int.tryParse(text);
                              if (parsed == null) return 'Numbers only';
                              if (parsed < 1) return 'Must be at least 1';

                              // Editing capacity below the heads already in the
                              // room would silently oversubscribe the batch.
                              final enrolled =
                                  widget.batch?.currentStudents ?? 0;
                              if (widget.isEdit && parsed < enrolled) {
                                return '$enrolled students are already '
                                    'enrolled';
                              }
                              return null;
                            },
                          ),
                          second: _Field(
                            controller: _fees,
                            label: 'Fees',
                            hint: 'e.g. 2500',
                            icon: Icons.currency_rupee_rounded,
                            required: true,
                            enabled: !_saving,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9.]'),
                              ),
                              LengthLimitingTextInputFormatter(9),
                            ],
                            validator: (value) {
                              final server = _serverError(['fees', 'fee']);
                              if (server != null) return server;
                              final text = (value ?? '').trim();
                              if (text.isEmpty) return 'Fees are required';
                              final parsed = num.tryParse(text);
                              if (parsed == null) return 'Numbers only';
                              if (parsed < 0) return 'Cannot be negative';
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(height: AdminTokens.space4),
                        _Pair(
                          narrow: narrow,
                          first: isEdit
                              ? _ReadOnlyField(
                                  label: 'Age group',
                                  value: widget.batch!.ageGroup,
                                  icon: Icons.cake_outlined,
                                )
                              : _AgeGroupField(
                                  controller: _ageGroup,
                                  enabled: !_saving,
                                  suggestions: widget.knownAgeGroups,
                                  serverError: _serverError(const [
                                    'ageGroup',
                                    'age_group',
                                  ]),
                                ),
                          second: _Field(
                            controller: _duration,
                            label: 'Duration',
                            hint: 'e.g. 3 months',
                            icon: Icons.timelapse_rounded,
                            enabled: !_saving,
                            validator: (_) => _serverError(['duration']),
                          ),
                        ),

                        // --- 4. Description and features ---------------------
                        const SizedBox(height: AdminTokens.space6),
                        _Section(
                          icon: Icons.notes_rounded,
                          label: 'Description',
                          color: tokens.warning,
                        ),
                        const SizedBox(height: AdminTokens.space4),
                        _Field(
                          controller: _description,
                          label: 'Description',
                          hint: 'What the batch covers and who it suits',
                          icon: Icons.notes_rounded,
                          enabled: !_saving,
                          maxLines: 4,
                          textCapitalization: TextCapitalization.sentences,
                          validator: (_) => _serverError(['description']),
                        ),
                        if (!isEdit) ...[
                          const SizedBox(height: AdminTokens.space4),
                          _FeaturesField(
                            controller: _feature,
                            features: _features,
                            enabled: !_saving,
                            onAdd: _addFeature,
                            onRemove: (feature) => setState(() {
                              _features = _features
                                  .where((f) => f != feature)
                                  .toList();
                            }),
                          ),
                        ],

                        // --- 5. Status ---------------------------------------
                        const SizedBox(height: AdminTokens.space6),
                        _Section(
                          icon: Icons.toggle_on_outlined,
                          label: 'Status',
                          color: tokens.accent,
                        ),
                        const SizedBox(height: AdminTokens.space4),
                        _StatusDropdown(
                          value: _status,
                          enabled: !_saving,
                          error: _serverError(const ['status']),
                          onChanged: (status) {
                            AdminLog.ui(
                              'Form status → ${status?.slug ?? 'none'}',
                            );
                            setState(() => _status = status);
                          },
                        ),

                        // --- 6. Image ----------------------------------------
                        if (!isEdit) ...[
                          const SizedBox(height: AdminTokens.space6),
                          _Section(
                            icon: Icons.image_outlined,
                            label: 'Batch Image',
                            color: const Color(0xFF3949AB),
                          ),
                          const SizedBox(height: AdminTokens.space4),
                          // The sports-complex module's field, reused as-is.
                          // The batches API documents no delete-image route, so
                          // no onServerDelete is passed and the field offers
                          // Replace and Remove only.
                          ComplexImageField(
                            imageUrl: _image,
                            enabled: !_saving,
                            onUpload: widget.onUploadImage,
                            onChanged: (url) => setState(() => _image = url),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              _Footer(
                saving: _saving,
                submitLabel: isEdit ? 'Save Changes' : 'Save Batch',
                onCancel: _saving ? null : _close,
                onSubmit: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Explains why the coach list is shorter than the full roster.
  String? get _coachScopeNote {
    final complex = _complex;
    final sport = _sport;
    if (complex == null && sport == null) return null;
    if (_coachOptions.length == widget.coaches.length) return null;

    final scope = [
      if (sport != null) sport.displayName,
      if (complex != null) complex.name,
    ].join(' at ');
    return 'Showing coaches for $scope.';
  }

  static String _dateLabel(DateTime? value) {
    if (value == null) return '';
    return BatchDraft.formatDate(value) ?? '';
  }
}

// -----------------------------------------------------------------------------
// Fields specific to this form
// -----------------------------------------------------------------------------

/// The day chips, over the comma-separated string the column actually stores.
class _DaysField extends StatelessWidget {
  const _DaysField({
    required this.days,
    required this.customValue,
    required this.enabled,
    required this.onChanged,
    required this.onClearCustom,
  });

  final Set<Weekday> days;

  /// Set when the stored value is not a day list; the chips go read-only and
  /// the text is kept verbatim rather than being rewritten.
  final String? customValue;

  final bool enabled;
  final ValueChanged<Set<Weekday>> onChanged;
  final VoidCallback onClearCustom;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final custom = customValue != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Expanded(child: _Label('Days')),
            if (!custom && days.isNotEmpty)
              TextButton(
                onPressed: enabled ? () => onChanged(<Weekday>{}) : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AdminTokens.space2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Clear', style: TextStyle(fontSize: 11.5)),
              ),
            if (!custom)
              TextButton(
                onPressed: enabled
                    ? () => onChanged(Weekday.values.toSet())
                    : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AdminTokens.space2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('All days', style: TextStyle(fontSize: 11.5)),
              ),
          ],
        ),
        const SizedBox(height: AdminTokens.space2),
        if (custom) ...[
          Container(
            padding: const EdgeInsets.all(AdminTokens.space3),
            decoration: BoxDecoration(
              color: tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
              border: Border.all(color: tokens.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event_repeat_rounded,
                  size: 18,
                  color: tokens.textMuted,
                ),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Text(
                    customValue!,
                    style: TextStyle(
                      color: tokens.textPrimary,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: enabled ? onClearCustom : null,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Pick days instead',
                    style: TextStyle(fontSize: 11.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AdminTokens.space2),
          Text(
            'This schedule is stored as free text and is sent back exactly as '
            'written.',
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 11,
              height: 1.4,
            ),
          ),
        ] else
          Wrap(
            spacing: AdminTokens.space2,
            runSpacing: AdminTokens.space2,
            children: Weekday.values.map((day) {
              final selected = days.contains(day);
              return _Chip(
                label: day.shortLabel,
                selected: selected,
                enabled: enabled,
                onTap: () {
                  final next = days.toSet();
                  if (!next.remove(day)) next.add(day);
                  onChanged(next);
                },
              );
            }).toList(),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: AdminTokens.fast,
          padding: const EdgeInsets.symmetric(
            horizontal: AdminTokens.space3 + 2,
            vertical: AdminTokens.space2 + 2,
          ),
          decoration: BoxDecoration(
            color: selected ? tokens.accentSoft : tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
            border: Border.all(
              color: selected ? tokens.accent : tokens.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                Icon(Icons.check_rounded, size: 14, color: tokens.accent),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: TextStyle(
                  color: selected ? tokens.accent : tokens.textSecondary,
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A tappable date, validated like a form field so the required markers behave
/// the same as the text boxes beside it.
class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.required = false,
    this.enabled = true,
    this.error,
  });

  final String label;
  final DateTime? value;
  final IconData icon;
  final VoidCallback onTap;
  final bool required;
  final bool enabled;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return FormField<DateTime>(
      initialValue: value,
      validator: (_) => error,
      builder: (field) {
        // The picker owns the value; this keeps the field in step so its error
        // clears as soon as a date is chosen.
        if (field.value != value) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (field.mounted) field.didChange(value);
          });
        }

        final message = error;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Label(label, required: required),
            const SizedBox(height: AdminTokens.space2),
            InkWell(
              onTap: enabled ? onTap : null,
              borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AdminTokens.space4,
                  vertical: AdminTokens.space3 + 3,
                ),
                decoration: BoxDecoration(
                  color: tokens.surfaceAlt,
                  borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
                  border: Border.all(
                    color: message != null ? tokens.danger : tokens.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(icon, size: 18, color: tokens.textMuted),
                    const SizedBox(width: AdminTokens.space3),
                    Expanded(
                      child: Text(
                        value == null
                            ? 'Select a date'
                            : (BatchDraft.formatDate(value) ?? ''),
                        style: TextStyle(
                          color: value == null
                              ? tokens.textMuted
                              : tokens.textPrimary,
                          fontSize: 13.5,
                          fontWeight: value == null
                              ? FontWeight.w400
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 15,
                      color: tokens.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              Text(
                message,
                style: TextStyle(color: tokens.danger, fontSize: 11.5),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// A tappable time. Optional everywhere, so it carries its own clear button
/// rather than a required marker.
class _TimeField extends StatelessWidget {
  const _TimeField({
    required this.label,
    required this.value,
    required this.onTap,
    required this.onClear,
    this.enabled = true,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final VoidCallback onClear;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final text = (value ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Label(label),
        const SizedBox(height: AdminTokens.space2),
        InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
          child: Container(
            padding: const EdgeInsets.only(
              left: AdminTokens.space4,
              right: AdminTokens.space2,
              top: AdminTokens.space2,
              bottom: AdminTokens.space2,
            ),
            constraints: const BoxConstraints(minHeight: 48),
            decoration: BoxDecoration(
              color: tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
              border: Border.all(color: tokens.border),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.access_time_rounded,
                  size: 18,
                  color: tokens.textMuted,
                ),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Text(
                    text.isEmpty ? 'Select a time' : text,
                    style: TextStyle(
                      color: text.isEmpty
                          ? tokens.textMuted
                          : tokens.textPrimary,
                      fontSize: 13.5,
                      fontWeight: text.isEmpty
                          ? FontWeight.w400
                          : FontWeight.w600,
                    ),
                  ),
                ),
                if (text.isNotEmpty)
                  IconButton(
                    onPressed: enabled ? onClear : null,
                    icon: const Icon(Icons.close_rounded, size: 16),
                    color: tokens.textMuted,
                    tooltip: 'Clear',
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Free text with the age groups already in use offered as shortcuts. There is
/// no `/age-groups` endpoint, so nothing here is hardcoded and any value can
/// still be typed.
class _AgeGroupField extends StatelessWidget {
  const _AgeGroupField({
    required this.controller,
    required this.enabled,
    required this.suggestions,
    this.serverError,
  });

  final TextEditingController controller;
  final bool enabled;
  final List<String> suggestions;
  final String? serverError;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Label('Age Group'),
        const SizedBox(height: AdminTokens.space2),
        TextFormField(
          controller: controller,
          enabled: enabled,
          validator: (_) => serverError,
          style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. 8-14 years',
            prefixIcon: Icon(
              Icons.cake_outlined,
              size: 18,
              color: tokens.textMuted,
            ),
            suffixIcon: suggestions.isEmpty
                ? null
                : PopupMenuButton<String>(
                    tooltip: 'Age groups already in use',
                    icon: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: tokens.textMuted,
                    ),
                    onSelected: (value) => controller.text = value,
                    itemBuilder: (context) => suggestions
                        .map(
                          (group) => PopupMenuItem<String>(
                            value: group,
                            height: 40,
                            child: Text(
                              group,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                  ),
          ),
        ),
      ],
    );
  }
}

/// The features list: type, press enter, get a chip.
class _FeaturesField extends StatelessWidget {
  const _FeaturesField({
    required this.controller,
    required this.features,
    required this.enabled,
    required this.onAdd,
    required this.onRemove,
  });

  final TextEditingController controller;
  final List<String> features;
  final bool enabled;
  final VoidCallback onAdd;
  final ValueChanged<String> onRemove;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Label('Features'),
        const SizedBox(height: AdminTokens.space2),
        TextField(
          controller: controller,
          enabled: enabled,
          onSubmitted: (_) => onAdd(),
          style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. Equipment provided — press enter to add',
            prefixIcon: Icon(
              Icons.checklist_rounded,
              size: 18,
              color: tokens.textMuted,
            ),
            suffixIcon: IconButton(
              onPressed: enabled ? onAdd : null,
              icon: const Icon(Icons.add_rounded, size: 18),
              color: tokens.accent,
              tooltip: 'Add feature',
            ),
          ),
        ),
        if (features.isNotEmpty) ...[
          const SizedBox(height: AdminTokens.space3),
          Wrap(
            spacing: AdminTokens.space2,
            runSpacing: AdminTokens.space2,
            children: features
                .map(
                  (feature) => Container(
                    padding: const EdgeInsets.only(
                      left: AdminTokens.space3,
                      right: 4,
                      top: 4,
                      bottom: 4,
                    ),
                    decoration: BoxDecoration(
                      color: tokens.accentSoft,
                      borderRadius: BorderRadius.circular(
                        AdminTokens.radiusPill,
                      ),
                      border: Border.all(
                        color: tokens.accent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          feature,
                          style: TextStyle(
                            color: tokens.accent,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        InkWell(
                          onTap: enabled ? () => onRemove(feature) : null,
                          borderRadius: BorderRadius.circular(
                            AdminTokens.radiusPill,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(2),
                            child: Icon(
                              Icons.close_rounded,
                              size: 14,
                              color: tokens.accent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

/// A dropdown over one of the fetched catalogues, with its own retry when the
/// catalogue failed to load.
class _PickerDropdown<T> extends StatelessWidget {
  const _PickerDropdown({
    required this.label,
    required this.icon,
    required this.options,
    required this.value,
    required this.labelOf,
    required this.idOf,
    required this.state,
    required this.onReload,
    required this.enabled,
    required this.onChanged,
    this.required = false,
    this.error,
    this.note,
  });

  final String label;
  final IconData icon;
  final List<T> options;
  final T? value;
  final String Function(T value) labelOf;
  final int Function(T value) idOf;
  final ViewState state;
  final VoidCallback onReload;
  final bool enabled;
  final ValueChanged<T?> onChanged;
  final bool required;
  final String? error;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    // A selection that is no longer in the option list would assert inside
    // DropdownButtonFormField, so it is dropped rather than passed through.
    final selected =
        value != null && options.any((option) => idOf(option) == idOf(value as T))
        ? value
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            _Label(label, required: required),
            const Spacer(),
            if (state.isLoading)
              const SizedBox(
                width: 13,
                height: 13,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (state.isFailed)
              TextButton(
                onPressed: onReload,
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Retry', style: TextStyle(fontSize: 11.5)),
              ),
          ],
        ),
        const SizedBox(height: AdminTokens.space2),
        DropdownButtonFormField<T>(
          initialValue: selected,
          isExpanded: true,
          onChanged: enabled && options.isNotEmpty ? onChanged : null,
          validator: (picked) {
            if (error != null) return error;
            if (required && picked == null) return '$label is required';
            return null;
          },
          dropdownColor: tokens.surface,
          borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
          icon: Icon(
            Icons.expand_more_rounded,
            size: 18,
            color: tokens.textMuted,
          ),
          style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
          hint: Text(
            state.isLoading
                ? 'Loading…'
                : (options.isEmpty
                      ? 'Nothing available'
                      : 'Select ${label.toLowerCase()}'),
            style: TextStyle(fontSize: 13.5, color: tokens.textMuted),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: tokens.textMuted),
          ),
          items: options
              .map(
                (option) => DropdownMenuItem<T>(
                  value: option,
                  child: Text(
                    labelOf(option),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
              )
              .toList(),
        ),
        if (note != null) ...[
          const SizedBox(height: 6),
          Text(
            note!,
            style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
          ),
        ],
      ],
    );
  }
}

class _StatusDropdown extends StatelessWidget {
  const _StatusDropdown({
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.error,
  });

  final AdminUserStatus? value;
  final bool enabled;
  final ValueChanged<AdminUserStatus?> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Label('Status'),
        const SizedBox(height: AdminTokens.space2),
        DropdownButtonFormField<AdminUserStatus>(
          initialValue: value,
          isExpanded: true,
          onChanged: enabled ? onChanged : null,
          validator: (_) => error,
          dropdownColor: tokens.surface,
          borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
          icon: Icon(
            Icons.expand_more_rounded,
            size: 18,
            color: tokens.textMuted,
          ),
          style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.toggle_on_outlined,
              size: 18,
              color: tokens.textMuted,
            ),
          ),
          items: const [AdminUserStatus.active, AdminUserStatus.inactive]
              .map(
                (status) => DropdownMenuItem<AdminUserStatus>(
                  value: status,
                  child: Text(
                    status.label,
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Chrome
// -----------------------------------------------------------------------------

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onClose,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AdminTokens.space5,
        AdminTokens.space5,
        AdminTokens.space3,
        AdminTokens.space4,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: tokens.border)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
              color: tokens.accentSoft,
            ),
            child: Icon(icon, size: 20, color: tokens.accent),
          ),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded, size: 20),
            color: tokens.textMuted,
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.saving,
    required this.submitLabel,
    required this.onCancel,
    required this.onSubmit,
  });

  final bool saving;
  final String submitLabel;
  final VoidCallback? onCancel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space5),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        border: Border(top: BorderSide(color: tokens.border)),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AdminTokens.radiusXl),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton(onPressed: onCancel, child: const Text('Cancel')),
          const SizedBox(width: AdminTokens.space3),
          FilledButton(
            onPressed: saving ? null : onSubmit,
            child: saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(submitLabel),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Row(
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
        const SizedBox(width: AdminTokens.space3),
        Text(
          label,
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
        const SizedBox(width: AdminTokens.space3),
        Expanded(child: Divider(color: tokens.border, height: 1)),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space3),
      decoration: BoxDecoration(
        color: tokens.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: tokens.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: tokens.danger),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: tokens.danger,
                fontSize: 12.5,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(AdminTokens.space3),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
        border: Border.all(color: tokens.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: tokens.textMuted),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: tokens.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pair extends StatelessWidget {
  const _Pair({
    required this.narrow,
    required this.first,
    required this.second,
  });

  final bool narrow;
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          first,
          const SizedBox(height: AdminTokens.space4),
          second,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        const SizedBox(width: AdminTokens.space4),
        Expanded(child: second),
      ],
    );
  }
}

/// The label above every field, with the required marker.
class _Label extends StatelessWidget {
  const _Label(this.text, {this.required = false});

  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return RichText(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: tokens.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        children: [
          if (required)
            TextSpan(
              text: ' *',
              style: TextStyle(color: tokens.danger, fontSize: 12),
            ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.required = false,
    this.enabled = true,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final bool required;
  final bool enabled;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Label(label, required: required),
        const SizedBox(height: AdminTokens.space2),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          maxLines: maxLines,
          validator: validator,
          style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: tokens.textMuted),
            // A multiline box aligns its icon to the first line.
            prefixIconConstraints: maxLines > 1
                ? const BoxConstraints(minWidth: 44, minHeight: 44)
                : null,
          ),
        ),
      ],
    );
  }
}

/// A value the update route will not accept, shown rather than offered.
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String? value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final text = (value ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Label(label),
        const SizedBox(height: AdminTokens.space2),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AdminTokens.space4,
            vertical: AdminTokens.space3 + 3,
          ),
          decoration: BoxDecoration(
            color: tokens.surfaceAlt,
            borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
            border: Border.all(color: tokens.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: tokens.textMuted),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                child: Text(
                  text.isEmpty || text == '—' ? '—' : text,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: text.isEmpty ? tokens.textMuted : tokens.textPrimary,
                    fontSize: 13.5,
                    fontWeight: text.isEmpty
                        ? FontWeight.w400
                        : FontWeight.w600,
                  ),
                ),
              ),
              Icon(
                Icons.lock_outline_rounded,
                size: 15,
                color: tokens.textMuted,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
