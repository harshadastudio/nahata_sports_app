import 'package:flutter/material.dart';

import '../../domain/entities/visitor_pass.dart';
import '../theme/admin_theme.dart';
import '../utils/admin_format.dart';

/// The colour and icon each lifecycle state carries, drawn from the console's
/// own semantic tokens so the module reads like the rest of the panel.
extension VisitorPassStatusStyle on AdminTokens {
  Color visitorStatusColor(VisitorPassStatus? status) {
    switch (status) {
      case VisitorPassStatus.pending:
        // Issued but not yet used — waiting on something, like every other
        // pending state in the console.
        return warning;
      case VisitorPassStatus.checkedIn:
        return success;
      case VisitorPassStatus.checkedOut:
        // Completed, not failed: the visit finished as it should have.
        return info;
      case VisitorPassStatus.expired:
        return textMuted;
      case VisitorPassStatus.invalid:
        return danger;
      case null:
        return textMuted;
    }
  }

  IconData visitorStatusIcon(VisitorPassStatus? status) {
    switch (status) {
      case VisitorPassStatus.pending:
        return Icons.hourglass_empty_rounded;
      case VisitorPassStatus.checkedIn:
        return Icons.login_rounded;
      case VisitorPassStatus.checkedOut:
        return Icons.logout_rounded;
      case VisitorPassStatus.expired:
        return Icons.schedule_rounded;
      case VisitorPassStatus.invalid:
        return Icons.block_rounded;
      case null:
        return Icons.help_outline_rounded;
    }
  }
}

/// A dot-and-label pill for a pass's state.
class VisitorPassStatusChip extends StatelessWidget {
  const VisitorPassStatusChip({
    super.key,
    required this.pass,
    this.dense = false,
  });

  final VisitorPass pass;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return VisitorStatusChip(
      status: pass.status,
      label: pass.statusLabel,
      dense: dense,
    );
  }
}

/// The same pill, for a status that is not attached to a loaded row (a scan
/// result, for instance).
class VisitorStatusChip extends StatelessWidget {
  const VisitorStatusChip({
    super.key,
    required this.status,
    this.label,
    this.dense = false,
  });

  final VisitorPassStatus? status;

  /// Falls back to the status's own label; used to show a raw value the app
  /// does not recognise rather than swallowing it.
  final String? label;

  final bool dense;

  @override
  Widget build(BuildContext context) {
    final tokens = AdminTheme.of(context);
    final color = tokens.visitorStatusColor(status);

    final text = (label ?? '').trim().isNotEmpty
        ? label!.trim()
        : (status?.label ?? AdminFormat.dash);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AdminTokens.space2 : AdminTokens.space3,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AdminTokens.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            tokens.visitorStatusIcon(status),
            size: dense ? 11 : 13,
            color: color,
          ),
          const SizedBox(width: AdminTokens.space2),
          Flexible(
            child: Text(
              text,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: dense ? 11 : 12,
                fontWeight: FontWeight.w600,
                height: 1.1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
