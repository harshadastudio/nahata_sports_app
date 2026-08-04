import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/court.dart';
import '../../domain/entities/sport.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/server_field_errors.dart';
import 'admin_form_fields.dart';
import 'complex_image_field.dart';
import 'complex_picker_field.dart';

/// Add / Edit court.
///
/// [court] null means create (`POST /courts`), otherwise edit
/// (`PUT /courts/{id}`). The update route documents eight editable fields, so
/// on an edit the sport and complex assignment renders read-only — the same
/// treatment the Coach and Batch forms give their fixed fields.
class CourtFormDialog extends StatefulWidget {
  const CourtFormDialog({
    super.key,
    required this.onSubmit,
    required this.onUploadImage,
    required this.sports,
    required this.sportsState,
    required this.onReloadSports,
    required this.complexes,
    required this.complexesState,
    required this.onReloadComplexes,
    this.court,
    this.knownSurfaces = const [],
  });

  final Court? court;

  /// Throws on failure so this dialog can stay open and explain itself.
  final Future<void> Function(CourtDraft draft) onSubmit;

  final Future<String> Function(String path, {String? filename}) onUploadImage;

  final List<Sport> sports;
  final ViewState sportsState;
  final VoidCallback onReloadSports;

  final List<SportsComplex> complexes;
  final ViewState complexesState;
  final VoidCallback onReloadComplexes;

  /// Surface types seen on the loaded rows — there is no endpoint listing them,
  /// so these are the only values that can be proved acceptable.
  final List<String> knownSurfaces;

  bool get isEdit => court != null;

  /// Resolves to true when a save succeeded.
  static Future<bool> show(
    BuildContext context, {
    Court? court,
    required Future<void> Function(CourtDraft draft) onSubmit,
    required Future<String> Function(String path, {String? filename})
    onUploadImage,
    required List<Sport> sports,
    required ViewState sportsState,
    required VoidCallback onReloadSports,
    required List<SportsComplex> complexes,
    required ViewState complexesState,
    required VoidCallback onReloadComplexes,
    List<String> knownSurfaces = const [],
  }) async {
    AdminLog.ui(
      '${court == null ? 'Add' : 'Edit'} court dialog opened'
      '${court == null ? '' : ' for ${court.id}'}',
    );

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => CourtFormDialog(
        court: court,
        onSubmit: onSubmit,
        onUploadImage: onUploadImage,
        sports: sports,
        sportsState: sportsState,
        onReloadSports: onReloadSports,
        complexes: complexes,
        complexesState: complexesState,
        onReloadComplexes: onReloadComplexes,
        knownSurfaces: knownSurfaces,
      ),
    );

    AdminLog.ui('Court dialog closed (saved: ${saved ?? false})');
    return saved ?? false;
  }

  @override
  State<CourtFormDialog> createState() => _CourtFormDialogState();
}

