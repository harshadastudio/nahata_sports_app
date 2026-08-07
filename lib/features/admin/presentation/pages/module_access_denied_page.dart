import 'package:flutter/material.dart';

import '../navigation/admin_destination.dart';
import '../theme/admin_theme.dart';
import '../widgets/glass_card.dart';

/// Shown when a module is reached that `data.user.permissions` does not grant.
///
/// The sidebar already hides those entries, so this is the second line of
/// defence — a deep link, a restored destination or a permission revoked while
/// the console was open all land here instead of on data the user may not see.
class ModuleAccessDeniedPage extends StatelessWidget {
  const ModuleAccessDeniedPage({super.key, required this.destination});

  final AdminDestination destination;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AdminTokens.space6),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: GlassCard(
            padding: const EdgeInsets.all(AdminTokens.space8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: tokens.danger.withValues(alpha: 0.12),
                  ),
                  child: Icon(
                    Icons.lock_outline_rounded,
                    size: 28,
                    color: tokens.danger,
                  ),
                ),
                const SizedBox(height: AdminTokens.space5),
                Text(
                  'No access to ${destination.label}',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: tokens.textPrimary),
                ),
                const SizedBox(height: AdminTokens.space3),
                Text(
                  'Your account does not have permission to view this module. '
                  'Ask an administrator if you need it.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: tokens.textSecondary,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}