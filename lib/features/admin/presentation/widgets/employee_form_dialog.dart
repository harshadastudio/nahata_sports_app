import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../models/sports_complex_model.dart';
import '../../core/admin_log.dart';
import '../../domain/entities/admin_role.dart';
import '../../domain/entities/employee.dart';
import '../../domain/entities/employee_vocabulary.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'complex_picker_field.dart';

/// Add / Edit employee.
///
/// The layout follows the supplied form design — Basic Information, Employment
/// Details, Address, then Save/Cancel — rendered in the console's own theme
/// and built from the same field widgets the other modules use.
///
/// [employee] null means create (`POST /admin/employees`), otherwise edit
/// (`PUT /admin/employees/{id}`). Credentials and the employee code are
/// create-only: the API has a separate reset-password route, and a staff number
/// is an identity, not an editable attribute.
class EmployeeFormDialog extends StatefulWidget {
  const EmployeeFormDialog({
    super.key,
    required this.onSubmit,
    required this.complexes,
    required this.complexesState,
    required this.onReloadComplexes,
    this.employee,
  });

  final Employee? employee;

  /// Throws on failure so this dialog can stay open and explain itself.
  final Future<void> Function(EmployeeDraft draft, {required bool clearAddress})
  onSubmit;

  final List<SportsComplex> complexes;
  final ViewState complexesState;
  final VoidCallback onReloadComplexes;

  bool get isEdit => employee != null;

  /// Resolves to true when a save succeeded.
  static Future<bool> show(
    BuildContext context, {
    Employee? employee,
    required Future<void> Function(
      EmployeeDraft draft, {
      required bool clearAddress,
    })
    onSubmit,
    required List<SportsComplex> complexes,
    required ViewState complexesState,
    required VoidCallback onReloadComplexes,
  }) async {
    AdminLog.ui(
      '${employee == null ? 'Add' : 'Edit'} employee dialog opened'
      '${employee == null ? '' : ' for ${employee.id}'}',
    );

    final saved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (_) => EmployeeFormDialog(
        employee: employee,
        onSubmit: onSubmit,
        complexes: complexes,
        complexesState: complexesState,
        onReloadComplexes: onReloadComplexes,
      ),
    );