class _CourtFormDialogState extends State<CourtFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _capacity;
  late final TextEditingController _surface;
  late final TextEditingController _equipment;
  late final TextEditingController _hourlyRate;

  SportsComplex? _complex;
  Sport? _sport;
  AdminUserStatus? _status;
  bool _lighting = false;
  bool _showOnFrontend = false;
  String? _image;

  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  /// Values this backend has already refused, keyed by payload field. Several
  /// of its columns are database enums, so a rejection is worth remembering
  /// rather than resubmitting.
  final Map<String, String> _rejected = <String, String>{};

  @override
  void initState() {
    super.initState();
    final court = widget.court;

    _name = TextEditingController(text: court?.name ?? '');
    _description = TextEditingController(text: court?.description ?? '');
    _capacity = TextEditingController(
      text: court?.capacity?.toString() ?? '',
    );
    _surface = TextEditingController(text: court?.surfaceType ?? '');
    _equipment = TextEditingController(text: court?.equipmentAvailable ?? '');
    _hourlyRate = TextEditingController(text: _numberText(court?.hourlyRate));

    _status = court?.status ?? AdminUserStatus.active;
    _lighting = court?.lightingAvailable ?? false;
    _showOnFrontend = court?.showOnFrontend ?? false;
    _image = court?.image;
    _complex = _matchComplex(court);
    _sport = _matchSport(court);

    AdminLog.life(
      'CourtFormDialog mounted (${widget.isEdit ? 'edit' : 'create'})',
    );
  }

  /// `800.0` reads as `800` in the box; a rate with paise keeps them.
  static String _numberText(num? value) {
    if (value == null) return '';
    if (value is int) return value.toString();
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  SportsComplex? _matchComplex(Court? court) {
    if (court == null) return null;
    final id = court.sportComplexId;
    if (id != null) {
      for (final complex in widget.complexes) {
        if (complex.id == id) return complex;
      }
    }
    final name = (court.sportComplexName ?? '').trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final complex in widget.complexes) {
      if (complex.name.trim().toLowerCase() == name) return complex;
    }
    return null;
  }

  Sport? _matchSport(Court? court) {
    if (court == null) return null;
    final id = court.sportId;
    if (id != null) {
      for (final sport in widget.sports) {
        if (sport.id == id) return sport;
      }
    }
    final name = (court.sportName ?? '').trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final sport in widget.sports) {
      if (sport.displayName.trim().toLowerCase() == name) return sport;
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant CourtFormDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Either catalogue may land after the dialog opened; preselect once it has.
    if (_complex == null && widget.complexes.isNotEmpty) {
      final matched = _matchComplex(widget.court);
      if (matched != null) setState(() => _complex = matched);
    }
    if (_sport == null && widget.sports.isNotEmpty) {
      final matched = _matchSport(widget.court);
      if (matched != null) setState(() => _sport = matched);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _description,
      _capacity,
      _surface,
      _equipment,
      _hourlyRate,
    ]) {
      controller.dispose();
    }
    AdminLog.life('CourtFormDialog disposed');
    super.dispose();
  }

  /// The sports on offer at the chosen complex, falling back to the full list
  /// when the catalogue does not cover it — a stale `/sports` read must never
  /// make a court unassignable.
  List<Sport> get _sportOptions {
    final complexId = _complex?.id;
    if (complexId == null) return widget.sports;

    final scoped = widget.sports
        .where((sport) => sport.sportComplexId == complexId)
        .toList(growable: false);
    return scoped.isEmpty ? widget.sports : scoped;
  }

  Future<void> _submit() async {
    if (_saving) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      AdminLog.ui('Court form failed local validation');
      return;
    }

    final draft = widget.isEdit
        // Only the eight documented fields; toUpdateJson drops the rest anyway,
        // but sending them from here would misrepresent the intent.
        ? CourtDraft(
            name: _name.text,
            description: _description.text,
            capacity: _intOrNull(_capacity.text),
            hourlyRate: _numOrNull(_hourlyRate.text),
            surfaceType: _surface.text,
            lightingAvailable: _lighting,
            equipmentAvailable: _equipment.text,
            status: _status,
          )
        : CourtDraft(
            name: _name.text,
            sportId: _sport?.id,
            sportComplexId: _complex?.id,
            description: _description.text,
            capacity: _intOrNull(_capacity.text),
            surfaceType: _surface.text,
            lightingAvailable: _lighting,
            equipmentAvailable: _equipment.text,
            hourlyRate: _numOrNull(_hourlyRate.text),
            // Empty rather than null so an image the admin removed is actually
            // cleared on the server record instead of silently kept.
            image: _image ?? '',
            status: _status,
            showOnFrontend: _showOnFrontend,
          );

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = const {};
    });

    try {
      await widget.onSubmit(draft);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      // Several columns here are database enums, and the backend names the
      // offending one in the message only — never in `errors`.
      final parsed = ServerFieldErrors.from(error, fieldLabel: 'Surface type');
      setState(() {
        _saving = false;
        _error = parsed.summary ?? error.message;
        _fieldErrors = parsed.fields;
        final rejected = parsed.rejected;
        if (rejected != null) _rejected[rejected.field] = rejected.value;
      });
      _formKey.currentState?.validate();
      AdminLog.failure('Court save rejected: ${error.message}');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this court. Please try again.';
      });
      AdminLog.failure(
        'Court save crashed',
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

  String? _serverError(List<String> keys) {
    for (final key in keys) {
      final message = _fieldErrors[key];
      if (message != null) return message;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final size = MediaQuery.sizeOf(context);
    final narrow = size.width < AdminTokens.mobileMax;
    final isEdit = widget.isEdit;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? AdminTokens.space4 : AdminTokens.space8,
        vertical: AdminTokens.space6,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 820,
          maxHeight: size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AdminFormHeader(
              title: isEdit ? 'Edit court' : 'Add court',
              subtitle: isEdit
                  ? widget.court!.displayName
                  : 'Create a court and open it for slot scheduling',
              icon: isEdit ? Icons.edit_outlined : Icons.grid_view_rounded,
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

                      // --- 1. General information ---------------------------
                      AdminFormSection(
                        icon: Icons.grid_view_outlined,
                        label: 'General Information',
                        color: tokens.accent,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminTextField(
                        controller: _name,
                        label: 'Court Name',
                        hint: 'e.g. Court 1',
                        icon: Icons.badge_outlined,
                        required: true,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          final server = _serverError(['name', 'courtName']);
                          if (server != null) return server;
                          if ((value ?? '').trim().isEmpty) {
                            return 'Court name is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      if (isEdit)
                        AdminFieldPair(
                          narrow: narrow,
                          first: AdminReadOnlyField(
                            label: 'Sports complex',
                            value: widget.court!.sportComplexName,
                            icon: Icons.stadium_outlined,
                          ),
                          second: AdminReadOnlyField(
                            label: 'Sport',
                            value: widget.court!.sportName,
                            icon: Icons.sports_tennis_outlined,
                          ),
                        )
                      else
                        AdminFieldPair(
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
                                // A sport not offered at the new venue would be
                                // an assignment the backend has to reject.
                                final sport = _sport;
                                if (sport != null &&
                                    complex != null &&
                                    sport.sportComplexId != null &&
                                    sport.sportComplexId != complex.id) {
                                  _sport = null;
                                }
                              });
                            },
                            validator: (complex) => complex == null
                                ? 'Sport complex is required'
                                : null,
                          ),
                          second: AdminCatalogueDropdown<Sport>(
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
                            onChanged: (sport) =>
                                setState(() => _sport = sport),
                          ),
                        ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminTextField(
                        controller: _description,
                        label: 'Description',
                        hint: 'What the court is used for',
                        icon: Icons.notes_rounded,
                        enabled: !_saving,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (_) => _serverError(['description']),
                      ),

                      // --- 2. Court details ---------------------------------
                      const SizedBox(height: AdminTokens.space6),
                      AdminFormSection(
                        icon: Icons.straighten_rounded,
                        label: 'Court Details',
                        color: tokens.info,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminFieldPair(
                        narrow: narrow,
                        first: AdminTextField(
                          controller: _capacity,
                          label: 'Capacity',
                          hint: 'e.g. 4',
                          icon: Icons.groups_outlined,
                          required: true,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          validator: (value) {
                            final server = _serverError(['capacity']);
                            if (server != null) return server;
                            final text = (value ?? '').trim();
                            if (text.isEmpty) return 'Capacity is required';
                            final parsed = int.tryParse(text);
                            if (parsed == null) return 'Numbers only';
                            if (parsed < 1) return 'Must be at least 1';
                            return null;
                          },
                        ),
                        second: AdminTextField(
                          controller: _hourlyRate,
                          label: 'Hourly Rate',
                          hint: 'e.g. 800',
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
                            final server = _serverError([
                              'hourlyRate',
                              'hourly_rate',
                            ]);
                            if (server != null) return server;
                            final text = (value ?? '').trim();
                            if (text.isEmpty) return 'Hourly rate is required';
                            final parsed = num.tryParse(text);
                            if (parsed == null) return 'Numbers only';
                            if (parsed < 0) return 'Cannot be negative';
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminSuggestionField(
                        controller: _surface,
                        label: 'Surface Type',
                        hint: 'e.g. Synthetic',
                        icon: Icons.texture_rounded,
                        enabled: !_saving,
                        suggestions: widget.knownSurfaces,
                        // Said plainly: this app cannot enumerate the column,
                        // so the values already in use are the safe ones.
                        note: widget.knownSurfaces.isEmpty
                            ? null
                            : 'Surfaces already in use on other courts.',
                        rejectedValue: _rejected['surfaceType'],
                        validator: (value) {
                          final text = (value ?? '').trim();
                          final refused = _rejected['surfaceType'];
                          if (refused != null &&
                              refused.toLowerCase() == text.toLowerCase()) {
                            return _serverError([
                                  'surfaceType',
                                  'surface_type',
                                ]) ??
                                '"$text" was rejected by the server';
                          }
                          return _serverError(['surfaceType', 'surface_type']);
                        },
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminFieldPair(
                        narrow: narrow,
                        first: AdminSwitchField(
                          label: 'Lighting Available',
                          value: _lighting,
                          enabled: !_saving,
                          onLabel: 'Floodlit',
                          offLabel: 'No lighting',
                          onIcon: Icons.light_mode_rounded,
                          offIcon: Icons.dark_mode_outlined,
                          onChanged: (value) {
                            AdminLog.ui('Form lighting → $value');
                            setState(() => _lighting = value);
                          },
                        ),
                        second: AdminTextField(
                          controller: _equipment,
                          label: 'Equipment Available',
                          hint: 'e.g. Rackets, balls',
                          icon: Icons.sports_handball_outlined,
                          enabled: !_saving,
                          validator: (_) => _serverError([
                            'equipmentAvailable',
                            'equipment_available',
                          ]),
                        ),
                      ),

                      // --- 3. Display settings ------------------------------
                      const SizedBox(height: AdminTokens.space6),
                      AdminFormSection(
                        icon: Icons.tune_rounded,
                        label: 'Display Settings',
                        color: tokens.warning,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      AdminFieldPair(
                        narrow: narrow,
                        first: AdminStatusDropdown(
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
                        // The update route does not document visibility — it
                        // has a PATCH route of its own — so an edit does not
                        // offer it here.
                        second: isEdit
                            ? AdminReadOnlyField(
                                label: 'Show on frontend',
                                value: widget.court!.showOnFrontend == null
                                    ? null
                                    : (widget.court!.showOnFrontend!
                                          ? 'Shown'
                                          : 'Hidden'),
                                icon: Icons.visibility_outlined,
                                note: 'Change this from the switch on the row.',
                              )
                            : AdminSwitchField(
                                label: 'Show on Frontend',
                                value: _showOnFrontend,
                                enabled: !_saving,
                                onLabel: 'Visible in the app',
                                offLabel: 'Hidden from the app',
                                onIcon: Icons.visibility_outlined,
                                offIcon: Icons.visibility_off_outlined,
                                onChanged: (value) {
                                  AdminLog.ui('Form showOnFrontend → $value');
                                  setState(() => _showOnFrontend = value);
                                },
                              ),
                      ),

                      // --- 4. Image -----------------------------------------
                      if (!isEdit) ...[
                        const SizedBox(height: AdminTokens.space6),
                        AdminFormSection(
                          icon: Icons.image_outlined,
                          label: 'Court Image',
                          color: const Color(0xFF3949AB),
                        ),
                        const SizedBox(height: AdminTokens.space4),
                        // The sports-complex module's field, reused as-is. The
                        // courts API documents no delete-image route, so no
                        // onServerDelete is passed and it offers Replace and
                        // Remove only.
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
            AdminFormFooter(
              saving: _saving,
              submitLabel: isEdit ? 'Save Changes' : 'Save Court',
              onCancel: _saving ? null : () => Navigator.of(context).pop(false),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
