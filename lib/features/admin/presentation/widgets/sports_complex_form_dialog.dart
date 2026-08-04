import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/admin_sports_complex.dart';
import '../theme/admin_theme.dart';
import 'complex_image_field.dart';

/// Add / Edit sports complex.
///
/// The layout follows the five sections the spec lays out — Basic Information,
/// Contact Details, Operations, Display Settings, Image — rendered in the
/// console's own theme and built from the same field widgets the other modules
/// use.
///
/// [complex] null means create (`POST /sports-complexes`), otherwise edit
/// (`PUT /sports-complexes/{id}`). Unlike the staff modules every field stays
/// editable on an edit: the route documents all of them as updatable, and a
/// venue's address or map URL is legitimately something that changes.
class SportsComplexFormDialog extends StatefulWidget {
  const SportsComplexFormDialog({
    super.key,
    required this.onSubmit,
    required this.onUploadImage,
    this.onDeleteImage,
    this.complex,
  });

  final AdminSportsComplex? complex;

  /// Throws on failure so this dialog can stay open and explain itself.
  final Future<void> Function(SportsComplexDraft draft) onSubmit;

  final Future<String> Function(String path, {String? filename}) onUploadImage;

  /// Offered only on edit, where the image already lives on the server.
  final Future<void> Function(String imageUrl)? onDeleteImage;

  bool get isEdit => complex != null;

  /// Resolves to true when a save succeeded.
  static Future<bool> show(
    BuildContext context, {
    AdminSportsComplex? complex,
    required Future<void> Function(SportsComplexDraft draft) onSubmit,
    required Future<String> Function(String path, {String? filename})
    onUploadImage,
    Future<void> Function(String imageUrl)? onDeleteImage,
  }) async {
    AdminLog.ui(
      '${complex == null ? 'Add' : 'Edit'} sports complex dialog opened'
      '${complex == null ? '' : ' for ${complex.id}'}',
    );

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => SportsComplexFormDialog(
        complex: complex,
        onSubmit: onSubmit,
        onUploadImage: onUploadImage,
        onDeleteImage: onDeleteImage,
      ),
    );

    AdminLog.ui('Sports complex dialog closed (saved: ${saved ?? false})');
    return saved ?? false;
  }

  @override
  State<SportsComplexFormDialog> createState() =>
      _SportsComplexFormDialogState();
}