    AdminLog.ui('Employee dialog closed (saved: ${saved ?? false})');
    return saved ?? false;
  }

  @override
  State<EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends State<EmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullName;
  late final TextEditingController _email;
  late final TextEditingController _phone;
  late final TextEditingController _password;
  late final TextEditingController _confirmPassword;
  late final TextEditingController _employeeCode;
  late final TextEditingController _salary;
  late final TextEditingController _address;

  SportsComplex? _complex;
  Department? _department;
  Designation? _designation;
  Shift? _shift;
  AdminUserStatus? _status;
  DateTime? _joiningDate;

  /// Set when the admin empties an address that had a value — the only field
  /// an update is allowed to blank.
  bool get _clearAddress =>
      widget.isEdit &&
      (widget.employee!.address ?? '').trim().isNotEmpty &&
      _address.text.trim().isEmpty;

  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void initState() {
    super.initState();
    final employee = widget.employee;

    _fullName = TextEditingController(text: employee?.fullName ?? '');
    _email = TextEditingController(text: employee?.email ?? '');
    _phone = TextEditingController(text: employee?.phone ?? '');
    _password = TextEditingController();
    _confirmPassword = TextEditingController();
    _employeeCode = TextEditingController(text: employee?.employeeCode ?? '');
    _salary = TextEditingController(
      text: employee?.salary == null ? '' : _plainSalary(employee!.salary!),
    );
    _address = TextEditingController(text: employee?.address ?? '');

    _department = employee?.department;
    _designation = employee?.designation;
    _shift = employee?.shift;
    _status = employee?.status ?? AdminUserStatus.active;
    _joiningDate = employee?.joiningDate;
    _complex = _matchComplex(employee);

    AdminLog.life(
      'EmployeeFormDialog mounted (${widget.isEdit ? 'edit' : 'create'})',
    );
  }

  /// `35000` not `35000.0` — the field is text and round-trips to the API.
  static String _plainSalary(num value) =>
      value == value.roundToDouble() ? value.toInt().toString() : '$value';

  SportsComplex? _matchComplex(Employee? employee) {
    if (employee == null) return null;

    final id = employee.sportComplexId;
    if (id != null) {
      for (final complex in widget.complexes) {
        if (complex.id == id) return complex;
      }
    }

    final name = (employee.sportComplexName ?? '').trim().toLowerCase();
    if (name.isEmpty) return null;
    for (final complex in widget.complexes) {
      if (complex.name.trim().toLowerCase() == name) return complex;
    }
    return null;
  }

  @override
  void didUpdateWidget(covariant EmployeeFormDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The venue list may land after the dialog opened; preselect once it does.
    if (_complex == null && widget.complexes.isNotEmpty) {
      final matched = _matchComplex(widget.employee);
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
      _employeeCode,
      _salary,
      _address,
    ]) {
      controller.dispose();
    }
    AdminLog.life('EmployeeFormDialog disposed');
    super.dispose();
  }

  Future<void> _pickJoiningDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _joiningDate ?? now,
      // Wide enough for a long-serving employee and a future start date.
      firstDate: DateTime(now.year - 50),
      lastDate: DateTime(now.year + 5, 12, 31),
      helpText: 'Select joining date',
    );

    if (picked == null || !mounted) return;
    AdminLog.ui('Joining date → ${EmployeeDraft.formatDate(picked)}');
    setState(() => _joiningDate = picked);
    // Clears the "required" error the moment a date is chosen.
    _formKey.currentState?.validate();
  }

  Future<void> _submit() async {
    if (_saving) return;

    if (!(_formKey.currentState?.validate() ?? false)) {
      AdminLog.ui('Employee form failed local validation');
      return;
    }

    final draft = EmployeeDraft(
      fullName: _fullName.text,
      // Email and the staff code identify the account; both are create-only.
      email: widget.isEdit ? null : _email.text,
      phone: _phone.text,
      password: widget.isEdit ? null : _password.text,
      employeeCode: widget.isEdit ? null : _employeeCode.text,
      department: _department,
      designation: _designation,
      joiningDate: _joiningDate,
      salary: _salary.text,
      shift: _shift,
      status: _status,
      sportComplexId: _complex?.id,
      address: _address.text,
    );

    setState(() {
      _saving = true;
      _error = null;
      _fieldErrors = const {};
    });

    try {
      await widget.onSubmit(draft, clearAddress: _clearAddress);
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
      AdminLog.failure('Employee save rejected: ${error.message}');
    } catch (error, stackTrace) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Could not save this employee. Please try again.';
      });
      AdminLog.failure(
        'Employee save crashed',
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
          maxWidth: 720,
          maxHeight: size.height * 0.92,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Header(
              title: widget.isEdit ? 'Edit employee' : 'Add employee',
              subtitle: widget.isEdit
                  ? widget.employee!.displayName
                  : 'Create a staff account and assign it to a complex',
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
                          hint: 'e.g. Rahul Kale',
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
                          required: !widget.isEdit,
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
                      _Pair(
                        narrow: narrow,
                        first: _Field(
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
                            final server = _serverError([
                              'phone',
                              'phoneNumber',
                            ]);
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
                        second: ComplexPickerField(
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
                      ),
                      // Credentials are set at creation; an existing employee's
                      // password is changed through the reset-password route.
                      if (!widget.isEdit) ...[
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

                      // --- Employment details --------------------------------
                      const SizedBox(height: AdminTokens.space6),
                      _Section(
                        icon: Icons.work_outline_rounded,
                        label: 'Employment Details',
                        color: tokens.info,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Pair(
                        narrow: narrow,
                        first: _Field(
                          controller: _employeeCode,
                          label: 'Employee ID',
                          hint: 'e.g. NS-1042',
                          icon: Icons.tag_rounded,
                          required: !widget.isEdit,
                          enabled: !_saving && !widget.isEdit,
                          helper: widget.isEdit
                              ? 'Employee ID cannot be changed'
                              : null,
                          validator: (value) {
                            final server = _serverError([
                              'employeeId',
                              'employee_id',
                            ]);
                            if (server != null) return server;
                            if (widget.isEdit) return null;
                            return (value ?? '').trim().isEmpty
                                ? 'Employee ID is required'
                                : null;
                          },
                        ),
                        second: _Dropdown<Department>(
                          label: 'Department',
                          icon: Icons.apartment_rounded,
                          value: _department,
                          required: true,
                          enabled: !_saving,
                          items: Department.values,
                          labelOf: (department) => department.label,
                          error: _serverError(const ['department']),
                          emptyMessage: 'Department is required',
                          onChanged: (department) {
                            AdminLog.ui(
                              'Form department → ${department?.slug ?? 'none'}',
                            );
                            setState(() => _department = department);
                          },
                        ),
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Pair(
                        narrow: narrow,
                        first: _Dropdown<Designation>(
                          label: 'Designation',
                          icon: Icons.workspace_premium_outlined,
                          value: _designation,
                          required: true,
                          enabled: !_saving,
                          items: Designation.values,
                          labelOf: (designation) => designation.label,
                          error: _serverError(const ['designation']),
                          emptyMessage: 'Designation is required',
                          onChanged: (designation) {
                            AdminLog.ui(
                              'Form designation → ${designation?.slug ?? 'none'}',
                            );
                            setState(() => _designation = designation);
                          },
                        ),
                        second: _DateField(
                          // Keyed on the value: a FormField keeps its own
                          // state, so without this its validator would still
                          // be looking at the date from before the picker.
                          key: ValueKey<DateTime?>(_joiningDate),
                          label: 'Joining Date',
                          value: _joiningDate,
                          enabled: !_saving,
                          onTap: _pickJoiningDate,
                          error: _serverError(const [
                            'joiningDate',
                            'joining_date',
                          ]),
                          validator: (date) =>
                              date == null ? 'Joining date is required' : null,
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
                          enabled: !_saving,
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
                        second: _Dropdown<Shift>(
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
                            AdminLog.ui(
                              'Form shift → ${shift?.slug ?? 'none'}',
                            );
                            setState(() => _shift = shift);
                          },
                        ),
                      ),
                      // Status is set by the create payload and only becomes
                      // editable once the employee exists.
                      if (widget.isEdit) ...[
                        const SizedBox(height: AdminTokens.space4),
                        _Dropdown<AdminUserStatus>(
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
                      ],

                      // --- Address -------------------------------------------
                      const SizedBox(height: AdminTokens.space6),
                      _Section(
                        icon: Icons.place_outlined,
                        label: 'Address',
                        color: tokens.success,
                      ),
                      const SizedBox(height: AdminTokens.space4),
                      _Field(
                        controller: _address,
                        label: 'Address',
                        hint: 'Street, area, city and postcode',
                        icon: Icons.home_outlined,
                        enabled: !_saving,
                        maxLines: 3,
                        textCapitalization: TextCapitalization.sentences,
                        validator: (_) => _serverError(['address']),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _Footer(
              saving: _saving,
              submitLabel: widget.isEdit ? 'Save Changes' : 'Save Employee',
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
    this.helper,
    this.required = false,
    this.enabled = true,
    this.keyboardType,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.obscure = false,
    this.onToggleObscure,
    this.onChanged,
    this.maxLines = 1,
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
          obscureText: obscure,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textCapitalization: textCapitalization,
          onChanged: onChanged,
          maxLines: obscure ? 1 : maxLines,
          validator: validator,
          style: TextStyle(fontSize: 13.5, color: tokens.textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            helperText: helper,
            helperStyle: TextStyle(color: tokens.textMuted, fontSize: 11),
            // A multiline box aligns its icon to the first line.
            prefixIcon: Icon(icon, size: 18, color: tokens.textMuted),
            prefixIconConstraints: maxLines > 1
                ? const BoxConstraints(minWidth: 44, minHeight: 44)
                : null,
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
               _Label(label, required: true),
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
               ],
             ],
           );
         },
       );
}
