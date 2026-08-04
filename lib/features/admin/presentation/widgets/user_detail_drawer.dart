import 'package:flutter/material.dart';

import '../../domain/entities/admin_user.dart';
import '../state/view_state.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';
import 'admin_badges.dart';
import 'admin_states.dart';
import 'glass_card.dart';
import 'users_table.dart';

/// The right-side detail panel.
///
/// It slides in over the table on wide layouts and is presented as a full-height
/// sheet on mobile (see `UsersPage`), but the body is the same widget in both
/// cases so the two never drift.
class UserDetailPanel extends StatelessWidget {
  const UserDetailPanel({
    super.key,
    required this.user,
    required this.state,
    required this.error,
    required this.onClose,
    required this.onAction,
    required this.onRetry,
    this.showCloseButton = true,
  });

  final AdminUser user;
  final ViewState state;
  final String? error;
  final VoidCallback onClose;
  final void Function(UserRowAction action, AdminUser user) onAction;
  final VoidCallback onRetry;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(user: user, onClose: onClose, showCloseButton: showCloseButton),
        // Detail is fetched in the background while the row we already have is
        // on screen — a thin line rather than a spinner over real content.
        RefreshLine(visible: state.isLoading),
        Expanded(
          child: state.isFailed
              ? ErrorStateView(
                  compact: true,
                  title: 'Could not load this user',
                  message: error ?? 'Please try again.',
                  onRetry: onRetry,
                )
              : ListView(
                  padding: const EdgeInsets.all(AdminTokens.space5),
                  children: [
                    _IdentityCard(user: user),
                    const SizedBox(height: AdminTokens.space4),
                    _AccountCard(user: user),
                    const SizedBox(height: AdminTokens.space4),
                    _VerificationCard(user: user),
                    if (user.isEmployeeLike) ...[
                      const SizedBox(height: AdminTokens.space4),
                      _EmploymentCard(user: user),
                    ],
                    if (user.isCoach) ...[
                      const SizedBox(height: AdminTokens.space4),
                      _CoachingCard(user: user),
                    ],
                    const SizedBox(height: AdminTokens.space4),
                    _PermissionsCard(user: user, loading: state.isLoading),
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
                  onPressed: () => onAction(UserRowAction.delete, user),
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
                  onPressed: () => onAction(UserRowAction.edit, user),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit user'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.user,
    required this.onClose,
    required this.showCloseButton,
  });

  final AdminUser user;
  final VoidCallback onClose;
  final bool showCloseButton;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
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
              'User details',
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
    );
  }
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return SolidCard(
      child: Column(
        children: [
          AdminAvatar(user: user, size: 76),
          const SizedBox(height: AdminTokens.space4),
          Text(
            user.displayName,
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
            AdminFormat.text(user.email),
            textAlign: TextAlign.center,
            style: TextStyle(color: tokens.textMuted, fontSize: 13),
          ),
          const SizedBox(height: AdminTokens.space4),
          Wrap(
            spacing: AdminTokens.space2,
            runSpacing: AdminTokens.space2,
            alignment: WrapAlignment.center,
            children: [
              RoleChip(roleRaw: user.roleRaw),
              StatusBadge(user: user),
              MembershipChip(membership: user.membership),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      icon: Icons.person_outline_rounded,
      title: 'Profile',
      rows: [
        _DetailRow('Phone', AdminFormat.text(user.phone)),
        _DetailRow('Date of birth', AdminFormat.date(user.dateOfBirth)),
        _DetailRow('Gender', AdminFormat.text(user.gender)),
        _DetailRow('Blood group', AdminFormat.text(user.bloodGroup)),
        _DetailRow('Total bookings', AdminFormat.number(user.totalBookings)),
        _DetailRow('Joined', AdminFormat.date(user.joinedAt)),
        _DetailRow('Last active', AdminFormat.dateTime(user.lastActiveAt)),
      ],
    );
  }
}

class _VerificationCard extends StatelessWidget {
  const _VerificationCard({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      icon: Icons.verified_user_outlined,
      title: 'Verification',
      body: Wrap(
        spacing: AdminTokens.space2,
        runSpacing: AdminTokens.space2,
        children: [
          VerificationBadge(label: 'Email', verified: user.emailVerified),
          VerificationBadge(label: 'Phone', verified: user.phoneVerified),
        ],
      ),
    );
  }
}

class _EmploymentCard extends StatelessWidget {
  const _EmploymentCard({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    return _DetailCard(
      icon: Icons.badge_outlined,
      title: 'Employment',
      rows: [
        _DetailRow('Employee ID', AdminFormat.text(user.employeeId)),
        _DetailRow('Department', AdminFormat.text(user.department)),
      ],
    );
  }
}

class _CoachingCard extends StatelessWidget {
  const _CoachingCard({required this.user});

  final AdminUser user;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return _DetailCard(
      icon: Icons.sports_outlined,
      title: 'Coaching',
      rows: [
        _DetailRow(
          'Assigned location',
          AdminFormat.text(user.assignedLocation),
        ),
      ],
      body: user.assignedSports.isEmpty
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: AdminTokens.space3),
                Text(
                  'ASSIGNED SPORTS',
                  style: TextStyle(
                    color: tokens.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: AdminTokens.space2),
                Wrap(
                  spacing: AdminTokens.space2,
                  runSpacing: AdminTokens.space2,
                  children: user.assignedSports
                      .map((sport) => _Tag(label: sport))
                      .toList(),
                ),
              ],
            ),
    );
  }
}

class _PermissionsCard extends StatelessWidget {
  const _PermissionsCard({required this.user, required this.loading});

  final AdminUser user;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    if (user.permissions.isEmpty) {
      return _DetailCard(
        icon: Icons.lock_outline_rounded,
        title: 'Permissions',
        body: Text(
          loading
              ? 'Loading permissions…'
              : 'No permissions were returned for this user. Role-level access '
                    'is managed on the Roles & Permissions tab.',
          style: TextStyle(
            color: tokens.textMuted,
            fontSize: 12.5,
            height: 1.5,
          ),
        ),
      );
    }

    return _DetailCard(
      icon: Icons.lock_outline_rounded,
      title: 'Permissions',
      trailing: Text(
        '${user.permissions.length}',
        style: TextStyle(
          color: tokens.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: Wrap(
        spacing: AdminTokens.space2,
        runSpacing: AdminTokens.space2,
        children: user.permissions
            .map((slug) => _Tag(label: slug, mono: true))
            .toList(),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.icon,
    required this.title,
    this.rows = const [],
    this.body,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final List<_DetailRow> rows;
  final Widget? body;
  final Widget? trailing;

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
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: tokens.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
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

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);

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

class _Tag extends StatelessWidget {
  const _Tag({required this.label, this.mono = false});

  final String label;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AdminTokens.space3,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: tokens.surfaceAlt,
        borderRadius: BorderRadius.circular(AdminTokens.radiusSm),
        border: Border.all(color: tokens.border),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: tokens.textSecondary,
          fontSize: mono ? 11.5 : 12,
          fontWeight: FontWeight.w600,
          fontFamily: mono ? 'monospace' : null,
        ),
      ),
    );
  }
}
