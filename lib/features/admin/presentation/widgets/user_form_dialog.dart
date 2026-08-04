import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/admin_user.dart';
import '../theme/admin_theme.dart';
import 'glass_card.dart';

/// Add / Edit user.
///
/// One dialog serves both: [user] null means create (`POST /admin/create-user`),
/// otherwise edit (`PUT /admin/users/{id}`). The conditional blocks appear as
/// soon as a role that needs them is picked, and only the fields that block
/// applies are ever sent — see [AdminUserDraft.toJson].
///
/// [onSubmit] is expected to throw on failure; the dialog stays open, unlocks
/// and shows the server's message, including per-field errors when the API
/// sends an `errors` map.
class UserFormDialog extends StatefulWidget {
  const UserFormDialog({
    super.key,
    required this.onSubmit,
    this.user,
    this.knownMemberships = const [],
    this.knownDepartments = const [],
    this.knownSports = const [],
    this.knownLocations = const [],
  });

  final AdminUser? user;
  final Future<void> Function(AdminUserDraft draft) onSubmit;

  /// Vocabulary learned from the loaded rows — offered as suggestions so an
  /// admin does not have to remember exact spellings, while still allowing a
  /// new value to be typed.
  final List<String> knownMemberships;
  final List<String> knownDepartments;
  final List<String> knownSports;
  final List<String> knownLocations;

  bool get isEdit => user != null;

  /// Convenience launcher. Resolves to true when a save succeeded.
  static Future<bool> show(
    BuildContext context, {
    AdminUser? user,
    required Future<void> Function(AdminUserDraft draft) onSubmit,
    List<String> knownMemberships = const [],
    List<String> knownDepartments = const [],
    List<String> knownSports = const [],
    List<String> knownLocations = const [],
  }) async {
    AdminLog.ui(
      '${user == null ? 'Add' : 'Edit'} user dialog opened'
      '${user == null ? '' : ' for ${user.id}'}',
    );

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => UserFormDialog(
        user: user,
        onSubmit: onSubmit,
        knownMemberships: knownMemberships,
        knownDepartments: knownDepartments,
        knownSports: knownSports,
        knownLocations: knownLocations,
      ),
    );

