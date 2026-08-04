import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/coach.dart';
import '../../domain/entities/sport.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import 'complex_image_field.dart';
import 'complex_picker_field.dart';

/// Add / Edit coach.
///
/// The layout follows the seven sections the spec lays out — Basic Information,
/// Sports Assignment, Professional Details, Availability, Biography, Status,
/// Profile Image — and reuses the console's existing venue picker and image
/// field rather than growing new ones.
///
/// [coach] null means create (`POST /coaches`), otherwise edit
/// (`PUT /coaches/{id}`). The update route documents exactly eleven editable
/// fields, so on an edit the email, password and the sport / complex / ground
/// assignment render read-only with a notice explaining why — the same
/// treatment the Security Guard module gives its own fixed fields.
class CoachFormDialog extends StatefulWidget {
  const CoachFormDialog({
    super.key,
    required this.onSubmit,
    required this.onUploadImage,
    required this.sports,
    required this.sportsState,
    required this.onReloadSports,
    required this.complexes,
    required this.complexesState,
    required this.onReloadComplexes,
    this.coach,
    this.knownGrounds = const [],
  });

  final Coach? coach;

  /// Throws on failure so this dialog can stay open and explain itself.
  final Future<void> Function(CoachDraft draft) onSubmit;

  final Future<String> Function(String path, {String? filename}) onUploadImage;

  final List<Sport> sports;
  final ViewState sportsState;
  final VoidCallback onReloadSports;

  final List<SportsComplex> complexes;
  final ViewState complexesState;
  final VoidCallback onReloadComplexes;

  /// Grounds seen on the rows so far — there is no `/grounds` route, so the
  /// suggestions are learned rather than hardcoded.
  final List<String> knownGrounds;

  bool get isEdit => coach != null;

  /// Resolves to true when a save succeeded.
  static Future<bool> show(
    BuildContext context, {
    Coach? coach,
    required Future<void> Function(CoachDraft draft) onSubmit,
    required Future<String> Function(String path, {String? filename})
    onUploadImage,
    required List<Sport> sports,
    required ViewState sportsState,
    required VoidCallback onReloadSports,
    required List<SportsComplex> complexes,
    required ViewState complexesState,
    required VoidCallback onReloadComplexes,
    List<String> knownGrounds = const [],
  }) async {
    AdminLog.ui(
      '${coach == null ? 'Add' : 'Edit'} coach dialog opened'
      '${coach == null ? '' : ' for ${coach.id}'}',
    );

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => CoachFormDialog(
        coach: coach,
        onSubmit: onSubmit,
        onUploadImage: onUploadImage,
        sports: sports,
        sportsState: sportsState,
        onReloadSports: onReloadSports,
        complexes: complexes,
        complexesState: complexesState,
        onReloadComplexes: onReloadComplexes,
        knownGrounds: knownGrounds,
      ),
    );

    AdminLog.ui('Coach dialog closed (saved: ${saved ?? false})');
    return saved ?? false;
  }

  @override
  State<CoachFormDialog> createState() => _CoachFormDialogState();
}

