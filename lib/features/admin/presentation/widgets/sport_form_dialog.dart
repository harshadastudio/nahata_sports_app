import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/sport.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import 'complex_image_field.dart';
import 'complex_picker_field.dart';

/// Add / Edit sport.
///
/// The layout follows the five sections the spec lays out — Basic Information,
/// Training Information, Descriptions, Display Settings, Image — and reuses the
/// console's existing venue picker and image field rather than growing new
/// ones.
///
/// [sport] null means create (`POST /sports`), otherwise edit
/// (`PUT /sports/{id}`). Every field stays editable on an edit: the route
/// documents all of them as updatable.
class SportFormDialog extends StatefulWidget {
  const SportFormDialog({
    super.key,
    required this.onSubmit,
    required this.onUploadImage,
    required this.complexes,
    required this.complexesState,
    required this.onReloadComplexes,
    this.sport,
  });

  final Sport? sport;

  /// Throws on failure so this dialog can stay open and explain itself.
  final Future<void> Function(SportDraft draft) onSubmit;

  final Future<String> Function(String path, {String? filename}) onUploadImage;

  final List<SportsComplex> complexes;
  final ViewState complexesState;
  final VoidCallback onReloadComplexes;

  bool get isEdit => sport != null;

  /// Resolves to true when a save succeeded.
  static Future<bool> show(
    BuildContext context, {
    Sport? sport,
    required Future<void> Function(SportDraft draft) onSubmit,
    required Future<String> Function(String path, {String? filename})
    onUploadImage,
    required List<SportsComplex> complexes,
    required ViewState complexesState,
    required VoidCallback onReloadComplexes,
  }) async {
    AdminLog.ui(
      '${sport == null ? 'Add' : 'Edit'} sport dialog opened'
      '${sport == null ? '' : ' for ${sport.id}'}',
    );

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => SportFormDialog(
        sport: sport,
        onSubmit: onSubmit,
        onUploadImage: onUploadImage,
        complexes: complexes,
        complexesState: complexesState,
        onReloadComplexes: onReloadComplexes,
      ),
    );

    AdminLog.ui('Sport dialog closed (saved: ${saved ?? false})');
    return saved ?? false;
  }

  @override
  State<SportFormDialog> createState() => _SportFormDialogState();
}

