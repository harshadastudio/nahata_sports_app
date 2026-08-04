import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/employee_vocabulary.dart';
import '../../domain/entities/security_guard.dart';
import '../state/view_state.dart';
import '../utils/server_field_errors.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'complex_picker_field.dart';

/// Add / Edit security guard.
///
/// The layout follows the employee form — Basic Information, Employment
/// Information, then Save/Cancel — rendered in the console's own theme and
/// built from the same field widgets the other modules use.
///
/// [guard] null means create (`POST /admin/security-guards`), otherwise edit
/// (`PUT /admin/security-guards/{id}`). The update route documents exactly five
/// editable fields — name, phone, shift, assigned area and status — so every
/// other input is shown read-only rather than hidden: an admin still needs to
/// see the licence number and the posting they are editing around.
class SecurityGuardFormDialog extends StatefulWidget {
  const SecurityGuardFormDialog({
    super.key,
    required this.onSubmit,
    required this.complexes,
    required this.complexesState,
    required this.onReloadComplexes,
    this.guard,
  });

  final SecurityGuard? guard;

  /// Throws on failure so this dialog can stay open and explain itself.
  final Future<void> Function(SecurityGuardDraft draft) onSubmit;

  final List<SportsComplex> complexes;
  final ViewState complexesState;
  final VoidCallback onReloadComplexes;

  /// Learned from the rows the API returned — never a hardcoded list.

  bool get isEdit => guard != null;

  /// Resolves to true when a save succeeded.
  static Future<bool> show(
    BuildContext context, {
    SecurityGuard? guard,
    required Future<void> Function(SecurityGuardDraft draft) onSubmit,
    required List<SportsComplex> complexes,
    required ViewState complexesState,
    required VoidCallback onReloadComplexes,
  }) async {
    AdminLog.ui(
      '${guard == null ? 'Add' : 'Edit'} security guard dialog opened'
      '${guard == null ? '' : ' for ${guard.id}'}',
    );

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => SecurityGuardFormDialog(
        guard: guard,
        onSubmit: onSubmit,
        complexes: complexes,
        complexesState: complexesState,
        onReloadComplexes: onReloadComplexes,
      ),
    );

    AdminLog.ui('Security guard dialog closed (saved: ${saved ?? false})');
    return saved ?? false;
  }

  @override
  State<SecurityGuardFormDialog> createState() =>
      _SecurityGuardFormDialogState();
}