class _SportsComplexFormDialogState extends State<SportsComplexFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _city;
  late final TextEditingController _state;
  late final TextEditingController _zipCode;
  late final TextEditingController _contactPhone;
  late final TextEditingController _contactEmail;
  late final TextEditingController _openingHours;
  late final TextEditingController _facilities;
  late final TextEditingController _mapUrl;

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
    final complex = widget.complex;

    _name = TextEditingController(text: complex?.name ?? '');
    _address = TextEditingController(text: complex?.address ?? '');
    _city = TextEditingController(text: complex?.city ?? '');
    _state = TextEditingController(text: complex?.state ?? '');
    _zipCode = TextEditingController(text: complex?.zipCode ?? '');
    _contactPhone = TextEditingController(text: complex?.contactPhone ?? '');
    _contactEmail = TextEditingController(text: complex?.contactEmail ?? '');
    _openingHours = TextEditingController(text: complex?.openingHours ?? '');
    _facilities = TextEditingController(text: complex?.facilities ?? '');
    _mapUrl = TextEditingController(text: complex?.mapUrl ?? '');

    _status = complex?.status ?? AdminUserStatus.active;
    _showOnFrontend = complex?.showOnFrontend ?? false;
    _image = complex?.image;

    AdminLog.life(
      'SportsComplexFormDialog mounted (${widget.isEdit ? 'edit' : 'create'})',
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _address,
      _city,
      _state,
      _zipCode,
      _contactPhone,
      _contactEmail,
      _openingHours,
      _facilities,
      _mapUrl,
    ]) {
      controller.dispose();
    }
    AdminLog.life('SportsComplexFormDialog disposed');
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      AdminLog.ui('Sports complex form failed local validation');
      return;
    }

    final draft = SportsComplexDraft(
      name: _name.text,
      address: _address.text,
      city: _city.text,
      state: _state.text,
      zipCode: _zipCode.text,
      contactPhone: _contactPhone.text,
      contactEmail: _contactEmail.text,
      openingHours: _openingHours.text,
      facilities: _facilities.text,
      status: _status,
      mapUrl: _mapUrl.text,
      // Empty rather than null so an image the admin removed is actually
      // cleared on the server record instead of silently kept.
      image: _image ?? '',
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
      AdminLog.failure('Sports complex save rejected: ${error.message}');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this sports complex. Please try again.';
      });
      AdminLog.failure(
        'Sports complex save crashed',
        error: error,
        stackTrace: stackTrace,
      );
    }
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
              title: widget.isEdit
                  ? 'Edit sports complex'
                  : 'Add sports complex',
              subtitle: widget.isEdit
                  ? widget.complex!.displayName
                  : 'Create a venue and choose whether it shows on the app',
              icon: widget.isEdit
                  ? Icons.edit_outlined
                  : Icons.add_business_outlined,
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
                        icon: Icons.stadium_outlined,
                        label: 'Basic Information',
                        color: tokens.accent,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Field(
                        controller: _name,
                        label: 'Complex Name',
                        hint: 'e.g. Kothrud Sports Arena',
                        icon: Icons.badge_outlined,
                        required: true,
                        enabled: !_saving,
                        textCapitalization: TextCapitalization.words,
                        validator: (value) {
                          final server = _serverError([
                            'name',
                            'complexName',
                          ]);
                          if (server != null) return server;
                          if ((value ?? '').trim().isEmpty) {
                            return 'Complex name is required';
                          }
                          if ((value ?? '').trim().length < 2) {
                            return 'Enter the full name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Field(
                        controller: _address,
                        label: 'Address',
                        hint: 'Street, area and landmark',
                        icon: Icons.home_outlined,
                        enabled: !_saving,
                        maxLines: 2,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (_) => _serverError(['address']),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Pair(
                        narrow: narrow,
                        first: _Field(
                          controller: _city,
                          label: 'City',
                          hint: 'e.g. Pune',
                          icon: Icons.location_city_outlined,
                          enabled: !_saving,
                          textCapitalization: TextCapitalization.words,
                          validator: (_) => _serverError(['city']),
                        ),
                        second: _Field(
                          controller: _state,
                          label: 'State',
                          hint: 'e.g. Maharashtra',
                          icon: Icons.map_outlined,
                          enabled: !_saving,
                          textCapitalization: TextCapitalization.words,
                          validator: (_) => _serverError(['state']),
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Field(
                        controller: _zipCode,
                        label: 'Zip Code',
                        hint: 'e.g. 411038',
                        icon: Icons.markunread_mailbox_outlined,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (value) {
                          final server = _serverError(['zipCode', 'zip_code']);
                          if (server != null) return server;
                          final text = (value ?? '').trim();
                          // Optional; only its shape is checked once typed.
                          if (text.isEmpty) return null;
                          if (text.length < 4) return 'Enter a valid zip code';
                          return null;
                        },
                      ),

                      // --- 2. Contact details --------------------------------
                      const SizedBox(height: AdminTokens.space6),
                      _Section(
                        icon: Icons.call_outlined,
                        label: 'Contact Details',
                        color: tokens.info,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Pair(
                        narrow: narrow,
                        first: _Field(
                          controller: _contactPhone,
                          label: 'Contact Phone',
                          hint: 'Mobile or landline',
                          icon: Icons.phone_outlined,
                          enabled: !_saving,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            // Landlines carry an STD code and separators, so
                            // this is looser than the staff phone fields.
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+\-\s]'),
                            ),
                            LengthLimitingTextInputFormatter(20),
                          ],
                          validator: (value) {
                            final server = _serverError([
                              'contactPhone',
                              'contact_phone',
                              'phone',
                            ]);
                            if (server != null) return server;
                            final digits = (value ?? '').replaceAll(
                              RegExp(r'\D'),
                              '',
                            );
                            if (digits.isEmpty) return null;
                            if (digits.length < 7 || digits.length > 15) {
                              return 'Enter a valid phone number';
                            }
                            return null;
                          },
                        ),
                        second: _Field(
                          controller: _contactEmail,
                          label: 'Contact Email',
                          hint: 'venue@example.com',
                          icon: Icons.mail_outline_rounded,
                          enabled: !_saving,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final server = _serverError([
                              'contactEmail',
                              'contact_email',
                              'email',
                            ]);
                            if (server != null) return server;
                            final text = (value ?? '').trim();
                            if (text.isEmpty) return null;
                            final valid = RegExp(
                              r'^[\w.+-]+@[\w-]+\.[\w.-]+$',
                            ).hasMatch(text);
                            return valid ? null : 'Enter a valid email';
                          },
                        ),
                      ),

                      // --- 3. Operations -------------------------------------
                      const SizedBox(height: AdminTokens.space6),
                      _Section(
                        icon: Icons.schedule_rounded,
                        label: 'Operations',
                        color: tokens.success,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Field(
                        controller: _openingHours,
                        label: 'Opening Hours',
                        hint: 'e.g. 6:00 AM – 11:00 PM',
                        icon: Icons.access_time_rounded,
                        enabled: !_saving,
                        validator: (_) =>
                            _serverError(['openingHours', 'opening_hours']),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Field(
                        controller: _facilities,
                        label: 'Facilities',
                        hint:
                            'One per line, or comma separated — '
                            'e.g. Floodlights, Parking, Cafeteria',
                        icon: Icons.pool_outlined,
                        enabled: !_saving,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.words,
                        validator: (_) => _serverError(['facilities']),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Field(
                        controller: _mapUrl,
                        label: 'Google Map URL',
                        hint: 'https://maps.google.com/…',
                        icon: Icons.map_outlined,
                        enabled: !_saving,
                        keyboardType: TextInputType.url,
                        validator: (value) {
                          final server = _serverError(['mapUrl', 'map_url']);
                          if (server != null) return server;
                          final text = (value ?? '').trim();
                          if (text.isEmpty) return null;
                          final uri = Uri.tryParse(text);
                          if (uri == null ||
                              !uri.hasScheme ||
                              !(uri.isScheme('http') || uri.isScheme('https'))) {
                            return 'Enter a full URL starting with https://';
                          }
                          return null;
                        },
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
                        label: 'Complex Image',
                        color: const Color(0xFF3949AB),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      ComplexImageField(
                        imageUrl: _image,
                        enabled: !_saving,
                        onUpload: widget.onUploadImage,
                        onServerDelete: widget.onDeleteImage,
                        onChanged: (url) => setState(() => _image = url),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _Footer(
              saving: _saving,
              submitLabel: widget.isEdit
                  ? 'Save Changes'
                  : 'Save Sports Complex',
              onCancel: _saving ? null : () => Navigator.of(context).pop(false),
              onSubmit: _submit,
            ),
          ],
        ),
      ),
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