class _SportFormDialogState extends State<SportFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _minAge;
  late final TextEditingController _maxAge;
  late final TextEditingController _duration;
  late final TextEditingController _allowedMembers;
  late final TextEditingController _description;
  late final TextEditingController _equipment;
  late final TextEditingController _achievements;
  late final TextEditingController _completeInformation;

  SportsComplex? _complex;
  SportCategory? _category;
  AdminUserStatus? _status;
  bool _showOnFrontend = false;

  /// The stored image value — a URL from the upload route, or null.
  String? _image;

  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    final sport = widget.sport;

    _name = TextEditingController(text: sport?.name ?? '');
    _minAge = TextEditingController(text: sport?.minAge?.toString() ?? '');
    _maxAge = TextEditingController(text: sport?.maxAge?.toString() ?? '');
    _duration = TextEditingController(text: sport?.duration ?? '');
    _allowedMembers = TextEditingController(
      text: sport?.allowedMembers?.toString() ?? '',
    );
    _description = TextEditingController(text: sport?.description ?? '');
    _equipment = TextEditingController(text: sport?.equipmentRequired ?? '');
    _achievements = TextEditingController(text: sport?.achievements ?? '');
    _completeInformation = TextEditingController(
      text: sport?.completeInformation ?? '',
    );

    _category = sport?.category;
    _status = sport?.status ?? AdminUserStatus.active;
    _showOnFrontend = sport?.showOnFrontend ?? false;
    _image = sport?.image;
    _complex = _matchComplex(sport);

    AdminLog.life(
      'SportFormDialog mounted (${widget.isEdit ? 'edit' : 'create'})',
    );
  }

  SportsComplex? _matchComplex(Sport? sport) {
    if (sport == null) return null;

    final id = sport.sportComplexId;
    if (id != null) {
      for (final complex in widget.complexes) {
        if (complex.id == id) return complex;
      }
    }

    final name = (sport.sportComplexName ?? '').trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final complex in widget.complexes) {
      if (complex.name.trim().toLowerCase() == name) return complex;
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant SportFormDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The venue list may land after the dialog opened; preselect once it does.
    if (_complex == null && widget.complexes.isNotEmpty) {
      final matched = _matchComplex(widget.sport);
      if (matched != null) setState(() => _complex = matched);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _minAge,
      _maxAge,
      _duration,
      _allowedMembers,
      _description,
      _equipment,
      _achievements,
      _completeInformation,
    ]) {
      controller.dispose();
    }
    AdminLog.life('SportFormDialog disposed');
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      AdminLog.ui('Sport form failed local validation');
      return;
    }

    final draft = SportDraft(
      name: _name.text,
      sportComplexId: _complex?.id,
      description: _description.text,
      category: _category,
      minAge: _intOrNull(_minAge.text),
      maxAge: _intOrNull(_maxAge.text),
      duration: _duration.text,
      equipmentRequired: _equipment.text,
      // Empty rather than null so an image the admin removed is actually
      // cleared on the server record instead of silently kept.
      image: _image ?? '',
      allowedMembers: _intOrNull(_allowedMembers.text),
      achievements: _achievements.text,
      completeInformation: _completeInformation.text,
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
      setState(() {
        _saving = false;
        _error = error.message;
        _fieldErrors = _readFieldErrors(error.errors);
      });
      _formKey.currentState?.validate();
      AdminLog.failure('Sport save rejected: ${error.message}');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this sport. Please try again.';
      });
      AdminLog.failure(
        'Sport save crashed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// A blank age or member count is "not specified", not zero.
  static int? _intOrNull(String value) {
    final text = value.trim();
    if (text.isEmpty) return null;
    return int.tryParse(text);
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

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: narrow ? AdminTokens.space4 : AdminTokens.space8,
        vertical: AdminTokens.space6,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 780,
          maxHeight: size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(
              title: widget.isEdit ? 'Edit sport' : 'Add sport',
              subtitle: widget.isEdit
                  ? widget.sport!.displayName
                  : 'Create a sport and offer it at a complex',
              icon: widget.isEdit
                  ? Icons.edit_outlined
                  : Icons.sports_tennis_rounded,
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
                        icon: Icons.sports_tennis_outlined,
                        label: 'Basic Information',
                        color: tokens.accent,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Field(
                        controller: _name,
                        label: 'Sport Name',
                        hint: 'e.g. Badminton',
                        icon: Icons.badge_outlined,
                        required: true,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          final server = _serverError(['name', 'sportName']);
                          if (server != null) return server;
                          if ((value ?? '').trim().isEmpty) {
                            return 'Sport name is required';
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
                          onChanged: (complex) =>
                              setState(() => _complex = complex),
                          validator: (complex) => complex == null
                              ? 'Sport complex is required'
                              : null,
                        ),
                        second: _Dropdown<SportCategory>(
                          label: 'Category',
                          icon: Icons.category_outlined,
                          value: _category,
                          required: true,
                          enabled: !_saving,
                          items: SportCategory.values,
                          labelOf: (category) => category.label,
                          error: _serverError(const ['category']),
                          emptyMessage: 'Category is required',
                          onChanged: (category) {
                            AdminLog.ui(
                              'Form category → ${category?.slug ?? 'none'}',
                            );
                            setState(() => _category = category);
                          },
                        ),
                      ),

                      // --- 2. Training information ---------------------------
                      const SizedBox(height: AdminTokens.space6),
                      _Section(
                        icon: Icons.fitness_center_rounded,
                        label: 'Training Information',
                        color: tokens.info,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Pair(
                        narrow: narrow,
                        first: _Field(
                          controller: _minAge,
                          label: 'Minimum Age',
                          hint: 'e.g. 6',
                          icon: Icons.child_care_outlined,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          validator: (value) {
                            final server = _serverError(['minAge', 'min_age']);
                            if (server != null) return server;
                            return _validateAge(value);
                          },
                        ),
                        second: _Field(
                          controller: _maxAge,
                          label: 'Maximum Age',
                          hint: 'e.g. 45',
                          icon: Icons.elderly_outlined,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(3),
                          ],
                          onChanged: (_) {
                            // Keeps "must be at least the minimum" honest while
                            // the other box is still being typed.
                            if (_minAge.text.isNotEmpty) {
                              _formKey.currentState?.validate();
                            }
                          },
                          validator: (value) {
                            final server = _serverError(['maxAge', 'max_age']);
                            if (server != null) return server;

                            final basic = _validateAge(value);
                            if (basic != null) return basic;

                            final min = _intOrNull(_minAge.text);
                            final max = _intOrNull(value ?? '');
                            if (min != null && max != null && max < min) {
                              return 'Must be at least the minimum age';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Pair(
                        narrow: narrow,
                        first: _Field(
                          controller: _duration,
                          label: 'Duration',
                          hint: 'e.g. 60 mins',
                          icon: Icons.timer_outlined,
                          enabled: !_saving,
                          validator: (_) => _serverError(['duration']),
                        ),
                        second: _Field(
                          controller: _allowedMembers,
                          label: 'Allowed Members',
                          hint: 'e.g. 4',
                          icon: Icons.groups_outlined,
                          enabled: !_saving,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          validator: (value) {
                            final server = _serverError([
                              'allowedMembers',
                              'allowed_members',
                            ]);
                            if (server != null) return server;
                            final text = (value ?? '').trim();
                            if (text.isEmpty) return null;
                            final parsed = int.tryParse(text);
                            if (parsed == null) return 'Numbers only';
                            if (parsed < 1) return 'Must be at least 1';
                            return null;
                          },
                        ),
                      ),

                      // --- 3. Descriptions -----------------------------------
                      const SizedBox(height: AdminTokens.space6),
                      _Section(
                        icon: Icons.notes_rounded,
                        label: 'Descriptions',
                        color: tokens.success,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Field(
                        controller: _description,
                        label: 'Description',
                        hint: 'What the sport involves and who it suits',
                        icon: Icons.notes_rounded,
                        enabled: !_saving,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (_) => _serverError(['description']),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Field(
                        controller: _equipment,
                        label: 'Equipment Required',
                        hint: 'e.g. Racket, shuttlecocks, non-marking shoes',
                        icon: Icons.sports_handball_outlined,
                        enabled: !_saving,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (_) => _serverError([
                          'equipmentRequired',
                          'equipment_required',
                        ]),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Field(
                        controller: _achievements,
                        label: 'Achievements',
                        hint: 'Notable results, titles and milestones',
                        icon: Icons.emoji_events_outlined,
                        enabled: !_saving,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (_) => _serverError(['achievements']),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Field(
                        controller: _completeInformation,
                        label: 'Complete Information',
                        hint: 'Anything else worth publishing about this sport',
                        icon: Icons.menu_book_outlined,
                        enabled: !_saving,
                        maxLines: 5,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (_) => _serverError([
                          'completeInformation',
                          'complete_information',
                        ]),
                      ),

                      // --- 4. Display settings -------------------------------
                      const SizedBox(height: AdminTokens.space6),
                      _Section(
                        icon: Icons.tune_rounded,
                        label: 'Display Settings',
                        color: tokens.warning,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Pair(
                        narrow: narrow,
                        first: _Dropdown<AdminUserStatus>(
                          label: 'Status',
                          icon: Icons.toggle_on_outlined,
                          value: _status,
                          enabled: !_saving,
                          items: const [
                            AdminUserStatus.active,
                            AdminUserStatus.inactive,
                          ],
                          labelOf: (status) => status.label,
                          error: _serverError(const ['status']),
                          onChanged: (status) {
                            AdminLog.ui(
                              'Form status → ${status?.slug ?? 'none'}',
                            );
                            setState(() => _status = status);
                          },
                        ),
                        second: _VisibilityToggle(
                          value: _showOnFrontend,
                          enabled: !_saving,
                          onChanged: (value) {
                            AdminLog.ui('Form showOnFrontend → $value');
                            setState(() => _showOnFrontend = value);
                          },
                        ),
                      ),

                      // --- 5. Image ------------------------------------------
                      const SizedBox(height: AdminTokens.space6),
                      _Section(
                        icon: Icons.image_outlined,
                        label: 'Sport Image',
                        color: const Color(0xFF3949AB),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      // The sports-complex module's field, reused as-is. The
                      // sports API has no delete-image route, so no
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
              submitLabel: widget.isEdit ? 'Save Changes' : 'Save Sport',
              onCancel: _saving ? null : () => Navigator.of(context).pop(false),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }

  /// Both age fields are optional; only their range is checked once typed.
  static String? _validateAge(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    final parsed = int.tryParse(text);
    if (parsed == null) return 'Numbers only';
    if (parsed < 1 || parsed > 120) return 'Enter an age between 1 and 120';
    return null;
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
    this.onChanged,
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
  final ValueChanged<String>? onChanged;
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
          onChanged: onChanged,
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

/// A dropdown over one of the fixed vocabularies.
class _Dropdown<T> extends StatelessWidget {
  const _Dropdown({
    required this.label,
    required this.icon,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
    this.required = false,
    this.enabled = true,
    this.error,
    this.emptyMessage,
  });

  final String label;
  final IconData icon;
  final T? value;
  final List<T> items;
  final String Function(T value) labelOf;
  final ValueChanged<T?> onChanged;
  final bool required;
  final bool enabled;
  final String? error;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _Label(label, required: required),
        const SizedBox(height: AdminTokens.space2),
        DropdownButtonFormField<T>(
          initialValue: value,
          isExpanded: true,
          onChanged: enabled ? onChanged : null,
          validator: (selected) {
            if (error != null) return error;
            if (required && selected == null) {
              return emptyMessage ?? '$label is required';
            }
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
            'Select ${label.toLowerCase()}',
            style: TextStyle(fontSize: 13.5, color: tokens.textMuted),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, size: 18, color: tokens.textMuted),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item,
                  child: Text(
                    labelOf(item),
                    overflow: TextOverflow.ellipsis,
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

/// The storefront visibility switch, boxed so it lines up with the dropdown
/// beside it rather than floating at a different height.
class _VisibilityToggle extends StatelessWidget {
  const _VisibilityToggle({
    required this.value,
    required this.onChanged,
    required this.enabled,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        const _Label('Show on Frontend'),
        const SizedBox(height: AdminTokens.space2),
        InkWell(
          onTap: enabled ? () => onChanged(!value) : null,
          borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AdminTokens.space4,
              vertical: AdminTokens.space2,
            ),
            decoration: BoxDecoration(
              color: tokens.surfaceAlt,
              borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
              border: Border.all(
                color: value
                    ? tokens.success.withValues(alpha: 0.45)
                    : tokens.border,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  value
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 18,
                  color: value ? tokens.success : tokens.textMuted,
                ),
                const SizedBox(width: AdminTokens.space3),
                Expanded(
                  child: Text(
                    value ? 'Visible in the app' : 'Hidden from the app',
                    style: TextStyle(
                      color: value ? tokens.textPrimary : tokens.textMuted,
                      fontSize: 13.5,
                      fontWeight: value ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                Switch(
                  value: value,
                  onChanged: enabled ? onChanged : null,
                  activeThumbColor: Colors.white,
                  activeTrackColor: tokens.success,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
