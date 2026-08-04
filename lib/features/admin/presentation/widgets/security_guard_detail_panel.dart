import 'package:flutter/material.dart';

import '../../domain/entities/security_guard.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'admin_states.dart';
import 'glass_card.dart';
import 'security_guards_table.dart';

/// The right-side security guard detail panel.
///
/// Shows the row already in hand immediately, then fills in from
/// `GET /admin/security-guards/{id}` behind a thin progress line — the same
/// pattern as the employee detail panel.
class SecurityGuardDetailPanel extends StatelessWidget {
  const SecurityGuardDetailPanel({
    super.key,
    required this.guard,
    required this.state,
    required this.error,
    required this.onClose,
    required this.onAction,
    required this.onRetry,
    this.showCloseButton = true,
  });

  final SecurityGuard guard;
  final ViewState state;
  final String? error;
  final VoidCallback onClose;
  final void Function(SecurityGuardAction action, SecurityGuard guard) onAction;
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
                  'Security guard details',
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
                  title: 'Could not load this security guard',
                  message: error ?? 'Please try again.',
                  onRetry: onRetry,
                )
              : ListView(
                  padding: const EdgeInsets.all(AdminTokens.space5),
                  children: [
                    _IdentityCard(guard: guard),
                    const SizedBox(height: AdminTokens.space4),
                    _Card(
                      icon: Icons.person_outline_rounded,
                      title: 'Personal information',
                      rows: [
                        _Row('Full name', AdminFormat.text(guard.fullName)),
                        _Row('Email', AdminFormat.text(guard.email)),
                        _Row('Phone number', AdminFormat.text(guard.phone)),
                      ],
                    ),
                    const SizedBox(height: AdminTokens.space4),
                    _Card(
                      icon: Icons.shield_outlined,
                      title: 'Employment information',
                      rows: [
                        _Row('Guard ID', AdminFormat.text(guard.guardCode)),
                        _Row(
                          'License number',
                          AdminFormat.text(guard.licenseNumber),
                        ),
                        _Row(
                          'Assigned area',
                          guard.assignedArea == null
                              ? AdminFormat.dash
                              : guard.assignedAreaLabel,
                        ),
                        _Row(
                          'Shift',
                          guard.shiftRaw == null
                              ? AdminFormat.dash
                              : guard.shiftLabel,
                        ),
                        _Row(
                          'Joining date',
                          AdminFormat.date(guard.joiningDate),
                        ),
                        _Row('Salary', AdminFormat.currency(guard.salary)),
                        _Row('Status', AdminFormat.text(guard.statusLabel)),
                      ],
                    ),
                    const SizedBox(height: AdminTokens.space4),
                    _Card(
                      icon: Icons.stadium_outlined,
                      title: 'Complex information',
                      rows: [
                        _Row(
                          'Sport complex',
                          AdminFormat.text(guard.sportComplexName),
                        ),
                        _Row('City', AdminFormat.text(guard.sportComplexCity)),
                      ],
                    ),
                    const SizedBox(height: AdminTokens.space4),
                    _PasswordCard(guard: guard, onAction: onAction),
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
                  onPressed: () =>
                      onAction(SecurityGuardAction.delete, guard),
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
                  onPressed: () => onAction(SecurityGuardAction.edit, guard),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit guard'),
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
  const _IdentityCard({required this.guard});

  final SecurityGuard guard;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    // Through the vocabulary, so a row stored as `parking` still reads as
    // `Parking` and an unknown value is title-cased rather than shown raw.
    final area = guard.assignedArea == null ? '' : guard.assignedAreaLabel;

    return SolidCard(
      child: Column(
        children: [
          GuardAvatar(guard: guard, size: 76),
          const SizedBox(height: AdminTokens.space4),
          Text(
            guard.displayName,
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
            area.isEmpty
                ? AdminFormat.text(guard.email)
                : 'Security guard · $area',
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
              GuardCodeChip(guard: guard),
              GuardStatusBadge(guard: guard),
              GuardShiftChip(guard: guard, dense: false),
            ],
          ),
        ],
      ),
    );
  }
}

/// Password management, reachable from the drawer as well as the row menu.
class _PasswordCard extends StatelessWidget {
  const _PasswordCard({required this.guard, required this.onAction});

  final SecurityGuard guard;
  final void Function(SecurityGuardAction action, SecurityGuard guard) onAction;

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
            'emailed to the security guard.',
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
                      onAction(SecurityGuardAction.viewPassword, guard),
                  icon: const Icon(Icons.visibility_outlined, size: 17),
                  label: const Text('View'),
                ),
              ),
              const SizedBox(width: AdminTokens.space3),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      onAction(SecurityGuardAction.resetPassword, guard),
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
  const _Card({required this.icon, required this.title, this.rows = const []});

  final IconData icon;
  final String title;
  final List<_Row> rows;

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