    AdminLog.ui('User dialog closed (saved: ${saved ?? false})');
    return saved ?? false;
  }

  @override
  State<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<UserFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _membership;
  late final TextEditingController _employeeId;
  late final TextEditingController _department;
  late final TextEditingController _location;

  late AdminRole? _role;
  late AdminUserStatus? _status;
  late Set<String> _sports;

  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    final user = widget.user;

    _name = TextEditingController(text: user?.name ?? '');
    _email = TextEditingController(text: user?.email ?? '');
    _phone = TextEditingController(text: user?.phone ?? '');
    _membership = TextEditingController(text: user?.membership ?? '');
    _employeeId = TextEditingController(text: user?.employeeId ?? '');
    _department = TextEditingController(text: user?.department ?? '');
    _location = TextEditingController(text: user?.assignedLocation ?? '');

    _role = user?.role;
    _status = user?.status;
    _sports = user?.assignedSports.toSet() ?? <String>{};

    AdminLog.life(
      'UserFormDialog mounted (${widget.isEdit ? 'edit' : 'create'})',
    );
  }

  @override
  void dispose() {
    for (final controller in [
      _name,
      _email,
      _phone,
      _membership,
      _employeeId,
      _department,
      _location,
    ]) {
      controller.dispose();
    }
    AdminLog.life('UserFormDialog disposed');
    super.dispose();
  }

  bool get _showEmployeeFields => _role?.isEmployeeLike ?? false;
  bool get _showCoachFields => _role?.isCoach ?? false;

  Future<void> _submit() async {
    if (_saving) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      AdminLog.ui('User form failed local validation');
      return;
    }

    final draft = AdminUserDraft(
      name: _name.text,
      // Email is immutable on edit — the API keys accounts on it, so it is only
      // sent when creating.
      email: widget.isEdit ? null : _email.text,
      phone: _phone.text,
      role: _role,
      membership: _membership.text,
      status: _status,
      employeeId: _showEmployeeFields ? _employeeId.text : null,
      department: _showEmployeeFields ? _department.text : null,
      assignedSports: _showCoachFields ? _sports.toList() : null,
      assignedLocation: _showCoachFields ? _location.text : null,
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
      // Re-run validation so the server's per-field messages appear inline.
      _formKey.currentState?.validate();
      AdminLog.failure('User save rejected: ${error.message}');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this user. Please try again.';
      });
      AdminLog.failure(
        'User save crashed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Flattens `{field: "msg"}` and `{field: ["msg", …]}` onto one message each.
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
          maxWidth: 620,
          maxHeight: size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _DialogHeader(
              title: widget.isEdit ? 'Edit user' : 'Add user',
              subtitle: widget.isEdit
                  ? widget.user!.displayName
                  : 'Create an account and assign its role',
              icon: widget.isEdit
                  ? Icons.edit_outlined
                  : Icons.person_add_alt_1_rounded,
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
                      _FieldPair(
                        narrow: narrow,
                        first: _TextField(
                          controller: _name,
                          label: 'Full name',
                          hint: 'e.g. Riya Sharma',
                          icon: Icons.person_outline_rounded,
                          enabled: !_saving,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            final server = _serverError(['name', 'fullName']);
                            if (server != null) return server;
                            if ((value ?? '').trim().length < 2) {
                              return 'Enter the full name';
                            }
                            return null;
                          },
                        ),
                        second: _TextField(
                          controller: _email,
                          label: 'Email',
                          hint: 'name@example.com',
                          icon: Icons.mail_outline_rounded,
                          // The backend identifies accounts by email; changing
                          // it is a different operation than editing a profile.
                          enabled: !_saving && !widget.isEdit,
                          helper: widget.isEdit
                              ? 'Email cannot be changed here'
                              : null,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final server = _serverError(['email']);
                            if (server != null) return server;
                            if (widget.isEdit) return null;
                            final text = (value ?? '').trim();
                            if (text.isEmpty) return 'Email is required';
                            final valid = RegExp(
                              r'^[\w.+-]+@[\w-]+\.[\w.-]+$',
                            ).hasMatch(text);
                            return valid ? null : 'Enter a valid email';
                          },
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _FieldPair(
                        narrow: narrow,
                        first: _TextField(
                          controller: _phone,
                          label: 'Phone number',
                          hint: '10-digit mobile number',
                          icon: Icons.phone_outlined,
                          enabled: !_saving,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9+\- ]'),
                            ),
                          ],
                          validator: (value) {
                            final server = _serverError([
                              'phoneNumber',
                              'phone',
                            ]);
                            if (server != null) return server;
                            final digits = (value ?? '').replaceAll(
                              RegExp(r'\D'),
                              '',
                            );
                            if (digits.isEmpty) return 'Phone is required';
                            if (digits.length < 10) {
                              return 'Enter at least 10 digits';
                            }
                            return null;
                          },
                        ),
                        second: _RoleField(
                          value: _role,
                          enabled: !_saving,
                          error: _serverError(['role']),
                          onChanged: (role) {
                            AdminLog.ui('Form role → ${role?.slug ?? 'none'}');
                            setState(() => _role = role);
                          },
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _FieldPair(
                        narrow: narrow,
                        first: _SuggestionField(
                          controller: _membership,
                          label: 'Membership',
                          hint: 'e.g. Premium',
                          icon: Icons.card_membership_outlined,
                          enabled: !_saving,
                          suggestions: widget.knownMemberships,
                          error: _serverError(['membershipType', 'membership']),
                        ),
                        second: _StatusField(
                          value: _status,
                          enabled: !_saving,
                          error: _serverError(['status']),
                          onChanged: (status) {
                            AdminLog.ui(
                              'Form status → ${status?.slug ?? 'none'}',
                            );
                            setState(() => _status = status);
                          },
                        ),
                      ),
                      // Conditional blocks — animated so the dialog does not
                      // jump when a role is picked.
                      AnimatedSize(
                        duration: AdminTokens.normal,
                        curve: AdminTokens.curve,
                        alignment: Alignment.topCenter,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_showEmployeeFields) ...[
                              const SizedBox(height: AdminTokens.space5),
                              _SectionDivider(
                                icon: Icons.badge_outlined,
                                label: 'Employee information',
                                color: tokens.info,
                              ),
                              const SizedBox(height: AdminTokens.space4),
                              _FieldPair(
                                narrow: narrow,
                                first: _TextField(
                                  controller: _employeeId,
                                  label: 'Employee ID',
                                  hint: 'e.g. NS-1042',
                                  icon: Icons.tag_rounded,
                                  enabled: !_saving,
                                  validator: (_) =>
                                      _serverError(['employeeId']),
                                ),
                                second: _SuggestionField(
                                  controller: _department,
                                  label: 'Department',
                                  hint: 'e.g. Operations',
                                  icon: Icons.apartment_rounded,
                                  enabled: !_saving,
                                  suggestions: widget.knownDepartments,
                                  error: _serverError(['department']),
                                ),
                              ),
                            ],
                            if (_showCoachFields) ...[
                              const SizedBox(height: AdminTokens.space5),
                              _SectionDivider(
                                icon: Icons.sports_outlined,
                                label: 'Coach information',
                                color: tokens.success,
                              ),
                              const SizedBox(height: AdminTokens.space4),
                              _SportsPicker(
                                selected: _sports,
                                options: widget.knownSports,
                                enabled: !_saving,
                                error: _serverError(['assignedSports']),
                                onChanged: (sports) =>
                                    setState(() => _sports = sports),
                              ),
                              const SizedBox(height: AdminTokens.space4),
                              _SuggestionField(
                                controller: _location,
                                label: 'Assigned location',
                                hint: 'e.g. Nahata Sports Complex',
                                icon: Icons.place_outlined,
                                enabled: !_saving,
                                suggestions: widget.knownLocations,
                                error: _serverError(['assignedLocation']),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _DialogFooter(
              saving: _saving,
              submitLabel: widget.isEdit ? 'Save changes' : 'Create user',
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
// Dialog chrome
// -----------------------------------------------------------------------------

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({
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

class _DialogFooter extends StatelessWidget {
  const _DialogFooter({
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

class _SectionDivider extends StatelessWidget {
  const _SectionDivider({
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
        Icon(icon, size: 16, color: color),
        const SizedBox(width: AdminTokens.space2),
        Text(
          label,
          style: TextStyle(
            color: tokens.textPrimary,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: AdminTokens.space3),
        Expanded(child: Divider(color: tokens.border, height: 1)),
      ],
    );
  }
}

/// Two fields side by side on wide dialogs, stacked when narrow.
class _FieldPair extends StatelessWidget {
  const _FieldPair({
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

class _TextField extends StatelessWidget {
  const _TextField({
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.helper,
    this.enabled = true,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final String? helper;
  final bool enabled;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FieldLabel(label),
        const SizedBox(height: AdminTokens.space2),
        TextFormField(
          controller: controller,
          enabled: enabled,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          validator: validator,
          style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            helperStyle: TextStyle(color: tokens.textMuted, fontSize: 11),
            prefixIcon: Icon(icon, size: 18, color: tokens.textMuted),
          ),
        ),
      ],
    );
  }
}

/// A text field with a dropdown of values already seen in the data. The typed
/// value always wins — suggestions never restrict what can be entered.
class _SuggestionField extends StatelessWidget {
  const _SuggestionField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.suggestions,
    this.hint,
    this.enabled = true,
    this.error,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final List<String> suggestions;
  final String? hint;
  final bool enabled;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FieldLabel(label),
        const SizedBox(height: AdminTokens.space2),
        TextFormField(
          controller: controller,
          enabled: enabled,
          validator: (_) => error,
          style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, size: 18, color: tokens.textMuted),
            suffixIcon: suggestions.isEmpty
                ? null
                : PopupMenuButton<String>(
                    tooltip: 'Existing values',
                    icon: Icon(
                      Icons.expand_more_rounded,
                      size: 18,
                      color: tokens.textMuted,
                    ),
                    onSelected: (value) {
                      AdminLog.ui('$label suggestion → $value');
                      controller.text = value;
                    },
                    itemBuilder: (context) => suggestions
                        .map(
                          (value) => PopupMenuItem<String>(
                            value: value,
                            height: 38,
                            child: Text(
                              value,
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

class _RoleField extends StatelessWidget {
  const _RoleField({
    required this.value,
    required this.onChanged,
    required this.enabled,
    this.error,
  });

  final AdminRole? value;
  final ValueChanged<AdminRole?> onChanged;
  final bool enabled;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FieldLabel('Role'),
        const SizedBox(height: AdminTokens.space2),
        DropdownButtonFormField<AdminRole>(
          initialValue: value,
          isExpanded: true,
          onChanged: enabled ? onChanged : null,
          validator: (selected) {
            if (error != null) return error;
            return selected == null ? 'Pick a role' : null;
          },
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
              Icons.shield_outlined,
              size: 18,
              color: tokens.textMuted,
            ),
          ),
          items: AdminRole.values
              .map(
                (role) => DropdownMenuItem<AdminRole>(
                  value: role,
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: tokens.roleColor(role),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AdminTokens.space3),
                      Flexible(
                        child: Text(
                          role.label,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13.5),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _StatusField extends StatelessWidget {
  const _StatusField({
    required this.value,
    required this.onChanged,
    required this.enabled,
    this.error,
  });

  final AdminUserStatus? value;
  final ValueChanged<AdminUserStatus?> onChanged;
  final bool enabled;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _FieldLabel('Status'),
        const SizedBox(height: AdminTokens.space2),
        DropdownButtonFormField<AdminUserStatus>(
          initialValue: value,
          isExpanded: true,
          onChanged: enabled ? onChanged : null,
          validator: (selected) {
            if (error != null) return error;
            return selected == null ? 'Pick a status' : null;
          },
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
          items: AdminUserStatus.values
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

/// Multi-select for a coach's sports. Values already in the data are offered as
/// toggles; anything else can be typed in.
class _SportsPicker extends StatefulWidget {
  const _SportsPicker({
    required this.selected,
    required this.options,
    required this.onChanged,
    required this.enabled,
    this.error,
  });

  final Set<String> selected;
  final List<String> options;
  final ValueChanged<Set<String>> onChanged;
  final bool enabled;
  final String? error;

  @override
  State<_SportsPicker> createState() => _SportsPickerState();
}

class _SportsPickerState extends State<_SportsPicker> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  void _add(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;
    AdminLog.ui('Assigned sport added: $trimmed');
    widget.onChanged({...widget.selected, trimmed});
    _input.clear();
  }

  void _remove(String value) {
    AdminLog.ui('Assigned sport removed: $value');
    widget.onChanged({...widget.selected}..remove(value));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    // Options not yet picked, offered as one-tap adds.
    final available = widget.options
        .where((option) => !widget.selected.contains(option))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabel('Assigned sports'),
        const SizedBox(height: AdminTokens.space2),
        SolidCard(
          padding: const EdgeInsets.all(AdminTokens.space3),
          color: tokens.surfaceAlt,
          borderColor: widget.error == null ? tokens.border : tokens.danger,
          radius: AdminTokens.radiusMd,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.selected.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'No sports assigned yet',
                    style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
                  ),
                )
              else
                Wrap(
                  spacing: AdminTokens.space2,
                  runSpacing: AdminTokens.space2,
                  children: widget.selected
                      .map(
                        (sport) => Chip(
                          label: Text(
                            sport,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onDeleted: widget.enabled
                              ? () => _remove(sport)
                              : null,
                          deleteIcon: const Icon(Icons.close_rounded, size: 14),
                          backgroundColor: tokens.surface,
                          side: BorderSide(color: tokens.border),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: AdminTokens.space2),
              TextField(
                controller: _input,
                enabled: widget.enabled,
                onSubmitted: _add,
                style: TextStyle(fontSize: 13, color: tokens.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Type a sport and press enter',
                  filled: true,
                  fillColor: tokens.surface,
                  prefixIcon: Icon(
                    Icons.add_rounded,
                    size: 18,
                    color: tokens.textMuted,
                  ),
                ),
              ),
              if (available.isNotEmpty) ...[
                const SizedBox(height: AdminTokens.space3),
                Text(
                  'SUGGESTIONS',
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: AdminTokens.space2),
                Wrap(
                  spacing: AdminTokens.space2,
                  runSpacing: AdminTokens.space2,
                  children: available
                      .map(
                        (sport) => ActionChip(
                          label: Text(
                            sport,
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: widget.enabled ? () => _add(sport) : null,
                          backgroundColor: tokens.surface,
                          side: BorderSide(color: tokens.border),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
        if (widget.error != null) ...[
          const SizedBox(height: AdminTokens.space2),
          Text(
            widget.error!,
            style: TextStyle(color: tokens.danger, fontSize: 11.5),
          ),
        ],
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    return Text(
      label,
      style: TextStyle(
        color: tokens.textSecondary,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
