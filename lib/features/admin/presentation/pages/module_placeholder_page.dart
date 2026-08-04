import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/admin_log.dart';
import '../navigation/admin_destination.dart';
import '../state/admin_shell_controller.dart';
import '../theme/admin_theme.dart';
import '../widgets/glass_card.dart';

/// Shown for a sidebar entry whose module is not built yet.
///
/// Deliberately explicit rather than a fake screen full of sample rows: an
/// empty table with invented data is worse than an honest "not wired up yet",
/// and it keeps the "no placeholder data" rule intact.
class ModulePlaceholderPage extends StatelessWidget {
  const ModulePlaceholderPage({super.key, required this.destination});

  final AdminDestination destination;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AdminTokens.space6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: GlassCard(
            padding: const EdgeInsets.all(AdminTokens.space8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AdminTokens.radiusLg),
                    gradient: LinearGradient(
                      colors: [
                        tokens.accent.withValues(alpha: 0.18),
                        tokens.accent.withValues(alpha: 0.05),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Icon(
                    destination.activeIcon,
                    size: 30,
                    color: tokens.accent,
                  ),
                ),
                const SizedBox(height: AdminTokens.space5),
                Text(
                  destination.label,
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: tokens.textPrimary),
                ),
                const SizedBox(height: AdminTokens.space2),
                Text(
                  destination.subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AdminTokens.space5),
                Container(
                  padding: const EdgeInsets.all(AdminTokens.space4),
                  decoration: BoxDecoration(
                    color: tokens.surfaceAlt,
                    borderRadius: BorderRadius.circular(AdminTokens.radiusMd),
                    border: Border.all(color: tokens.border),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.construction_rounded,
                        size: 18,
                        color: tokens.warning,
                      ),
                      const SizedBox(width: AdminTokens.space3),
                      Expanded(
                        child: Text(
                          'This module has not been built yet. The console is '
                          'structured so it can be added without touching the '
                          'existing layers — a page, a repository and one entry '
                          'in the sidebar.',
                          style: TextStyle(
                            color: tokens.textSecondary,
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AdminTokens.space6),
                FilledButton.icon(
                  onPressed: () {
                    AdminLog.ui('Placeholder → Users module');
                    context.read<AdminShellController>().go(
                      AdminDestination.users,
                    );
                  },
                  icon: const Icon(Icons.manage_accounts_rounded, size: 18),
                  label: const Text('Go to Users, Roles & Permissions'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
