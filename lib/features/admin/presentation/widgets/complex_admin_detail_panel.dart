import 'package:flutter/material.dart';

import '../../domain/entities/complex_admin.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'complex_admins_table.dart';
import 'glass_card.dart';

/// The right-side detail panel for a complex admin.
///
/// The list row already carries every field shown here, so this opens
/// instantly — there is no detail endpoint to wait on.
class ComplexAdminDetailPanel extends StatelessWidget {
  const ComplexAdminDetailPanel({
    super.key,
    required this.admin,
    required this.onClose,
    required this.onAction,
    this.showCloseButton = true,
  });

  final ComplexAdmin admin;
  final VoidCallback onClose;
  final void Function(ComplexAdminAction action, ComplexAdmin admin) onAction;
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
                  'Complex admin',
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
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AdminTokens.space5),
            children: [
              _IdentityCard(admin: admin),
              const SizedBox(height: AdminTokens.space4),
              _Card(
                icon: Icons.contact_page_outlined,
                title: 'Contact',
                rows: [
                  _Row('Email', AdminFormat.text(admin.email)),
                  _Row('Phone', AdminFormat.text(admin.phone)),
                ],
              ),
              const SizedBox(height: AdminTokens.space4),
              _Card(
                icon: Icons.stadium_outlined,
                title: 'Assignment',
                rows: [
                  _Row(
                    'Sport complex',
                    AdminFormat.text(admin.sportComplexName),
                  ),
                  _Row('City', AdminFormat.text(admin.city)),
                ],
              ),
              const SizedBox(height: AdminTokens.space4),
              _Card(
                icon: Icons.info_outline_rounded,
                title: 'Account',
                rows: [
                  _Row('Status', AdminFormat.text(admin.statusLabel)),
                  _Row('Created', AdminFormat.date(admin.createdAt)),
                ],
              ),
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
                  onPressed: () => onAction(ComplexAdminAction.delete, admin),
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
                  onPressed: () => onAction(ComplexAdminAction.edit, admin),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit admin'),
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
  const _IdentityCard({required this.admin});

  final ComplexAdmin admin;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      child: Column(
        children: [
          ComplexAdminAvatar(admin: admin, size: 76),
          const SizedBox(height: AdminTokens.space4),
          Text(
            admin.displayName,
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
            admin.venueLabel.isEmpty
                ? AdminFormat.text(admin.email)
                : admin.venueLabel,
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.textMuted, fontSize: 13),
          ),
          const SizedBox(height: AdminTokens.space4),
          ComplexAdminStatusBadge(admin: admin),
        ],
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.icon, required this.title, required this.rows});

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
          const SizedBox(height: AdminTokens.space3),
          ...rows,
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
            width: 118,
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