class _SecurityGuardFormDialogState extends State<SecurityGuardFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _password;
  late final TextEditingController _confirmPassword;
  late final TextEditingController _guardCode;
  late final TextEditingController _licenseNumber;
  late final TextEditingController _salary;

  SportsComplex? _complex;
  Shift? _shift;
  AdminUserStatus? _status;
  DateTime? _joiningDate;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  /// Values this backend has already refused, keyed by payload field. Kept so
  /// the form can block a resubmit of the identical value rather than spending
  /// another round trip on a rejection it has already seen.
  final Map<String, String> _rejected = <String, String>{};

  @override
  void initState() {
    super.initState();
    final guard = widget.guard;

    _fullName = TextEditingController(text: guard?.fullName ?? '');
    _email = TextEditingController(text: guard?.email ?? '');
    _phone = TextEditingController(text: guard?.phone ?? '');
    _password = TextEditingController();
    _confirmPassword = TextEditingController();
    _guardCode = TextEditingController(text: guard?.guardCode ?? '');
    _licenseNumber = TextEditingController(text: guard?.licenseNumber ?? '');
    _salary = TextEditingController(
      text: guard?.salary == null ? '' : _plainSalary(guard!.salary!),
    );

    _shift = guard?.shift;
    _status = guard?.status ?? AdminUserStatus.active;
    _areaValue = _seedArea(guard);
    _joiningDate = guard?.joiningDate;
    _complex = _matchComplex(guard);

    AdminLog.life(
      'SecurityGuardFormDialog mounted (${widget.isEdit ? 'edit' : 'create'})',
    );
  }

  /// `28000` not `28000.0` — the field is text and round-trips to the API.
  static String _plainSalary(num value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  SportsComplex? _matchComplex(SecurityGuard? guard) {
    if (guard == null) return null;

    final id = guard.sportComplexId;
    if (id != null) {
      for (final complex in widget.complexes) {
        if (complex.id == id) return complex;
      }
    }

    final name = (guard.sportComplexName ?? '').trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final complex in widget.complexes) {
      if (complex.name.trim().toLowerCase() == name) return complex;
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant SecurityGuardFormDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The venue list may land after the dialog opened; preselect once it does.
    if (_complex == null && widget.complexes.isNotEmpty) {
      final matched = _matchComplex(widget.guard);
      if (matched != null) setState(() => _complex = matched);
    }
  }

  @override
  void dispose() {
    for (final controller in [
      _fullName,
      _email,
      _phone,
      _password,
      _confirmPassword,
      _guardCode,
      _licenseNumber,
      _salary,
    ]) {
      controller.dispose();
    }
    AdminLog.life('SecurityGuardFormDialog disposed');
    super.dispose();
  }

  Future<void> _pickJoiningDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate ?? now,
      // Wide enough for a long-serving guard and a future start date.
      firstDate: DateTime(now.year - 50),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: 'Select joining date',
    );

    if (picked == null || !mounted) return;
    AdminLog.ui('Joining date → ${SecurityGuardDraft.formatDate(picked)}');
    setState(() => _joiningDate = picked);
    // Clears the "required" error the moment a date is chosen.
    _formKey.currentState?.validate();
  }

  Future<void> _submit() async {
    if (_saving) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      AdminLog.ui('Security guard form failed local validation');
      return;
    }

    // On edit only the five documented fields are carried; the draft's update
    // body would drop the rest anyway, and passing them would be misleading.
    final draft = widget.isEdit
        ? SecurityGuardDraft(
            fullName: _fullName.text,
            phone: _phone.text,
            shift: _shift,
            assignedArea: _areaValue,
            status: _status,
          )
        : SecurityGuardDraft(
            fullName: _fullName.text,
            email: _email.text,
            phone: _phone.text,
            password: _password.text,
            guardCode: _guardCode.text,
            licenseNumber: _licenseNumber.text,
            shift: _shift,
            assignedArea: _areaValue,
            joiningDate: _joiningDate,
            salary: _salary.text,
            status: _status,
            sportComplexId: _complex?.id,
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
      // The backend reports a rejected enum value in the message only — never
      // in `errors` — so it is parsed out and attached to the field that
      // caused it instead of sitting in the banner alone.
      final parsed = ServerFieldErrors.from(error, fieldLabel: 'Assigned area');
      setState(() {
        _saving = false;
        _error = parsed.summary ?? error.message;
        _fieldErrors = parsed.fields;
        final rejected = parsed.rejected;
        if (rejected != null) _rejected[rejected.field] = rejected.value;
      });
      _formKey.currentState?.validate();
      AdminLog.failure('Security guard save rejected: ${error.message}');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this security guard. Please try again.';
      });
      AdminLog.failure(
        'Security guard save crashed',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  String? _serverError(List<String> keys) {
    for (final key in keys) {
      final message = _fieldErrors[key];
      if (message != null) return message;
    }
    return null;
  }

  /// The posting, as the exact string that goes on the wire. Held as a String
  /// rather than an [AssignedArea] so a row whose value predates the enum
  /// stays selectable and is not silently rewritten on save.
  String? _areaValue;

  /// Options for the assigned-area dropdown.
  ///
  /// The five enum members, plus — only on an edit — whatever the row already
  /// holds if that is outside them. Without that, opening an older guard whose
  /// area predates the constraint would show an empty box and silently rewrite
  /// the value on save.
  /// The value to preselect: the row's own, normalised onto the enum's casing
  /// when it matches one, and left exactly as stored when it does not.
  static String? _seedArea(SecurityGuard? guard) {
    final stored = (guard?.assignedArea ?? '').trim();
    if (stored.isEmpty) return null;
    return AssignedArea.tryParse(stored)?.slug ?? stored;
  }

  List<String> get _areaOptions {
    final options = AssignedArea.values.map((area) => area.slug).toList();

    final existing = (widget.guard?.assignedArea ?? '').trim();
    if (existing.isNotEmpty && AssignedArea.tryParse(existing) == null) {
      options.add(existing);
    }
    return options;
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
          maxWidth: 720,
          maxHeight: size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(
              title: isEdit ? 'Edit security guard' : 'Add security guard',
              subtitle: isEdit
                  ? widget.guard!.displayName
                  : 'Create a guard account and assign it to a complex',
              icon: isEdit
                  ? Icons.edit_outlined
                  : Icons.add_moderator_outlined,
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
                      if (isEdit) ...[
                        const _EditNotice(),
                        const SizedBox(height: AdminTokens.space4),
                      ],

                      // --- Basic information ---------------------------------
                      _Section(
                        icon: Icons.person_outline_rounded,
                        label: 'Basic Information',
                        color: tokens.accent,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Pair(
                        narrow: narrow,
                        first: _Field(
                          controller: _fullName,
                          label: 'Full Name',
                          hint: 'e.g. Sanjay Pawar',
                          icon: Icons.badge_outlined,
                          required: true,
                          enabled: !_saving,
                          textCapitalization: TextCapitalization.words,
                          validator: (value) {
                            final server = _serverError([
                              'fullName',
                              'full_name',
                              'name',
                            ]);
                            if (server != null) return server;
                            if ((value ?? '').trim().isEmpty) {
                              return 'Full name is required';
                            }
                            if ((value ?? '').trim().length < 2) {
                              return 'Enter the full name';
                            }
                            return null;
                          },
                        ),
                        second: _Field(
                          controller: _email,
                          label: 'Email',
                          hint: 'name@example.com',
                          icon: Icons.mail_outline_rounded,
                          required: !isEdit,
                          enabled: !_saving && !isEdit,
                          helper: isEdit
                              ? 'Email cannot be changed here'
                              : null,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            final server = _serverError(['email']);
                            if (server != null) return server;
                            if (isEdit) return null;
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
                      _Field(
                        controller: _phone,
                        label: 'Phone Number',
                        hint: '10-digit mobile number',
                        icon: Icons.phone_outlined,
                        required: true,
                        enabled: !_saving,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (value) {
                          final server = _serverError(['phone', 'phoneNumber']);
                          if (server != null) return server;
                          final digits = (value ?? '').replaceAll(
                            RegExp(r'\D'),
                            '',
                          );
                          if (digits.isEmpty) return 'Phone is required';
                          // The spec is explicit: exactly ten digits.
                          if (digits.length != 10) {
                            return 'Enter exactly 10 digits';
                          }
                          return null;
                        },
                      ),
                      // Credentials are set at creation; an existing guard's
                      // password is changed through the reset-password route.
                      if (!isEdit) ...[
                        const SizedBox(height: AdminTokens.space4),
                        _Pair(
                          narrow: narrow,
                          first: _Field(
                            controller: _password,
                            label: 'Password',
                            hint: 'At least 6 characters',
                            icon: Icons.lock_outline_rounded,
                            required: true,
                            enabled: !_saving,
                            obscure: _obscurePassword,
                            onToggleObscure: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            onChanged: (_) {
                              // Keeps "passwords do not match" honest while
                              // the first field is still being typed.
                              if (_confirmPassword.text.isNotEmpty) {
                                _formKey.currentState?.validate();
                              }
                            },
                            validator: (value) {
                              final server = _serverError(['password']);
                              if (server != null) return server;
                              final text = value ?? '';
                              if (text.isEmpty) return 'Password is required';
                              if (text.length < 6) {
                                return 'Use at least 6 characters';
                              }
                              return null;
                            },
                          ),
                          second: _Field(
                            controller: _confirmPassword,
                            label: 'Confirm Password',
                            hint: 'Re-enter the password',
                            icon: Icons.lock_person_outlined,
                            required: true,
                            enabled: !_saving,
                            obscure: _obscureConfirm,
                            onToggleObscure: () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                            validator: (value) {
                              final text = value ?? '';
                              if (text.isEmpty) {
                                return 'Confirm the password';
                              }
                              if (text != _password.text) {
                                return 'Passwords do not match';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],

                      // --- Employment information ----------------------------
                      const SizedBox(height: AdminTokens.space6),
                      _Section(
                        icon: Icons.shield_outlined,
                        label: 'Employment Information',
                        color: tokens.info,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Pair(
                        narrow: narrow,
                        first: _Field(
                          controller: _guardCode,
                          label: 'Guard ID',
                          hint: 'e.g. SG-204',
                          icon: Icons.tag_rounded,
                          required: !isEdit,
                          enabled: !_saving && !isEdit,
                          helper: isEdit ? 'Guard ID cannot be changed' : null,
                          validator: (value) {
                            final server = _serverError([
                              'guardId',
                              'guard_id',
                            ]);
                            if (server != null) return server;
                            if (isEdit) return null;
                            return (value ?? '').trim().isEmpty
                                ? 'Guard ID is required'
                                : null;
                          },
                        ),
                        second: _Field(
                          controller: _licenseNumber,
                          label: 'License Number',
                          hint: 'Optional security licence number',
                          icon: Icons.verified_user_outlined,
                          enabled: !_saving && !isEdit,
                          helper: isEdit
                              ? 'License number cannot be changed here'
                              : null,
                          validator: (_) => _serverError([
                            'licenseNumber',
                            'license_number',
                          ]),
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Pair(
                        narrow: narrow,
                        first: ComplexPickerField(
                          complexes: widget.complexes,
                          state: widget.complexesState,
                          onReload: widget.onReloadComplexes,
                          initialComplex: _complex,
                          enabled: !_saving && !isEdit,
                          serverError: _serverError(const [
                            'sportComplexId',
                            'sport_complex_id',
                          ]),
                          onChanged: (complex) =>
                              setState(() => _complex = complex),
                          validator: (complex) {
                            // The complex is create-only, so an edit never
                            // blocks on a venue list that has not landed.
                            if (isEdit) return null;
                            return complex == null
                                ? 'Sport complex is required'
                                : null;
                          },
                        ),
                        // A dropdown, not a text box: `assignedArea` is a
                        // database enum, and free text spent a round trip to
                        // come back as `invalid input value for enum`.
                        second: _Dropdown<String>(
                          label: 'Assigned Area',
                          icon: Icons.place_outlined,
                          value: _areaValue,
                          required: true,
                          enabled: !_saving,
                          items: _areaOptions,
                          labelOf: AssignedArea.labelFor,
                          error: _serverError(const [
                            'assignedArea',
                            'assigned_area',
                          ]),
                          emptyMessage: 'Assigned area is required',
                          onChanged: (area) {
                            AdminLog.ui('Form assigned area → ${area ?? '-'}');
                            setState(() => _areaValue = area);
                          },
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Pair(
                        narrow: narrow,
                        first: _Dropdown<Shift>(
                          label: 'Shift',
                          icon: Icons.schedule_rounded,
                          value: _shift,
                          required: true,
                          enabled: !_saving,
                          items: Shift.values,
                          labelOf: (shift) => shift.label,
                          error: _serverError(const ['shift']),
                          emptyMessage: 'Shift is required',
                          onChanged: (shift) {
                            AdminLog.ui('Form shift → ${shift?.slug ?? 'none'}');
                            setState(() => _shift = shift);
                          },
                        ),
                        second: _DateField(
                          // Keyed on the value: a FormField keeps its own
                          // state, so without this its validator would still
                          // be looking at the date from before the picker.
                          key: ValueKey<DateTime?>(_joiningDate),
                          label: 'Joining Date',
                          value: _joiningDate,
                          required: !isEdit,
                          enabled: !_saving && !isEdit,
                          helper: isEdit
                              ? 'Joining date cannot be changed here'
                              : null,
                          onTap: _pickJoiningDate,
                          error: _serverError(const [
                            'joiningDate',
                            'joining_date',
                          ]),
                          validator: (date) {
                            if (isEdit) return null;
                            return date == null
                                ? 'Joining date is required'
                                : null;
                          },
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Pair(
                        narrow: narrow,
                        first: _Field(
                          controller: _salary,
                          label: 'Salary',
                          hint: 'Monthly amount, numbers only',
                          icon: Icons.currency_rupee_rounded,
                          enabled: !_saving && !isEdit,
                          helper: isEdit
                              ? 'Salary cannot be changed here'
                              : null,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          validator: (value) {
                            final server = _serverError(['salary']);
                            if (server != null) return server;
                            final text = (value ?? '').trim();
                            // Salary is not in the required list; only its
                            // format is checked when something was typed.
                            if (text.isEmpty) return null;
                            final parsed = num.tryParse(text);
                            if (parsed == null) return 'Numbers only';
                            if (parsed < 0) return 'Cannot be negative';
                            return null;
                          },
                        ),
                        second: _Dropdown<AdminUserStatus>(
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
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _Footer(
              saving: _saving,
              submitLabel: isEdit ? 'Save Changes' : 'Save Security Guard',
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

/// Explains why most of an edit form is read-only, rather than leaving the
/// admin to wonder whether the field is broken.
class _EditNotice extends StatelessWidget {
  const _EditNotice();

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
          Icon(Icons.info_outline_rounded, size: 16, color: tokens.info),
          const SizedBox(width: AdminTokens.space3),
          Expanded(
            child: Text(
              'Name, phone number, shift, assigned area and status can be '
              'updated. Everything else is fixed once the guard exists.',
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

/// Areas already in use, one tap away — the API has no `/areas` route, so the
/// options are whatever the loaded rows carry.
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
    this.helper,
    this.required = false,
    this.enabled = true,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.obscure = false,
    this.onToggleObscure,
    this.onChanged,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? hint;
  final String? helper;
  final bool required;
  final bool enabled;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool obscure;
  final VoidCallback? onToggleObscure;
  final ValueChanged<String>? onChanged;
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
          obscureText: obscure,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          validator: validator,
          style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            helperStyle: TextStyle(color: tokens.textMuted, fontSize: 11),
            prefixIcon: Icon(icon, size: 18, color: tokens.textMuted),
            suffixIcon: onToggleObscure == null
                ? null
                : IconButton(
                    onPressed: onToggleObscure,
                    icon: Icon(
                      obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 17,
                    ),
                    color: tokens.textMuted,
                    tooltip: obscure ? 'Show' : 'Hide',
                  ),
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

/// A read-only field that opens the platform date picker.
///
/// The parent owns the date; this only displays it and reports "required" to
/// the surrounding [Form]. Callers must key it on the value — see the call site.
class _DateField extends FormField<DateTime> {
  _DateField({
    super.key,
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
    required bool enabled,
    bool required = true,
    String? helper,
    String? error,
    super.validator,
  }) : super(
         initialValue: value,
         enabled: enabled,
         autovalidateMode: AutovalidateMode.disabled,
         builder: (field) {
           final context = field.context;
           final tokens = AdminTheme.of(context);
           // The parent owns the date, so the field mirrors it rather than
           // holding a second copy that could drift.
           final message = error ?? field.errorText;

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
                     vertical: AdminTokens.space3 + 1,
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
                       Icon(
                         Icons.calendar_today_outlined,
                         size: 17,
                         color: tokens.textMuted,
                       ),
                       const SizedBox(width: AdminTokens.space3),
                       Expanded(
                         child: Text(
                           value == null
                               ? 'Select joining date'
                               : AdminFormat.date(value),
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
                       if (enabled)
                         Icon(
                           Icons.expand_more_rounded,
                           size: 18,
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
               ] else if (helper != null) ...[
                 const SizedBox(height: 6),
                 Text(
                   helper,
                   style: TextStyle(color: tokens.textMuted, fontSize: 11),
                 ),
               ],
             ],
           );
         },
       );
}
