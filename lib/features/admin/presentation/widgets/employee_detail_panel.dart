import 'package:flutter/material.dart';

import '../../domain/entities/employee.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'admin_states.dart';
import 'employees_table.dart';
import 'glass_card.dart';

/// The right-side employee detail panel.
///
/// Shows the row already in hand immediately, then fills in from
/// `GET /admin/employees/{id}` behind a thin progress line — the same pattern
/// as the user detail drawer.
class EmployeeDetailPanel extends StatelessWidget {
  const EmployeeDetailPanel({
    super.key,
    required this.employee,
    required this.state,
    required this.error,
    required this.onClose,
    required this.onAction,
    required this.onRetry,
    this.showCloseButton = true,
  });

  final Employee employee;
  final ViewState state;
  final String? error;
  final VoidCallback onClose;
  final void Function(EmployeeAction action, Employee employee) onAction;
  final VoidCallback onRetry;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(
            AdminTokens.space5,
            AdminTokens.space4,
            AdminTokens.space3,
            AdminTokens.space4,
          ),
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border(bottom: BorderSide(color: tokens.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Employee details',
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (showCloseButton)
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  tooltip: 'Close',
                  color: tokens.textMuted,
                ),
            ],
          ),
        ),
        RefreshLine(visible: state.isLoading),
        Expanded(
          child: state.isFailed
              ? ErrorStateView(
                  compact: true,
                  title: 'Could not load this employee',
                  message: error ?? 'Please try again.',
                  onRetry: onRetry,
                )
              : ListView(
                  padding: const EdgeInsets.all(AdminTokens.space5),
                  children: [
                    _IdentityCard(employee: employee),
                    const SizedBox(height: AdminTokens.space4),
                    _Card(
                      icon: Icons.person_outline_rounded,
                      title: 'Basic information',
                      rows: [
                        _Row(
                          'Employee name',
                          AdminFormat.text(employee.fullName),
                        ),
                        _Row('Email', AdminFormat.text(employee.email)),
                        _Row('Phone', AdminFormat.text(employee.phone)),
                        _Row(
                          'Employee ID',
                          AdminFormat.text(employee.employeeCode),
                        ),
                        _Row('Status', AdminFormat.text(employee.statusLabel)),
                      ],
                    ),
                    const SizedBox(height: AdminTokens.space4),
                    _Card(
                      icon: Icons.work_outline_rounded,
                      title: 'Employment information',
                      rows: [
                        _Row(
                          'Department',
                          employee.departmentRaw == null
                              ? AdminFormat.dash
                              : employee.departmentLabel,
                        ),
                        _Row(
                          'Designation',
                          employee.designationRaw == null
                              ? AdminFormat.dash
                              : employee.designationLabel,
                        ),
                        _Row(
                          'Joining date',
                          AdminFormat.date(employee.joiningDate),
                        ),
                        _Row(
                          'Shift',
                          employee.shiftRaw == null
                              ? AdminFormat.dash
                              : employee.shiftLabel,
                        ),
                        _Row('Salary', AdminFormat.currency(employee.salary)),
                      ],
                    ),
                    const SizedBox(height: AdminTokens.space4),
                    _Card(
                      icon: Icons.stadium_outlined,
                      title: 'Complex information',
                      rows: [
                        _Row(
                          'Assigned sport complex',
                          AdminFormat.text(employee.sportComplexName),
                        ),
                      ],
                    ),
                    if ((employee.address ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: AdminTokens.space4),
                      _Card(
                        icon: Icons.place_outlined,
                        title: 'Address',
                        body: Text(
                          employee.address!.trim(),
                          style: TextStyle(
                            color: tokens.textPrimary,
                            fontSize: 12.5,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: AdminTokens.space4),
                    _PasswordCard(employee: employee, onAction: onAction),
                    const SizedBox(height: AdminTokens.space6),
                  ],
                ),
        ),
        Container(
          padding: const EdgeInsets.all(AdminTokens.space4),
          decoration: BoxDecoration(
            color: tokens.surface,
            border: Border(top: BorderSide(color: tokens.border)),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onAction(EmployeeAction.delete, employee),
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tokens.danger,
                    side: BorderSide(
                      color: tokens.danger.withValues(alpha: 0.4),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: () => onAction(EmployeeAction.edit, employee),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit employee'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      child: Column(
        children: [
          EmployeeAvatar(employee: employee, size: 76),
          const SizedBox(height: AdminTokens.space4),
          Text(
            employee.displayName,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: tokens.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: AdminTokens.space1),
          Text(
            employee.designationRaw == null
                ? AdminFormat.text(employee.email)
                : '${employee.designationLabel} · ${employee.departmentLabel}',
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.textMuted, fontSize: 13),
          ),
          const SizedBox(height: AdminTokens.space4),
          Wrap(
            spacing: AdminTokens.space2,
            runSpacing: AdminTokens.space2,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              EmployeeCodeChip(employee: employee),
              EmployeeStatusBadge(employee: employee),
              ShiftChip(employee: employee, dense: false),
            ],
          ),
        ],
      ),
    );
  }
}

/// Password management, reachable from the drawer as well as the row menu.
class _PasswordCard extends StatelessWidget {
  const _PasswordCard({required this.employee, required this.onAction});

  final Employee employee;
  final void Function(EmployeeAction action, Employee employee) onAction;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.key_outlined, size: 17, color: tokens.accent),
              const SizedBox(width: AdminTokens.space2),
              Text(
                'Sign-in credentials',
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: AdminTokens.space2),
          Text(
            'Read the current temporary password, or set a new one and have it '
            'emailed to the employee.',
            style: TextStyle(
              color: tokens.textMuted,
              fontSize: 11.5,
              height: 1.45,
            ),
          ),
          const SizedBox(height: AdminTokens.space3),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      onAction(EmployeeAction.viewPassword, employee),
                  icon: const Icon(Icons.visibility_outlined, size: 17),
                  label: const Text('View'),
                ),
              ),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      onAction(EmployeeAction.resetPassword, employee),
                  icon: const Icon(Icons.lock_reset_rounded, size: 17),
                  label: const Text('Reset'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.icon,
    required this.title,
    this.rows = const [],
    this.body,
  });

  final IconData icon;
  final String title;
  final List<_Row> rows;
  final Widget? body;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      padding: const EdgeInsets.all(AdminTokens.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 17, color: tokens.accent),
              const SizedBox(width: AdminTokens.space2),
              Text(
                title,
                style: TextStyle(
                  color: tokens.textPrimary,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: AdminTokens.space3),
            ...rows,
          ],
          if (body != null) ...[
            const SizedBox(height: AdminTokens.space3),
            body!,
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: TextStyle(color: tokens.textMuted, fontSize: 12.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: value == AdminFormat.dash
                    ? tokens.textMuted
                    : tokens.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