class _CoachFormDialogState extends State<CoachFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _password;
  late final TextEditingController _ground;
  late final TextEditingController _experience;
  late final TextEditingController _certification;
  late final TextEditingController _qualifications;
  late final TextEditingController _specialization;
  late final TextEditingController _price;
  late final TextEditingController _availability;
  late final TextEditingController _bio;

  SportsComplex? _complex;
  Sport? _sport;
  AdminUserStatus? _status;

  bool _obscurePassword = true;

  /// The stored image value — a URL from the upload route, or null.
  String? _image;

  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    final coach = widget.coach;

    _name = TextEditingController(text: coach?.name ?? '');
    _email = TextEditingController(text: coach?.email ?? '');
    _phone = TextEditingController(text: coach?.phone ?? '');
    _password = TextEditingController();
    _ground = TextEditingController(text: coach?.ground ?? '');
    _experience = TextEditingController(text: coach?.experience ?? '');
    _certification = TextEditingController(text: coach?.certification ?? '');
    _qualifications = TextEditingController(text: coach?.qualifications ?? '');
    _specialization = TextEditingController(text: coach?.specialization ?? '');
    _price = TextEditingController(text: _priceText(coach?.price));
    _availability = TextEditingController(text: coach?.availabilityRaw ?? '');
    _bio = TextEditingController(text: coach?.bio ?? '');

    _status = coach?.status ?? AdminUserStatus.active;
    _image = coach?.image;
    _complex = _matchComplex(coach);
    _sport = _matchSport(coach);

    AdminLog.life(
      'CoachFormDialog mounted (${widget.isEdit ? 'edit' : 'create'})',
    );
  }

  /// `1200.0` reads as `1200` in the box; a fee with paise keeps them.
  static String _priceText(num? value) {
    if (value == null) return '';
    if (value is int) return value.toString();
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toString();
  }

  SportsComplex? _matchComplex(Coach? coach) {
    if (coach == null) return null;

    final id = coach.sportComplexId;
    if (id != null) {
      for (final complex in widget.complexes) {
        if (complex.id == id) return complex;
      }
    }

    final name = (coach.sportComplexName ?? '').trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final complex in widget.complexes) {
      if (complex.name.trim().toLowerCase() == name) return complex;
    }
    return null;
  }

  Sport? _matchSport(Coach? coach) {
    if (coach == null) return null;

    final id = coach.sportId;
    if (id != null) {
      for (final sport in widget.sports) {
        if (sport.id == id) return sport;
      }
    }

    final name = (coach.sportName ?? '').trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final sport in widget.sports) {
      if (sport.displayName.trim().toLowerCase() == name) return sport;
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant CoachFormDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Either catalogue may land after the dialog opened; preselect once it has.
    if (_complex == null && widget.complexes.isNotEmpty) {
      final matched = _matchComplex(widget.coach);
      if (matched != null) setState(() => _complex = matched);
    }
    if (_sport == null && widget.sports.isNotEmpty) {
      final matched = _matchSport(widget.coach);
      if (matched != null) setState(() => _sport = matched);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _phone,
      _password,
      _ground,
      _experience,
      _certification,
      _qualifications,
      _specialization,
      _price,
      _availability,
      _bio,
    ]) {
      controller.dispose();
    }
    AdminLog.life('CoachFormDialog disposed');
    super.dispose();
  }

  /// The sports on offer at the chosen complex.
  ///
  /// A complex whose sports the catalogue does not cover falls back to the full
  /// list rather than an empty dropdown — a stale or partial `/sports` read
  /// must never make the coach unassignable.
  List<Sport> get _sportOptions {
    final complexId = _complex?.id;
    if (complexId == null) return widget.sports;

    final scoped = widget.sports
        .where((sport) => sport.sportComplexId == complexId)
        .toList(growable: false);
    return scoped.isEmpty ? widget.sports : scoped;
  }

  bool get _sportsAreScoped {
    final complexId = _complex?.id;
    if (complexId == null) return false;
    return widget.sports.any((sport) => sport.sportComplexId == complexId);
  }

  Future<void> _submit() async {
    if (_saving) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      AdminLog.ui('Coach form failed local validation');
      return;
    }

    final draft = widget.isEdit
        // Only the eleven documented fields; toUpdateJson drops the rest
        // anyway, but sending them from here would misrepresent the intent.
        ? CoachDraft(
            name: _name.text,
            phone: _phone.text,
            experience: _experience.text,
            price: _numOrNull(_price.text),
            certification: _certification.text,
            qualifications: _qualifications.text,
            specialization: _specialization.text,
            bio: _bio.text,
            availability: _availability.text,
            // Empty rather than null so an image the admin removed is actually
            // cleared on the server record instead of silently kept.
            image: _image ?? '',
            status: _status,
          )
        : CoachDraft(
            name: _name.text,
            email: _email.text,
            phone: _phone.text,
            password: _password.text,
            sportId: _sport?.id,
            sportComplexId: _complex?.id,
            ground: _ground.text,
            price: _numOrNull(_price.text),
            availability: _availability.text,
            certification: _certification.text,
            bio: _bio.text,
            image: _image ?? '',
            experience: _experience.text,
            specialization: _specialization.text,
            qualifications: _qualifications.text,
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
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.message;
        _fieldErrors = _readFieldErrors(error.errors);
      });
      _formKey.currentState?.validate();
      AdminLog.failure('Coach save rejected: ${error.message}');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this coach. Please try again.';
      });
      AdminLog.failure(
        'Coach save crashed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// A blank fee is "not specified", not zero.
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
            _Header(
              title: isEdit ? 'Edit coach' : 'Add coach',
              subtitle: isEdit
                  ? widget.coach!.displayName
                  : 'Create a coaching account and assign it to a sport',
              icon: isEdit ? Icons.edit_outlined : Icons.sports_rounded,
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
                        _ErrorBanner(message: _error!),
                        const SizedBox(height: AdminTokens.space4),
                      ],

                      // --- 1. Basic information ------------------------------
                      _Section(
                        icon: Icons.person_outline_rounded,
                        label: 'Basic Information',
                        color: tokens.accent,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Field(
                        controller: _name,
                        label: 'Name',
                        hint: 'e.g. Rahul Sharma',
                        icon: Icons.badge_outlined,
                        required: true,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          final server = _serverError(['name', 'coachName']);
                          if (server != null) return server;
                          if ((value ?? '').trim().isEmpty) {
                            return 'Name is required';
                          }
                          if ((value ?? '').trim().length < 2) {
                            return 'Enter the full name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Pair(
                        narrow: narrow,
                        first: isEdit
                            // The update route does not accept an email, so it
                            // is shown rather than offered.
                            ? _ReadOnlyField(
                                label: 'Email',
                                value: widget.coach!.email,
                                icon: Icons.mail_outline_rounded,
                              )
                            : _Field(
                                controller: _email,
                                label: 'Email',
                                hint: 'coach@nahatasports.com',
                                icon: Icons.mail_outline_rounded,
                                required: true,
                                enabled: !_saving,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  final server = _serverError(['email']);
                                  if (server != null) return server;
                                  final text = (value ?? '').trim();
                                  if (text.isEmpty) {
                                    return 'Email is required';
                                  }
                                  if (!_looksLikeEmail(text)) {
                                    return 'Enter a valid email address';
                                  }
                                  return null;
                                },
                              ),
                        second: _Field(
                          controller: _phone,
                          label: 'Phone',
                          hint: '10-digit mobile number',
                          icon: Icons.phone_outlined,
                          required: !isEdit,
                          enabled: !_saving,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(15),
                          ],
                          validator: (value) {
                            final server = _serverError([
                              'phone',
                              'phoneNumber',
                            ]);
                            if (server != null) return server;
                            final text = (value ?? '').trim();
                            if (text.isEmpty) {
                              return isEdit ? null : 'Phone is required';
                            }
                            final digits = text.replaceAll(
                              RegExp(r'[^0-9]'),
                              '',
                            );
                            if (digits.length < 10) {
                              return 'Enter at least 10 digits';
                            }
                            return null;
                          },
                        ),
                      ),
                      if (!isEdit) ...[
                        const SizedBox(height: AdminTokens.space4),
                        _Field(
                          controller: _password,
                          label: 'Password',
                          hint: 'At least 6 characters',
                          icon: Icons.lock_outline_rounded,
                          required: true,
                          enabled: !_saving,
                          obscureText: _obscurePassword,
                          suffix: IconButton(
                            onPressed: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              size: 17,
                            ),
                            color: tokens.textMuted,
                            tooltip: _obscurePassword ? 'Show' : 'Hide',
                          ),
                          validator: (value) {
                            final server = _serverError(['password']);
                            if (server != null) return server;
                            final text = value ?? '';
                            if (text.isEmpty) return 'Set an initial password';
                            if (text.length < 6) {
                              return 'Use at least 6 characters';
                            }
                            return null;
                          },
                        ),
                      ],

                      // --- 2. Sports assignment ------------------------------
                      const SizedBox(height: AdminTokens.space6),
                      _Section(
                        icon: Icons.sports_tennis_outlined,
                        label: 'Sports Assignment',
                        color: tokens.info,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      if (isEdit) ...[
                        _Note(
                          icon: Icons.lock_outline_rounded,
                          text:
                              'The assignment is fixed after creation — the '
                              'update route does not accept the sport, complex '
                              'or ground. Delete and re-create the coach to '
                              'move them.',
                        ),
                        const SizedBox(height: AdminTokens.space4),
                        _Pair(
                          narrow: narrow,
                          first: _ReadOnlyField(
                            label: 'Sport complex',
                            value: widget.coach!.sportComplexName,
                            icon: Icons.stadium_outlined,
                          ),
                          second: _ReadOnlyField(
                            label: 'Sport',
                            value: widget.coach!.sportName,
                            icon: Icons.sports_tennis_outlined,
                          ),
                        ),
                        const SizedBox(height: AdminTokens.space4),
                        _ReadOnlyField(
                          label: 'Ground',
                          value: widget.coach!.ground,
                          icon: Icons.place_outlined,
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
                                // A sport that is not offered at the new venue
                                // would be an assignment the backend has to
                                // reject, so it is dropped here instead.
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
                          second: _SportDropdown(
                            sports: _sportOptions,
                            state: widget.sportsState,
                            onReload: widget.onReloadSports,
                            value: _sport,
                            enabled: !_saving,
                            scoped: _sportsAreScoped,
                            error: _serverError(const ['sportId', 'sport_id']),
                            onChanged: (sport) {
                              AdminLog.ui('Form sport → ${sport?.id ?? 'none'}');
                              setState(() => _sport = sport);
                            },
                          ),
                        ),
                        const SizedBox(height: AdminTokens.space4),
                        _GroundField(
                          controller: _ground,
                          enabled: !_saving,
                          suggestions: widget.knownGrounds,
                          serverError: _serverError(const [
                            'ground',
                            'groundName',
                          ]),
                        ),
                      ],

                      // --- 3. Professional details ---------------------------
                      const SizedBox(height: AdminTokens.space6),
                      _Section(
                        icon: Icons.workspace_premium_outlined,
                        label: 'Professional Details',
                        color: tokens.success,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Pair(
                        narrow: narrow,
                        first: _Field(
                          controller: _experience,
                          label: 'Experience',
                          hint: 'e.g. 5 years',
                          icon: Icons.timeline_rounded,
                          enabled: !_saving,
                          validator: (_) => _serverError(['experience']),
                        ),
                        second: _Field(
                          controller: _price,
                          label: 'Price',
                          hint: 'e.g. 1200',
                          icon: Icons.currency_rupee_rounded,
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
                            final server = _serverError(['price', 'fee']);
                            if (server != null) return server;
                            final text = (value ?? '').trim();
                            if (text.isEmpty) return null;
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
                        first: _Field(
                          controller: _certification,
                          label: 'Certification',
                          hint: 'e.g. NIS Level 2',
                          icon: Icons.verified_outlined,
                          enabled: !_saving,
                          validator: (_) => _serverError([
                            'certification',
                            'certifications',
                          ]),
                        ),
                        second: _Field(
                          controller: _qualifications,
                          label: 'Qualification',
                          hint: 'e.g. BPEd, Sports Science',
                          icon: Icons.school_outlined,
                          enabled: !_saving,
                          validator: (_) => _serverError([
                            'qualifications',
                            'qualification',
                          ]),
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Field(
                        controller: _specialization,
                        label: 'Specialization',
                        hint: 'e.g. Junior coaching, doubles strategy',
                        icon: Icons.stars_outlined,
                        enabled: !_saving,
                        validator: (_) => _serverError([
                          'specialization',
                          'specialisation',
                        ]),
                      ),

                      // --- 4. Availability -----------------------------------
                      const SizedBox(height: AdminTokens.space6),
                      _Section(
                        icon: Icons.calendar_month_outlined,
                        label: 'Availability',
                        color: tokens.warning,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _AvailabilityField(
                        controller: _availability,
                        enabled: !_saving,
                        serverError: _serverError(const [
                          'availability',
                          'availableDays',
                        ]),
                      ),

                      // --- 5. Biography --------------------------------------
                      const SizedBox(height: AdminTokens.space6),
                      _Section(
                        icon: Icons.notes_rounded,
                        label: 'Biography',
                        color: const Color(0xFF0EA5E9),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Field(
                        controller: _bio,
                        label: 'Bio',
                        hint: 'Background, coaching style and achievements',
                        icon: Icons.notes_rounded,
                        enabled: !_saving,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (_) => _serverError(['bio', 'about']),
                      ),

                      // --- 6. Status -----------------------------------------
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
                          AdminLog.ui('Form status → ${status?.slug ?? 'none'}');
                          setState(() => _status = status);
                        },
                      ),

                      // --- 7. Profile image ----------------------------------
                      const SizedBox(height: AdminTokens.space6),
                      _Section(
                        icon: Icons.image_outlined,
                        label: 'Profile Image',
                        color: const Color(0xFF3949AB),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      // The sports-complex module's field, reused as-is. The
                      // coaches API has no delete-image route, so no
                      // onServerDelete is passed and the field offers Replace
                      // and Remove only.
                      ComplexImageField(
                        imageUrl: _image,
                        enabled: !_saving,
                        onUpload: widget.onUploadImage,
                        onChanged: (url) => setState(() => _image = url),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _Footer(
              saving: _saving,
              submitLabel: isEdit ? 'Save Changes' : 'Save Coach',
              onCancel: _saving ? null : () => Navigator.of(context).pop(false),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }

  static bool _looksLikeEmail(String value) =>
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
}

// -----------------------------------------------------------------------------
// Availability
// -----------------------------------------------------------------------------

/// Day chips over the free-text field the API actually stores.
///
/// The text box is the source of truth — it is what a save sends — and the
/// chips are a shortcut for writing it. When the stored value is something the
/// day list cannot express ("Weekdays 6–9am"), the chips go read-only rather
/// than silently rewriting the admin's own words.
class _AvailabilityField extends StatefulWidget {
  const _AvailabilityField({
    required this.controller,
    required this.enabled,
    this.serverError,
  });

  final TextEditingController controller;
  final bool enabled;
  final String? serverError;

  @override
  State<_AvailabilityField> createState() => _AvailabilityFieldState();
}

class _AvailabilityFieldState extends State<_AvailabilityField> {
  CoachAvailability get _parsed =>
      CoachAvailability.parse(widget.controller.text);

  void _toggle(Weekday day) {
    if (!widget.enabled) return;

    final current = _parsed;
    if (current.isCustom) return;

    final days = current.days.toSet();
    if (!days.remove(day)) days.add(day);

    final text = CoachAvailability.compose(days);
    AdminLog.ui('Form availability → ${days.length} days');
    widget.controller.text = text;
    setState(() {});
  }

  void _selectAll() {
    if (!widget.enabled) return;
    widget.controller.text = CoachAvailability.compose(Weekday.values);
    setState(() {});
  }

  void _clear() {
    if (!widget.enabled) return;
    widget.controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final availability = _parsed;
    final custom = availability.isCustom;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const Expanded(child: _Label('Available days')),
            if (!custom) ...[
              TextButton(
                onPressed: widget.enabled ? _selectAll : null,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AdminTokens.space2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('All days', style: TextStyle(fontSize: 11.5)),
              ),
              if (availability.isNotEmpty)
                TextButton(
                  onPressed: widget.enabled ? _clear : null,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AdminTokens.space2,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Clear', style: TextStyle(fontSize: 11.5)),
                ),
            ],
          ],
        ),
        const SizedBox(height: AdminTokens.space2),
        Wrap(
          spacing: AdminTokens.space2,
          runSpacing: AdminTokens.space2,
          children: Weekday.values.map((day) {
            final selected = availability.days.contains(day);
            return _DayChip(
              day: day,
              selected: selected,
              enabled: widget.enabled && !custom,
              onTap: () => _toggle(day),
            );
          }).toList(),
        ),
        if (custom) ...[
          const SizedBox(height: AdminTokens.space3),
          _Note(
            icon: Icons.edit_note_rounded,
            text:
                'This schedule is stored as free text, so the day chips are '
                'read-only. Edit the field below, or clear it to pick days '
                'again.',
          ),
        ],
        const SizedBox(height: AdminTokens.space4),
        TextFormField(
          controller: widget.controller,
          enabled: widget.enabled,
          maxLines: 3,
          minLines: 1,
          onChanged: (_) => setState(() {}),
          validator: (_) => widget.serverError,
          style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
          decoration: InputDecoration(
            labelText: 'Availability (sent as written)',
            hintText: 'Monday, Wednesday, Friday',
            alignLabelWithHint: true,
            prefixIcon: Icon(
              Icons.schedule_rounded,
              size: 18,
              color: tokens.textMuted,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 44,
              minHeight: 44,
            ),
          ),
        ),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.day,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final Weekday day;
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
                day.shortLabel,
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

// -----------------------------------------------------------------------------
// Pickers
// -----------------------------------------------------------------------------

/// The sport dropdown, scoped to the chosen complex when the catalogue knows
/// which sports it offers.
class _SportDropdown extends StatelessWidget {
  const _SportDropdown({
    required this.sports,
    required this.state,
    required this.onReload,
    required this.value,
    required this.enabled,
    required this.scoped,
    required this.onChanged,
    this.error,
  });

  final List<Sport> sports;
  final ViewState state;
  final VoidCallback onReload;
  final Sport? value;
  final bool enabled;

  /// True when [sports] has already been narrowed to one complex.
  final bool scoped;

  final ValueChanged<Sport?> onChanged;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    // A selection that is no longer in the option list would assert inside
    // DropdownButtonFormField, so it is dropped rather than passed through.
    final selected = sports.any((sport) => sport.id == value?.id)
        ? value
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            const _Label('Sport', required: true),
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
        DropdownButtonFormField<Sport>(
          initialValue: selected,
          isExpanded: true,
          onChanged: enabled && sports.isNotEmpty ? onChanged : null,
          validator: (picked) {
            if (error != null) return error;
            if (picked == null) return 'Sport is required';
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
                ? 'Loading sports…'
                : (sports.isEmpty ? 'No sports available' : 'Select a sport'),
            style: TextStyle(fontSize: 13.5, color: tokens.textMuted),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(
              Icons.sports_tennis_outlined,
              size: 18,
              color: tokens.textMuted,
            ),
          ),
          items: sports
              .map(
                (sport) => DropdownMenuItem<Sport>(
                  value: sport,
                  child: Text(
                    sport.displayName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
              )
              .toList(),
        ),
        if (scoped) ...[
          const SizedBox(height: 6),
          Text(
            'Showing the sports offered at the selected complex.',
            style: TextStyle(color: tokens.textMuted, fontSize: 11.5),
          ),
        ],
      ],
    );
  }
}

/// Ground, as free text with the grounds already seen offered as shortcuts.
/// There is no `/grounds` endpoint, so nothing here is hardcoded and any value
/// can still be typed.
class _GroundField extends StatelessWidget {
  const _GroundField({
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
        const _Label('Ground'),
        const SizedBox(height: AdminTokens.space2),
        TextFormField(
          controller: controller,
          enabled: enabled,
          textCapitalization: TextCapitalization.words,
          validator: (_) => serverError,
          style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. Court 3, Main Arena',
            prefixIcon: Icon(
              Icons.place_outlined,
              size: 18,
              color: tokens.textMuted,
            ),
            suffixIcon: suggestions.isEmpty
                ? null
                : PopupMenuButton<String>(
                    tooltip: 'Grounds already in use',
                    icon: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: tokens.textMuted,
                    ),
                    onSelected: (value) => controller.text = value,
                    itemBuilder: (context) => suggestions
                        .map(
                          (ground) => PopupMenuItem<String>(
                            value: ground,
                            height: 40,
                            child: Text(
                              ground,
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

// -----------------------------------------------------------------------------
// Fields
// -----------------------------------------------------------------------------

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
    this.obscureText = false,
    this.suffix,
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
  final bool obscureText;
  final Widget? suffix;
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
          // An obscured field cannot be multiline.
          maxLines: obscureText ? 1 : maxLines,
          obscureText: obscureText,
          validator: validator,
          style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: tokens.textMuted),
            // A multiline box aligns its icon to the first line.
            prefixIconConstraints: maxLines > 1
                ? const BoxConstraints(minWidth: 44, minHeight: 44)
                : null,
            suffixIcon: suffix,
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
                  text.isEmpty ? '—' : text,
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
              Icon(Icons.lock_outline_rounded, size: 15, color: tokens.textMuted),
            ],
          ),
        ),
      ],
    );
  }
}
